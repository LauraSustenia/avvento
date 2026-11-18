-- Eseguire nel SQL Editor dopo 001_profiles.sql. Nessun punteggio viene modificato.
begin;
create table if not exists calendar_private.leagues (
  code text primary key check (code ~ '^[0-9]{4}$'),
  id uuid not null default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 50),
  place text not null default 'bosco',
  created_at timestamptz not null default now()
);
alter table calendar_private.leagues add column if not exists id uuid not null default gen_random_uuid();
alter table calendar_private.leagues add column if not exists place text not null default 'bosco';
create unique index if not exists leagues_id_idx on calendar_private.leagues(id);
alter table calendar_private.leagues drop constraint if exists leagues_place_check;
alter table calendar_private.leagues add constraint leagues_place_check check(place in ('cassa','bosco','palude','prato','siepe','fiume'));
create table if not exists calendar_private.league_members (
  league_code text not null references calendar_private.leagues(code) on delete cascade,
  profile_id uuid not null references calendar_private.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (league_code, profile_id)
);
create index if not exists league_members_profile_idx on calendar_private.league_members(profile_id);
alter table calendar_private.leagues enable row level security;
alter table calendar_private.league_members enable row level security;
revoke all on calendar_private.leagues, calendar_private.league_members from public, anon, authenticated;
drop function if exists public.calendar_leagues(text,text,text);
create or replace function public.calendar_leagues(
  p_action text, p_code text default null, p_name text default null,
  p_league_id uuid default null, p_place text default null
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_profile uuid;
  v_code text := btrim(coalesce(p_code,''));
  v_id uuid;
  v_league calendar_private.leagues%rowtype;
  v_result jsonb;
  v_rows jsonb;
begin
  if p_action is null or p_action not in ('search','list','create','join','leave','ranking') then
    return jsonb_build_object('error','Operazione non valida.');
  end if;
  -- La ricerca pubblica espone il nome e il luogo, mai il codice per iscriversi.
  if p_action='search' then
    if char_length(coalesce(p_name,''))>50 then return jsonb_build_object('error','Cerca con un nome di massimo 50 caratteri.'); end if;
    select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'name',l.name,'place',l.place,
      'members_count',(select count(*) from calendar_private.league_members m where m.league_code=l.code)) order by l.name,l.id),'[]'::jsonb)
    into v_result from (select * from calendar_private.leagues where strpos(lower(name),lower(btrim(coalesce(p_name,''))))>0 order by name,id limit 30) l;
    return jsonb_build_object('leagues',v_result);
  end if;
  if p_action in ('join','leave','ranking') and p_league_id is null then
    return jsonb_build_object('error','Seleziona prima una lega dall’elenco.');
  end if;
  if p_action in ('create','join') and v_code !~ '^[0-9]{4}$' then
    return jsonb_build_object('error','Inserisci le quattro cifre del codice della lega.');
  end if;
  -- Consultare una classifica non iscrive il visitatore e non richiede un account.
  if p_action='ranking' then
    select * into v_league from calendar_private.leagues where id=p_league_id;
    if not found then return jsonb_build_object('error','Non trovo questa lega. Prova a cercarla di nuovo.'); end if;
    select coalesce(jsonb_agg(jsonb_build_object('name',p.name,'animal',p.animal,'score',p.score)
      order by p.score desc,p.name,p.id),'[]'::jsonb) into v_rows
    from calendar_private.league_members m join calendar_private.profiles p on p.id=m.profile_id where m.league_code=v_league.code;
    return jsonb_build_object('league',jsonb_build_object('id',v_league.id,'name',v_league.name,'place',v_league.place),'rows',v_rows);
  end if;
  select profile_id into v_profile from calendar_private.memberships where user_id=auth.uid();
  if v_profile is null then return jsonb_build_object('error','Accedi con il tuo codice personale per partecipare a una lega.'); end if;
  if p_action='create' then
    if p_name is null or char_length(btrim(p_name)) not between 2 and 50 then return jsonb_build_object('error','Il nome della lega deve contenere da 2 a 50 caratteri.'); end if;
    if p_place is null or p_place not in ('cassa','bosco','palude','prato','siepe','fiume') then return jsonb_build_object('error','Scegli uno dei sei luoghi per la lega.'); end if;
    insert into calendar_private.leagues(code,name,place) values(v_code,btrim(p_name),p_place)
      on conflict(code) do nothing returning id into v_id;
    if v_id is null then return jsonb_build_object('error','Questo codice è già usato da un’altra lega. Scegline un altro.'); end if;
    insert into calendar_private.league_members(league_code,profile_id) values(v_code,v_profile);
  elsif p_action='join' then
    select code into v_code from calendar_private.leagues where id=p_league_id and code=v_code;
    if not found then return jsonb_build_object('error','Il codice non corrisponde alla lega selezionata.'); end if;
    insert into calendar_private.league_members(league_code,profile_id) values(v_code,v_profile) on conflict do nothing;
  elsif p_action='leave' then
    delete from calendar_private.league_members m using calendar_private.leagues l
      where m.league_code=l.code and l.id=p_league_id and m.profile_id=v_profile;
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'code',l.code,'name',l.name,'place',l.place,
      'members_count',(select count(*) from calendar_private.league_members c where c.league_code=l.code)) order by l.name,l.id),'[]'::jsonb)
  into v_result from calendar_private.leagues l join calendar_private.league_members m on m.league_code=l.code where m.profile_id=v_profile;
  return jsonb_build_object('leagues',v_result,'code',case when p_action='create' then v_code else null end);
end;
$$;
revoke all on function public.calendar_leagues(text,text,text,uuid,text) from public;
grant execute on function public.calendar_leagues(text,text,text,uuid,text) to anon, authenticated;
commit;

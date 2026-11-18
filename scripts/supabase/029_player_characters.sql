-- Sei personaggi definitivi. Eseguire dopo 001_profiles.sql.
-- Conserva account, codici, punteggi, preferenze e progressi.
-- Uccellino diventa Martin pescatore; Insettino diventa Emys.
begin;
alter table calendar_private.profiles drop constraint if exists profiles_animal_check;
update calendar_private.profiles set animal=case animal when 'uccellino' then 'martin-pescatore' when 'insettino' then 'emys' else animal end where animal in ('uccellino','insettino');
alter table calendar_private.profiles add constraint profiles_animal_check check (animal in ('emys','tritone','cicogna','martin-pescatore','riccio','tasso'));
create or replace function public.calendar_profile(
  p_action text,
  p_name text default null,
  p_animal text default null,
  p_code text default null,
  p_show_in_leaderboard boolean default null
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_profile calendar_private.profiles%rowtype;
  v_code text := upper(coalesce(p_code,''));
  v_hash text;
  v_count integer;
begin
  if v_user is null then return jsonb_build_object('error','Accedi di nuovo con il tuo codice.'); end if;
  if p_action not in ('read','create','recover','update','change_code','logout') or p_action is null then
    return jsonb_build_object('error','Operazione non valida.');
  end if;

  if p_action in ('create','recover','change_code') then
    -- Il risultato di errore viene restituito, non sollevato: il contatore resta salvato.
    insert into calendar_private.attempts as a(user_id, attempts) values(v_user, 1)
    on conflict(user_id) do update set
      attempts = case when a.started_at < now()-interval '15 minutes' then 1 else a.attempts+1 end,
      started_at = case when a.started_at < now()-interval '15 minutes' then now() else a.started_at end
    returning attempts into v_count;
    if v_count > 10 then return jsonb_build_object('error','Troppi tentativi. Riprova tra 15 minuti.'); end if;
    if v_code !~ '^[A-Z0-9!@#$%&*+?_-]{10}$' then return jsonb_build_object('error','Il codice deve avere 10 caratteri: lettere, numeri o simboli ! @ # $ % & * + ? _ -.'); end if;
    v_hash := encode(extensions.digest(v_code, 'sha256'),'hex');
  end if;
  if p_action in ('create','update') and
    (p_name is null or char_length(btrim(p_name)) not between 2 and 40 or p_animal is null or p_animal not in ('emys','tritone','cicogna','martin-pescatore','riccio','tasso')) then
    return jsonb_build_object('error','Controlla nome e animale.');
  end if;

  select p.* into v_profile from calendar_private.profiles p
    join calendar_private.memberships m on m.profile_id=p.id where m.user_id=v_user;
  if p_action = 'logout' then
    delete from calendar_private.memberships where user_id=v_user;
    return jsonb_build_object('profile', null);
  elsif p_action = 'create' then
    if v_profile.id is not null then return jsonb_build_object('error','Hai già un profilo su questo dispositivo. Esci prima di crearne un altro.'); end if;
    begin
      insert into calendar_private.profiles(name,animal,code_hash,show_in_leaderboard) values(btrim(p_name),p_animal,v_hash,coalesce(p_show_in_leaderboard,false)) returning * into v_profile;
    exception when unique_violation then return jsonb_build_object('error','Questo codice è già utilizzato. Scegline un altro.'); end;
    insert into calendar_private.memberships(user_id,profile_id) values(v_user,v_profile.id);
  elsif p_action = 'recover' then
    select * into v_profile from calendar_private.profiles where code_hash=v_hash for update;
    if v_profile.id is null then return jsonb_build_object('error','Codice non riconosciuto. Controllalo e riprova.'); end if;
    insert into calendar_private.memberships(user_id,profile_id) values(v_user,v_profile.id)
      on conflict(user_id) do update set profile_id=excluded.profile_id;
  elsif p_action in ('update','change_code') then
    if v_profile.id is null then return jsonb_build_object('error','Accedi di nuovo con il tuo codice.'); end if;
    -- Serializza recupero e cambio codice per revocare correttamente gli altri dispositivi.
    perform 1 from calendar_private.profiles where id=v_profile.id for update;
    if not exists(select 1 from calendar_private.memberships where user_id=v_user and profile_id=v_profile.id) then
      return jsonb_build_object('error','Accedi di nuovo con il tuo codice.');
    end if;
    if p_action = 'update' then
      update calendar_private.profiles set name=btrim(p_name),animal=p_animal,show_in_leaderboard=coalesce(p_show_in_leaderboard,show_in_leaderboard),updated_at=now() where id=v_profile.id returning * into v_profile;
    else
      begin
        update calendar_private.profiles set code_hash=v_hash,updated_at=now() where id=v_profile.id returning * into v_profile;
      exception when unique_violation then return jsonb_build_object('error','Questo codice è già utilizzato. Scegline un altro.'); end;
      delete from calendar_private.memberships where profile_id=v_profile.id and user_id<>v_user;
    end if;
  end if;
  if v_profile.id is null then return jsonb_build_object('profile',null); end if;
  return jsonb_build_object('profile',jsonb_build_object('id',v_profile.id,'name',v_profile.name,'animal',v_profile.animal,'score',v_profile.score,'show_in_leaderboard',v_profile.show_in_leaderboard));
end;
$$;
revoke all on function public.calendar_profile(text,text,text,text,boolean) from public, anon;
grant execute on function public.calendar_profile(text,text,text,text,boolean) to authenticated;

commit;

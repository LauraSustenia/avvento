-- Eseguire dopo 001_profiles.sql. Include anche 002 se non era stato eseguito.
begin;
-- Eseguire DOPO 001_profiles.sql. Non modifica né elimina i profili esistenti.

create table if not exists calendar_private.calendar_settings (
  singleton boolean primary key default true check(singleton),
  year integer not null default 2026 check(year between 2026 and 2100),
  preview boolean not null default true,
  correct_points integer not null default 10 check(correct_points>=0),
  wrong_points integer not null default -2 check(wrong_points<=0),
  recovery_points integer not null default 5 check(recovery_points>=0)
);
insert into calendar_private.calendar_settings(singleton) values(true) on conflict do nothing;
create table if not exists calendar_private.calendar_days (
  day integer primary key check(day between 1 and 24),
  name text not null,
  challenge jsonb not null check(challenge->>'type'='quiz'),
  area_description text not null,
  area_image text
);
create table if not exists calendar_private.day_progress (
  profile_id uuid not null references calendar_private.profiles(id) on delete cascade,
  year integer not null,
  day integer not null references calendar_private.calendar_days(day),
  attempts integer not null default 0 check(attempts between 0 and 2),
  status text not null default 'new' check(status in ('new','retry','correct','recovered','failed')),
  last_answer integer,
  last_request uuid,
  last_delta integer not null default 0,
  day_points integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key(profile_id,year,day)
);
alter table calendar_private.calendar_settings enable row level security;
alter table calendar_private.calendar_days enable row level security;
alter table calendar_private.day_progress enable row level security;
revoke all on all tables in schema calendar_private from public,anon,authenticated;

create or replace function public.calendar_day(p_day integer,p_answer integer default null,p_request uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_settings calendar_private.calendar_settings%rowtype;
  v_day calendar_private.calendar_days%rowtype;
  v_profile calendar_private.profiles%rowtype;
  v_progress calendar_private.day_progress%rowtype;
  v_correct boolean;
  v_delta integer;
  v_before integer;
begin
  select * into v_settings from calendar_private.calendar_settings where singleton=true;
  select * into v_day from calendar_private.calendar_days where day=p_day;
  if v_day.day is null then return jsonb_build_object('error','Giornata non disponibile.'); end if;
  if not v_settings.preview and (clock_timestamp() at time zone 'Europe/Rome')::date < make_date(v_settings.year,12,p_day) then
    return jsonb_build_object('locked',true,'preview',false,'opens_on',make_date(v_settings.year,12,p_day));
  end if;
  -- Un unico ordine dei blocchi: profilo, poi giornata. Evita conteggi doppi in richieste concorrenti.
  select p.* into v_profile from calendar_private.profiles p join calendar_private.memberships m on m.profile_id=p.id
    where m.user_id=auth.uid() for update of p;
  if v_profile.id is not null then
    select * into v_progress from calendar_private.day_progress where profile_id=v_profile.id and year=v_settings.year and day=p_day;
  end if;
  if p_answer is not null then
    if v_profile.id is null then return jsonb_build_object('error','Entra nel tuo account per salvare il risultato.','login_required',true); end if;
    if p_request is null or p_answer < 0 or p_answer >= jsonb_array_length(v_day.challenge->'options') then
      return jsonb_build_object('error','Scegli una risposta valida.');
    end if;
    if coalesce(v_progress.attempts,0)<2 and coalesce(v_progress.status,'new') in ('new','retry') and v_progress.last_request is distinct from p_request then
      v_correct := p_answer=(v_day.challenge->>'correct_index')::integer;
      v_before := v_profile.score;
      v_delta := case when v_correct then case when coalesce(v_progress.attempts,0)=0 then v_settings.correct_points else v_settings.recovery_points end else v_settings.wrong_points end;
      update calendar_private.profiles set score=greatest(0,score+v_delta),updated_at=now() where id=v_profile.id returning * into v_profile;
      v_delta := v_profile.score-v_before;
      insert into calendar_private.day_progress as dp(profile_id,year,day,attempts,status,last_answer,last_request,last_delta,day_points)
      values(v_profile.id,v_settings.year,p_day,coalesce(v_progress.attempts,0)+1,
        case when v_correct then case when coalesce(v_progress.attempts,0)=0 then 'correct' else 'recovered' end
        else case when coalesce(v_progress.attempts,0)=0 then 'retry' else 'failed' end end,
        p_answer,p_request,v_delta,coalesce(v_progress.day_points,0)+v_delta)
      on conflict(profile_id,year,day) do update set attempts=excluded.attempts,status=excluded.status,last_answer=excluded.last_answer,
        last_request=excluded.last_request,last_delta=excluded.last_delta,day_points=excluded.day_points,updated_at=now()
      returning * into v_progress;
    end if;
  end if;
  return jsonb_build_object(
    'locked',false,'preview',v_settings.preview,'year',v_settings.year,
    'rules',jsonb_build_object('correct_points',v_settings.correct_points,'wrong_points',v_settings.wrong_points,'recovery_points',v_settings.recovery_points),
    'challenge',v_day.challenge-'correct_index'-'explanation',
    'name',v_day.name,'login_required',v_profile.id is null,
    'profile',case when v_profile.id is not null then jsonb_build_object('id',v_profile.id,'name',v_profile.name,'animal',v_profile.animal,'score',v_profile.score) else null end,
    'progress',case when v_progress.attempts>0 then jsonb_build_object('attempts',v_progress.attempts,'status',v_progress.status,'last_answer',v_progress.last_answer,'last_delta',v_progress.last_delta,'day_points',v_progress.day_points) else null end,
    'explanation',case when v_progress.attempts>0 then v_day.challenge->>'explanation' else null end,
    'area',case when v_progress.attempts>0 then jsonb_build_object('name',v_day.name,'description',v_day.area_description,'image',v_day.area_image) else null end
  );
end;
$$;
revoke all on function public.calendar_day(integer,integer,uuid) from public,anon,authenticated;
grant execute on function public.calendar_day(integer,integer,uuid) to anon,authenticated;

-- Le 24 giornate dimostrative vengono inserite dallo script di preparazione qui sotto.
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(1,'Bosco di S. Lucia','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Bosco di S. Lucia è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(2,'Fascia boscata dell’Interporto','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Fascia boscata dell’Interporto è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(3,'Cassa di espansione Ponte Alto','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Cassa di espansione Ponte Alto è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(4,'Madonna dei Prati','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Madonna dei Prati è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(5,'Ex Zuccherificio di Argelato','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Ex Zuccherificio di Argelato è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(6,'Cassa di espansione del Fiume Panaro','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Cassa di espansione del Fiume Panaro è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(7,'Valli mirandolesi','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Valli mirandolesi è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(8,'Cassa di espansione Dosolo','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Cassa di espansione Dosolo è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(9,'Ex Risaia di Bentivoglio','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Ex Risaia di Bentivoglio è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(10,'Golena San Vitale','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Golena San Vitale è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(11,'Nodo ecologico di Via dei Tigli','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Nodo ecologico di Via dei Tigli è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(12,'Bisana','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Bisana è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(13,'Vasche Ex Zuccherificio','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Vasche Ex Zuccherificio è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(14,'Manzolino Tivoli','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Manzolino Tivoli è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(15,'Torrazzuolo','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Torrazzuolo è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(16,'Collegio di Spagna','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Collegio di Spagna è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(17,'Cassa di espansione del Torrente Samoggia','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Cassa di espansione del Torrente Samoggia è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(18,'Le Meleghine','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Le Meleghine è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(19,'Boscovivo','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Boscovivo è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(20,'Parco Lamborghini','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Parco Lamborghini è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(21,'Casone del Partigiano','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Casone del Partigiano è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(22,'Torrente Idice','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Torrente Idice è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(23,'Canale Collettore delle Acque Alte','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di Canale Collettore delle Acque Alte è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;
insert into calendar_private.calendar_days(day,name,challenge,area_description,area_image) values(24,'La Bora','{"type":"quiz","placeholder":true,"title":"Durante una visita in un’area naturale, quale comportamento scegli?","options":["Raccogliere fiori per portarli a casa.","Restare sui percorsi consentiti e osservare gli animali senza disturbarli.","Avvicinarsi agli animali per dar loro da mangiare."],"correct_index":1,"explanation":"Restare sui percorsi consentiti e osservare a distanza aiuta a limitare il disturbo agli animali e a proteggere la vegetazione. Segui sempre le indicazioni specifiche dell’area."}'::jsonb,'La scheda di La Bora è in preparazione. Qui inseriremo la descrizione, le immagini e le informazioni utili per conoscere l’area.',null) on conflict(day) do nothing;

-- Estensione delle prove: la preparazione include anche 002 per chi non l'ha ancora eseguito.
alter table calendar_private.calendar_days drop constraint if exists calendar_days_challenge_check;
alter table calendar_private.calendar_days drop constraint if exists calendar_days_challenge_type_check;
alter table calendar_private.calendar_days add constraint calendar_days_challenge_type_check check(challenge->>'type' in ('quiz','matching','mystery','audio','sequence','find'));
alter table calendar_private.calendar_days add column if not exists area_url text;
create table if not exists calendar_private.game_results(
  profile_id uuid not null references calendar_private.profiles(id) on delete cascade,
  year integer not null,
  day integer not null references calendar_private.calendar_days(day),
  version text not null,
  attempts integer not null check(attempts between 1 and 2),
  best_score integer not null check(best_score between -2 and 10),
  last_score integer not null,
  day_points integer not null,
  last_delta integer not null,
  last_request uuid,
  closed boolean not null,
  updated_at timestamptz not null default now(),
  primary key(profile_id,year,day,version)
);
alter table calendar_private.game_results enable row level security;
revoke all on all tables in schema calendar_private from public,anon,authenticated;

create or replace function calendar_private.score_game(c jsonb,s jsonb) returns integer
language plpgsql immutable set search_path='' as $$
declare t text:=c->>'type'; a jsonb; i integer; n integer:=0; w integer:=0; v integer; count_items integer;
begin
  if jsonb_typeof(s) is distinct from 'object' then raise exception 'invalid_submission'; end if;
  if t in ('quiz','mystery','audio') then
    if jsonb_typeof(s->'choice') is distinct from 'number' or (s->>'choice') !~ '^[0-9]{1,2}$' then raise exception 'invalid_submission'; end if;
    v:=(s->>'choice')::integer;
    if v>=jsonb_array_length(c->'options') then raise exception 'invalid_submission'; end if;
    if c ? 'scores' then return(c->'scores'->>v)::integer; end if;
    return case when v=(c->>'correct_index')::integer then 10 else -2 end;
  end if;
  a:=case t when 'matching' then s->'pairs' when 'sequence' then s->'order' when 'find' then s->'targets' else null end;
  if jsonb_typeof(a) is distinct from 'array' then raise exception 'invalid_submission'; end if;
  count_items:=jsonb_array_length(a);
  if count_items>4 or (t<>'find' and count_items<>4) then raise exception 'invalid_submission'; end if;
  if exists(select 1 from jsonb_array_elements(a) e where jsonb_typeof(e) is distinct from 'number' or e::text !~ '^[0-9]{1,2}$') then raise exception 'invalid_submission'; end if;
  if (select count(distinct e::text) from jsonb_array_elements(a)e)<>count_items then raise exception 'invalid_submission'; end if;
  if count_items>0 then for i in 0..count_items-1 loop
    v:=(a->>i)::integer;
    if v<0 or v>=(case when t='find' then jsonb_array_length(c->'choices') else 4 end) then raise exception 'invalid_submission'; end if;
    if t='find' then
      if c->'solution' @> jsonb_build_array(v) then n:=n+1; else w:=w+1; end if;
    elsif v=(c->'solution'->>i)::integer then n:=n+1;
    end if;
  end loop; end if;
  return greatest(0,(n-w)*2)+case when n=4 and w=0 then 2 else 0 end;
end;
$$;
revoke all on function calendar_private.score_game(jsonb,jsonb) from public,anon,authenticated;

create or replace function public.calendar_game(p_day integer,p_submission jsonb default null,p_request uuid default null,p_finish boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
  cfg calendar_private.calendar_settings%rowtype;
  d calendar_private.calendar_days%rowtype;
  p calendar_private.profiles%rowtype;
  r calendar_private.game_results%rowtype;
  v_version text;
  score integer; best integer; before_score integer; next_total integer; delta integer;
  feedback text;
begin
  select * into cfg from calendar_private.calendar_settings where singleton=true;
  select * into d from calendar_private.calendar_days where day=p_day;
  if d.day is null then return jsonb_build_object('error','Giornata non disponibile.'); end if;
  if not cfg.preview and (clock_timestamp() at time zone 'Europe/Rome')::date<make_date(cfg.year,12,p_day) then
    return jsonb_build_object('locked',true,'preview',false,'opens_on',make_date(cfg.year,12,p_day));
  end if;
  v_version:=coalesce(d.challenge->>'version','prototype-v1');
  select pr.* into p from calendar_private.profiles pr join calendar_private.memberships m on m.profile_id=pr.id where m.user_id=auth.uid() for update of pr;
  if p.id is not null then select * into r from calendar_private.game_results g where g.profile_id=p.id and g.year=cfg.year and g.day=p_day and g.version=v_version; end if;
  if p_submission is not null or p_finish then
    if p.id is null then return jsonb_build_object('error','Entra nel tuo account per salvare i punti.'); end if;
    if p_finish then
      if r.attempts is null then return jsonb_build_object('error','Completa prima un tentativo.'); end if;
      update calendar_private.game_results g set closed=true,updated_at=now() where g.profile_id=p.id and g.year=cfg.year and g.day=p_day and g.version=v_version returning * into r;
    elsif coalesce(r.closed,false)=false and coalesce(r.attempts,0)<2 and r.last_request is distinct from p_request then
      if p_request is null then return jsonb_build_object('error','Richiesta non valida.'); end if;
      begin score:=calendar_private.score_game(d.challenge,p_submission);
      exception when others then return jsonb_build_object('error','Completa la prova con risposte valide.'); end;
      best:=greatest(coalesce(r.best_score,-2),score);
      before_score:=p.score;
      next_total:=greatest(0,p.score+case when r.attempts is null or best>r.best_score then best-coalesce(r.day_points,0) else 0 end);
      delta:=next_total-before_score;
      update calendar_private.profiles set score=next_total,updated_at=now() where id=p.id returning * into p;
      insert into calendar_private.game_results as g(profile_id,year,day,version,attempts,best_score,last_score,day_points,last_delta,last_request,closed)
        values(p.id,cfg.year,p_day,v_version,coalesce(r.attempts,0)+1,best,score,coalesce(r.day_points,0)+delta,delta,p_request,coalesce(r.attempts,0)+1>=2 or best=10)
        on conflict(profile_id,year,day,version) do update set attempts=excluded.attempts,best_score=excluded.best_score,last_score=excluded.last_score,day_points=excluded.day_points,last_delta=excluded.last_delta,last_request=excluded.last_request,closed=excluded.closed,updated_at=now()
        returning * into r;
    end if;
  end if;
  feedback:=case when r.closed then d.challenge->>'explanation' else d.challenge->>'hint' end;
  return jsonb_build_object('locked',false,'preview',cfg.preview,'year',cfg.year,'name',d.name,'login_required',p.id is null,
    'challenge',d.challenge-'scores'-'option_feedback'-'correct_index'-'solution'-'explanation'-'hint'-'sources',
    'profile',case when p.id is null then null else jsonb_build_object('id',p.id,'name',p.name,'animal',p.animal,'score',p.score) end,
    'progress',case when r.attempts is null then null else jsonb_build_object('attempts',r.attempts,'best_score',r.best_score,'last_score',r.last_score,'last_delta',r.last_delta,'day_points',r.day_points,'closed',r.closed) end,
    'explanation',feedback,'sources',case when r.closed then d.challenge->'sources' else null end,
    'area',case when r.closed then jsonb_build_object('name',d.name,'description',d.area_description,'image',d.area_image,'url',d.area_url) else null end);
end;
$$;
revoke all on function public.calendar_game(integer,jsonb,uuid,boolean) from public,anon,authenticated;
grant execute on function public.calendar_game(integer,jsonb,uuid,boolean) to anon,authenticated;
-- I vecchi conteggi non devono restare una seconda strada per ottenere punti.
revoke all on function public.calendar_day(integer,integer,uuid) from public,anon,authenticated;

update calendar_private.calendar_days set challenge='{"placeholder":false,"version":"six-games-v1","hint":"Il silenzio è utile, ma pensa anche a quanto sei vicino.","sources":[{"title":"Indicazioni di visita GIAPP","url":"https://naturadipianura.it/luoghi/"}],"type":"quiz","title":"Un incontro nel bosco: che cosa fai?","instructions":"Un uccello si allontana quando ti avvicini. Scegli il comportamento che lo disturba meno.","options":["Lo segui tra gli arbusti per riuscire a fotografarlo.","Prosegui lungo il sentiero, senza fermarti a osservarlo.","Ti fermi e fai silenzio, ma rimani vicino al punto da cui è fuggito.","Aumenti la distanza e, se torna tranquillo, lo osservi senza avvicinarti."],"scores":[-2,2,5,10],"option_feedback":["Seguire un animale che si allontana può prolungare il disturbo.","Non lo insegui: è una scelta prudente, anche se rinunci a osservarlo.","Fare silenzio aiuta, ma anche la distanza conta.","Hai dato spazio all’animale: osservare significa anche saper fare un passo indietro."],"explanation":"La scelta migliore è aumentare la distanza. Se un animale cambia comportamento al nostro arrivo, possiamo ridurre il disturbo allontanandoci e rispettando i percorsi e le indicazioni dell’area."}'::jsonb,area_description='Il Bosco di Santa Lucia si trova a Sant’Agata Bolognese. È stato realizzato nel 1998–1999 con la messa a dimora di alberi e arbusti. Il bosco comprende specie diverse e spazi aperti, offrendo occasioni per osservare il paesaggio e conoscere la natura della pianura.',area_url='https://naturadipianura.it/luoghi/bosco-di-santa-lucia/' where day=1;
update calendar_private.calendar_days set challenge='{"placeholder":false,"version":"six-games-v1","hint":"Due uccelli scavano, ma uno nel legno e l’altro nella terra. La rondine usa il fango.","sources":[{"title":"RSPB: picchio rosso maggiore","url":"https://www.rspb.org.uk/birds-and-wildlife/great-spotted-woodpecker"},{"title":"RSPB: rondine","url":"https://www.rspb.org.uk/birds-and-wildlife/swallow"},{"title":"Woodland Trust: martin pescatore","url":"https://www.woodlandtrust.org.uk/trees-woods-and-wildlife/animals/birds/kingfisher/"},{"title":"Kent Wildlife Trust: folaga","url":"https://www.kentwildlifetrust.org.uk/wildlife-explorer/birds/wading-birds/coot"}],"type":"matching","title":"A ogni uccello il suo nido","instructions":"Tocca un uccello, poi il suo nido. Puoi cambiare gli abbinamenti prima di confermare.","left":["Picchio rosso maggiore","Rondine","Martin pescatore","Folaga"],"right":["Cavità nel tronco","Coppa di fango sotto una trave","Galleria in una sponda di terra","Nido di vegetazione sull’acqua"],"solution":[0,1,2,3],"bird_images":["images/giochi/uccello-0.webp","images/giochi/uccello-1.webp","images/giochi/uccello-2.webp","images/giochi/uccello-3.webp"],"nest_images":["images/giochi/nido-0.webp","images/giochi/nido-1.webp","images/giochi/nido-2.webp","images/giochi/nido-3.webp"],"explanation":"Il picchio rosso maggiore scava una cavità nel tronco; la rondine costruisce una coppa di fango riparata negli edifici; il martin pescatore scava una galleria nella sponda; la folaga costruisce un nido di vegetazione sull’acqua. Sono esempi di nidi tipici, non gli unici ripari possibili."}'::jsonb,area_description='La Fascia boscata dell’Interporto è una delle aree elencate nella rete GIAPP. Il gioco di oggi invita a scoprire quanto possano essere diversi i luoghi scelti dagli uccelli per nidificare. La scheda di dettaglio dell’area sarà completata con i materiali dei gestori.',area_url='https://naturadipianura.it/luoghi/' where day=2;
update calendar_private.calendar_days set challenge='{"placeholder":false,"version":"six-games-v1","hint":"Ha un carapace e piccole macchie gialle sulla pelle.","sources":[{"title":"Regione Emilia-Romagna: testuggine palustre europea","url":"https://ambiente.regione.emilia-romagna.it/it/parchi-natura2000/sistema-regionale/fauna/rettili-e-anfibi/schede/testuggine-palustre-europea"}],"type":"mystery","title":"Chi si nasconde nel dettaglio?","instructions":"Osserva il dettaglio dell’illustrazione e scegli l’animale. Al secondo tentativo vedrai una porzione più ampia.","image":"images/animali/emys-segnaposto.png","options":["Rana verde","Testuggine palustre europea","Riccio","Lucertola muraiola"],"scores":[-2,10,-2,-2],"explanation":"È la testuggine palustre europea, Emys orbicularis. Nell’illustrazione si riconoscono il carapace e le macchie gialle della testa e delle zampe. L’immagine è un disegno, non una fotografia scattata nell’area."}'::jsonb,area_description='La Cassa di espansione Ponte Alto è indicata nella mappa della rete GIAPP. In questa giornata abbiamo incontrato, attraverso un’illustrazione, un animale delle zone umide. La scheda con le caratteristiche specifiche dell’area sarà completata con i materiali dei gestori.',area_url='https://naturadipianura.it/luoghi/' where day=3;
update calendar_private.calendar_days set challenge='{"placeholder":false,"version":"six-games-v1","hint":"È un canto melodioso: non è il tambureggiamento di un picchio.","sources":[{"title":"Registrazione e attribuzione","url":"https://commons.wikimedia.org/wiki/File:Turdus_merula_(06_02_16).ogg"}],"type":"audio","title":"Di chi è questa voce?","instructions":"Ascolta il canto, anche più volte, poi scegli. Se non puoi ascoltare, usa l’indizio visivo alternativo.","audio":"audio/canto-01.ogg","options":["Picchio rosso maggiore","Folaga","Merlo","Rondine"],"scores":[-2,-2,10,-2],"alternative":"Indizio alternativo: il maschio adulto di questo uccello ha piumaggio nero e becco giallo-arancio.","explanation":"È il canto del merlo, Turdus merula. La registrazione è stata realizzata a Utrecht il 16 febbraio 2006: serve a riconoscere la voce della specie e non proviene dall’area GIAPP.","credit":{"text":"Registrazione: Taka (attribuzione riportata da Wikimedia Commons), Utrecht, 16 febbraio 2006. File originale, senza modifiche.","url":"https://commons.wikimedia.org/wiki/File:Turdus_merula_(06_02_16).ogg","license":"CC BY 2.5","license_url":"https://creativecommons.org/licenses/by/2.5/"}}'::jsonb,area_description='L’ex-polveriera Madonna dei Prati è presentata tra le aree della rete GIAPP. La prova di oggi propone un modo diverso di osservare la natura: fermarsi ad ascoltare. La registrazione utilizzata è un esempio del canto del merlo e non è stata effettuata in questa area.',area_url='https://naturadipianura.it/luoghi/ex-polveriera-madonna-dei-prati/' where day=4;
update calendar_private.calendar_days set challenge='{"placeholder":false,"version":"six-games-v1","hint":"Prima viene l’uovo. Il bruco cresce prima di trasformarsi in crisalide.","sources":[{"title":"American Museum of Natural History: il ciclo della farfalla","url":"https://www.amnh.org/explore/news-blogs/life-cycle-butterfly"}],"type":"sequence","title":"Da uovo a farfalla","instructions":"Metti in ordine le quattro fasi, iniziando dall’uovo. Usa le frecce per spostare le carte.","items":["Uovo","Bruco","Crisalide","Farfalla adulta"],"images":["images/giochi/ciclo-0.webp","images/giochi/ciclo-1.webp","images/giochi/ciclo-2.webp","images/giochi/ciclo-3.webp"],"solution":[0,1,2,3],"explanation":"La sequenza è uovo → bruco (larva) → crisalide (pupa) → farfalla adulta. È una metamorfosi completa. Le illustrazioni mostrano uno schema generale del ciclo, non una specie censita nell’area."}'::jsonb,area_description='I bacini dell’ex-zuccherificio di Argelato e la golena del Reno sono presentati nel sito GIAPP come un sito della rete Natura 2000, tra i territori di Argelato e Castello d’Argile. La scheda di dettaglio sarà completata con i materiali dei gestori.',area_url='https://naturadipianura.it/luoghi/bacini-ex-zuccherificio-di-argelato-e-golena-del-fiume-reno/' where day=5;
update calendar_private.calendar_days set challenge='{"placeholder":false,"version":"six-games-v1","hint":"Cerca un animale sul ramo, uno sul tronco, uno nell’acqua e uno su una foglia.","sources":[],"type":"find","title":"Quattro incontri sullo stagno","instructions":"Cerca quattro animali nella scena e toccali. Puoi ingrandire l’immagine. Per giocare senza cercare i punti nell’immagine, apri la modalità con elenco.","image":"images/giochi/scena-stagno.webp","targets":[{"label":"Pettirosso","x":14.5,"y":17,"w":15,"h":22},{"label":"Testuggine palustre","x":19,"y":70,"w":25,"h":19},{"label":"Airone cenerino","x":80,"y":53,"w":22,"h":31},{"label":"Coccinella","x":86.5,"y":18,"w":8,"h":9}],"choices":["Pettirosso","Testuggine palustre","Airone cenerino","Coccinella","Volpe","Rana","Gufo","Farfalla"],"solution":[0,1,2,3],"explanation":"Nella scena ci sono un pettirosso sul ramo, una testuggine sul tronco, un airone nell’acqua e una coccinella sulla foglia. La scena è illustrata e non documenta la presenza contemporanea di queste specie nell’area."}'::jsonb,area_description='La Cassa di espansione del Fiume Panaro, nel territorio di San Cesario sul Panaro, comprende ambienti acquatici e boschi di salici e pioppi. Il sito GIAPP segnala numerosi uccelli, oltre a rettili e anfibi. La scena del gioco è illustrata: la scheda ufficiale racconta gli ambienti e le specie dell’area.',area_url='https://naturadipianura.it/luoghi/cassa-di-espansione-del-fiume-panaro/' where day=6;

-- Collegamenti aggiornati delle aree.
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/bosco-di-santa-lucia/' where day=1;
update calendar_private.calendar_days set area_url=null where day=2;
update calendar_private.calendar_days set area_url=null where day=3;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/ex-polveriera-madonna-dei-prati/' where day=4;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/bacini-ex-zuccherificio-di-argelato-e-golena-del-fiume-reno/' where day=5;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/cassa-di-espansione-del-fiume-panaro/' where day=6;
update calendar_private.calendar_days set area_url=null where day=7;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/cassa-di-espansione-dosolo-ecomuseo-dellacqua/' where day=8;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/ex-risaia-di-bentivoglio-la-rizza/' where day=9;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/golena-san-vitale/' where day=10;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/nodo-della-rete-ecologica-di-via-dei-tigli/' where day=11;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/bisana/' where day=12;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/vasche-ex-zuccherificio/' where day=13;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/manzolino-tivoli/' where day=14;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/torrazzuolo/' where day=15;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/area-di-riequilibrio-ambientale-di-baricella/' where day=16;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/cassa-di-espansione-del-torrente-samoggia/' where day=17;
update calendar_private.calendar_days set area_url=null where day=18;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/boscovivo/' where day=19;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/parco-lamborghini/' where day=20;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/casone-del-partigiano/' where day=21;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/torrente-idice/' where day=22;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/canale-collettore-delle-acque-alte/' where day=23;
update calendar_private.calendar_days set area_url='https://naturadipianura.it/luoghi/la-bora-casa-della-natura/' where day=24;
commit;

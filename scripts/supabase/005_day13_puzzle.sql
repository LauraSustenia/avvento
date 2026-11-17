-- Richiede 003_first_six_games.sql. Non azzera profili o punteggi.
begin;
do $$ begin
  if to_regprocedure('public.calendar_game(integer,jsonb,uuid,boolean)') is null then
    raise exception 'Esegui prima 003_first_six_games.sql, poi questo aggiornamento.';
  end if;
end $$;
alter table calendar_private.calendar_days drop constraint if exists calendar_days_challenge_check;
alter table calendar_private.calendar_days drop constraint if exists calendar_days_challenge_type_check;
alter table calendar_private.calendar_days add constraint calendar_days_challenge_type_check check(challenge->>'type' in ('quiz','matching','mystery','audio','sequence','find','puzzle'));
create or replace function calendar_private.score_game(c jsonb,s jsonb) returns integer
language plpgsql immutable set search_path='' as $$
declare t text:=c->>'type'; a jsonb; i integer; n integer:=0; w integer:=0; v integer; count_items integer;
begin
  if jsonb_typeof(s) is distinct from 'object' then raise exception 'invalid_submission'; end if;
  if t='puzzle' then
    a:=s->'tiles';
    if jsonb_typeof(a) is distinct from 'array' or jsonb_array_length(a)<>12 then raise exception 'invalid_submission'; end if;
    if exists(select 1 from jsonb_array_elements(a)e where jsonb_typeof(e) is distinct from 'number' or e::text !~ '^(0|[1-9]|10|11)$') then raise exception 'invalid_submission'; end if;
    if (select count(distinct e::text) from jsonb_array_elements(a)e)<>12 then raise exception 'invalid_submission'; end if;
    for i in 0..11 loop
      if (a->>i)::integer=i then n:=n+1; end if;
    end loop;
    return floor(n*10.0/12)::integer;
  end if;
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
update calendar_private.calendar_days set challenge='{"type":"puzzle","placeholder":false,"version":"cicogna-puzzle-v1","title":"Ricomponi la cicogna","instructions":"La foto è divisa in dodici tessere. Tocca una tessera e poi un’altra per scambiarle. Puoi fare tutti gli scambi che vuoi prima di confermare. Se ti serve, apri la foto guida.","image":"images/giochi/cicogna-giorno-13.webp","image_width":824,"image_height":1233,"columns":3,"rows":4,"image_alt":"Fotografia verticale di una cicogna, con becco rosso e piumaggio bianco e nero.","hint":"Parti dalla testa e dal becco. Poi segui la continuità del collo, delle ali e della zampa. Puoi aprire la foto guida e riprovare: la disposizione delle tessere viene conservata in questa scheda del browser.","explanation":"La protagonista del puzzle è la cicogna bianca (Ciconia ciconia). La riconosci dal piumaggio bianco, dalle grandi penne nere delle ali e dal lungo becco rossastro. È un grande trampoliere: quando apre le ali può avvicinarsi ai due metri di apertura.\n\nCerca il cibo in ambienti aperti, come prati, campi e zone umide poco profonde. Il suo lungo becco le permette di catturare prede diverse: grandi insetti, anfibi, piccoli mammiferi e altri piccoli animali.\n\nUn indizio per distinguerla dagli aironi? In volo la cicogna tiene il collo disteso, mentre gli aironi lo ripiegano. Per il nido sceglie punti elevati, come alberi, edifici e piattaforme.\n\nAlle Vasche Ex Zuccherificio di Crevalcore è documentata la nidificazione spontanea delle cicogne. Il puzzle ci porta così dal ritratto di un animale a un luogo dove conoscere il suo ambiente.","credit":{"text":"Fotografia fornita per il calendario GIAPP."},"sources":[{"title":"Lipu — Cicogna bianca","url":"https://www.lipu.it/uccelli/conoscerli-proteggerli/cicogna-bianca"},{"title":"GIAPP — Vasche Ex Zuccherificio","url":"https://naturadipianura.it/luoghi/vasche-ex-zuccherificio/"}]}'::jsonb,area_description='A Crevalcore, le vasche di decantazione di un vecchio zuccherificio hanno trovato una nuova vita. Dopo la chiusura dell’impianto nel 1985, questi bacini sono diventati ambienti umidi che offrono rifugio alla fauna della pianura.

L’area si estende per circa 22 ettari. L’acqua ha profondità diverse: accanto agli specchi aperti si incontrano bassi fondali, superfici fangose, prati umidi e canneti. Salici e sambuchi crescono sugli argini; nelle vicinanze si trovano anche rimboschimenti. Questo mosaico offre spazi per alimentarsi, sostare e nidificare.

Gli uccelli cambiano con le stagioni. Durante le migrazioni arrivano numerosi ospiti; in inverno si possono osservare anatre, cormorani e aironi. Tra le presenze documentate ci sono anche le cicogne, protagoniste della nostra giornata. Le acque ospitano inoltre anfibi e testuggini palustri.

Le Vasche sono un’Area di Riequilibrio Ecologico e fanno parte del sito Natura 2000 “Biotopi e ripristini ambientali di Crevalcore”. Sono gestite da Sustenia per conto del Comune. Per osservare senza disturbare, resta sul percorso segnalato e rispetta le indicazioni presenti sul posto.' where day=13;
commit;

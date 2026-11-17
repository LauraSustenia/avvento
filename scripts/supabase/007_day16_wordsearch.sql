-- Giorno 16: crucipuzzle. Richiede 003_first_six_games.sql; non azzera profili o punti.
begin;
do $$ begin
  if to_regprocedure('public.calendar_game(integer,jsonb,uuid,boolean)') is null then raise exception 'Esegui prima 003_first_six_games.sql.'; end if;
end $$;
alter table calendar_private.calendar_days drop constraint if exists calendar_days_challenge_check;
alter table calendar_private.calendar_days drop constraint if exists calendar_days_challenge_type_check;
alter table calendar_private.calendar_days add constraint calendar_days_challenge_type_check check(challenge->>'type' in ('quiz','matching','mystery','audio','sequence','find','puzzle','wordsearch'));
create or replace function calendar_private.wordsearch_score(c jsonb,s jsonb) returns integer
language plpgsql immutable set search_path='' as $$
declare
  paths jsonb:=s->'paths'; path jsonb; start_cell integer; end_cell integer;
  width integer:=char_length(c->'grid'->>0); height integer:=jsonb_array_length(c->'grid');
  dr integer; dc integer; steps integer; j integer; row_num integer; col_num integer;
  word text; seen text[]:='{}'; found integer:=0; guess text;
begin
  if jsonb_typeof(paths) is distinct from 'array' then raise exception 'invalid_submission'; end if;
  if jsonb_array_length(paths)>jsonb_array_length(c->'words') or jsonb_typeof(s->'guess') is distinct from 'string' or char_length(s->>'guess')>32 then raise exception 'invalid_submission'; end if;
  for path in select value from jsonb_array_elements(paths) loop
    if jsonb_typeof(path) is distinct from 'array' then raise exception 'invalid_submission'; end if;
    if jsonb_array_length(path)<>2 or jsonb_typeof(path->0) is distinct from 'number' or jsonb_typeof(path->1) is distinct from 'number' then raise exception 'invalid_submission'; end if;
    if (path->>0) !~ '^[0-9]{1,2}$' or (path->>1) !~ '^[0-9]{1,2}$' then raise exception 'invalid_submission'; end if;
    start_cell:=(path->>0)::integer;end_cell:=(path->>1)::integer;
    if start_cell=end_cell or start_cell>=width*height or end_cell>=width*height then raise exception 'invalid_submission'; end if;
    dr:=end_cell/width-start_cell/width;dc:=end_cell%width-start_cell%width;
    if dr<>0 and dc<>0 and abs(dr)<>abs(dc) then raise exception 'invalid_submission'; end if;
    steps:=greatest(abs(dr),abs(dc))+1;word:='';
    for j in 0..steps-1 loop
      row_num:=start_cell/width+j*sign(dr)::integer;col_num:=start_cell%width+j*sign(dc)::integer;
      word:=word||substring(c->'grid'->>row_num from col_num+1 for 1);
    end loop;
    if not ((c->'words') @> jsonb_build_array(word)) then word:=reverse(word); end if;
    if not ((c->'words') @> jsonb_build_array(word)) or word=any(seen) then raise exception 'invalid_submission'; end if;
    seen:=array_append(seen,word);found:=found+1;
  end loop;
  guess:=upper(regexp_replace(s->>'guess','\s','','g'));
  return floor(8.0*found/jsonb_array_length(c->'words'))::integer+case when found=jsonb_array_length(c->'words') and guess=c->>'solution' then 2 else 0 end;
end;
$$;
revoke all on function calendar_private.wordsearch_score(jsonb,jsonb) from public,anon,authenticated;

create or replace function calendar_private.score_game(c jsonb,s jsonb) returns integer
language plpgsql immutable set search_path='' as $$
declare t text:=c->>'type'; a jsonb; i integer; n integer:=0; w integer:=0; v integer; count_items integer;
begin
  if jsonb_typeof(s) is distinct from 'object' then raise exception 'invalid_submission'; end if;
  if t='wordsearch' then return calendar_private.wordsearch_score(c,s); end if;
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
update calendar_private.calendar_days set challenge='{"type":"wordsearch","placeholder":false,"version":"baricella-wordsearch-v2","title":"Una parola nascosta tra gli habitat","instructions":"Trova nella griglia le quattordici parole dell’elenco. Le parole si incrociano in orizzontale, verticale e diagonale, anche al contrario. Tocca la prima e l’ultima lettera per selezionarle. Le dodici lettere rimaste, lette da sinistra a destra e dall’alto in basso, formano la parola nascosta.","grid":["EFERTSULAP","NOHMUAATEL","IEGOCSUOTE","GLARCSQITG","GOLEEACLEN","UVOTLIARZA","TAFTLAMURI","SZTAIARIAA","ELSANPPHGO","TATIBAHCLA"],"words":["SALICI","MORETTA","SASSAIA","UCCELLI","CHIURLI","GERMANI","GARZETTE","LEGNAIA","PALUSTRE","HABITAT","FOLAGHE","ALZAVOLE","TESTUGGINE","ACQUA"],"solution":"FOTOTRAPPOLA","word_note":"Le parole riprendono gli ambienti, le piante e gli animali descritti nella scheda dell’area.","hint":"Controlla anche le parole scritte al contrario. Quando le hai trovate tutte, leggi in ordine le lettere gialle: il nome indica uno strumento usato per osservare gli animali.","explanation":"La parola nascosta è FOTOTRAPPOLA. È una macchina fotografica che può attivarsi automaticamente al passaggio di un animale e registrare foto o video. Consente di raccogliere informazioni anche quando nessuno è presente vicino al dispositivo.\n\nLe immagini aiutano i ricercatori a riconoscere le specie e a studiarne la presenza e gli orari di attività. Ma uno strumento non vede tutto: distanza, velocità di passaggio, vegetazione e condizioni di luce possono influenzare il rilevamento. Non trovare un animale nelle immagini non significa quindi, da solo, che sia assente.\n\nLe parole del gioco richiamano ambienti e presenze descritti nella scheda del Collegio di Spagna. Non indicano che in questa area sia in corso uno specifico progetto di fototrappolaggio.","sources":[{"title":"GIAPP — Area di Baricella, Collegio di Spagna","url":"https://naturadipianura.it/luoghi/area-di-riequilibrio-ambientale-di-baricella/"},{"title":"WIKIPEDIA — Fototrappolaggio","url":"https://it.wikipedia.org/wiki/Fototrappolaggio"}]}'::jsonb,area_description='L’Area di Riequilibrio Ambientale di Baricella è stata realizzata dal Comune su terreni del Reale Collegio di Spagna. Il recupero, iniziato nel 1998, ha ricreato zone umide, siepi, boschetti e radure su circa 38 ettari.

Due bacini con acqua bassa costituiscono il cuore dell’area. Attorno si trovano salici, pioppi bianchi, prati e rimboschimenti: ambienti diversi che offrono spazi per alimentarsi, sostare e nidificare. La scheda GIAPP segnala, tra gli altri, folaghe, rospi, raganelle, testuggini palustri e orbettini.

Un percorso ad anello consente di conoscere l’area e raggiungere due piccoli capanni di osservazione. Sono presenti anche esempi di rifugi per la fauna, come nidi artificiali, una legnaia e un muretto a secco.

L’area fa parte della rete Natura 2000 ed è gestita da Sustenia per conto del Comune, in coordinamento con il Reale Collegio di Spagna. Durante la visita segui il percorso e le indicazioni sul posto.',area_url='https://naturadipianura.it/luoghi/area-di-riequilibrio-ambientale-di-baricella/' where day=16;
commit;

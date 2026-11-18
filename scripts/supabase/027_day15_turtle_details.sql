-- Giorno 15: riconoscere Emys e Trachemys dai particolari. Eseguire dopo 026_day14_birdwatch_story.sql.
-- Aggiorna soltanto la prova del Torrazzuolo, preservando area e altri giochi.
begin;
create or replace function calendar_private.score_game(c jsonb,s jsonb) returns integer
language plpgsql immutable set search_path='' as $$
declare t text:=c->>'type'; a jsonb; i integer; n integer:=0; w integer:=0; v integer; count_items integer;
begin
  if jsonb_typeof(s) is distinct from 'object' then raise exception 'invalid_submission'; end if;
  if t='memory' then return calendar_private.memory_score(s); end if;
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
  if t='matching' and c->>'visual'='turtle-details' then
    a:=s->'pairs';
    if jsonb_typeof(a) is distinct from 'array' then raise exception 'invalid_submission'; end if;
    if jsonb_array_length(a)<>3 then raise exception 'invalid_submission'; end if;
    if exists(select 1 from jsonb_array_elements(a)e where jsonb_typeof(e) is distinct from 'number' or e::text !~ '^[01]$') then raise exception 'invalid_submission'; end if;
    for i in 0..2 loop if (a->>i)::integer=(c->'solution'->>i)::integer then n:=n+1; end if; end loop;
    return n*3+case when n=3 then 1 else 0 end;
  end if;
  if t='matching' and c->>'visual'='birdwatch-story' then
    a:=s->'pairs';
    if jsonb_typeof(a) is distinct from 'array' then raise exception 'invalid_submission'; end if;
    if jsonb_array_length(a)<>4 then raise exception 'invalid_submission'; end if;
    if exists(select 1 from jsonb_array_elements(a)e where jsonb_typeof(e) is distinct from 'number' or e::text !~ '^[01]$') then raise exception 'invalid_submission'; end if;
    for i in 0..3 loop if (a->>i)::integer=(c->'solution'->>i)::integer then n:=n+1; end if; end loop;
    return n*2+case when n=4 then 2 else 0 end;
  end if;
  if t='matching' and c->>'visual'='water-story' then
    a:=s->'pairs';
    if jsonb_typeof(a) is distinct from 'array' then raise exception 'invalid_submission'; end if;
    if jsonb_array_length(a)<>3 then raise exception 'invalid_submission'; end if;
    if exists(select 1 from jsonb_array_elements(a)e where jsonb_typeof(e) is distinct from 'number' or e::text !~ '^[0-2]$') then raise exception 'invalid_submission'; end if;
    for i in 0..2 loop if (a->>i)::integer=(c->'solution'->>i)::integer then n:=n+1; end if; end loop;
    return n*3+case when n=3 then 1 else 0 end;
  end if;
  if t='matching' and c->>'visual'='bird-sorting' then
    a:=s->'pairs';
    if jsonb_typeof(a) is distinct from 'array' then raise exception 'invalid_submission'; end if;
    if jsonb_array_length(a)<>8 then raise exception 'invalid_submission'; end if;
    if exists(select 1 from jsonb_array_elements(a)e where jsonb_typeof(e) is distinct from 'number' or e::text !~ '^[01]$') then raise exception 'invalid_submission'; end if;
    if jsonb_typeof(c->'solution') is distinct from 'array' or jsonb_array_length(c->'solution')<>8 then raise exception 'invalid_challenge'; end if;
    for i in 0..7 loop if (a->>i)::integer=(c->'solution'->>i)::integer then n:=n+1; end if; end loop;
    return n+case when n=8 then 2 else 0 end;
  end if;
  if t='matching' and c->>'visual'='audio-matching' then
    a:=s->'pairs';
    if jsonb_typeof(a) is distinct from 'array' then raise exception 'invalid_submission'; end if;
    if jsonb_array_length(a)<>3 then raise exception 'invalid_submission'; end if;
    if exists(select 1 from jsonb_array_elements(a)e where jsonb_typeof(e) is distinct from 'number' or e::text !~ '^[0-2]$') or (select count(distinct e::text) from jsonb_array_elements(a)e)<>3 then raise exception 'invalid_submission'; end if;
    for i in 0..2 loop if (a->>i)::integer=(c->'solution'->>i)::integer then n:=n+1; end if; end loop;
    return n*3+case when n=3 then 1 else 0 end;
  end if;
  a:=case t when 'matching' then s->'pairs' when 'sequence' then s->'order' when 'find' then s->'targets' else null end;
  if jsonb_typeof(a) is distinct from 'array' then raise exception 'invalid_submission'; end if;
  count_items:=jsonb_array_length(a);
  if count_items>(case when t='find' and c->>'visual' in ('frog-search','wildlife-search') then jsonb_array_length(c->'choices') else 4 end) or (t<>'find' and count_items<>4) then raise exception 'invalid_submission'; end if;
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
  if t='find' and c->>'visual'='wildlife-search' then
    if count_items=0 or jsonb_array_length(c->'solution')<>20 then raise exception 'invalid_submission'; end if;
    return floor(n*10.0/jsonb_array_length(c->'solution'))::integer;
  end if;
  if t='find' and c->>'visual'='frog-search' then
    if count_items=0 then raise exception 'invalid_submission'; end if;
    return floor(greatest(0,n-w)*8.0/jsonb_array_length(c->'solution'))::integer+case when n=jsonb_array_length(c->'solution') and w=0 then 2 else 0 end;
  end if;
  return greatest(0,(n-w)*2)+case when n=4 and w=0 then 2 else 0 end;
end;
$$;
revoke all on function calendar_private.score_game(jsonb,jsonb) from public,anon,authenticated;
update calendar_private.calendar_days
set challenge = $day15${"type":"matching","visual":"turtle-details","version":"torrazzuolo-turtle-details-v1","placeholder":false,"title":"Emys o Trachemys? Guarda i dettagli","instructions":"Tre confronti ravvicinati: testa, collo e carapace. In ogni coppia scegli il particolare di Emys, la testuggine palustre europea. Tocca un’immagine per rispondere; puoi ingrandire i dettagli e cambiare tutte le scelte prima della conferma.","sheet":{"image":"images/giochi/torrazzuolo-particolari-v1.png","width":1217,"height":1293,"regions":[[0,30,605,365],[615,25,602,375],[0,398,605,366],[615,425,602,339],[0,777,605,490],[608,777,609,490]]},"whole_sheet":{"image":"images/giochi/torrazzuolo-testuggini-intere-v1.png","width":2172,"height":724,"regions":[[0,0,724,724],[724,0,724,724],[1448,0,724,724]]},"steps":[{"label":"Testa","title":"La macchia dietro l’occhio","question":"Quale delle due teste appartiene a Emys?","tiles":[0,1],"descriptions":["Testa scura con piccoli puntini gialli.","Testa con striature gialle e una macchia rossa dietro l’occhio."],"species":["Emys orbicularis","Trachemys scripta elegans"],"explanation":"Nell’esempio di Emys si vedono piccoli puntini gialli sulla testa scura. La macchia rossa allungata dietro l’occhio caratterizza invece la Trachemys dalle guance rosse. Non tutte le Trachemys hanno però la macchia rossa."},{"label":"Collo","title":"Puntini o striature?","question":"Quale particolare del collo appartiene a Emys?","tiles":[2,3],"descriptions":["Collo con lunghe striature gialle e una macchia gialla dietro l’occhio.","Collo scuro con tanti piccoli puntini gialli."],"species":["Trachemys scripta scripta","Emys orbicularis"],"explanation":"Emys presenta una punteggiatura gialla su testa e collo; Trachemys ha vistose striature gialle. Qui la Trachemys mostra una macchia gialla dietro l’occhio: è una diversa sottospecie, non Emys."},{"label":"Carapace","title":"Il disegno del carapace","question":"Quale carapace appartiene all’esemplare di Emys illustrato nel gioco?","tiles":[4,5],"descriptions":["Carapace scuro con piccoli segni e raggi gialli.","Carapace olivastro con disegni gialli curvi sulle placche."],"species":["Emys orbicularis","Trachemys scripta"],"explanation":"Il carapace di Emys può essere bruno o nerastro, con macchiette e raggi gialli. Quello della Trachemys illustrata ha un disegno olivastro con linee gialle. Il carapace da solo non basta sempre: età e variabilità individuale modificano colori e disegni. In natura vanno confrontati più caratteri."}],"whole_animals":[{"name":"Emys","scientific_name":"Emys orbicularis","note":"La testuggine palustre europea è autoctona. Nell’esemplare illustrato, testa e collo sono punteggiati di giallo."},{"name":"Trachemys: macchia rossa","scientific_name":"Trachemys scripta elegans","note":"La macchia dietro l’occhio è rossa e il collo presenta striature gialle."},{"name":"Trachemys: macchia gialla","scientific_name":"Trachemys scripta scripta","note":"La macchia dietro l’occhio è gialla. È una sottospecie della stessa specie Trachemys scripta, non una Emys."}],"solution":[0,1,0],"hint":"Confronta i particolari già osservati. Considera insieme la distribuzione dei segni gialli e le macchie dietro l’occhio: il solo colore del guscio può trarre in inganno.","explanation":"Emys orbicularis è la testuggine palustre europea autoctona. Trachemys scripta è originaria del Nord America ed è stata introdotta anche attraverso il rilascio di animali tenuti in cattività. Le due varianti mostrate, con macchia rossa e con macchia gialla, appartengono entrambe a Trachemys scripta.\n\nUna specie è aliena quando l’uomo la porta, volontariamente o accidentalmente, fuori dalla sua distribuzione naturale. Non tutte le specie aliene diventano invasive: lo sono quelle la cui introduzione o diffusione minaccia la biodiversità. Ambienti adatti, risorse disponibili e condizioni favorevoli alla riproduzione possono permettere a una specie introdotta di insediarsi e diffondersi.\n\nTrachemys scripta è una specie aliena invasiva. Può competere con Emys per il cibo e per i punti emersi dove scaldarsi al sole. Le introduzioni ripetute ne hanno favorito la diffusione; una volta insediata, contenerla richiede interventi organizzati e prolungati.\n\nLiberare un animale in uno stagno può quindi danneggiare le specie che già vi abitano. La responsabilità delle introduzioni è umana: gli animali non hanno una “colpa”. Per prevenire nuove introduzioni, gli animali tenuti in cattività non vanno abbandonati in natura.","sources":[{"title":"Torrazzuolo · GIAPP","url":"https://naturadipianura.it/luoghi/torrazzuolo/"},{"title":"Progetto Emys · GIAPP","url":"https://naturadipianura.it/progetti-speciali-e-ricerca/progetto-emys/"},{"title":"LIFE URCA PROEMYS · Regione Emilia-Romagna","url":"https://ambiente.regione.emilia-romagna.it/it/parchi-natura2000/consultazione/progetti-europei/life-urca-proemys"},{"title":"Trachemys: riconoscimento e impatti · ISPRA","url":"https://www.specieinvasive.isprambiente.it/index.php/it/specie-aliene-invasive/2-le-specie-invasive/44-specie-21"},{"title":"Specie aliene e invasive: definizioni · ISPRA","url":"https://indicatoriambientali.isprambiente.it/it/biodiversita-stato-e-minacce/diffusione-di-specie-alloctone-animali-e-vegetali"}]}$day15$::jsonb
where day = 15;
commit;

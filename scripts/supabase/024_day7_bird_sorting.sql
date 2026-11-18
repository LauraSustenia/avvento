-- Giorno 7: otto uccelli da classificare. Eseguire dopo 017_day19_sounds.sql.
-- Conserva la gestione degli altri giochi. Aggiorna soltanto la prova del giorno 7.
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
set challenge = $day7${"type":"matching","visual":"bird-sorting","version":"mirandola-bird-sorting-v1","placeholder":false,"title":"Chi resta e chi parte?","instructions":"Osserva gli otto uccelli. Tocca una carta, poi scegli Sedentari o Migratori. Per il gioco consideriamo il comportamento abituale delle popolazioni della nostra pianura. Puoi cambiare tutte le scelte prima di confermare.","groups":["Sedentari","Migratori"],"group_descriptions":["Restano nel territorio durante tutto l’anno","Compiono spostamenti stagionali"],"sheets":[{"image":"images/giochi/uccelli-giorno-7-a.png","width":1261,"height":1247,"regions":[[0,0,630.5,623.5],[630.5,0,630.5,623.5],[0,623.5,630.5,623.5],[630.5,623.5,630.5,623.5]]},{"image":"images/giochi/uccelli-giorno-7-b.png","width":1261,"height":1247,"regions":[[0,0,630.5,623.5],[630.5,0,630.5,623.5],[0,623.5,630.5,623.5],[630.5,623.5,630.5,623.5]]}],"birds":[{"name":"Cinciallegra","scientific_name":"Parus major","source":"https://www.lipu.it/uccelli/conoscerli-proteggerli/cinciallegra","sheet":0,"tile":0,"note":"Le popolazioni locali sono in gran parte sedentarie: cercano cibo tra alberi e arbusti anche in inverno. In altre regioni alcuni individui migrano."},{"name":"Picchio verde","scientific_name":"Picus viridis","source":"https://www.lipu.it/uccelli/conoscerli-proteggerli/picchio-verde","sheet":0,"tile":1,"note":"È sedentario e rimane legato al territorio in cui trova alberi per nidificare e formiche di cui nutrirsi."},{"name":"Gazza","scientific_name":"Pica pica","source":"https://www.lipu.it/uccelli/conoscerli-proteggerli/gazza","sheet":0,"tile":2,"note":"È sedentaria. Frequenta durante tutto l’anno campagne alberate, parchi e zone abitate, compiendo anche spostamenti locali."},{"name":"Passera mattugia","scientific_name":"Passer montanus","source":"https://www.lipu.it/uccelli/conoscerli-proteggerli/passera-mattugia","sheet":0,"tile":3,"note":"È sedentaria: vive nelle campagne con alberi, siepi e casolari. Nidifica in cavità naturali e artificiali."},{"name":"Rondine","scientific_name":"Hirundo rustica","source":"https://www.lipu.it/uccelli/conoscerli-proteggerli/rondine","sheet":1,"tile":0,"note":"È una migratrice a lungo raggio. Arriva nella stagione riproduttiva e trascorre l’inverno soprattutto nell’Africa centrale e meridionale."},{"name":"Gruccione","scientific_name":"Merops apiaster","source":"https://www.lipu.it/uccelli/conoscerli-proteggerli/gruccione","sheet":1,"tile":1,"note":"È un migratore a lungo raggio: trascorre l’inverno in Africa e torna nella stagione riproduttiva, quando può cacciare numerosi insetti in volo."},{"name":"Tarabusino","scientific_name":"Ixobrychus minutus","source":"https://www.lipu.it/uccelli/conoscerli-proteggerli/tarabusino","sheet":1,"tile":2,"note":"È migratore e nidifica nei canneti durante la bella stagione. È segnalato fra le specie nidificanti delle Valli Mirandolesi."},{"name":"Sgarza ciuffetto","scientific_name":"Ardeola ralloides","source":"https://www.lipu.it/uccelli/conoscerli-proteggerli/sgarza-ciuffetto","sheet":1,"tile":3,"note":"È una migratrice a lungo raggio. Frequenta le zone umide per riprodursi e sverna soprattutto nell’Africa subsahariana."}],"solution":[0,0,0,0,1,1,1,1],"hint":"Pensa agli uccelli che puoi incontrare anche durante l’inverno e a quelli che arrivano nella bella stagione. Il colore del piumaggio, da solo, non rivela se una specie migra.","explanation":"Nel gioco, cinciallegra, picchio verde, gazza e passera mattugia appartengono al gruppo dei sedentari. Rondine, gruccione, tarabusino e sgarza ciuffetto sono migratori che compiono lunghi viaggi stagionali.\n\nSedentario non significa immobile: un uccello può spostarsi nel territorio per cercare cibo o riparo. Inoltre, popolazioni della stessa specie possono comportarsi in modo diverso: qui consideriamo le abitudini prevalenti nella nostra pianura.\n\nLe migrazioni collegano i luoghi di riproduzione con quelli in cui trascorrere il resto dell’anno. Lungo il viaggio servono soste per riposare e alimentarsi. Le acque, i canneti e gli altri ambienti delle Valli Mirandolesi offrono queste possibilità; secondo la specie e la stagione, possono ospitare anche la riproduzione o lo svernamento.","sources":[{"title":"Valli Mirandolesi · Unione Comuni Modenesi Area Nord","url":"https://www.unioneareanord.mo.it/territori/mirandola/valli-mirandolesi"},{"title":"Valli Mirandolesi · Regione Emilia-Romagna","url":"https://ambiente.regione.emilia-romagna.it/it/parchi-natura2000/rete-natura-2000/siti/it4040014"}]}$day7$::jsonb
where day = 7;
commit;

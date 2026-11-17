-- Giorno 11: memory, sei coppie. Eseguire dopo 014_day6_wildlife.sql.
begin;
alter table calendar_private.calendar_days drop constraint if exists calendar_days_challenge_type_check;
alter table calendar_private.calendar_days add constraint calendar_days_challenge_type_check check(challenge->>'type' in ('quiz','audio','mystery','matching','sequence','find','puzzle','wordsearch','memory'));
create or replace function calendar_private.memory_score(s jsonb) returns integer
language plpgsql immutable set search_path='' as $$
declare deck jsonb:=s->'deck'; moves jsonb:=s->'moves'; m jsonb; matched integer[]:='{}'; a integer; b integer; i integer; errors integer:=0;
begin
 if jsonb_typeof(s) is distinct from 'object' or jsonb_typeof(deck) is distinct from 'array' or jsonb_typeof(moves) is distinct from 'array' then raise exception 'invalid_submission'; end if;
 if jsonb_array_length(deck)<>12 or jsonb_array_length(moves)<6 or jsonb_array_length(moves)>200 then raise exception 'invalid_submission'; end if;
 if exists(select 1 from jsonb_array_elements(deck)e where jsonb_typeof(e) is distinct from 'number' or e::text !~ '^[0-5]$') then raise exception 'invalid_submission'; end if;
 for i in 0..5 loop if (select count(*) from jsonb_array_elements(deck)e where e::text=i::text)<>2 then raise exception 'invalid_submission'; end if; end loop;
 for m in select value from jsonb_array_elements(moves) loop
  if jsonb_typeof(m) is distinct from 'array' then raise exception 'invalid_submission'; end if;
  if jsonb_array_length(m)<>2 then raise exception 'invalid_submission'; end if;
  if exists(select 1 from jsonb_array_elements(m)e where jsonb_typeof(e) is distinct from 'number' or e::text !~ '^(0|[1-9]|10|11)$') then raise exception 'invalid_submission'; end if;
  a:=(m->>0)::integer; b:=(m->>1)::integer;
  if a=b or a=any(matched) or b=any(matched) then raise exception 'invalid_submission'; end if;
  if deck->>a=deck->>b then matched:=array_append(array_append(matched,a),b); else errors:=errors+1; end if;
 end loop;
 if cardinality(matched)<>12 then raise exception 'invalid_submission'; end if;
 return greatest(0,10-errors);
end;$$;
revoke all on function calendar_private.memory_score(jsonb) from public,anon,authenticated;
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
update calendar_private.calendar_days set challenge='{"type":"memory","placeholder":false,"version":"tigli-memory-v1","title":"Ali aperte o ali chiuse?","instructions":"Trova le 6 coppie di libellule e damigelle nascoste nelle 12 carte. Scopri due carte alla volta e osserva anche la posizione delle ali. Le coppie uguali restano scoperte. Non c’è un limite di tempo.","image":"images/giochi/libellule-damigelle-giorno-11.png","sheet_width":1536,"sheet_height":1024,"items":["Libellula rossa","Libellula azzurra","Libellula color ocra","Damigella azzurra","Damigella verde","Damigella rossa"],"hint":"Prova a ricordare la posizione delle carte viste. Il colore aiuta, ma osserva anche le ali e la forma del corpo.","explanation":"Libellule e damigelle appartengono allo stesso ordine di insetti, gli Odonati. Nelle carte puoi distinguerle osservando il corpo e soprattutto le ali a riposo.\n\nLe libellule hanno un corpo più robusto e tengono le quattro ali aperte lateralmente. Le damigelle sono più esili e generalmente richiudono le ali lungo il corpo: esistono però eccezioni, quindi questo indizio va considerato insieme agli altri caratteri. Il colore da solo non basta per distinguere i due gruppi.\n\nLe illustrazioni aiutano a confrontare questi caratteri generali; non costituiscono un elenco delle specie censite in Via dei Tigli. La scheda GIAPP segnala la presenza di libellule nell’area, insieme ad anfibi, rettili, farfalle e piccoli uccelli.","sources":[{"title":"British Dragonfly Society — distinguere libellule e damigelle","url":"https://british-dragonflies.org.uk/odonata/dragonfly-and-damselfly-identification-help/"},{"title":"GIAPP — Nodo ecologico di Via dei Tigli","url":"https://naturadipianura.it/luoghi/nodo-della-rete-ecologica-di-via-dei-tigli/"}]}'::jsonb,area_description='In Via dei Tigli, ad Anzola dell’Emilia, bosco, prato e una piccola zona umida si incontrano in uno spazio di circa 2,6 ettari. L’area è stata realizzata nel 2004 dal Comune, in collaborazione con la Provincia di Bologna, per ricostruire ambienti naturali della pianura.

La zona umida si sviluppa presso la vasca di laminazione dello Scolo Garofalo, tra canneti e arbusti che crescono sui terreni umidi. Anfibi, rettili, farfalle e libellule frequentano questi ambienti, insieme a una piccola comunità di uccelli degli arbusti.

Il nome «nodo ecologico» descrive la sua funzione: offrire uno spazio in cui le specie possano vivere e da cui possano spostarsi nel territorio attraverso i corridoi della rete ecologica. Un percorso di visita permette di osservare i diversi ambienti.' where day=11;
commit;

-- Giorno 8: la piena in tre momenti. Eseguire dopo 024_day7_bird_sorting.sql.
-- Aggiorna soltanto la prova del giorno 8, preservando le altre giornate e le aree.
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
set challenge = $day8${"type":"matching","visual":"water-story","version":"dosolo-water-story-v1","placeholder":false,"title":"Fai spazio all’acqua","instructions":"Segui i tre momenti della piena. Osserva come cambia il paesaggio e scegli una risposta per ogni momento. Puoi tornare indietro e modificare le scelte prima di confermare.","image_width":1672,"image_height":941,"steps":[{"title":"Arriva la piena","short_label":"Piena","image_alt":"Il Dosolo e il Reno sono alti; la cassa centrale è ancora in gran parte asciutta.","situation":"Piove molto. Il Reno è alto e ostacola il deflusso delle acque del Dosolo.","question":"Dove può essere accolta temporaneamente l’acqua in eccesso?","options":["Nei campi e vicino alle case.","Nella cassa di espansione.","Direttamente nel Reno, anche se è già alto."],"explanation":"La cassa offre uno spazio predisposto per accogliere le acque che il Dosolo non riesce a scaricare nel Reno.","image":"images/giochi/dosolo-momento-1.png"},{"title":"La cassa si riempie","short_label":"Invaso","image_alt":"L’acqua occupa il bacino centrale, mentre i campi e le case esterni restano asciutti.","situation":"Il bacino accoglie parte dell’acqua. Il Reno è ancora alto.","question":"A cosa serve trattenere temporaneamente questa acqua?","options":["Per darle spazio mentre il deflusso è ostacolato.","A farla scomparire subito.","A trasformare tutto il bacino in un lago sempre pieno."],"explanation":"L’acqua viene accumulata temporaneamente: non scompare e il bacino non deve restare interamente allagato per sempre.","image":"images/giochi/dosolo-momento-2.png"},{"title":"Torna il deflusso","short_label":"Deflusso","image_alt":"I livelli si abbassano e riemerge il prato; restano lo stagno e alcune pozze.","situation":"Le piogge diminuiscono e i livelli dell’acqua si abbassano.","question":"Quando le condizioni lo consentono, cosa succede all’acqua raccolta?","options":["Resta per sempre tutta nella cassa.","Torna a scorrere verso le case.","Può defluire gradualmente attraverso la rete idraulica."],"explanation":"Quando i livelli lo permettono, l’acqua può essere restituita gradualmente alla rete. Le zone umide e la vegetazione mantengono la loro funzione ecologica.","image":"images/giochi/dosolo-momento-3.png"}],"solution":[1,0,2],"hint":"La cassa dà spazio alla piena finché il deflusso può riprendere. Distingui l’acqua temporaneamente accumulata da quella che resta nelle zone umide.","explanation":"Quando il Reno è in piena, le acque del Dosolo possono incontrare difficoltà a defluire. La cassa di espansione offre uno spazio in cui trattenerle temporaneamente. Quando i livelli lo consentono, il deflusso può riprendere e l’acqua accumulata viene rilasciata gradualmente.\n\nIl bacino non è quindi un lago da mantenere sempre pieno. Al suo interno, però, sono presenti anche ambienti umidi e boschivi che ospitano piante e animali. La sequenza illustrata distingue questi ambienti dall’allagamento temporaneo durante la piena.\n\nÈ questo rapporto tra acqua, opere idrauliche e paesaggio che racconta l’Ecomuseo dell’Acqua Dosolo.","sources":[{"title":"Cassa di espansione Dosolo · GIAPP","url":"https://naturadipianura.it/luoghi/cassa-di-espansione-dosolo-ecomuseo-dellacqua/"},{"title":"Ecomuseo dell’Acqua · Città metropolitana di Bologna","url":"https://www.cittametropolitana.bo.it/cultura/Musei_home/Ecomuseo_dell_Acqua"}]}$day8$::jsonb
where day = 8;
commit;

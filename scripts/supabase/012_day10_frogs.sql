-- Giorno 10: sei dalmatine tra 19 anfibi. Conserva i punteggi dei giochi precedenti.
begin;
do $$ begin
  if to_regprocedure('calendar_private.wordsearch_score(jsonb,jsonb)') is null then raise exception 'Eseguire prima 007_day16_wordsearch.sql.'; end if;
end $$;
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
  if count_items>(case when t='find' and c->>'visual'='frog-search' then jsonb_array_length(c->'choices') else 4 end) or (t<>'find' and count_items<>4) then raise exception 'invalid_submission'; end if;
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
  if t='find' and c->>'visual'='frog-search' then
    if count_items=0 then raise exception 'invalid_submission'; end if;
    return floor(greatest(0,n-w)*8.0/jsonb_array_length(c->'solution'))::integer+case when n=jsonb_array_length(c->'solution') and w=0 then 2 else 0 end;
  end if;
  return greatest(0,(n-w)*2)+case when n=4 and w=0 then 2 else 0 end;
end;
$$;
revoke all on function calendar_private.score_game(jsonb,jsonb) from public,anon,authenticated;
update calendar_private.calendar_days set challenge='{"type":"find","visual":"frog-search","placeholder":false,"version":"sanvitale-frogs-v1","title":"Trova le 6 rane dalmatine","instructions":"Nello stagno si nascondono 6 rane dalmatine. Tocca gli animali che pensi appartengano a questa specie. Tutte le rane e tutti i rospi sono cliccabili: il contatore aumenta per ogni selezione, anche se è sbagliata. Puoi deselezionare un animale toccandolo di nuovo. La verifica avviene solo dopo Conferma.","image":"images/giochi/stagno-giorno-10.png","comparison_image":"images/giochi/anfibi-confronto-giorno-10.png","target_count":6,"targets":[{"x":12.5,"y":20,"w":8,"h":7},{"x":63,"y":21,"w":9,"h":7},{"x":10.3,"y":45.8,"w":10,"h":8},{"x":84.8,"y":50.8,"w":11,"h":10},{"x":14.3,"y":82,"w":8,"h":7},{"x":63.6,"y":79.8,"w":8,"h":8},{"x":29.2,"y":27.5,"w":9,"h":8},{"x":47.8,"y":27,"w":7,"h":5},{"x":86.7,"y":22,"w":9,"h":7},{"x":96,"y":11,"w":5,"h":6},{"x":68.8,"y":35.1,"w":11,"h":8},{"x":89.5,"y":35.7,"w":10,"h":8},{"x":26.6,"y":41.6,"w":10,"h":7},{"x":8,"y":54,"w":7,"h":6},{"x":37.7,"y":53,"w":12,"h":9},{"x":29.8,"y":70.5,"w":9,"h":8},{"x":61.6,"y":68,"w":10,"h":8},{"x":89.8,"y":64.2,"w":10,"h":8},{"x":77.7,"y":82.5,"w":10,"h":7}],"choices":["tra le erbe in alto a sinistra","sulla riva in alto, a destra del centro","tra le foglie a sinistra","sulla radice a destra","sotto una foglia in basso a sinistra","tra le radici in basso, a destra del centro","sulla riva alta a sinistra","tra i giunchi sulla riva lontana","sulla riva in alto a destra","su una foglia nell’angolo in alto a destra","sul sasso nell’acqua a destra del centro","sotto la foglia sulla riva destra","sul bordo dell’acqua a sinistra","sulla foglia a sinistra","sotto la grande foglia vicino all’acqua","sulla riva in basso a sinistra","sul bordo dell’acqua in basso, verso il centro","sotto una foglia sul lato destro","nell’acqua in basso a destra"],"species":["Rana dalmatina","Rana dalmatina","Rana dalmatina","Rana dalmatina","Rana dalmatina","Rana dalmatina","Rospo smeraldino","Rana verde","Rospo smeraldino","Raganella","Rana toro","Rana verde","Rana verde","Raganella","Rana toro","Rospo smeraldino","Rana verde","Rospo smeraldino","Rana verde"],"solution":[0,1,2,3,4,5],"hint":"Le dalmatine sono brune, hanno un muso appuntito e una macchia scura dietro l’occhio. Osserva anche gli esemplari tra le erbe e sotto le foglie: non basta cercare quelli più evidenti.","explanation":"La rana dalmatina, chiamata anche rana agile, ha corpo slanciato, muso appuntito e zampe posteriori lunghe. Nel disegno si riconosce per il colore bruno e per la macchia scura dietro l’occhio, accompagnata da una linea chiara lungo il labbro. Questi caratteri vanno osservati insieme: il colore, da solo, non basta.\n\nNella tavola di confronto la rana verde mostra il dorso verde e le pieghe lungo i lati del dorso; il rospo smeraldino ha pelle verrucosa con macchie verdi; la rana toro è più robusta e ha un timpano particolarmente evidente dietro l’occhio. Nello stagno illustrato ci sono anche raganelle.\n\nLa dalmatina vive per buona parte dell’anno a terra, anche nei boschi, e raggiunge l’acqua per riprodursi. Alla Golena San Vitale la scheda GIAPP ne descrive la presenza nelle pozze e negli stagni all’inizio della primavera.\n\nLa scena è stata composta per confrontare specie diverse: non è un censimento degli anfibi della Golena. In particolare la rana toro è una specie aliena invasiva, distinta dalla fauna autoctona.","sources":[{"title":"GIAPP — Golena San Vitale","url":"https://naturadipianura.it/luoghi/golena-san-vitale/"}],"species_notes":[{"name":"Rana toro","description":"Corpo robusto e grande timpano dietro l’occhio. È una specie aliena invasiva.","url":"https://it.wikipedia.org/wiki/Lithobates_catesbeianus"},{"name":"Rospo smeraldino","description":"Corpo tozzo, pelle verrucosa e macchie verdi su fondo chiaro.","url":"https://it.wikipedia.org/wiki/Bufotes"},{"name":"Rana verde","description":"Nel disegno ha il dorso verde, una striscia chiara centrale e pieghe lungo i lati del dorso.","url":"https://it.wikipedia.org/wiki/Pelophylax"},{"name":"Rana dalmatina","description":"Corpo slanciato, muso appuntito, zampe lunghe e macchia scura dietro l’occhio. Il colore bruno la mimetizza tra le foglie.","url":"https://it.wikipedia.org/wiki/Rana_dalmatina"}],"additional_species_link":{"name":"Raganelle","description":"Nella scena sono presenti anche raganelle, oltre ai quattro tipi illustrati nella tavola.","url":"https://it.wikipedia.org/wiki/Hyla"}}'::jsonb,
area_description='La Golena San Vitale si trova lungo il fiume Reno, tra il Lippo di Calderara di Reno e il Trebbo di Castel Maggiore. Conserva un bosco di pianura e laghetti formati in aree di cava abbandonate.

Salici, pioppi e frassini, insieme ad arbusti e vegetazione del sottobosco, creano ambienti diversi lungo le rive. Nelle pozze e negli stagni la rana agile o dalmatina si reca all’inizio della primavera per riprodursi. La scheda GIAPP descrive anche il rospo comune e il tritone crestato italiano.

L’area è tutelata come Area di Riequilibrio Ecologico e fa parte della rete Natura 2000. I percorsi di visita permettono di conoscere il bosco e gli ambienti acquatici: segui le indicazioni sul posto e osserva gli animali senza disturbarli.',area_url='https://naturadipianura.it/luoghi/golena-san-vitale/' where day=10;
commit;

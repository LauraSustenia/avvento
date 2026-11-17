-- Giorno 6: venti animali del Panaro. Eseguire dopo 012_day10_frogs.sql.
begin;
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
update calendar_private.calendar_days set challenge='{"type":"find","visual":"wildlife-search","placeholder":false,"version":"panaro-wildlife-v1","title":"Venti incontri lungo il Panaro","instructions":"Nella scena si nascondono 20 animali. Cercali tutti e toccali: alcuni sono ben visibili, altri si confondono tra rami, foglie, canne e acqua. Un segno compare solo dopo il clic. Ingrandisci l’immagine per cercare i più piccoli, poi conferma quando hai finito.","image":"images/giochi/panaro-20-animali.png","image_alt":"Lago dalle acque turchesi, salici, pioppi e canneti, con venti animali tra le rive e l’acqua.","image_width":1536,"image_height":1024,"target_count":20,"targets":[{"x":14,"y":12,"w":19,"h":19},{"x":36,"y":22,"w":9,"h":13},{"x":89.2,"y":25.8,"w":12,"h":21},{"x":62.2,"y":35.8,"w":14,"h":9},{"x":20,"y":36.4,"w":13,"h":9},{"x":73.8,"y":13.7,"w":10,"h":14},{"x":41.6,"y":44,"w":7,"h":11},{"x":89.9,"y":44.6,"w":15,"h":18},{"x":50.1,"y":11.3,"w":11,"h":9},{"x":7.5,"y":42.9,"w":13,"h":15},{"x":64.8,"y":50.7,"w":16,"h":10},{"x":86.8,"y":62.5,"w":17,"h":9},{"x":12.9,"y":59.2,"w":15,"h":12},{"x":30.5,"y":69.1,"w":15,"h":7},{"x":47.5,"y":64,"w":11,"h":10},{"x":14.1,"y":88,"w":17,"h":15},{"x":38.9,"y":85,"w":19,"h":10},{"x":94,"y":73.3,"w":5,"h":10},{"x":63.1,"y":76.7,"w":21,"h":13},{"x":79.5,"y":85,"w":23,"h":17}],"choices":["Cormorano","Martin pescatore","Airone cenerino","Germano reale","Alzavola","Nitticora","Gallinella d’acqua","Cavaliere d’Italia","Capinera","Usignolo","Testuggine palustre europea","Natrice tassellata","Ramarro","Orbettino","Rana verde","Rospo smeraldino","Tritone crestato","Raganella","Carpa","Anguilla"],"solution":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19],"hint":"Osserva anche le fronde in alto, gli animali tra le canne e quelli sotto la superficie dell’acqua. I più mimetizzati possono essere visibili solo in parte.","explanation":"Nella scena ci sono 20 animali. I numeri sulla soluzione ti aiutano a ritrovarli e ad associarli ai loro nomi.\n\nLungo le rive puoi riconoscere il martin pescatore, la nitticora e l’airone cenerino; tra le canne si nascondono l’alzavola e la gallinella d’acqua. Le foglie e i rami offrono riparo ai piccoli uccelli.\n\nSulla riva e sui tronchi si trovano rettili e anfibi, mentre nell’acqua si distinguono la carpa, l’anguilla e il tritone crestato. Cercarli richiede attenzione: sagome, colori e vegetazione possono rendere un animale poco evidente.\n\nLa varietà degli ambienti della Cassa di espansione del Panaro comprende il lago con vegetazione sommersa e i boschi a galleria di salici e pioppi. La scena riunisce a scopo di gioco specie segnalate nell’area: non rappresenta un avvistamento simultaneo né le loro dimensioni in scala.","sources":[{"title":"GIAPP — Cassa di espansione del Fiume Panaro","url":"https://naturadipianura.it/luoghi/cassa-di-espansione-del-fiume-panaro/"}]}'::jsonb,area_description='Acque turchesi, canneti e boschi di salici e pioppi: ai Laghi di Sant’Anna, nel comune di San Cesario sul Panaro, le aree un tempo interessate dall’estrazione di ghiaia sono state recuperate per la natura e la visita. Il paesaggio fa parte della Cassa di espansione del Fiume Panaro, tutelata dalla Rete Natura 2000.

Sotto la superficie del lago crescono alghe del genere Chara, mentre lungo le rive si sviluppa un bosco a galleria. Acqua e vegetazione offrono ambienti diversi agli animali: d’inverno sostano cormorani e anatre; in primavera e in autunno arrivano gli uccelli migratori. Tra le specie che nidificano nell’area ci sono il martin pescatore, la nitticora, il gruccione e il cavaliere d’Italia.

La vita continua anche lontano dai posatoi più visibili: tra sponde, sottobosco e acqua si trovano testuggini palustri, tritoni, raganelle e pesci. Un paesaggio da osservare con calma, seguendo i percorsi e rispettando gli animali e la vegetazione.' where day=6;
commit;

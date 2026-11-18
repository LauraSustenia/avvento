-- Giorno 14: osservare dal capanno. Eseguire dopo 025_day8_water_story.sql.
-- Aggiorna soltanto la prova di Manzolino; lascia invariati area e altri giochi.
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
set challenge = $day14${"type":"matching","visual":"birdwatch-story","version":"manzolino-birdwatch-v1","placeholder":false,"title":"Dal capanno, senza farsi notare","instructions":"Quattro situazioni per osservare e fotografare senza disturbare. Per ognuna scegli uno dei due comportamenti: puoi toccare i numeri nell’immagine o i pulsanti sotto. Puoi rivedere tutte le scelte prima di confermare.","image":"images/giochi/manzolino-capanno-v1.png","image_alt":"Interno di un capanno in legno affacciato su uno stagno con airone, anatre e canneto. Sul ripiano ci sono un binocolo e una macchina fotografica; in basso una panchina e a destra l’uscita sul sentiero.","image_width":1586,"image_height":992,"steps":[{"title":"Guardare da lontano","short_label":"Distanza","situation":"Un airone è sulla riva. Vorresti osservarlo meglio.","question":"Come scegli di guardarlo?","options":[{"text":"Uso il binocolo restando dietro la schermatura.","x":21,"y":64},{"text":"Esco dal capanno per avvicinarmi all’airone.","x":91,"y":56}],"explanation":"Il binocolo permette di osservare i dettagli mantenendo la distanza. La schermatura aiuta a rendere meno evidente la tua presenza."},{"title":"Dare tempo all’attesa","short_label":"Attesa","situation":"Tra le canne non noti movimenti.","question":"Come continui l’osservazione?","options":[{"text":"Esco subito e cerco di avvicinarmi al canneto.","x":91,"y":56},{"text":"Mi fermo in silenzio e osservo con pazienza.","x":24,"y":86}],"explanation":"Non vedere subito un animale non significa che non ci sia. Fermarsi, ascoltare e osservare con calma permette di cogliere movimenti e presenze senza inseguirli."},{"title":"Lasciare che si mostri","short_label":"Richiami","situation":"Hai intravisto un uccello nel canneto, ma ora è nascosto.","question":"Come provi a osservarlo di nuovo?","options":[{"text":"Riproduco un richiamo per farlo uscire.","x":65,"y":34},{"text":"Resto schermato e aspetto che si mostri spontaneamente.","x":37,"y":49}],"explanation":"I richiami registrati possono interferire con il comportamento degli uccelli. Per questa osservazione, lascia che l’animale scelga quando uscire dal riparo."},{"title":"Prima della fotografia","short_label":"Fotografia","situation":"Dalla feritoia una canna copre parte dell’inquadratura.","question":"Cosa fai per cercare una fotografia?","options":[{"text":"Provo un’inquadratura dalla feritoia, senza avvicinarmi.","x":67,"y":59},{"text":"Esco dal percorso per cercare una foto più vicina.","x":91,"y":56}],"explanation":"Una fotografia va cercata dai punti consentiti, senza far spostare l’animale. Se l’inquadratura non riesce, puoi aspettare un’altra occasione."}],"solution":[0,1,1,0],"hint":"Pensa alla distanza, al silenzio e alla pazienza. La scelta migliore permette agli animali di continuare le proprie attività senza essere richiamati o inseguiti.","explanation":"Capanni e schermature consentono di osservare limitando la visibilità delle persone. Restare sui percorsi e usare il binocolo permette di guardare anche gli animali lontani.\n\nL’attesa fa parte dell’osservazione: un uccello può restare nascosto nella vegetazione e comparire dopo qualche minuto. Ascoltare e cercare piccoli movimenti aiuta a individuarlo.\n\nAnche per fotografare vale lo stesso criterio: evitare di provocare una reazione nell’animale. Se la nostra presenza lo mette in allarme o lo fa allontanare, occorre interrompere l’avvicinamento e aumentare la distanza.","sources":[{"title":"Manzolino–Tivoli · GIAPP","url":"https://naturadipianura.it/luoghi/manzolino-tivoli/"},{"title":"Decalogo del birdwatcher · EBN Italia","url":"https://www.ebnitalia.it/it/news-82/decalogo-del-birdwatcher.html"},{"title":"Osservare nelle zone umide · WWT (in inglese)","url":"https://www.wwt.org.uk/discover-wetlands/blog/a-birdwatching-code-of-conduct-how-to-respect-our-wetland-nature-while-still-getting-the-most-out-of-your-birdwatching-experience"}]}$day14$::jsonb
where day = 14;
commit;

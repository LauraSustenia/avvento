-- Giorno 19: abbina tre audio alle illustrazioni. Eseguire dopo 015_day11_memory.sql.
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
update calendar_private.calendar_days set challenge='{"type":"matching","visual":"audio-matching","placeholder":false,"version":"boscovivo-sounds-v1","title":"Chi fa questo suono?","instructions":"Ascolta i tre suoni e abbinali agli animali illustrati. Quando avvii un audio, quel suono viene selezionato: tocca poi l’animale corrispondente. Puoi riascoltare e cambiare gli abbinamenti prima di confermare.","image":"images/giochi/animali-suoni-giorno-19.png","sheet_width":2172,"sheet_height":724,"crops":[[0,0,724,724],[724,0,630,724],[1320,0,852,724]],"animals":["Rana toro","Barbagianni","Istrice"],"solution":[0,1,2],"recordings":[{"file":"audio/suono-19-0-v2.wav","source":"https://freesound.org/people/TheKingOfGeeks360/sounds/799266/","credit":"Rana toro: TheKingOfGeeks360, “Frogs - American Bullfrog; Three Frogs Croaking in Pond”, Freesound. Da anteprima MP3 fornita dal sito; ricodifica WAV mono, filtraggio delle frequenze estreme e volume normalizzato.","license":"CC0 1.0","license_url":"https://creativecommons.org/publicdomain/zero/1.0/"},{"file":"audio/suono-19-1-v2.wav","source":"https://lasonotheque.org/chouette-effraie-2-s1403.html","credit":"Barbagianni: LaSonothèque, “Chouette effraie #2”, richiamo territoriale di un maschio (Tyto alba), registrato dall’interno di un fienile. Da MP3 originale; ricodifica WAV mono, filtraggio delle frequenze estreme e volume normalizzato.","license":"CC0 1.0","license_url":"https://creativecommons.org/publicdomain/zero/1.0/"},{"file":"audio/suono-19-2-v2.wav","source":"https://freesound.org/people/craigsmith/sounds/675452/","credit":"Istrice: craigsmith, “S27-31 Porcupine puffing grunting & rattling quills”, Freesound, archivio SSE/USC Cinema. Da anteprima MP3 fornita dal sito; ricodifica WAV mono, filtraggio delle frequenze estreme e volume normalizzato. La specie di istrice non è indicata nella scheda originale.","license":"CC0 1.0","license_url":"https://creativecommons.org/publicdomain/zero/1.0/"}],"hint":"Riascolta il carattere di ogni suono: uno è profondo e ripetuto, un altro è uno stridio, il terzo comprende un rumore secco e vibrante. Non tutti i suoni degli animali sono prodotti dalla voce.","explanation":"Questi suoni sembrano strani perché si allontanano dai versi che associamo più facilmente a una rana, a un rapace notturno o a un roditore. Sono però segnali con funzioni precise.\n\nRana toro — Il richiamo profondo ricorda un muggito, da cui deriva il nome comune. Il maschio canta per attirare le femmine e segnalare il territorio agli altri maschi. La rana toro è una specie nordamericana introdotta in Italia: il gioco non la presenta come fauna autoctona.\n\nBarbagianni — Il suo richiamo è uno stridio aspro e prolungato. Non tutti i rapaci notturni fanno il tipico «uh-uh»: il barbagianni usa vocalizzazioni diverse per comunicare. Lo stridio del maschio si può sentire soprattutto nelle prime fasi della stagione riproduttiva. Un suono impressionante per noi non indica necessariamente paura o aggressività.\n\nIstrice — Il rumore simile a un sonaglio non è una voce: è prodotto da particolari aculei cavi della coda che, quando vengono agitati, urtano tra loro. Fa parte dei segnali di difesa che avvertono un possibile aggressore. Nell’audio si sentono anche altri rumori dell’animale.\n\nLe registrazioni sono esempi d’archivio e non provengono da Boscovivo. Nell’illustrazione compare l’istrice europeo (Hystrix cristata), mentre la scheda dell’audio non specifica la specie registrata.","sources":[{"title":"BTO — I richiami del barbagianni","url":"https://www.bto.org/learn/about-birds/owls/barn-owl"},{"title":"Schianini e altri — Gli aculei sonagli dell’istrice","url":"https://link.springer.com/article/10.1007/s42991-024-00454-y"},{"title":"GIAPP — Boscovivo","url":"https://naturadipianura.it/luoghi/boscovivo/"}]}'::jsonb,area_description='A Funo, nel comune di Argelato, Boscovivo riunisce circa 38 ettari di bosco e ambienti legati all’acqua. L’area è nata da interventi di rimboschimento avviati nel 1995, attorno alla cassa di espansione del canale Riolo, realizzata per la sicurezza idraulica.

Con il tempo gli alberi sono cresciuti e si è sviluppato un fitto sottobosco. La varietà degli ambienti offre spazio a numerose forme di vita e permette di conoscere un bosco di pianura in evoluzione.

Durante la visita segui i percorsi predisposti ed evita le zone non accessibili. Sono vietati caccia, pesca, raccolta di fiori e prodotti naturali, accensione di fuochi e accesso con veicoli a motore non autorizzati. I cani devono essere tenuti al guinzaglio.' where day=19;
commit;

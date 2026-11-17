# Giorno 16 — Collegio di Spagna

Crucipuzzle 8×8: SALICI, PIOPPI, FOLAGHE, ROSPI, PRATI, ACQUA, SIEPI, NIDI, EMYS, BOSCO. I termini riprendono ambienti e presenze della scheda GIAPP: https://naturadipianura.it/luoghi/area-di-riequilibrio-ambientale-di-baricella/ . BOSCO è la forma singolare usata nel gioco per i boschetti e rimboschimenti descritti. EMYS è spiegato come genere della testuggine palustre.

Le dieci parole occupano 52 caselle diverse. Ognuna compare una sola volta nella griglia, in orizzontale, verticale o diagonale, nei due versi. Le dodici caselle non utilizzate, lette per righe da sinistra a destra, formano FOTOTRAPPOLA. Non vengono copiate illustrazioni o testi dell'esempio allegato dall'utente.

Interazione: primo e ultimo carattere con due tocchi, oppure Tab e frecce nella griglia, Invio/Spazio per scegliere. Le parole trovate diventano verdi e vengono segnate nell'elenco. Dopo l'ultima parola, le lettere residue diventano gialle e si abilita il campo della soluzione. Disponibile uno zoom con scorrimento interno. Le selezioni vengono conservate nella scheda del browser, distinte per account, anno, giornata e versione.

Punti: floor(8 × parole valide trovate / 10), più 2 soltanto se tutte le dieci parole sono state trovate e la soluzione è corretta. Massimo 10, due tentativi, migliore conservato. La selezione sbagliata di lettere non invia un tentativo: conta la conferma. Il server verifica le lettere di ogni percorso, la direzione e l'assenza di parole duplicate; non accetta un punteggio trasmesso dal browser. I dati pubblici della modalità senza salvataggio non sono pensati per impedire a chi ispeziona il sorgente di trovare la soluzione.

## Supabase

Eseguire `007_day16_wordsearch.sql` nel SQL Editor dopo il sistema giochi 003. L'aggiornamento conserva il supporto del puzzle del giorno 13, modifica soltanto la prova e la descrizione del giorno 16 e non azzera i profili o i risultati. Il gioco ha versione `baricella-wordsearch-v1`, distinta dal vecchio quiz dimostrativo. Non rieseguire i vecchi script di creazione giochi dopo questo aggiornamento: ripristinerebbero il precedente elenco dei tipi.

Finché il database non è aggiornato, il sito offre “Prova senza salvare” per il nuovo gioco, senza mostrare il vecchio quiz del giorno 16. I testi editoriali di spiegazione e descrizione si aggiornano da `_data/advent_days.json`; il file SQL allinea anche il database.

La spiegazione della fototrappola si basa su ISPRA: https://www.isprambiente.gov.it/it/news/invisibili-agli-occhi-della-tecnologia . Non si afferma che presso il Collegio di Spagna sia installato un dispositivo o attivo un progetto specifico di fototrappolaggio. La foto dell'area rimane da inserire nei campi già predisposti.

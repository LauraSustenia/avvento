# Giorno 13 — puzzle della cicogna

Foto originale: `Cicogna gardenghi.tif`, fornita dall'utente. Formato verticale 824 × 1233. La versione WebP in `images/giochi/cicogna-giorno-13.webp` mantiene tutta la fotografia e le sue proporzioni; conversione con Pillow, senza ritocchi o generazione di immagini. Il TIFF originale non viene modificato. Il nome dell'autore non viene dedotto dal nome del file: il credito è modificabile in `challenge.credit.text` quando sarà confermato.

Il puzzle è una griglia 3 colonne × 4 righe con dodici tessere rettangolari. Si scambiano due tessere selezionandole con due tocchi, oppure con Tab e Invio/Spazio. La foto guida è apribile senza penalità. Rimescolare o scambiare tessere non conta come tentativo: conta soltanto premere Conferma. Punteggio: proporzionale alle tessere corrette: floor(10 × corrette / 12), massimo 10. Due tentativi, risultato migliore conservato, spiegazione e successivo accesso alla scheda dell'area.

La disposizione e il numero di scambi vengono conservati in sessionStorage nella sola scheda del browser, separati per profilo, anno, giorno e versione. Non vengono inviati punteggi dal client: il server controlla che la risposta contenga esattamente una volta ciascuna delle dodici tessere e calcola il risultato. I progressi e i punti restano salvati su Supabase come per gli altri giochi. La disposizione può quindi ripartire mescolata se si cambia browser o scheda; i tentativi salvati non si azzerano.

## Attivazione Supabase

Eseguire `005_day13_puzzle.sql` nel SQL Editor, dopo il precedente `003_first_six_games.sql`. Aggiorna soltanto il contenuto del giorno 13 e aggiunge la valutazione del puzzle al sistema esistente. Le altre prove rimangono invariate. Non eseguire di nuovo le vecchie migrazioni dopo la 005: un vecchio script 003 ripristinerebbe i tipi di prova precedenti.

Prima dell'aggiornamento del database, il sito segnala che il nuovo puzzle non è ancora attivo per il salvataggio e permette di provarlo senza salvare punti. I risultati di precedenti versioni dimostrative non vengono cancellati; la versione `cicogna-puzzle-v1` mantiene separati i nuovi tentativi.

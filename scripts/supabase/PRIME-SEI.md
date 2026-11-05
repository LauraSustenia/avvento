# Prime sei giornate

1. Bosco di S. Lucia: quattro comportamenti con punteggi −2, 2, 5, 10.
2. Fascia boscata dell'Interporto: quattro uccelli e i loro nidi tipici.
3. Ponte Alto: riconoscimento della testuggine palustre da un dettaglio illustrato.
4. Madonna dei Prati: canto del merlo, con indizio alternativo testuale.
5. Ex-zuccherificio di Argelato: riordino del ciclo di una farfalla.
6. Cassa del Panaro: ricerca di quattro animali in una scena illustrata, con zoom e alternativa a elenco.

## Collegamento reale

Eseguire `003_first_six_games.sql` nel SQL Editor del progetto GIAPP. Richiede il precedente 001 dei profili e include il necessario del 002: non occorre eseguirli di nuovo. Lo script non cancella i profili né i vecchi punteggi. La nuova tabella privata game_results separa le prove per anno, giornata e versione del contenuto. I risultati delle precedenti prove dimostrative restano nei loro dati e nei totali già assegnati; le nuove prove hanno una versione distinta.

La funzione pubblica è calendar_game. Tutti i punteggi sono verificati sul server, non ricevuti dal browser. Il precedente calendar_day non è più invocabile da anon/authenticated, per evitare due sistemi di assegnazione contemporanei. Soluzioni, punteggi delle opzioni e spiegazioni non vengono restituiti prima del momento previsto. La modalità esplicita senza salvataggio usa dati locali: le sue soluzioni sono leggibili nel sorgente e non cambiano i punti dell'account.

Due tentativi; si conserva il punteggio migliore, senza sommare. Il totale dell'account non scende sotto zero. Un primo risultato non perfetto mostra un indizio; si può riprovare oppure concludere. Solo a conclusione vengono mostrate la spiegazione completa e il pulsante per l'area. Un 10 chiude subito la prova. Abbinamenti e sequenza valgono 2 punti per elemento nella posizione corretta più 2 punti se tutti e quattro sono corretti. Nella scena, ogni scelta errata dall'elenco annulla un elemento corretto; minimo zero.

L'anteprima resta attiva. La data è verificata sul server nel fuso Europe/Rome, senza fidarsi del browser. Il punteggio guadagnato con il salvataggio reale conta nel totale e nella classifica, secondo la preferenza del profilo.

## Contenuti

Modificare `_data/advent_days.json` per il sito e la modalità senza salvataggio; per il gioco reale aggiornare i contenuti nella tabella calendar_days. Le giornate 7–24 rimangono dimostrative. Le descrizioni delle aree senza una scheda ufficiale completa restano esplicitamente provvisorie: non attribuiamo alle singole aree specie non verificate.

Fonti dei giochi e dei testi sono riportate nelle spiegazioni e nel file dati. Illustrazioni provvisorie, non fotografie dei luoghi né documentazione delle specie censite. Il ciclo della farfalla è uno schema generale, non identifica una specie locale.

## Audio

`audio/canto-01.ogg`: file originale senza modifiche, canto di Turdus merula registrato a Utrecht il 16 febbraio 2006. Wikimedia Commons attribuisce il file a Taka sulla base delle dichiarazioni di copyright. Scelta di licenza: **CC BY 2.5**, https://creativecommons.org/licenses/by/2.5/ . Fonte: https://commons.wikimedia.org/wiki/File:Turdus_merula_(06_02_16).ogg . Autore e licenza sono indicati accanto al lettore. La registrazione non proviene dall'area GIAPP.

## Illustrazioni

Strumento integrato imagegen, tre immagini originali, poi suddivisione e conversione per il sito senza ridisegnarle:

- Atlante 4×2 di picchio rosso maggiore, rondine, martin pescatore e folaga; sotto, cavità nel tronco, coppa di fango, galleria nella sponda e nido di vegetazione sull'acqua. Acquerello e matita, fondo crema, nessun testo.
- Atlante a quattro celle: uova sulla foglia, bruco, crisalide sospesa, farfalla adulta. Acquerello didattico senza frecce o scritte.
- Scena illustrata di stagno con quattro animali interi: pettirosso sul ramo in alto a sinistra, testuggine sul tronco in basso a sinistra, airone a destra, coccinella sulla foglia in alto a destra. Acquerello, vegetazione della pianura, nessun animale aggiuntivo o testo.

Le fonti originali sono conservate nella cartella generated_images di Codex. Gli asset consumati dal sito sono tutti in images/giochi; il dettaglio del giorno 3 usa il precedente segnaposto Emys.

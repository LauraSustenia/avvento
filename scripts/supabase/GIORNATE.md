# Giornate del calendario

Un solo modello `_layouts/day.html` (basato su `default.html`), 24 pagine minime in `giornate/`, contenuti in `_data/advent_days.json`, impostazioni in `_data/advent.yml`.

Percorso: prova → risultato, punti e spiegazione → pulsante “Scopri l’area: …” → scheda dell'area. Dopo un primo errore si può tentare il recupero; la scheda resta accessibile anche se la prova non viene superata. Al massimo due tentativi, senza rigiocare le giornate concluse per accumulare punti.

## Attivare il salvataggio reale

Eseguire `002_days.sql` nel SQL Editor del progetto GIAPP dopo il precedente `001_profiles.sql`. Non rieseguire `001_profiles.sql`. Il nuovo script aggiunge tre tabelle private: `calendar_settings`, `calendar_days`, `day_progress`, più la funzione `calendar_day`. Non contiene chiavi segrete. Le tabelle non sono accessibili direttamente da anon/authenticated.

Finché il nuovo script non è stato eseguito, la pagina offre una prova esplicita “senza salvare”: nessun punteggio o progresso viene modificato. La chiave pubblica del sito non permette di installare le tabelle. In modalità demo, i risultati vengono salvati soltanto nel browser. Nella modalità reale, punti e tentativi sono verificati dal database e l'header si aggiorna dopo la risposta.

## Contenuti e tipi di prova

Le 24 associazioni giorno/area provengono da `calendar_map.json`: il 24 è La Bora. Per ora tutte hanno una domanda dimostrativa e una descrizione dichiaratamente provvisoria. Non sono testi ufficiali delle aree. Il solo tipo implementato è `quiz`; altri giochi potranno usare la stessa struttura visiva, aggiungendo il proprio controllo sul server.

Campi di ogni giornata: `challenge.type`, `title`, `options`, `correct_index` (da zero), `explanation`, `placeholder`; `area_description` e `area_image` (URL HTTPS o percorso assoluto sul sito, comprensivo di baseurl). I testi vengono inseriti come testo, senza eseguire HTML. I dati locali servono anche al gioco senza salvataggio e contengono la soluzione dimostrativa: non sono una barriera contro chi ispeziona il sorgente.

Per il salvataggio reale i contenuti autorevoli sono in `calendar_private.calendar_days`. Aggiornare anche i dati Jekyll per mantenere coerente la prova locale. Il seed SQL usa ON CONFLICT DO NOTHING per non sovrascrivere contenuti già personalizzati.

## Date e punteggi

Anteprima attiva: tutte le giornate sono aperte. Per l'apertura alle date previste impostare `preview: false` in `_data/advent.yml` e `preview=false` nella riga di `calendar_private.calendar_settings`. Anno 2026; il server usa Europe/Rome e blocca anche le chiamate dirette prima del giorno previsto. Una giornata resta accessibile dopo la data.

Valori iniziali: +10 prima risposta corretta, −2 ogni risposta errata (massimo due), +5 risposta corretta al secondo tentativo. Il totale del profilo non scende sotto zero; il risultato mostra la variazione effettiva, che può essere 0 se non c'erano punti da sottrarre. Il saldo della singola giornata può essere negativo. Date e punti sono configurabili anche nella tabella settings; il server ha l'ultima parola. I punteggi guadagnati nell'anteprima con salvataggio sono reali e contano per la classifica.

Un identificativo di richiesta protegge dalle ritrasmissioni; un blocco sul profilo serializza i conteggi concorrenti. La riapertura mostra il risultato già salvato, senza riassegnare punti. La visibilità in classifica resta quella scelta dall'utente.

La futura edizione annuale richiederà una decisione esplicita sull'azzeramento o mantenimento dei punteggi complessivi: i progressi sono già separati per anno, il totale profilo è cumulativo.

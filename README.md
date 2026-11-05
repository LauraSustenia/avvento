# Calendario dell’Avvento — Natura di Pianura

Struttura Jekyll pronta per GitHub Pages. Header e footer si trovano in `_includes`, il layout in `_layouts/default.html` e la prova del calendario in `index.html`.

## Prova locale

Con Ruby e Bundler installati, eseguire dalla cartella del progetto:

```sh
bundle install
bundle exec jekyll serve
```

Aprire `http://localhost:4000/avvento/`. Live Server non elabora gli include e i cicli di Jekyll. Se si imposta `baseurl: ""`, l’indirizzo locale diventa `http://localhost:4000/`.

## Cambiare le fasce

- La cornice attiva si trova in `images/cornice-corta`: sei fasce PNG **2172 × 360 pixel**, testata 2172 × 706 e coda 2172 × 724. L'altezza è propria dei file; il sito conserva il rapporto tra larghezza e altezza senza comprimerli.
- La sorgente attiva dei rami è `scripts/frame-source/short/twigs.png`. Tre ritagli diversi producono sei combinazioni con lati differenti, variando la posizione di incroci, gemme e diramazioni. Le due prove `twigs-irregular-*.png`, troppo spigolose, sono escluse dalla composizione.
- Gli agganci derivano da due righe consecutive dello stesso ramo dipinto. Il passaggio alla testata modifica gradualmente sagoma e corteccia per evitare doppie sagome e stacchi netti. Anche la coda parte dagli stessi agganci, con i rami dietro il paesaggio originale.
- I raccordi usano un tratto poco ramificato della sorgente. Nelle transizioni viene conservata l'intera riga dipinta, comprese diramazioni e bordi trasparenti: ritagliare soltanto il tronco produceva sottili tagli orizzontali. Il passaggio più lungo e il profilo smussato evitano cambi bruschi di direzione; le illustrazioni angolose sono state eliminate e i piccoli decori sono diradati.
- Per rigenerare le PNG eseguire `./scripts/build-short-frame.ps1` in PowerShell. Gli script precedenti e le cartelle `cornice` e `cornice-png` conservano prove superate e non sono usati dal layout.
- Non tagliare le estremità delle PNG finali: occorre conservare gli agganci comuni. Per cambiare altezza si interviene sulle immagini sorgenti e sulla composizione, non su una compressione CSS.
- Per aggiungere o escludere una fascia, modificare la lista `1,2,3,4,5,6` nel layout.
- L’ordine è casuale a ogni caricamento; tutte le fasce vengono usate prima di ripetere un gruppo. Durante il ridimensionamento l’ordine resta stabile.
- Il numero di fasce segue l’altezza del contenuto. Aggiungere testo a `index2.html` per provarlo. L’ultima fascia resta intera prima della coda.

In `assets/css/style.css`:

```css
--paper-green: #e0ead5;    /* verde sotto le immagini trasparenti */
--decoration-space: 8%;   /* spazio riservato alle decorazioni, su ogni lato */
--content-padding: 24px;  /* spazio sopra e sotto il contenuto */
--content-top-margin: -60px; /* avvicina il titolo al logo della testata */
--content-bottom-margin: -160px; /* sovrapposizione del contenuto alla zona verde della coda */
--page-width: 1380px;     /* larghezza massima del foglio */
--card-gap: 18px;         /* distanza fra le caselle */
```

Per allontanare il testo dai disegni aumentare `--decoration-space`; per allargarlo diminuirlo con cautela. Un valore più negativo di `--content-top-margin` sposta il contenuto verso il logo. Su telefono il margine superiore è definito in `@media (max-width: 700px)` e parte da `-18px`; i margini laterali ereditano il valore generale e le foglie passano da quattro a due colonne.

Il numero di fasce si adegua allo spazio richiesto dal contenuto. La vecchia impostazione `--band-height-scale` è stata eliminata.

Per avvicinare l'ultima riga al paesaggio, diminuire `--content-bottom-margin` (per esempio `-200px`); per lasciare più verde aumentarlo verso `0px`. Su telefono lo stesso valore è definito nella sezione `@media (max-width: 700px)` e parte da `-48px`. Le immagini restano intere: lo sfondo si accorcia per fasce complete, quindi alcuni piccoli cambiamenti del valore possono non cambiare subito il risultato.

### Sorgenti illustrate

Generate con lo strumento integrato per le immagini, usando `reference-head-branch.png` come riferimento della corteccia. I prompt chiedono due rami su fondo trasparente, nitidi e spessi come il riferimento, senza foglie o neve; una prima forma con incrocio centrale e due varianti con curve angolose, gemme e diramazioni cieche, incroci rispettivamente più alto e più basso. Le riduzioni delle sorgenti sono uniformi e seguite da un ritaglio; i piccoli decori sono aggiunti dopo. I raccordi sono adattati direttamente nei pixel delle immagini, senza disegnare rami vettoriali.

## Seconda home: mappa

La mappa è la home in `index.html`, disponibile su `/avvento/`. Usa il layout dedicato `_layouts/map.html` e una sola immagine, `images/mappa-avvento-poster.webp` (2172 × 2800), che integra paesaggio, cartografia e logo trasparente. Non carica testata, coda o fasce ripetute. La versione alternativa a griglia è in `index2.html` (`/avvento/index2.html`).

- `Foglie` e `Caselle` cambiano l'aspetto dei segnaposto; i numeri restano associati alle stesse aree e il 24 è sulla Bora.
- I 24 abbinamenti sono in `_data/calendar_map.json`. Le coordinate `anchor_x` e `anchor_y` indicano il punto cartografico originale; `left` e `top` posizionano il segnaposto, leggermente distanziato dagli altri nei gruppi più densi.
- Su telefono la mappa è scorrevole e ingrandibile. `Intera mappa` mostra la vista completa. L'elenco espandibile permette di trovare anche le aree fuori dalla porzione visibile.
- Le foglie sono circa il 44% più grandi della prima prova. Le forme variano a ogni caricamento, usando la distanza geografica per separare le foglie uguali; numeri e aree rimangono fissi. La Bora non ha evidenziazioni iniziali.
- I pulsanti mostrano il nome dell'area selezionata in un fumetto vicino alla foglia, chiudibile con ×, Esc o un clic all'esterno. Le prove e le descrizioni giornaliere non sono ancora collegate.
- La composizione unica si rigenera con `node scripts/compose-map-poster.cjs`; dimensioni e posizione della cartografia sono in `_data/map_poster.json`. La decorazione nuova è descritta in `scripts/frame-source/poster/README.md`.
- Per rigenerare base e abbinamenti: eseguire `scripts/build-map.py` con Python e `pdfplumber`, passando il percorso del PDF come argomento. La base mantiene comuni, corsi d'acqua e aree protette, omettendo le etichette e i riquadri della tavola tecnica.

## GitHub Pages

Pubblicazione dalla branch, cartella principale. In `_config.yml`, `baseurl: "/avvento"` presuppone un repository chiamato `avvento`. Per `avvento.naturadipianura.it` usare `baseurl: ""` e configurare il dominio nelle impostazioni Pages.

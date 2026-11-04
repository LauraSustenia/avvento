# Tavola unica della home cartografica

La base attiva è `poster-integrated.png`, generata con lo strumento integrato per le immagini. Le precedenti prove restano in questa cartella come riferimenti e non sono usate nella composizione attiva.

Prompt usato: riprogettare la decorazione come un unico habitat invernale di pianura, con vegetazione ripariale continua, querce, edera, cinorrodi, canneti, una cinciarella e un airone; mantenere un grande campo centrale chiaro per la cartografia, senza testata, coda, riquadri, vignette isolate, loghi, testi o numeri. Riferimento stilistico: la prima prova della tavola, da superare nella composizione. Toni salvia, oliva, ocra e avorio; pochi richiami natalizi, corteccia e foglie dipinte con dettaglio.

`scripts/compose-map-poster.cjs` produce un solo file pubblicato: `images/mappa-avvento-poster.webp`, 2172 × 2800 pixel. La cartografia mantiene le coordinate del PDF GIAPP, con colori traslucidi e margini sfumati; il logo ufficiale conserva la prima riga, con il fondo bianco eliminato. I file `images/testa.png` e `images/coda.png` non sono più usati dalla home cartografica.

Titolo, giorni e nomi selezionati sono sovrapposti dal sito. Le loro coordinate derivano da `_data/map_poster.json` e `_data/calendar_map.json`. Il 7 è spostato verso il centro-sinistra delle Valli mirandolesi; il 24 resta sulla Bora e ha lo stesso trattamento degli altri giorni.

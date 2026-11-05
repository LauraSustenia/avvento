# Scheda dell'area nella giornata

Il modello comune `_layouts/day.html` mostra titolo, fotografia orizzontale, eventuale didascalia/credito, testo in paragrafi, collegamento alla scheda ufficiale e ritorno al calendario. Si apre con il pulsante Scopri l'area alla fine della prova.

La foto riempie un riquadro 16:9 senza deformarsi; può essere ritagliata per adattarsi al riquadro. Il testo è sempre sotto, anche su desktop. Se la foto manca o non si carica viene mostrato un segnaposto esplicito, senza immagini di luoghi diversi.

In `_data/advent_days.json`, per ciascuna giornata:

```json
{
  "area_image": "images/aree/bisana.jpg",
  "area_image_alt": "Una descrizione della fotografia",
  "area_image_caption": "Bisana — Foto: nome autore"
}
```

Il percorso relativo parte dalla cartella del sito: la gestione di `/avvento/` è automatica. Sono accettati anche URL HTTPS o percorsi che iniziano con `/`. Questi ultimi devono già includere l'eventuale prefisso `/avvento/`.

Immagine, testo alternativo e didascalia locali permettono di preparare la scheda senza aggiornare il database. Se manca l'immagine locale si usa quella restituita da Supabase. Anche il testo viene letto da `area_description` del file locale: foto, didascalia e descrizione si modificano tutti nello stesso punto, senza aggiornare il database. Una riga vuota nella descrizione separa due paragrafi. Il testo non viene interpretato come HTML.

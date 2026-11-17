# Giorno 10 — Golena San Vitale: trova le 6 dalmatine

Lo stagno approvato è copiato senza modifiche in images/giochi/stagno-giorno-10.png. Tutti i 19 anfibi hanno una zona cliccabile percentuale, compresi i mimetizzati. Gli indici corretti sono 0–5. La tavola orizzontale a fondo trasparente è anfibi-confronto-giorno-10.png e appare solo alla conclusione della prova.

La consegna indica 6 dalmatine. Il contatore sotto l'immagine registra ogni animale selezionato, senza giudicare la specie. Si può deselezionare ripetendo il tocco. Non c'è un limite di 6 selezioni: si possono scegliere anche tutti i 19 animali, ma le selezioni errate annullano altrettante corrette. Punteggio: floor(8 * max(0,corrette-errate) / 6), più 2 soltanto per tutte e 6 le dalmatine senza errori. Massimo 10. Due tentativi, viene conservato il migliore.

Dopo Conferma appaiono il conteggio corrette/altre specie e i colori sulle sole selezioni effettuate: verde corrette, rosso errate. Al primo tentativo le dalmatine non selezionate non vengono rivelate. Alla chiusura (secondo tentativo, punteggio pieno o Concludi) vengono mostrate tutte e sei, insieme alla spiegazione, alla tavola di confronto e al pulsante per l'area.

Le selezioni e l'ultimo invio confermato sono memorizzati separatamente in sessionStorage per personaggio, anno, giorno e versione. Il riepilogo visivo del tentativo è disponibile nel browser che lo ha effettuato; punti e tentativi sono salvati su Supabase. La scena ha ingrandimento, scorrimento interno e collegamento all'originale. Gli animali restano mimetizzati finché non vengono selezionati.

Eseguire 012_day10_frogs.sql dopo 007. Aggiorna il calcolo per questa variante find e i contenuti del giorno 10, mantenendo le regole delle altre giornate. Non elimina profili né risultati. Versione sanvitale-frogs-v1. Se il database non è aggiornato, il sito propone Prova senza salvare. Testi e fonti sono nei dati della giornata; la composizione non è presentata come censimento della fauna della Golena, e la spiegazione distingue la rana toro invasiva.

-- Solo testi e fonti della giornata 13. Non modifica punti, tentativi o versione del puzzle.
begin;
update calendar_private.calendar_days set challenge=challenge||jsonb_build_object('explanation','La protagonista del puzzle è la cicogna bianca (Ciconia ciconia). La riconosci dal piumaggio bianco, dalle grandi penne nere delle ali e dal lungo becco rossastro. È un grande trampoliere: quando apre le ali può avvicinarsi ai due metri di apertura.

Cerca il cibo in ambienti aperti, come prati, campi e zone umide poco profonde. Il suo lungo becco le permette di catturare prede diverse: grandi insetti, anfibi, piccoli mammiferi e altri piccoli animali.

Un indizio per distinguerla dagli aironi? In volo la cicogna tiene il collo disteso, mentre gli aironi lo ripiegano. Per il nido sceglie punti elevati, come alberi, edifici e piattaforme.

Alle Vasche Ex Zuccherificio di Crevalcore è documentata la nidificazione spontanea delle cicogne. Il puzzle ci porta così dal ritratto di un animale a un luogo dove conoscere il suo ambiente.','sources','[{"title":"Lipu — Cicogna bianca","url":"https://www.lipu.it/uccelli/conoscerli-proteggerli/cicogna-bianca"},{"title":"GIAPP — Vasche Ex Zuccherificio","url":"https://naturadipianura.it/luoghi/vasche-ex-zuccherificio/"}]'::jsonb),area_description='A Crevalcore, le vasche di decantazione di un vecchio zuccherificio hanno trovato una nuova vita. Dopo la chiusura dell’impianto nel 1985, questi bacini sono diventati ambienti umidi che offrono rifugio alla fauna della pianura.

L’area si estende per circa 22 ettari. L’acqua ha profondità diverse: accanto agli specchi aperti si incontrano bassi fondali, superfici fangose, prati umidi e canneti. Salici e sambuchi crescono sugli argini; nelle vicinanze si trovano anche rimboschimenti. Questo mosaico offre spazi per alimentarsi, sostare e nidificare.

Gli uccelli cambiano con le stagioni. Durante le migrazioni arrivano numerosi ospiti; in inverno si possono osservare anatre, cormorani e aironi. Tra le presenze documentate ci sono anche le cicogne, protagoniste della nostra giornata. Le acque ospitano inoltre anfibi e testuggini palustri.

Le Vasche sono un’Area di Riequilibrio Ecologico e fanno parte del sito Natura 2000 “Biotopi e ripristini ambientali di Crevalcore”. Sono gestite da Sustenia per conto del Comune. Per osservare senza disturbare, resta sul percorso segnalato e rispetta le indicazioni presenti sul posto.' where day=13 and challenge->>'type'='puzzle';
commit;

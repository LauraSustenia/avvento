(() => {
  'use strict';
  const element=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el;};
  let serial=0;
  window.GiappRiverPath={create({asset,image='images/giochi/samoggia-percorsi.png',reveal=false}={}){
    const source=asset?asset(image):image,figure=element('figure','river-game'+(reveal?' river-game--solution':''));
    const viewport=element('div','river-viewport');viewport.id='river-picture-'+(++serial);viewport.tabIndex=0;viewport.setAttribute('role','region');viewport.setAttribute('aria-label','Illustrazione dei percorsi del Samoggia. Quando ingrandita, usa le frecce o scorri per esplorarla.');
    const img=element('img','river-illustration');img.src=source;img.width=1942;img.height=809;img.decoding='async';
    img.alt='Illustrazione ad acquerello con tre corsi d’acqua intrecciati e vegetazione invernale. La partenza Fiume Samoggia è in basso a sinistra, sul punto verde. Gli arrivi a destra sono, dall’alto: Fiume Reno, Laghetti di Calderara e Modena.';
    viewport.append(img);figure.append(viewport);
    const controls=element('div','river-controls'),zoom=element('button','day-button day-button--light','Ingrandisci l’illustrazione');zoom.type='button';zoom.dataset.riverZoom='';zoom.setAttribute('aria-pressed','false');zoom.setAttribute('aria-controls',viewport.id);
    zoom.addEventListener('click',()=>{const enlarged=viewport.classList.toggle('is-zoomed');zoom.textContent=enlarged?'Adatta allo schermo':'Ingrandisci l’illustrazione';zoom.setAttribute('aria-pressed',String(enlarged));viewport.scrollTo({left:0,top:0});});
    const full=element('a','river-open','Apri l’immagine completa ↗');full.href=source;full.target='_blank';full.rel='noopener';controls.append(zoom,full);figure.append(controls);
    const caption=element('figcaption','',reveal?'La destinazione corretta è il Fiume Reno, illustrato in alto a destra. La partenza del Samoggia è il punto verde in basso a sinistra.':'Parti dal punto verde in basso a sinistra. Agli incroci segui la stessa linea, senza cambiare ramo. Puoi ingrandire l’immagine e scorrerla anche sul telefono. Il disegno è un gioco, non una mappa geografica.');figure.append(caption);
    return figure;
  }};
})();

(() => {
  'use strict';
  const el=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
  const valid=(items,total)=>Array.isArray(items)&&items.length<=total&&items.every(i=>Number.isInteger(i)&&i>=0&&i<total)&&new Set(items).size===items.length;
  const read=key=>{try{return JSON.parse(sessionStorage.getItem(key)||'null')||{};}catch{return{};}};
  function picture(c,asset,{selected=new Set(),reveal=false,closed=false,toggle=null}={}){
    const figure=el('figure','frog-picture'),viewport=el('div','frog-viewport'),scene=el('div','frog-scene'),image=el('img','frog-scene-image');viewport.tabIndex=0;viewport.setAttribute('role','region');viewport.setAttribute('aria-label','Stagno illustrato: puoi ingrandirlo e scorrerlo per cercare gli anfibi.');
    image.src=asset(c.image);image.alt='Stagno nel bosco con rane e rospi, alcuni mimetizzati tra foglie e radici.';image.width=1536;image.height=1024;image.decoding='async';image.draggable=false;scene.append(image);viewport.append(scene);figure.append(viewport);
    c.targets.forEach((target,i)=>{const button=el('button','frog-target');button.type='button';button.dataset.frogTarget=i;Object.assign(button.style,{left:target.x+'%',top:target.y+'%',width:target.w+'%',height:target.h+'%'});button.setAttribute('aria-label','Animale '+(i+1)+': '+c.choices[i]);button.setAttribute('aria-pressed',String(selected.has(i)));
      if(reveal){const correct=c.solution.includes(i);button.disabled=true;if(selected.has(i)){button.classList.add(correct?'is-hit':'is-miss');button.textContent=correct?'✓':'×';button.setAttribute('aria-label',c.species[i]+(correct?', dalmatina selezionata correttamente':', altra specie selezionata'));}else if(closed&&correct){button.classList.add('is-solution');button.textContent='✓';button.setAttribute('aria-label','Rana dalmatina da individuare');}}
      else{button.classList.toggle('is-selected',selected.has(i));button.textContent=selected.has(i)?'✓':'';button.addEventListener('click',()=>toggle(i));}scene.append(button);
    });
    const controls=el('div','frog-controls'),zoom=el('button','day-button day-button--light','Ingrandisci lo stagno');zoom.type='button';zoom.dataset.frogZoom='';zoom.setAttribute('aria-pressed','false');zoom.addEventListener('click',()=>{const on=scene.classList.toggle('is-zoomed');zoom.setAttribute('aria-pressed',String(on));zoom.textContent=on?'Adatta allo schermo':'Ingrandisci lo stagno';viewport.scrollTo({left:0,top:0});});
    const full=el('a','frog-open','Apri l’immagine completa ↗');full.href=asset(c.image);full.target='_blank';full.rel='noopener';controls.append(zoom,full);figure.append(controls);return{figure,scene};
  }
  window.GiappFrogSearch={render(container,c,{asset,storageKey}){
    const key=storageKey+':frog-search',saved=read(key);let selected=new Set(valid(saved.selected,c.targets.length)?saved.selected:[]);
    const {figure,scene}=picture(c,asset,{selected,toggle});container.append(figure);
    const counter=el('p','frog-counter');counter.dataset.frogCounter='';counter.setAttribute('role','status');counter.setAttribute('aria-atomic','true');figure.insertBefore(counter,figure.querySelector('.frog-controls'));
    container.append(el('p','frog-note','Il contatore conta tutti gli animali che hai selezionato, non solo le dalmatine. Tocca di nuovo un animale per deselezionarlo. La verifica avviene soltanto quando confermi.'));
    function persist(){try{sessionStorage.setItem(key,JSON.stringify({...read(key),selected:[...selected]}));}catch{}}
    function paint(){counter.textContent='Animali selezionati: '+selected.size+' · Dalmatine da trovare: '+c.target_count;scene.querySelectorAll('[data-frog-target]').forEach(button=>{const chosen=selected.has(Number(button.dataset.frogTarget));button.setAttribute('aria-pressed',String(chosen));button.classList.toggle('is-selected',chosen);button.textContent=chosen?'✓':'';});}
    function toggle(i){selected.has(i)?selected.delete(i):selected.add(i);persist();paint();}
    paint();return{get:()=>({targets:[...selected].sort((a,b)=>a-b)}),focus:()=>scene.querySelector('button').focus(),rememberSubmission(submission){try{sessionStorage.setItem(key,JSON.stringify({...read(key),submitted:[...submission.targets]}));}catch{}}};
  },result(c,{asset,storageKey,closed}){
    const saved=read(storageKey+':frog-search'),hasSubmission=valid(saved.submitted,c.targets.length),selected=new Set(hasSubmission?saved.submitted:[]),section=el('section','frog-result');
    if(!hasSubmission&&!closed){section.append(el('p','frog-note','Il risultato del tentativo precedente è salvato. Puoi riprovare da questo dispositivo.'));return section;}
    if(hasSubmission){const right=[...selected].filter(i=>c.solution.includes(i)).length,wrong=selected.size-right;section.append(el('h3','','Le tue scelte'),el('p','frog-feedback',right+' dalmatine selezionate correttamente · '+wrong+' animali di altre specie selezionati.'));}
    section.append(el('p','frog-note',closed?'In verde sono indicate tutte e 6 le dalmatine; in rosso le altre specie che avevi selezionato.':'In verde le dalmatine che hai selezionato; in rosso gli animali di altre specie. Le dalmatine non selezionate restano nascoste per il secondo tentativo.'));
    section.append(picture(c,asset,{selected,reveal:true,closed}).figure);
    if(closed){section.append(el('h3','','Confronta le specie'));const strip=el('div','frog-comparison'),image=el('img');image.src=asset(c.comparison_image);image.alt='Da sinistra: rana toro, rospo smeraldino, rana verde e rana dalmatina.';strip.tabIndex=0;strip.setAttribute('role','region');strip.setAttribute('aria-label','Tavola delle quattro specie: scorri lateralmente per confrontarle.');strip.append(image);section.append(strip);
      const notes=el('ul','frog-species-notes');
      (c.species_notes||[]).forEach(item=>{const li=el('li'),name=el('strong','',item.name+' — ');li.append(name,document.createTextNode(item.description+' '));if(/^https:\/\/it\.wikipedia\.org\/wiki\//.test(item.url)){const link=el('a','','Wikipedia ↗');link.href=item.url;link.target='_blank';link.rel='noopener noreferrer';link.setAttribute('aria-label',item.name+' su Wikipedia');li.append(link);}notes.append(li);});
      if(notes.children.length)section.append(notes);
      const extra=c.additional_species_link;if(extra&&/^https:\/\/it\.wikipedia\.org\/wiki\//.test(extra.url)){const paragraph=el('p','frog-note',extra.description+' '),link=el('a','',extra.name+' su Wikipedia ↗');link.href=extra.url;link.target='_blank';link.rel='noopener noreferrer';paragraph.append(link);section.append(paragraph);}
    }
    return section;
  }};
})();

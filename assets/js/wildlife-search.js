(() => {
  'use strict';
  const el=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
  const read=key=>{try{return JSON.parse(sessionStorage.getItem(key)||'{}');}catch{return{};}};
  const valid=(items,total)=>Array.isArray(items)&&items.length<=total&&items.every(i=>Number.isInteger(i)&&i>=0&&i<total)&&new Set(items).size===items.length;
  function picture(c,asset,{selected=new Set(),closed=false,toggle=null}={}){
    const figure=el('figure','wildlife-picture'),viewport=el('div','wildlife-viewport'),scene=el('div','wildlife-scene'),image=el('img','wildlife-image');
    viewport.tabIndex=0;viewport.setAttribute('role','region');viewport.setAttribute('aria-label','Paesaggio illustrato del Panaro. Ingrandisci e scorri per cercare gli animali.');
    image.src=asset(c.image);image.alt=c.image_alt;image.width=c.image_width;image.height=c.image_height;image.draggable=false;scene.append(image);viewport.append(scene);figure.append(viewport);
    c.targets.forEach((target,index)=>{
      const button=el('button','wildlife-target');button.type='button';button.dataset.wildlifeTarget=index;
      Object.assign(button.style,{left:target.x+'%',top:target.y+'%',width:target.w+'%',height:target.h+'%'});
      button.setAttribute('aria-pressed',String(selected.has(index)));
      button.setAttribute('aria-label',closed?c.choices[index]:'Animale da cercare, zona '+(index+1));
      button.classList.toggle('is-selected',selected.has(index));button.textContent=selected.has(index)?'✓':'';
      if(closed){button.disabled=true;button.classList.add('is-solution');button.textContent=String(index+1);}
      else button.addEventListener('click',()=>toggle(index));
      scene.append(button);
    });
    const controls=el('div','wildlife-controls'),zoom=el('button','day-button day-button--light','Ingrandisci la scena');zoom.type='button';zoom.dataset.wildlifeZoom='';zoom.setAttribute('aria-pressed','false');
    zoom.addEventListener('click',()=>{const on=scene.classList.toggle('is-zoomed');zoom.setAttribute('aria-pressed',String(on));zoom.textContent=on?'Adatta allo schermo':'Ingrandisci la scena';viewport.scrollTo({left:0,top:0});});
    const full=el('a','wildlife-open','Apri l’immagine completa ↗');full.href=asset(c.image);full.target='_blank';full.rel='noopener noreferrer';controls.append(zoom,full);figure.append(controls);
    return{figure,scene,controls};
  }
  window.GiappWildlifeSearch={render(container,c,{asset,storageKey}){
    const key=storageKey+':wildlife-search',saved=read(key);let selected=new Set(valid(saved.selected,c.targets.length)?saved.selected:[]);
    const {figure,scene,controls}=picture(c,asset,{selected,toggle});container.append(figure);
    const counter=el('p','wildlife-counter');counter.dataset.wildlifeCounter='';counter.setAttribute('role','status');counter.setAttribute('aria-atomic','true');figure.insertBefore(counter,controls);
    container.append(el('p','wildlife-note','Tocca di nuovo un animale per togliere la selezione. Puoi ingrandire la scena e scorrerla anche sul telefono. Conferma quando hai terminato la ricerca.'));
    function paint(){counter.textContent='Animali trovati: '+selected.size+' / '+c.target_count;scene.querySelectorAll('[data-wildlife-target]').forEach(button=>{const on=selected.has(Number(button.dataset.wildlifeTarget));button.setAttribute('aria-pressed',String(on));button.classList.toggle('is-selected',on);button.textContent=on?'✓':'';});}
    function toggle(index){selected.has(index)?selected.delete(index):selected.add(index);try{sessionStorage.setItem(key,JSON.stringify({...read(key),selected:[...selected]}));}catch{}paint();}
    paint();return{get:()=>({targets:[...selected].sort((a,b)=>a-b)}),focus:()=>scene.querySelector('button').focus(),rememberSubmission(submission){try{sessionStorage.setItem(key,JSON.stringify({...read(key),submitted:[...submission.targets]}));}catch{}}};
  },result(c,{asset,storageKey,closed}){
    const section=el('section','wildlife-result'),saved=read(storageKey+':wildlife-search'),known=valid(saved.submitted,c.targets.length),selected=new Set(known?saved.submitted:[]);
    if(!closed){section.append(el('p','wildlife-note','Gli animali che mancano restano nascosti: puoi cercarli con il secondo tentativo.'));return section;}
    section.append(el('h3','','I 20 animali della scena'),el('p','wildlife-note','I numeri indicano dove si trovano gli animali. Alcuni sono visibili solo in parte, tra foglie, canne e acqua.'));
    section.append(picture(c,asset,{selected,closed:true}).figure);
    const list=el('ol','wildlife-species');c.choices.forEach(name=>list.append(el('li','',name)));section.append(list);return section;
  }};
})();

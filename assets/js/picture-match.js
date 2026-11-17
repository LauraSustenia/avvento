(() => {
  'use strict';
  const element=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el;};
  const valid=pairs=>Array.isArray(pairs)&&pairs.length===4&&pairs.every(v=>Number.isInteger(v)&&v>=-1&&v<4)&&new Set(pairs.filter(v=>v>=0)).size===pairs.filter(v=>v>=0).length;
  window.GiappPictureMatch={render(container,c,{asset,storageKey}){
    const key=storageKey?storageKey+':picture-match':null;let pairs=Array(4).fill(-1),active=null;
    try{const saved=JSON.parse(key?sessionStorage.getItem(key):'null');if(valid(saved?.pairs)){pairs=saved.pairs;active=Number.isInteger(saved.active)&&saved.active>=0&&saved.active<4?saved.active:null;}}catch{}
    const status=element('p','picture-match-status');status.setAttribute('role','status');status.setAttribute('aria-atomic','true');container.append(status);
    const panels=element('div','picture-match-panels'),animals=element('figure','picture-match-panel'),shelters=element('figure','picture-match-panel');panels.append(animals,shelters);container.append(panels);
    const buttons=[[],[]],images=[];
    function panel(figure,title,source,zones,names,kind){
      const heading=element('figcaption','picture-match-heading',title),scene=element('div','picture-match-scene'),img=element('img','picture-match-image');img.src=asset(source);img.alt=kind===0?'Pettirosso, cinciallegra, scricciolo e pipistrello su fondo trasparente.':'Quattro rifugi: A in alto a sinistra, B in alto a destra, C appeso in basso a sinistra, D su palo in basso a destra.';img.decoding='async';img.draggable=false;scene.append(img);images.push(img);figure.append(heading,scene);
      zones.forEach((zone,i)=>{const button=element('button','picture-match-hotspot');button.type='button';button.dataset[kind===0?'animal':'shelter']=i;Object.assign(button.style,{left:zone.x+'%',top:zone.y+'%',width:zone.w+'%',height:zone.h+'%'});button.setAttribute('aria-label',kind===0?'Scegli '+names[i]:'Abbina alla cassetta '+String.fromCharCode(65+i)+': '+names[i]);
        const badge=element('span','picture-match-badge',kind===0?String(i+1):String.fromCharCode(65+i));badge.setAttribute('aria-hidden','true');button.append(badge);button.addEventListener('click',()=>kind===0?chooseAnimal(i):chooseShelter(i));scene.append(button);buttons[kind].push(button);
      });
    }
    panel(animals,'1. Tocca un animale',c.animal_image,c.animal_zones,c.left,0);panel(shelters,'2. Tocca la casetta',c.shelter_image,c.shelter_zones,c.right,1);
    const selected=element('p','picture-match-selected');shelters.insertBefore(selected,shelters.children[1]);
    const back=element('button','day-button day-button--light picture-match-back','Scegli un altro animale');back.type='button';back.addEventListener('click',()=>{const next=pairs.findIndex(v=>v<0);buttons[0][next<0?0:next].focus({preventScroll:true});animals.scrollIntoView({behavior:'smooth',block:'center'});});shelters.append(back);
    const summary=element('section','picture-match-summary'),title=element('h3','','I tuoi abbinamenti'),count=element('p','picture-match-count'),list=element('ul','picture-match-list');summary.setAttribute('aria-label','Riepilogo degli abbinamenti scelti');summary.append(title,count,list);container.append(summary);
    const note=element('p','picture-match-note','Puoi cambiare gli abbinamenti prima di confermare. Ogni casetta può essere assegnata a un solo animale.');container.append(note);
    function persist(){if(key)try{sessionStorage.setItem(key,JSON.stringify({pairs,active}));}catch{}}
    function paint(feedback=''){
      const assigned=pairs.filter(v=>v>=0).length;status.textContent=feedback||(active===null?'Tocca un animale, poi la casetta da abbinare.':c.left[active]+' selezionato: ora tocca una casetta.');selected.textContent=active===null?'Scegli prima un animale.':c.left[active]+' selezionato: scegli la sua casetta.';
      buttons[0].forEach((button,i)=>{button.setAttribute('aria-pressed',String(active===i));button.classList.toggle('is-assigned',pairs[i]>=0);button.setAttribute('aria-label','Scegli '+c.left[i]+(pairs[i]>=0?', abbinato alla cassetta '+String.fromCharCode(65+pairs[i]):', da abbinare'));});
      buttons[1].forEach((button,i)=>{const owner=pairs.indexOf(i);button.classList.toggle('is-assigned',owner>=0);button.setAttribute('aria-label','Abbina alla cassetta '+String.fromCharCode(65+i)+': '+c.right[i]+(owner>=0?'. Attualmente assegnata a '+c.left[owner]:''));});
      count.textContent=assigned+' abbinamenti scelti su 4';list.replaceChildren();
      c.left.forEach((name,i)=>{const row=element('li','picture-match-row');row.append(element('span','',name+' → '+(pairs[i]<0?'Da scegliere':'Cassetta '+String.fromCharCode(65+pairs[i])+' · '+c.right[pairs[i]])));
        if(pairs[i]>=0){const remove=element('button','picture-match-remove','Rimuovi');remove.type='button';remove.setAttribute('aria-label','Rimuovi abbinamento di '+name);remove.addEventListener('click',()=>{pairs[i]=-1;active=i;persist();paint('Abbinamento rimosso. Scegli una nuova casetta per '+name+'.');buttons[0][i].focus();});row.append(remove);}list.append(row);
      });
    }
    function chooseAnimal(i){active=i;persist();paint();if(matchMedia('(max-width: 700px)').matches)shelters.scrollIntoView({behavior:'smooth',block:'start'});}
    function chooseShelter(i){if(active===null){paint('Prima tocca l’animale da abbinare.');return;}const animal=active,old=pairs.indexOf(i);if(old>=0&&old!==animal)pairs[old]=-1;pairs[animal]=i;active=null;persist();const feedback=c.left[animal]+' → Cassetta '+String.fromCharCode(65+i)+'.'+(old>=0&&old!==animal?' '+c.left[old]+' è ora da abbinare.':'');paint(feedback);selected.textContent=feedback;}
    images.forEach(img=>img.addEventListener('error',()=>{paint('Una delle immagini non si carica. Ricarica la pagina prima di completare la prova.');}));
    paint();return{get:()=>({pairs:[...pairs]}),focus:()=>buttons[0][active??0].focus()};
  },solution(c){const section=element('section','picture-match-solution');section.append(element('h3','','Gli abbinamenti del gioco'));const list=element('ul');c.left.forEach((name,i)=>list.append(element('li','',name+' → Cassetta '+String.fromCharCode(65+c.solution[i])+' · '+c.right[c.solution[i]])));section.append(list);return section;}};
})();

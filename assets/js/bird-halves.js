(() => {
 'use strict';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const shuffle=()=>{const a=[0,1,2,3];for(let i=3;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;};
 const permutation=a=>Array.isArray(a)&&a.length===4&&new Set(a).size===4&&a.every(i=>Number.isInteger(i)&&i>=0&&i<4);
 const read=key=>{try{return JSON.parse(sessionStorage.getItem(key)||'{}');}catch{return{};}};
 let serial=0;
 function art(c,index,asset,part='whole'){
  const ns='http://www.w3.org/2000/svg',node=(tag,attrs={})=>{const n=document.createElementNS(ns,tag);for(const[k,v]of Object.entries(attrs))n.setAttribute(k,v);return n;};
  const [x,y,w,h]=c.sheet.regions[index],cut=h/2,sy=part==='bottom'?y+cut:y,sh=part==='whole'?h:cut,id='bird-halves-'+(++serial);
  const svg=node('svg',{viewBox:[x,sy,w,sh].join(' '),'aria-hidden':'true',focusable:'false'}),defs=node('defs'),clip=node('clipPath',{id,clipPathUnits:'userSpaceOnUse'});
  svg.style.aspectRatio=w+'/'+sh;clip.append(node('rect',{x,y:sy,width:w,height:sh}));defs.append(clip);svg.append(defs,node('image',{href:asset(c.sheet.image),width:c.sheet.width,height:c.sheet.height,'clip-path':'url(#'+id+')'}));return svg;
 }
 window.GiappBirdHalves={render(container,c,{asset,storageKey,onMessage=()=>{}}){
  const key=storageKey+':bird-halves',saved=read(key),top=permutation(saved.top)?saved.top:shuffle(),bottom=permutation(saved.bottom)?saved.bottom:shuffle();
  if(top.every((v,i)=>v===bottom[i]))bottom.push(bottom.shift());
  const valid=Array.isArray(saved.pairs)&&saved.pairs.length===4&&saved.pairs.every(i=>Number.isInteger(i)&&i>=-1&&i<4)&&new Set(saved.pairs.filter(i=>i>=0)).size===saved.pairs.filter(i=>i>=0).length;
  let pairs=valid?[...saved.pairs]:[-1,-1,-1,-1],active=null;
  const upper=el('section','bird-halves-upper'),lower=el('section','bird-halves-lower'),cards=el('div','bird-halves-grid'),bank=el('div','bird-halves-grid'),status=el('p','bird-halves-status');
  upper.append(el('h3','','1. Scegli una metà superiore'),cards);lower.append(el('h3','','2. Abbina una metà inferiore'),bank);status.setAttribute('role','status');status.setAttribute('aria-atomic','true');
  const upperButtons=[],lowerButtons=[];
  top.forEach((identity,position)=>{const card=el('div','bird-halves-card'),label=String.fromCharCode(65+position),button=el('button','bird-halves-preview'),picture=el('span','bird-halves-picture'),slot=el('span','bird-halves-slot'),description=el('p','bird-halves-assignment'),remove=el('button','bird-halves-remove','Rimuovi');
   button.type='button';button.dataset.birdTop=identity;button.setAttribute('aria-pressed','false');button.setAttribute('aria-label','Scegli la metà superiore '+label);slot.dataset.birdSlot=identity;slot.style.aspectRatio=c.sheet.regions[identity][2]+'/'+(c.sheet.regions[identity][3]/2);picture.append(art(c,identity,asset,'top'),slot);button.append(el('strong','bird-halves-label',label),picture);button.addEventListener('click',()=>{active=identity;paint();});remove.type='button';remove.dataset.birdRemove=identity;remove.setAttribute('aria-label','Rimuovi la metà inferiore abbinata ad '+label);remove.addEventListener('click',()=>{pairs[identity]=-1;active=identity;persist();paint();button.focus();});card.append(button,description,remove);cards.append(card);upperButtons.push({identity,button,slot,description,remove,label});
  });
  bottom.forEach((identity,position)=>{const label=String(position+1),button=el('button','bird-halves-piece');button.type='button';button.dataset.birdBottom=identity;button.setAttribute('aria-label','Abbina la metà inferiore '+label);button.append(art(c,identity,asset,'bottom'),el('strong','bird-halves-label',label));button.addEventListener('click',()=>{if(active===null){onMessage('Scegli prima una metà superiore.');status.textContent='Scegli prima una metà superiore.';return;}const chosen=active,owner=pairs.indexOf(identity);if(owner>=0)pairs[owner]=-1;pairs[chosen]=identity;active=null;persist();paint();status.textContent='Abbinata la metà inferiore '+label+'. Osserva il risultato e continua con le altre metà.';});bank.append(button);lowerButtons.push({identity,button});});
  const counter=el('p','bird-halves-counter');counter.dataset.birdHalvesCounter='';counter.setAttribute('aria-live','polite');container.append(status,upper,lower,counter,el('p','bird-halves-note','Ogni metà inferiore può essere usata una volta. Gli incastri si possono cambiare: il risultato viene valutato soltanto alla conferma.'));
  function persist(){try{sessionStorage.setItem(key,JSON.stringify({top,bottom,pairs}));}catch{}}
  function paint(){
   status.textContent=active===null?'Scegli una metà superiore, poi una metà inferiore per ricomporre l’uccello.':'Metà superiore '+upperButtons.find(v=>v.identity===active).label+' selezionata: scegli la metà inferiore.';
   upperButtons.forEach(({identity,button,slot,description,remove,label})=>{button.setAttribute('aria-pressed',String(active===identity));button.classList.toggle('is-assigned',pairs[identity]>=0);slot.replaceChildren();remove.hidden=pairs[identity]<0;
    if(pairs[identity]>=0){slot.append(art(c,pairs[identity],asset,'bottom'));description.textContent=label+' + '+(bottom.indexOf(pairs[identity])+1);}else{slot.append(el('span','','Scegli la metà inferiore'));description.textContent='Da completare';}
   });lowerButtons.forEach(({identity,button})=>button.classList.toggle('is-assigned',pairs.includes(identity)));counter.textContent='Uccelli ricomposti: '+pairs.filter(v=>v>=0).length+' / 4';
  }
  paint();persist();return{get:()=>({pairs:[...pairs]}),focus:()=>upperButtons[0].button.focus()};
 },solution(c,{asset}){
  const section=el('section','bird-halves-solution'),grid=el('div','bird-halves-recap');section.append(el('h3','','Gli uccelli ricomposti'),grid);
  c.names.forEach((name,index)=>{const figure=el('figure'),caption=el('figcaption');caption.append(el('strong','',name),el('em','',c.scientific_names[index]),el('p','',c.bird_notes[index]));figure.append(art(c,index,asset),caption);grid.append(figure);});return section;
 }};
})();

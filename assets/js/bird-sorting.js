(() => {
 'use strict';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const shuffle=()=>{const a=Array.from({length:8},(_,i)=>i);for(let i=7;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;};
 const validOrder=a=>Array.isArray(a)&&a.length===8&&new Set(a).size===8&&a.every(v=>Number.isInteger(v)&&v>=0&&v<8);
 const validPairs=a=>Array.isArray(a)&&a.length===8&&a.every(v=>Number.isInteger(v)&&v>=-1&&v<=1);
 const read=key=>{try{return JSON.parse(sessionStorage.getItem(key)||'{}');}catch{return{};}};let serial=0;
 function bird(c,index,asset){
  const ns='http://www.w3.org/2000/svg',node=(tag,attrs={})=>{const n=document.createElementNS(ns,tag);for(const[k,v]of Object.entries(attrs))n.setAttribute(k,v);return n;};
  const item=c.birds[index],sheet=c.sheets[item.sheet],[x,y,w,h]=sheet.regions[item.tile],id='bird-sort-'+(++serial),svg=node('svg',{viewBox:[x,y,w,h].join(' '),'aria-hidden':'true',focusable:'false'}),defs=node('defs'),clip=node('clipPath',{id,clipPathUnits:'userSpaceOnUse'});clip.append(node('rect',{x,y,width:w,height:h}));defs.append(clip);svg.append(defs,node('image',{href:asset(sheet.image),width:sheet.width,height:sheet.height,'clip-path':'url(#'+id+')'}));return svg;
 }
 window.GiappBirdSorting={render(container,c,{asset,storageKey,onMessage=()=>{}}){
  const key=storageKey+':bird-sorting',saved=read(key),order=validOrder(saved.order)?saved.order:shuffle();let pairs=validPairs(saved.pairs)?[...saved.pairs]:Array(8).fill(-1),active=null;
  const controls=el('div','bird-sort-controls'),selected=el('p','bird-sort-selected'),groups=el('div','bird-sort-groups'),grid=el('div','bird-sort-grid'),counter=el('p','bird-sort-counter'),cards=[];selected.setAttribute('role','status');selected.setAttribute('aria-atomic','true');controls.append(selected,groups);
  c.groups.forEach((name,group)=>{const button=el('button','bird-sort-group'),title=el('strong','',name),hint=el('span','',c.group_descriptions[group]);button.type='button';button.dataset.birdGroup=group;button.append(title,hint);button.addEventListener('click',()=>{if(active===null){onMessage('Scegli prima un uccello.');selected.textContent='Scegli prima un uccello, poi il gruppo.';return;}const identity=active;pairs[identity]=group;active=null;persist();paint();selected.textContent=c.birds[identity].name+' → '+name+'. Puoi cambiare la scelta.';});groups.append(button);});
  order.forEach(identity=>{const button=el('button','bird-sort-card'),assignment=el('span','bird-sort-assignment');button.type='button';button.dataset.sortBird=identity;button.setAttribute('aria-pressed','false');button.append(bird(c,identity,asset),el('strong','',c.birds[identity].name),assignment);button.addEventListener('click',()=>{active=identity;paint();});grid.append(button);cards.push({identity,button,assignment});});
  counter.dataset.birdSortCounter='';counter.setAttribute('aria-live','polite');container.append(controls,grid,counter,el('p','bird-sort-help','Tocca una carta per selezionarla, poi scegli il gruppo. Puoi riassegnare gli uccelli prima di confermare.'));
  function persist(){try{sessionStorage.setItem(key,JSON.stringify({order,pairs}));}catch{}}
  function paint(){selected.textContent=active===null?'Scegli un uccello, poi il suo gruppo.':c.birds[active].name+': scegli il gruppo.';cards.forEach(({identity,button,assignment})=>{button.setAttribute('aria-pressed',String(active===identity));button.classList.toggle('is-assigned',pairs[identity]>=0);assignment.textContent=pairs[identity]<0?'Da assegnare':'Scelta: '+c.groups[pairs[identity]];button.setAttribute('aria-label',c.birds[identity].name+', '+assignment.textContent);});counter.textContent='Uccelli assegnati: '+pairs.filter(v=>v>=0).length+' / 8';}
  paint();persist();return{get:()=>({pairs:[...pairs]}),focus:()=>cards[0].button.focus()};
 },solution(c,{asset}){
  const section=el('section','bird-sort-solution');c.groups.forEach((group,groupIndex)=>{const part=el('section','bird-sort-group-solution'),grid=el('div','bird-sort-recap');part.append(el('h3','',group),grid);c.birds.forEach((item,index)=>{if(c.solution[index]!==groupIndex)return;const figure=el('figure'),caption=el('figcaption'),link=el('a','bird-sort-source','Scheda LIPU ↗');caption.append(el('strong','',item.name),el('em','',item.scientific_name),el('p','',item.note));if(/^https:\/\/www\.lipu\.it\//.test(item.source)){link.href=item.source;link.target='_blank';link.rel='noopener noreferrer';caption.append(link);}figure.append(bird(c,index,asset),caption);grid.append(figure);});section.append(part);});return section;
 }};
})();

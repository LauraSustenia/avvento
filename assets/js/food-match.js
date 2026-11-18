(() => {
 'use strict';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const shuffle=()=>{const a=[0,1,2,3];for(let i=3;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;};
 const order=a=>Array.isArray(a)&&a.length===4&&new Set(a).size===4&&a.every(i=>Number.isInteger(i)&&i>=0&&i<4);
 const read=key=>{try{return JSON.parse(sessionStorage.getItem(key)||'{}');}catch{return{};}};
 let serial=0;
 function art(c,index,asset,food=false){
  const ns='http://www.w3.org/2000/svg',node=(tag,attrs={})=>{const n=document.createElementNS(ns,tag);for(const[k,v]of Object.entries(attrs))n.setAttribute(k,v);return n;};
  const sheet=food?c.food_sheet:c.bird_sheet,[x,y,w,h]=sheet.regions[index],id='food-art-'+(++serial);
  const svg=node('svg',{viewBox:[x,y,w,h].join(' '),'aria-hidden':'true',focusable:'false'}),defs=node('defs'),clip=node('clipPath',{id,clipPathUnits:'userSpaceOnUse'});
  clip.append(node('rect',{x,y,width:w,height:h}));defs.append(clip);svg.append(defs,node('image',{href:asset(sheet.image),width:sheet.width,height:sheet.height,'clip-path':'url(#'+id+')'}));return svg;
 }
 window.GiappFoodMatch={render(container,c,{asset,storageKey,onMessage=()=>{}}){
  const key=storageKey+':food-match',saved=read(key),left=order(saved.left)?saved.left:shuffle(),right=order(saved.right)?saved.right:shuffle();
  if(left.every((v,i)=>v===right[i]))right.push(right.shift());
  const valid=Array.isArray(saved.pairs)&&saved.pairs.length===4&&saved.pairs.every(i=>Number.isInteger(i)&&i>=-1&&i<4)&&new Set(saved.pairs.filter(i=>i>=0)).size===saved.pairs.filter(i=>i>=0).length;
  let pairs=valid?[...saved.pairs]:[-1,-1,-1,-1],active=null;
  const board=el('div','food-match-board'),birds=el('section','food-match-panel'),foods=el('section','food-match-panel'),leftGrid=el('div','food-match-grid'),rightGrid=el('div','food-match-grid');
  birds.append(el('h3','','1. Scegli un uccello'),leftGrid);foods.append(el('h3','','2. Scegli il cibo'),rightGrid);board.append(birds,foods);
  const birdButtons=[],foodButtons=[],status=el('p','food-match-status');status.setAttribute('role','status');status.setAttribute('aria-atomic','true');
  for(const[isFood,ids,grid,buttons,names]of[[false,left,leftGrid,birdButtons,c.left],[true,right,rightGrid,foodButtons,c.right]])ids.forEach(identity=>{
   const button=el('button','food-match-card');button.type='button';button.dataset[isFood?'food':'foodBird']=identity;
   if(!isFood)button.setAttribute('aria-pressed','false');button.append(art(c,identity,asset,isFood),el('strong','',names[identity]));
   button.addEventListener('click',()=>{if(!isFood){active=identity;paint();return;}if(active===null){onMessage('Scegli prima un uccello.');status.textContent='Scegli prima un uccello, poi il cibo.';return;}const owner=pairs.indexOf(identity),chosen=active;if(owner>=0)pairs[owner]=-1;pairs[chosen]=identity;active=null;persist();paint();status.textContent=c.left[chosen]+' → '+c.right[identity]+'.';});
   grid.append(button);buttons.push({button,identity});
  });
  const counter=el('p','food-match-counter'),list=el('ul','food-match-list');counter.dataset.foodCounter='';counter.setAttribute('aria-live','polite');
  container.append(board,status,el('h3','','I tuoi abbinamenti'),counter,list,el('p','food-match-note','Ogni cibo può essere abbinato a un solo uccello. Puoi modificare le scelte prima di confermare.'));
  function persist(){try{sessionStorage.setItem(key,JSON.stringify({left,right,pairs}));}catch{}}
  function paint(){
   birdButtons.forEach(({button,identity})=>{button.setAttribute('aria-pressed',String(active===identity));button.classList.toggle('is-assigned',pairs[identity]>=0);});foodButtons.forEach(({button,identity})=>button.classList.toggle('is-assigned',pairs.includes(identity)));
   status.textContent=active===null?'Tocca un uccello, poi il cibo da abbinare.':c.left[active]+' selezionato: scegli il cibo.';counter.textContent='Abbinamenti scelti: '+pairs.filter(i=>i>=0).length+' / 4';list.replaceChildren();
   left.forEach(identity=>{if(pairs[identity]<0)return;const item=el('li'),remove=el('button','','Rimuovi');remove.type='button';remove.setAttribute('aria-label','Rimuovi abbinamento di '+c.left[identity]);remove.addEventListener('click',()=>{pairs[identity]=-1;persist();paint();});item.append(el('span','',c.left[identity]+' → '+c.right[pairs[identity]]),remove);list.append(item);});
  }
  paint();persist();return{get:()=>({pairs:[...pairs]}),focus:()=>birdButtons[0].button.focus()};
 },solution(c,{asset}){
  const section=el('section','food-match-solution'),grid=el('div','food-match-recap');section.append(el('h3','','Gli abbinamenti corretti'),grid);
  c.left.forEach((name,index)=>{const figure=el('figure'),images=el('div','food-match-recap-art'),caption=el('figcaption');images.append(art(c,index,asset),art(c,c.solution[index],asset,true));caption.append(el('strong','',name+' → '+c.right[c.solution[index]]),el('p','',c.diet_notes[index]));figure.append(images,caption);grid.append(figure);});return section;
 }};
})();

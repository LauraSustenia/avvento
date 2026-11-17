(() => {
  'use strict';
  const ns='http://www.w3.org/2000/svg';let serial=0;
  const el=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
  const svgNode=(tag,attrs)=>{const node=document.createElementNS(ns,tag);for(const[k,v]of Object.entries(attrs))node.setAttribute(k,v);return node;};
  const shuffled=()=>[0,1,2,3].map(i=>({i,n:Math.random()})).sort((a,b)=>a.n-b.n).map(v=>v.i);
  const permutation=a=>Array.isArray(a)&&a.length===4&&a.every(v=>Number.isInteger(v)&&v>=0&&v<4)&&new Set(a).size===4;
  const valid=a=>Array.isArray(a)&&a.length===4&&a.every(v=>Number.isInteger(v)&&v>=-1&&v<4)&&new Set(a.filter(v=>v>=0)).size===a.filter(v=>v>=0).length;
  function illustration(source,tile){
    const x=tile.x*21.72,y=tile.y*7.24,w=tile.w*21.72,h=tile.h*7.24,id='bill-tile-'+(++serial),svg=svgNode('svg',{viewBox:`${x} ${y} ${w} ${h}`,preserveAspectRatio:'xMidYMid meet','aria-hidden':'true',focusable:'false'}),defs=svgNode('defs',{}),clip=svgNode('clipPath',{id,clipPathUnits:'userSpaceOnUse'});
    if(tile.clip)clip.append(svgNode('polygon',{points:tile.clip.map(([a,b])=>`${x+w*a/100},${y+h*b/100}`).join(' ')}));else clip.append(svgNode('rect',{x,y,width:w,height:h}));
    defs.append(clip);svg.append(defs,svgNode('image',{href:source,width:2172,height:724,'clip-path':`url(#${id})`}));return svg;
  }
  window.GiappBeakMatch={render(container,c,{asset,storageKey}){
    const key=storageKey+':beaks';let pairs=Array(4).fill(-1),active=null,leftOrder=shuffled(),rightOrder=shuffled();
    try{const saved=JSON.parse(sessionStorage.getItem(key)||'null');if(valid(saved?.pairs)){pairs=saved.pairs;if(permutation(saved.leftOrder))leftOrder=saved.leftOrder;if(permutation(saved.rightOrder))rightOrder=saved.rightOrder;active=Number.isInteger(saved.active)&&saved.active>=0&&saved.active<4?saved.active:null;}}catch{}
    if(leftOrder.every((v,i)=>v===rightOrder[i]))rightOrder=[...rightOrder.slice(1),rightOrder[0]];
    const status=el('p','beak-status');status.setAttribute('role','status');status.setAttribute('aria-atomic','true');container.append(status);
    const board=el('div','beak-board'),left=el('section','beak-panel'),right=el('section','beak-panel'),leftGrid=el('div','beak-grid'),rightGrid=el('div','beak-grid beak-grid--names');left.append(el('h3','','1. Scegli un becco'),leftGrid);const selected=el('p','beak-selected');right.append(el('h3','','2. Scegli l’uccello'),selected,rightGrid);board.append(left,right);container.append(board);
    const buttons=[[],[]];
    for(const [kind,order,grid,tiles,source,names]of [[0,leftOrder,leftGrid,c.beak_tiles,c.beak_image,c.left],[1,rightOrder,rightGrid,c.bird_tiles,c.bird_image,c.right]]){
      order.forEach(i=>{const button=el('button','beak-card'+(kind===1?' beak-card--bird':''));button.type='button';button.dataset[kind===0?'beak':'beakBird']=i;if(kind===0){const art=el('span','beak-art');art.append(illustration(asset(source),tiles[i]));button.append(art);}button.append(el('strong','',names[i]));button.addEventListener('click',()=>kind===0?choose(i):assign(i));grid.append(button);buttons[kind][i]=button;});
    }
    const back=el('button','day-button day-button--light beak-back','Scegli un altro becco');back.type='button';back.addEventListener('click',()=>{const next=pairs.findIndex(v=>v<0);buttons[0][next<0?0:next].focus({preventScroll:true});left.scrollIntoView({behavior:'smooth',block:'center'});});right.append(back);
    const summary=el('section','beak-summary'),count=el('p','beak-count'),list=el('ul','beak-list');summary.append(el('h3','','I tuoi abbinamenti'),count,list);container.append(summary,el('p','beak-note','Ogni uccello può essere abbinato a un solo becco. Puoi modificare o rimuovere le scelte prima di confermare.'));
    function persist(){try{sessionStorage.setItem(key,JSON.stringify({pairs,active,leftOrder,rightOrder}));}catch{}}
    function paint(feedback=''){
      status.textContent=feedback||(active===null?'Tocca un becco, poi l’uccello corrispondente.':c.left[active]+' selezionato: scegli l’uccello.');selected.textContent=active===null?'Seleziona prima un becco.':c.left[active]+' selezionato';
      buttons[0].forEach((button,i)=>{button.setAttribute('aria-pressed',String(active===i));button.classList.toggle('is-assigned',pairs[i]>=0);button.setAttribute('aria-label',c.left[i]+(pairs[i]>=0?', abbinato a '+c.right[pairs[i]]:''));});
      buttons[1].forEach((button,i)=>{const owner=pairs.indexOf(i);button.classList.toggle('is-assigned',owner>=0);button.setAttribute('aria-label','Abbina a '+c.right[i]+(owner>=0?'; già assegnato a '+c.left[owner]:''));});
      count.textContent=pairs.filter(v=>v>=0).length+' abbinamenti scelti su 4';list.replaceChildren();
      c.left.forEach((name,i)=>{const row=el('li');row.append(el('span','',name+' → '+(pairs[i]<0?'Da scegliere':c.right[pairs[i]])));if(pairs[i]>=0){const remove=el('button','beak-remove','Rimuovi');remove.type='button';remove.setAttribute('aria-label','Rimuovi abbinamento '+name);remove.addEventListener('click',()=>{pairs[i]=-1;active=i;persist();paint('Abbinamento rimosso: scegli di nuovo per '+name+'.');buttons[0][i].focus();});row.append(remove);}list.append(row);});
    }
    function choose(i){active=i;persist();paint();if(matchMedia('(max-width:700px)').matches)right.scrollIntoView({behavior:'smooth',block:'start'});}
    function assign(i){if(active===null){paint('Scegli prima un becco.');return;}const source=active,old=pairs.indexOf(i);if(old>=0&&old!==source)pairs[old]=-1;pairs[source]=i;active=null;persist();const text=c.left[source]+' → '+c.right[i]+(old>=0&&old!==source?'. '+c.left[old]+' è ora da abbinare.':'.');paint(text);selected.textContent=text;}
    paint();persist();return{get:()=>({pairs:[...pairs]}),focus:()=>buttons[0][active??leftOrder[0]].focus()};
  },solution(c,{asset}){
    const section=el('section','beak-solution');section.append(el('h3','','Gli abbinamenti corretti'));const list=el('ul');
    c.left.forEach((name,i)=>{const item=el('li'),note=c.bird_notes[c.solution[i]];item.append(el('strong','',name+' → '+note.name+'. '),document.createTextNode(note.description+' '));if(/^https:\/\/it\.wikipedia\.org\/wiki\//.test(note.url)){const link=el('a','','Wikipedia ↗');link.href=note.url;link.target='_blank';link.rel='noopener noreferrer';item.append(link);}list.append(item);});section.append(list);const img=el('img','beak-complete-birds');img.src=asset(c.bird_image);img.alt='Cicogna bianca, fenicottero, spatola e germano reale, raffigurati interi.';section.append(img);return section;
  }};
})();


(() => {
 'use strict';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 const shuffle=()=>{const a=[0,1,2,3];for(let i=3;i>0;i--){const j=Math.floor(Math.random()*(i+1));[a[i],a[j]]=[a[j],a[i]];}return a;};
 const order=a=>Array.isArray(a)&&a.length===4&&new Set(a).size===4&&a.every(i=>Number.isInteger(i)&&i>=0&&i<4);
 const read=key=>{try{return JSON.parse(sessionStorage.getItem(key)||'{}');}catch{return{};}};
 let artId=0;
 function art(c,index,asset,silhouette=false){
  const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg'),defs=document.createElementNS(ns,'defs'),clip=document.createElementNS(ns,'clipPath'),rect=document.createElementNS(ns,'rect'),image=document.createElementNS(ns,'image'),id='leaf-art-'+(++artId);
  const [x,y,w,h]=c.regions?.[index]||[index%2*c.sheet_width/2,Math.floor(index/2)*c.sheet_height/2,c.sheet_width/2,c.sheet_height/2];
  svg.setAttribute('viewBox',[x,y,w,h].join(' '));svg.setAttribute('aria-hidden','true');svg.setAttribute('focusable','false');clip.setAttribute('id',id);clip.setAttribute('clipPathUnits','userSpaceOnUse');Object.entries({x,y,width:w,height:h}).forEach(([k,v])=>rect.setAttribute(k,v));clip.append(rect);defs.append(clip);
  image.setAttribute('href',asset(c.image));image.setAttribute('width',c.sheet_width);image.setAttribute('height',c.sheet_height);image.setAttribute('clip-path','url(#'+id+')');
  if(silhouette){const filter=document.createElementNS(ns,'filter'),matrix=document.createElementNS(ns,'feColorMatrix'),transfer=document.createElementNS(ns,'feComponentTransfer'),alpha=document.createElementNS(ns,'feFuncA');filter.setAttribute('id',id+'-shape');matrix.setAttribute('type','matrix');matrix.setAttribute('values','0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1 0');alpha.setAttribute('type','discrete');alpha.setAttribute('tableValues','0 1');transfer.append(alpha);filter.append(matrix,transfer);defs.append(filter);image.setAttribute('filter','url(#'+id+'-shape)');}
  svg.append(defs,image);return svg;
 }
 window.GiappLeafMatch={render(container,c,{asset,storageKey,onMessage}){
  const key=storageKey+':leaf-match',saved=read(key),left=order(saved.left)?saved.left:shuffle(),right=order(saved.right)?saved.right:shuffle();
  if(left.every((v,i)=>v===right[i]))right.push(right.shift());
  const valid=Array.isArray(saved.pairs)&&saved.pairs.length===4&&saved.pairs.every(i=>Number.isInteger(i)&&i>=-1&&i<4)&&new Set(saved.pairs.filter(i=>i>=0)).size===saved.pairs.filter(i=>i>=0).length;
  let pairs=valid?[...saved.pairs]:[-1,-1,-1,-1],active=null;
  const board=el('div','leaf-match-board'),leaves=el('section'),trees=el('section');leaves.append(el('h3','','1. Scegli una foglia'));trees.append(el('h3','','2. Scegli l’albero'));
  const shapes=el('div','leaf-shapes'),names=el('div','leaf-names'),shapeButtons=[],nameButtons=[];
  left.forEach((identity,position)=>{const button=el('button','leaf-shape'),label=el('strong','',String.fromCharCode(65+position));button.type='button';button.dataset.leaf=identity;button.setAttribute('aria-label','Foglia '+String.fromCharCode(65+position)+': '+c.shape_descriptions[identity]);button.setAttribute('aria-pressed','false');button.append(art(c,identity,asset),label);button.addEventListener('click',()=>{active=identity;paint();});shapes.append(button);shapeButtons.push({button,identity});});
  right.forEach(identity=>{const button=el('button','leaf-name',c.trees[identity]);button.type='button';button.dataset.tree=identity;button.addEventListener('click',()=>{if(active===null){onMessage('Scegli prima una foglia.');return;}const owner=pairs.indexOf(identity);if(owner>=0)pairs[owner]=-1;pairs[active]=identity;active=null;persist();paint();});names.append(button);nameButtons.push({button,identity});});
  leaves.append(shapes);trees.append(names);board.append(leaves,trees);const counter=el('p','leaf-counter'),list=el('ul','leaf-assignments');counter.dataset.leafCounter='';counter.setAttribute('role','status');counter.setAttribute('aria-atomic','true');container.append(board,counter,list);
  function persist(){try{sessionStorage.setItem(key,JSON.stringify({left,right,pairs}));}catch{}}
  function paint(){shapeButtons.forEach(({button,identity})=>{button.setAttribute('aria-pressed',String(active===identity));button.classList.toggle('is-assigned',pairs[identity]>=0);});nameButtons.forEach(({button,identity})=>button.classList.toggle('is-assigned',pairs.includes(identity)));counter.textContent='Abbinamenti scelti: '+pairs.filter(i=>i>=0).length+' / 4';list.replaceChildren();left.forEach((identity,position)=>{if(pairs[identity]<0)return;const item=el('li','','Foglia '+String.fromCharCode(65+position)+' → '+c.trees[pairs[identity]]+' '),remove=el('button','','Rimuovi');remove.type='button';remove.setAttribute('aria-label','Rimuovi abbinamento della foglia '+String.fromCharCode(65+position));remove.addEventListener('click',()=>{pairs[identity]=-1;persist();paint();});item.append(remove);list.append(item);});}
  paint();persist();return{get:()=>({pairs:[...pairs]}),focus:()=>shapeButtons[0].button.focus()};
 },solution(c,{asset}){
  const section=el('section','leaf-solution');section.append(el('h3','','Le foglie e i loro alberi'));
  const grid=el('div','leaf-recap');c.trees.forEach((name,index)=>{const figure=el('figure'),caption=el('figcaption'),title=el('strong','',name),latin=el('em','',c.scientific_names[index]),note=el('p','',c.leaf_notes[index]);caption.append(title,latin,note);const images=el('div','leaf-recap-art'),leaf=el('div','leaf-recap-leaf'),tree=el('div','leaf-recap-tree');leaf.append(art(c,index,asset));tree.append(art({...c,image:c.tree_image,sheet_width:c.tree_sheet_width,sheet_height:c.tree_sheet_height,regions:c.tree_regions},index,asset));images.append(leaf,tree);figure.append(images,caption);grid.append(figure);});
  section.append(grid);return section;
 }};
})();

(() => {
 'use strict';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};
 function scene(c,asset,reveal=false){
  const figure=el('figure','emys-count-figure'),viewport=el('div','emys-count-viewport'),picture=el('div','emys-count-picture'),image=el('img'),zoom=el('button','day-button day-button--light emys-count-zoom','Ingrandisci l’immagine');
  image.src=asset(c.image);image.alt=reveal?'Le sei Emys sono indicate dai numeri. Le Trachemys, quando presenti, dalle lettere A e B.':'Scena subacquea illustrata di uno stagno, con testuggini palustri e altri animali tra le piante.';image.decoding='async';picture.append(image);viewport.append(picture);figure.append(viewport,zoom);viewport.tabIndex=0;viewport.setAttribute('role','region');viewport.setAttribute('aria-label','Immagine dello stagno. Quando è ingrandita, usa lo scorrimento per esplorarla.');
  if(reveal)c.locations.forEach((location,index)=>{const mark=el('span','emys-count-mark'),number=el('span','',String(index+1));mark.dataset.emysLocation=index;mark.setAttribute('aria-hidden','true');Object.assign(mark.style,{left:location.x+'%',top:location.y+'%',width:location.w+'%',height:location.h+'%'});mark.append(number);picture.append(mark);});
  if(reveal)c.trachemys_locations?.forEach((location,index)=>{const mark=el('span','emys-count-mark emys-count-mark--trachemys'),letter=el('span','',String.fromCharCode(65+index));mark.dataset.trachemysLocation=index;mark.setAttribute('aria-hidden','true');Object.assign(mark.style,{left:location.x+'%',top:location.y+'%',width:location.w+'%',height:location.h+'%'});mark.append(letter);picture.append(mark);});
  zoom.type='button';zoom.setAttribute('aria-pressed','false');zoom.addEventListener('click',()=>{const active=viewport.classList.toggle('is-zoomed');zoom.setAttribute('aria-pressed',String(active));zoom.textContent=active?'Riduci l’immagine':'Ingrandisci l’immagine';if(!active){viewport.scrollTop=0;viewport.scrollLeft=0;}});return figure;
 }
 window.GiappEmysCount={render(container,c,{asset,storageKey}){
  const key=storageKey+':emys-count',label=el('label','emys-count-label','Quante Emys hai contato?'),input=el('input','emys-count-input'),help=el('p','emys-count-help','Scrivi il numero totale di testuggini palustri europee che riesci a trovare. Puoi ingrandire e scorrere l’immagine.');
  input.type='number';input.name='emys-count';input.dataset.emysCount='';input.min='0';input.max=String(c.options.length-1);input.step='1';input.inputMode='numeric';input.required=true;input.autocomplete='off';input.placeholder='Scrivi un numero';
  try{const value=sessionStorage.getItem(key);if(value!==null&&Number.isInteger(Number(value))&&Number(value)>=0&&Number(value)<c.options.length)input.value=value;}catch{}
  input.addEventListener('input',()=>{try{sessionStorage.setItem(key,input.value);}catch{}});label.append(input);container.append(scene(c,asset),label,help);
  return{get:()=>({choice:input.value.trim()===''?NaN:Number(input.value)}),focus:()=>input.focus()};
 },solution(c,{asset}){
  const section=el('section','emys-count-solution'),list=el('ol','emys-count-locations');section.append(el('h3','','Ecco dove erano nascoste'),scene(c,asset,true));c.locations.forEach(location=>list.append(el('li','',location.label)));section.append(list);if(c.trachemys_locations?.length)section.append(el('p','emys-count-help','Le lettere A e B indicano le due Trachemys: non fanno parte del conteggio delle Emys.'));return section;
 }};
})();

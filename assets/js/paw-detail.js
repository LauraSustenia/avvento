(() => {
 'use strict';
 const el=(tag,cls,text)=>{const n=document.createElement(tag);if(cls)n.className=cls;if(text!==undefined)n.textContent=text;return n;};let serial=0;
 function animal(c,index,asset){
  const ns='http://www.w3.org/2000/svg',node=(tag,attrs={})=>{const n=document.createElementNS(ns,tag);for(const[k,v]of Object.entries(attrs))n.setAttribute(k,v);return n;};
  const [x,y,w,h]=c.sheet.regions[index],id='paw-detail-'+(++serial),svg=node('svg',{viewBox:[x,y,w,h].join(' '),'aria-hidden':'true',focusable:'false'}),defs=node('defs'),clip=node('clipPath',{id,clipPathUnits:'userSpaceOnUse'});
  clip.append(node('rect',{x,y,width:w,height:h}));defs.append(clip);svg.append(defs,node('image',{href:asset(c.sheet.image),width:c.sheet.width,height:c.sheet.height,'clip-path':'url(#'+id+')'}));return svg;
 }
 window.GiappPawDetail={render(container,c,{asset}){
  const figure=el('figure','paw-detail-photo'),img=el('img');img.src=asset(c.image);img.alt='Dettaglio ravvicinato di una piccola zampa di mammifero, con dita e artigli visibili.';img.decoding='async';figure.append(img,el('figcaption','',c.image_credit));
  const choices=el('div','day-answers paw-detail-answers');c.options.forEach((text,index)=>{const label=el('label'),input=el('input');input.type='radio';input.name='choice';input.value=index;input.required=true;label.append(input,el('span','',text));choices.append(label);});container.append(figure,choices);
  return{get:()=>({choice:Number(choices.querySelector('input:checked')?.value??NaN)}),focus:()=>choices.querySelector('input')?.focus()};
 },solution(c,{asset}){
  const section=el('section','paw-detail-solution'),grid=el('div','paw-detail-recap');section.append(el('h3','','Confronta gli animali'),grid);c.animals.forEach((name,index)=>{const figure=el('figure'),caption=el('figcaption');caption.append(el('strong','',name),el('em','',c.scientific_names[index]),el('p','',c.paw_notes[index]));figure.append(animal(c,index,asset),caption);grid.append(figure);});return section;
 }};
})();

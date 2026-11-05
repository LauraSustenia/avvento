(() => {
  const element=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el;};
  const shuffle=items=>{const arr=[...items];for(let i=arr.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[arr[i],arr[j]]=[arr[j],arr[i]];}return arr;};
  window.GiappGameUI={render(container,c,{asset,attempt=0,onMessage=()=>{}}){
    container.replaceChildren();let get;
    if(c.instructions)container.append(element('p','game-instructions',c.instructions));
    const image=(source,alt,cls='game-card-image')=>{const img=element('img',cls);img.src=asset(source);img.alt=alt;img.loading='lazy';return img;};
    const radioOptions=()=>{const box=element('div','day-answers');c.options.forEach((text,index)=>{const label=element('label'),input=element('input');input.type='radio';input.name='choice';input.value=index;input.required=true;label.append(input,element('span','',text));box.append(label);});container.append(box);return()=>({choice:Number(box.querySelector('input:checked')?.value??NaN)});};
    if(['quiz','mystery','audio'].includes(c.type)){
      if(c.type==='mystery'){const frame=element('div',`mystery-picture ${attempt?'is-wider':''}`);frame.append(image(c.image,'Dettaglio dell’illustrazione da riconoscere',''));container.append(frame);}
      if(c.type==='audio'){
        const audio=element('audio','game-audio');audio.controls=true;audio.preload='metadata';audio.src=asset(c.audio);audio.append(document.createTextNode('Il browser non supporta l’audio. Usa l’indizio alternativo.'));container.append(audio);
        const details=element('details','game-alternative');details.append(element('summary','','Non posso ascoltare: usa l’indizio alternativo'),element('p','',c.alternative));container.append(details);
        if(c.credit){const credit=element('p','game-credit',c.credit.text+' ');const link=element('a','',c.credit.license);link.href=c.credit.license_url;link.target='_blank';link.rel='noopener';credit.append(link);container.append(credit);}
      }
      get=radioOptions();
    }else if(c.type==='matching'){
      const pairs=Array(4).fill(-1),leftOrder=shuffle([0,1,2,3]),rightOrder=shuffle([0,1,2,3]);let active=leftOrder[0];
      const board=element('div','match-board');const left=element('div','match-column'),right=element('div','match-column');board.append(left,right);container.append(board);
      function paint(){left.replaceChildren();right.replaceChildren();
        leftOrder.forEach(i=>{const button=element('button','match-card');button.type='button';button.dataset.matchLeft=i;button.setAttribute('aria-pressed',String(active===i));button.append(image(c.bird_images[i],''),element('strong','',c.left[i]));if(pairs[i]>=0)button.append(element('span','match-assignment','→ '+c.right[pairs[i]]));button.addEventListener('click',()=>{active=i;paint();left.querySelector(`[data-match-left="${i}"]`).focus();});left.append(button);});
        rightOrder.forEach(i=>{const button=element('button','match-card');button.type='button';button.dataset.matchRight=i;const owner=pairs.indexOf(i);button.append(image(c.nest_images[i],''),element('strong','',c.right[i]));if(owner>=0)button.append(element('span','match-assignment',c.left[owner]));button.addEventListener('click',()=>{const old=pairs.indexOf(i);if(old>=0)pairs[old]=-1;pairs[active]=i;paint();right.querySelector(`[data-match-right="${i}"]`).focus();});right.append(button);});
      }paint();get=()=>({pairs:[...pairs]});
    }else if(c.type==='sequence'){
      let order=shuffle([0,1,2,3]);if(order.every((v,i)=>v===i))order=[2,0,3,1];
      const list=element('ol','sequence-list');container.append(list);
      function paint(focusIndex=null,direction=null){list.replaceChildren();order.forEach((item,index)=>{const li=element('li','sequence-card');li.dataset.sequenceItem=item;li.append(image(c.images[item],''),element('strong','',c.items[item]));const controls=element('div','sequence-controls');for(const [label,delta,dir]of[['↑',-1,'up'],['↓',1,'down']]){const button=element('button','',label);button.type='button';button.dataset.move=dir;button.disabled=index+delta<0||index+delta>=4;button.setAttribute('aria-label',`Sposta ${c.items[item]} ${delta<0?'prima':'dopo'}`);button.addEventListener('click',()=>{const next=index+delta;[order[index],order[next]]=[order[next],order[index]];paint(next,dir);});controls.append(button);}li.append(controls);list.append(li);});if(focusIndex!==null){const target=list.children[focusIndex].querySelector(`[data-move="${direction}"]:not(:disabled)`)||list.children[focusIndex].querySelector('button:not(:disabled)');target?.focus();}}
      paint();get=()=>({order:[...order]});
    }else if(c.type==='find'){
      const selected=new Set(),view=element('div','scene-viewport'),scene=element('div','scene-picture');scene.append(image(c.image,'Scena illustrata con vegetazione, stagno e animali da cercare','scene-image'));view.append(scene);container.append(view);
      const counter=element('p','game-counter','0 animali selezionati');counter.setAttribute('aria-live','polite');
      const zoom=element('button','day-button day-button--light','Ingrandisci la scena');zoom.type='button';zoom.setAttribute('aria-pressed','false');zoom.addEventListener('click',()=>{const on=scene.classList.toggle('is-zoomed');zoom.textContent=on?'Riduci la scena':'Ingrandisci la scena';zoom.setAttribute('aria-pressed',String(on));});container.append(zoom,counter);
      const choices=[];function sync(){counter.textContent=`${selected.size} animali selezionati`;scene.querySelectorAll('[data-target]').forEach(button=>{const chosen=selected.has(Number(button.dataset.target));button.setAttribute('aria-pressed',String(chosen));button.textContent=chosen?'✓':'';});choices.forEach((input,i)=>input.checked=selected.has(i));}
      function toggle(i){if(selected.has(i))selected.delete(i);else if(selected.size<4)selected.add(i);else onMessage('Puoi selezionare al massimo quattro animali.');sync();}
      c.targets.forEach((target,i)=>{const button=element('button','scene-target');button.type='button';button.dataset.target=i;Object.assign(button.style,{left:target.x+'%',top:target.y+'%',width:target.w+'%',height:target.h+'%'});button.setAttribute('aria-label',`Seleziona o deseleziona la zona ${i+1} della scena`);button.setAttribute('aria-pressed','false');button.addEventListener('click',()=>toggle(i));scene.append(button);});
      const alternative=element('details','game-alternative');alternative.append(element('summary','','Gioca con l’elenco degli animali'));const options=element('div','day-answers');c.choices.forEach((text,i)=>{const label=element('label'),input=element('input');input.type='checkbox';input.addEventListener('change',()=>toggle(i));choices.push(input);label.append(input,element('span','',text));options.append(label);});alternative.append(options);container.append(alternative);get=()=>({targets:[...selected]});
    }else throw new Error('Questo tipo di prova non è disponibile.');
    return{get,focus:()=>container.querySelector('input,button,select,summary')?.focus()};
  }};
})();

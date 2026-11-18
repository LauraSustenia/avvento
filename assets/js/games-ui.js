(() => {
  const element=(tag,cls,text)=>{const el=document.createElement(tag);if(cls)el.className=cls;if(text!==undefined)el.textContent=text;return el;};
  const shuffle=items=>{const arr=[...items];for(let i=arr.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[arr[i],arr[j]]=[arr[j],arr[i]];}return arr;};
  window.GiappGameUI={render(container,c,{asset,attempt=0,onMessage=()=>{},storageKey=null}){
    container.replaceChildren();let get;
    if(c.instructions)container.append(element('p','game-instructions',c.instructions));
    const image=(source,alt,cls='game-card-image')=>{const img=element('img',cls);img.src=asset(source);img.alt=alt;img.loading='lazy';return img;};
    const radioOptions=()=>{const box=element('div','day-answers');c.options.forEach((text,index)=>{const label=element('label'),input=element('input');input.type='radio';input.name='choice';input.value=index;input.required=true;label.append(input,element('span','',text));box.append(label);});container.append(box);return()=>({choice:Number(box.querySelector('input:checked')?.value??NaN)});};
    if(c.type==='matching'&&c.visual==='turtle-details')return window.GiappTurtleDetails.render(container,c,{asset,storageKey});
    if(c.type==='matching'&&c.visual==='birdwatch-story')return window.GiappBirdwatchStory.render(container,c,{asset,storageKey});
    if(c.type==='matching'&&c.visual==='water-story')return window.GiappWaterStory.render(container,c,{asset,storageKey});
    if(c.type==='matching'&&c.visual==='bird-sorting')return window.GiappBirdSorting.render(container,c,{asset,storageKey,onMessage});
    if(c.type==='mystery'&&c.visual==='emys-count')return window.GiappEmysCount.render(container,c,{asset,storageKey});
    if(c.type==='mystery'&&c.visual==='paw-detail')return window.GiappPawDetail.render(container,c,{asset});
    if(c.type==='matching'&&c.visual==='bird-halves')return window.GiappBirdHalves.render(container,c,{asset,storageKey,onMessage});
    if(c.type==='matching'&&c.visual==='food-matching')return window.GiappFoodMatch.render(container,c,{asset,storageKey,onMessage});
    if(c.type==='matching'&&c.visual==='leaf-matching')return window.GiappLeafMatch.render(container,c,{asset,storageKey,onMessage});
    if(c.type==='matching'&&c.visual==='audio-matching')return window.GiappAudioMatch.render(container,c,{asset,storageKey,onMessage});
    if(c.type==='memory')return window.GiappMemory.render(container,c,{asset,storageKey,attempt,onMessage});
    if(['quiz','mystery','audio'].includes(c.type)){
      if(c.type==='mystery'){const frame=element('div',`mystery-picture ${attempt?'is-wider':''}`);frame.append(image(c.image,'Dettaglio dell’illustrazione da riconoscere',''));container.append(frame);}
      if(c.type==='audio'){
        const audio=element('audio','game-audio');audio.controls=true;audio.preload='metadata';audio.src=asset(c.audio);audio.append(document.createTextNode('Il browser non supporta l’audio. Usa l’indizio alternativo.'));container.append(audio);
        const details=element('details','game-alternative');details.append(element('summary','','Non posso ascoltare: usa l’indizio alternativo'),element('p','',c.alternative));container.append(details);
        if(c.credit){const credit=element('p','game-credit',c.credit.text+' ');const link=element('a','',c.credit.license);link.href=c.credit.license_url;link.target='_blank';link.rel='noopener';credit.append(link);container.append(credit);}
      }
      if(c.visual==='river-path')container.append(window.GiappRiverPath.create({asset,image:c.image}));
      get=radioOptions();
      if(c.visual==='river-path'){const options=container.lastElementChild;options.classList.add('river-options');options.querySelectorAll('label span').forEach((span,index)=>span.textContent=(index+1)+' · '+span.textContent);}
    }else if(c.type==='wordsearch'){
      const width=c.grid[0].length,total=c.grid.length*width,core=window.GiappGames;
      let paths=[],active=null,focusCell=0,guess='';const key=storageKey?storageKey+':wordsearch':null;
      try{const saved=JSON.parse(sessionStorage.getItem(key)||'null');if(saved){core.wordsearchMatches(c,saved.paths);paths=saved.paths;guess=typeof saved.guess==='string'?saved.guess.slice(0,32):'';}}catch{}
      const viewport=element('div','wordsearch-viewport'),board=element('div','wordsearch-grid');board.style.setProperty('--wordsearch-columns',width);board.setAttribute('role','group');board.setAttribute('aria-label','Griglia del crucipuzzle');viewport.append(board);container.append(viewport);
      const zoom=element('button','day-button day-button--light','Ingrandisci la griglia');zoom.type='button';zoom.setAttribute('aria-pressed','false');zoom.addEventListener('click',()=>{const on=board.classList.toggle('is-zoomed');zoom.textContent=on?'Riduci la griglia':'Ingrandisci la griglia';zoom.setAttribute('aria-pressed',String(on));});container.append(zoom);
      const status=element('p','wordsearch-status');status.setAttribute('aria-live','polite');status.setAttribute('aria-atomic','true');container.append(status);
      const list=element('ul','wordsearch-words');list.setAttribute('aria-label','Parole da cercare');container.append(list);if(c.word_note)container.append(element('p','wordsearch-note',c.word_note));
      const label=element('label','wordsearch-guess-label','Qual è la parola nascosta?'),input=element('input','wordsearch-guess');input.type='text';input.maxLength=32;input.autocomplete='off';input.autocapitalize='characters';input.spellcheck=false;input.value=guess;label.append(input);container.append(label);
      const help=element('p','wordsearch-note','Quando avrai trovato tutte le parole, leggi le lettere gialle da sinistra a destra e dall’alto in basso.');container.append(help);
      function persist(){if(key)try{sessionStorage.setItem(key,JSON.stringify({paths,guess:input.value}));}catch{}}
      function focus(index){focusCell=index;board.querySelectorAll('button').forEach((b,i)=>b.tabIndex=i===index?0:-1);board.children[index]?.focus();}
      function paint(feedback=''){
        const found=core.wordsearchMatches(c,paths),covered=new Set(found.flatMap(match=>match.cells)),all=found.length===c.words.length;
        list.replaceChildren();c.words.forEach(word=>{const li=element('li',found.some(match=>match.word===word)?'is-found':'',word);if(li.classList.contains('is-found'))li.setAttribute('aria-label',word+', trovata');list.append(li);});
        board.replaceChildren();for(let index=0;index<total;index++){const letter=c.grid[Math.floor(index/width)][index%width],button=element('button','wordsearch-cell',letter);button.type='button';button.dataset.wordCell=index;button.tabIndex=index===focusCell?0:-1;button.classList.toggle('is-found',covered.has(index));button.classList.toggle('is-secret',all&&!covered.has(index));button.setAttribute('aria-label',`${letter}, riga ${Math.floor(index/width)+1}, colonna ${index%width+1}${covered.has(index)?', parola trovata':all?', lettera della soluzione':''}`);button.setAttribute('aria-pressed',String(active===index));
          button.addEventListener('keydown',event=>{const row=Math.floor(index/width),col=index%width;let next=index;if(event.key==='ArrowLeft'&&col>0)next--;else if(event.key==='ArrowRight'&&col<width-1)next++;else if(event.key==='ArrowUp'&&row>0)next-=width;else if(event.key==='ArrowDown'&&row<c.grid.length-1)next+=width;else return;event.preventDefault();focus(next);});
          button.addEventListener('click',()=>{focusCell=index;let feedback='';if(active===null)active=index;else if(active===index)active=null;else{const match=core.wordPath(c,active,index);if(!match)feedback='Questa selezione non forma una parola dell’elenco.';else if(core.wordsearchMatches(c,paths).some(item=>item.word===match.word))feedback=match.word+' è già stata trovata.';else{paths.push([active,index]);feedback=match.word+' trovata!';persist();}active=null;}paint(feedback);focus(index);});board.append(button);}
        input.disabled=!all;input.required=all;status.textContent=feedback||(active!==null?'Ora seleziona l’ultima lettera della parola.':`${found.length} parole trovate su ${c.words.length}.${all?' Le lettere gialle formano la parola nascosta.':''}`);
      }
      input.addEventListener('input',persist);paint();get=()=>({paths:paths.map(path=>[...path]),guess:input.value});
    }else if(c.type==='puzzle'){
      const valid=tiles=>Array.isArray(tiles)&&tiles.length===12&&tiles.every(v=>Number.isInteger(v)&&v>=0&&v<12)&&new Set(tiles).size===12;
      let order,moves=0,active=null;
      try{const saved=JSON.parse(sessionStorage.getItem(storageKey)||'null');if(saved&&valid(saved.tiles)){order=saved.tiles;moves=Number.isSafeInteger(saved.moves)&&saved.moves>=0?saved.moves:0;}}catch{}
      function mix(){let shuffled;do{shuffled=shuffle(Array.from({length:12},(_,i)=>i));}while(shuffled.filter((v,i)=>v===i).length>2);return shuffled;}
      order ||= mix();
      const guide=element('details','puzzle-guide');guide.append(element('summary','','Mostra la foto guida'),image(c.image,c.image_alt||'Fotografia da ricomporre','puzzle-guide-image'));container.append(guide);
      const board=element('div','puzzle-board');board.style.aspectRatio=`${c.image_width||824} / ${c.image_height||1233}`;board.setAttribute('role','group');board.setAttribute('aria-label','Puzzle della cicogna: dodici tessere, tre colonne e quattro righe');
      const status=element('p','puzzle-status');status.setAttribute('aria-live','polite');status.setAttribute('aria-atomic','true');container.append(board,status);
      const remix=element('button','day-button day-button--light','Rimescola le tessere');remix.type='button';container.append(remix);
      function persist(){if(storageKey)try{sessionStorage.setItem(storageKey,JSON.stringify({tiles:order,moves}));}catch{}}
      function paint(focusPosition=null){board.replaceChildren();
        order.forEach((tile,position)=>{const button=element('button','puzzle-tile');button.type='button';button.dataset.puzzlePosition=position;button.dataset.puzzleTile=tile;button.setAttribute('aria-label',`Tessera nella posizione ${position+1}. ${active===position?'Selezionata: scegli un’altra tessera.':'Seleziona per scambiarla.'}`);button.setAttribute('aria-pressed',String(active===position));
          button.style.backgroundImage=`url("${asset(c.image)}")`;button.style.backgroundPosition=`${(tile%3)*50}% ${Math.floor(tile/3)*100/3}%`;
          button.addEventListener('click',()=>{if(active===null)active=position;else if(active===position)active=null;else{[order[active],order[position]]=[order[position],order[active]];active=null;moves++;persist();}paint(position);});board.append(button);
        });
        status.textContent=active===null?`${moves} ${moves===1?'scambio effettuato':'scambi effettuati'}. Quando sei soddisfatto, conferma il puzzle.`:`Tessera nella posizione ${active+1} selezionata. Tocca un’altra tessera per scambiarle.`;
        if(focusPosition!==null)board.querySelector(`[data-puzzle-position="${focusPosition}"]`).focus();
      }
      remix.addEventListener('click',()=>{order=mix();moves=0;active=null;persist();paint(0);});
      if(c.credit?.text)container.append(element('p','game-credit',c.credit.text));
      paint();persist();get=()=>({tiles:[...order]});
    }else if(c.type==='matching'&&c.visual==='beak-matching'){
      return window.GiappBeakMatch.render(container,c,{asset,storageKey});
    }else if(c.type==='matching'&&c.visual==='picture-matching'){
      return window.GiappPictureMatch.render(container,c,{asset,storageKey});
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
    }else if(c.type==='find'&&c.visual==='wildlife-search'){
      return window.GiappWildlifeSearch.render(container,c,{asset,storageKey});
    }else if(c.type==='find'&&c.visual==='frog-search'){
      return window.GiappFrogSearch.render(container,c,{asset,storageKey});
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

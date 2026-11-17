(() => {
  'use strict';
  const el=(tag,cls,text)=>{const node=document.createElement(tag);if(cls)node.className=cls;if(text!==undefined)node.textContent=text;return node;};
  const read=key=>{try{return JSON.parse(sessionStorage.getItem(key)||'null');}catch{return null;}};
  const shuffled=()=>{const deck=Array.from({length:12},(_,i)=>i%6);for(let i=11;i>0;i--){const j=Math.floor(Math.random()*(i+1));[deck[i],deck[j]]=[deck[j],deck[i]];}return deck;};
  function art(c,index,asset){
    const ns='http://www.w3.org/2000/svg',svg=document.createElementNS(ns,'svg'),image=document.createElementNS(ns,'image');
    const width=c.sheet_width/3,height=c.sheet_height/2;svg.setAttribute('viewBox',`${index%3*width} ${Math.floor(index/3)*height} ${width} ${height}`);svg.setAttribute('aria-hidden','true');svg.setAttribute('focusable','false');
    image.setAttribute('href',asset(c.image));image.setAttribute('width',c.sheet_width);image.setAttribute('height',c.sheet_height);svg.append(image);return svg;
  }
  function replay(deck,moves){
    if(!Array.isArray(deck)||deck.length!==12||!deck.every(v=>Number.isInteger(v)&&v>=0&&v<6)||Array.from({length:6},(_,i)=>deck.filter(v=>v===i).length).some(n=>n!==2)||!Array.isArray(moves)||moves.length>200)return null;
    const matched=new Set();let errors=0;
    for(const move of moves){if(!Array.isArray(move)||move.length!==2||move.some(v=>!Number.isInteger(v)||v<0||v>11)||move[0]===move[1]||move.some(v=>matched.has(v)))return null;if(deck[move[0]]===deck[move[1]])move.forEach(v=>matched.add(v));else errors++;}
    return{matched,errors};
  }
  window.GiappMemory={render(container,c,{asset,storageKey,attempt=0,onMessage}){
    const key=storageKey+':memory:'+attempt,saved=read(key);let deck=saved?.deck,moves=saved?.moves,history=replay(deck,moves);
    if(!history){deck=shuffled();moves=[];history=replay(deck,moves);}
    let matched=history.matched,errors=history.errors,open=null,second=null,locked=false;
    const validOpen=saved?.open;if(Number.isInteger(validOpen)&&validOpen>=0&&validOpen<12&&!matched.has(validOpen))open=validOpen;
    const grid=el('div','memory-grid');grid.setAttribute('role','group');grid.setAttribute('aria-label','Memory: dodici carte, sei coppie');
    const buttons=deck.map((identity,index)=>{
      const button=el('button','memory-card'),back=el('span','memory-back','❧'),front=el('span','memory-front'),position=el('span','memory-position',String(index+1));
      button.type='button';button.dataset.memoryCard=index;back.setAttribute('aria-hidden','true');position.setAttribute('aria-hidden','true');front.append(art(c,identity,asset));button.append(back,front,position);button.addEventListener('click',()=>flip(index));grid.append(button);return button;
    });
    const counter=el('p','memory-counter');counter.dataset.memoryCounter='';counter.setAttribute('role','status');counter.setAttribute('aria-atomic','true');container.append(grid,counter,el('p','memory-note','Scopri due carte alla volta. Le coppie uguali restano visibili; le altre si richiudono. Non c’è un limite di tempo. Quando hai trovato le sei coppie, conferma il risultato.'));
    function persist(){try{sessionStorage.setItem(key,JSON.stringify({deck,moves,open}));}catch{}}
    function paint(){buttons.forEach((button,index)=>{const shown=matched.has(index)||open===index||second===index;button.classList.toggle('is-open',shown);button.classList.toggle('is-matched',matched.has(index));button.disabled=matched.has(index);button.setAttribute('aria-label',shown?c.items[deck[index]]+(matched.has(index)?', coppia trovata':''):'Carta coperta '+(index+1));button.setAttribute('aria-pressed',String(shown));});counter.textContent='Coppie trovate: '+matched.size/2+' / 6 · Abbinamenti errati: '+errors;}
    function flip(index){
      if(locked||matched.has(index)||open===index)return;
      if(moves.length>=200){onMessage('Hai raggiunto il limite di questa partita.');return;}
      if(open===null){open=index;persist();paint();return;}
      const first=open;second=index;moves.push([first,index]);
      if(deck[first]===deck[index]){matched.add(first);matched.add(index);open=null;second=null;persist();paint();}
      else{errors++;locked=true;persist();paint();setTimeout(()=>{if(!container.isConnected)return;open=null;second=null;locked=false;persist();paint();},1000);}
    }
    const restart=el('button','day-button day-button--light','Ricomincia questa partita');restart.type='button';restart.hidden=moves.length<200;
    restart.addEventListener('click',()=>{try{sessionStorage.removeItem(key);}catch{}container.replaceChildren();window.GiappMemory.render(container,c,{asset,storageKey,attempt,onMessage});});container.append(restart);
    buttons.forEach(button=>button.addEventListener('click',()=>{restart.hidden=moves.length<200;}));
    paint();persist();return{get:()=>({deck:[...deck],moves:moves.map(pair=>[...pair])}),focus:()=>buttons.find(b=>!b.disabled)?.focus()};
  },solution(c,{asset}){
    const section=el('section','memory-solution');section.append(el('h3','','Osserva le ali a riposo'));
    const grid=el('div','memory-species-grid');c.items.forEach((name,index)=>{const figure=el('figure','memory-species'),caption=el('figcaption','',name);figure.append(art(c,index,asset),caption);grid.append(figure);});section.append(grid);return section;
  }};
})();

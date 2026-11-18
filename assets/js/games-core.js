(function(scope){
  'use strict';
  function integer(value,min,max){return Number.isInteger(value)&&value>=min&&value<=max;}
  function array(value,length,max){return Array.isArray(value)&&value.length===length&&value.every(item=>integer(item,0,max))&&new Set(value).size===value.length;}
  function wordPath(c,start,end){
    const width=c.grid?.[0]?.length,height=c.grid?.length;
    if(!width||!height||!integer(start,0,width*height-1)||!integer(end,0,width*height-1)||start===end)return null;
    const r=Math.floor(start/width),col=start%width,dr=Math.floor(end/width)-r,dc=end%width-col;
    if(dr!==0&&dc!==0&&Math.abs(dr)!==Math.abs(dc))return null;
    const length=Math.max(Math.abs(dr),Math.abs(dc))+1,rs=Math.sign(dr),cs=Math.sign(dc),cells=[];let text='';
    for(let i=0;i<length;i++){const row=r+i*rs,column=col+i*cs;cells.push(row*width+column);text+=c.grid[row][column];}
    const word=c.words.includes(text)?text:[...text].reverse().join('');
    return c.words.includes(word)?{word,cells}:null;
  }
  function wordsearchMatches(c,paths){
    if(!Array.isArray(paths)||paths.length>c.words.length)throw new Error('Seleziona le parole della griglia.');
    const found=[],seen=new Set();for(const path of paths){if(!Array.isArray(path)||path.length!==2)throw new Error('Selezione non valida.');const match=wordPath(c,path[0],path[1]);if(!match||seen.has(match.word))throw new Error('Le selezioni devono indicare parole diverse dell’elenco.');seen.add(match.word);found.push(match);}return found;
  }
  function memoryScore(s){
    if(!s||!Array.isArray(s.deck)||s.deck.length!==12||!s.deck.every(v=>integer(v,0,5))||Array.from({length:6},(_,i)=>s.deck.filter(v=>v===i).length).some(n=>n!==2)||!Array.isArray(s.moves)||s.moves.length<6||s.moves.length>200)throw new Error('Completa le sei coppie prima di confermare.');
    const matched=new Set();let errors=0;
    for(const pair of s.moves){if(!array(pair,2,11)||pair.some(v=>matched.has(v)))throw new Error('Partita non valida.');if(s.deck[pair[0]]===s.deck[pair[1]])pair.forEach(v=>matched.add(v));else errors++;}
    if(matched.size!==12)throw new Error('Trova tutte e sei le coppie prima di confermare.');
    return Math.max(0,10-errors);
  }
  function evaluate(challenge,submission){
    if(!submission||typeof submission!=='object')throw new Error('Completa la prova prima di confermare.');
    const type=challenge.type;
    if(type==='memory')return memoryScore(submission);
    if(type==='wordsearch'){
      const found=wordsearchMatches(challenge,submission.paths).length;
      if(typeof submission.guess!=='string'||submission.guess.length>32)throw new Error('Scrivi la parola nascosta.');
      const guess=submission.guess.toUpperCase().replace(/\s/g,'');
      return Math.floor(8*found/challenge.words.length)+(found===challenge.words.length&&guess===challenge.solution?2:0);
    }
    if(['quiz','mystery','audio'].includes(type)){
      if(!integer(submission.choice,0,challenge.options.length-1))throw new Error('Scegli una risposta.');
      return challenge.scores?challenge.scores[submission.choice]:(submission.choice===challenge.correct_index?10:-2);
    }
    if(type==='puzzle'){
      if(!array(submission.tiles,12,11))throw new Error('Il puzzle deve contenere tutte e dodici le tessere, senza ripetizioni.');
      const correct=submission.tiles.filter((value,index)=>value===index).length;
      return Math.floor(correct*10/12);
    }
    if(type==='matching'&&challenge.visual==='turtle-details'){
      const pairs=submission.pairs;
      if(!Array.isArray(pairs)||pairs.length!==3||!pairs.every(v=>integer(v,0,1)))throw new Error('Scegli un particolare per tutti e tre i confronti.');
      const correct=pairs.filter((v,i)=>v===challenge.solution[i]).length;
      return correct*3+(correct===3?1:0);
    }
    if(type==='matching'&&challenge.visual==='birdwatch-story'){
      const pairs=submission.pairs;
      if(!Array.isArray(pairs)||pairs.length!==4||!pairs.every(v=>integer(v,0,1)))throw new Error('Scegli un comportamento per tutte e quattro le situazioni.');
      const correct=pairs.filter((v,i)=>v===challenge.solution[i]).length;
      return correct*2+(correct===4?2:0);
    }
    if(type==='matching'&&challenge.visual==='water-story'){
      const pairs=submission.pairs;
      if(!Array.isArray(pairs)||pairs.length!==3||!pairs.every(v=>integer(v,0,2)))throw new Error('Rispondi a tutti e tre i momenti della piena.');
      const correct=pairs.filter((v,i)=>v===challenge.solution[i]).length;
      return correct*3+(correct===3?1:0);
    }
    if(type==='matching'&&challenge.visual==='bird-sorting'){
      const pairs=submission.pairs;
      if(!Array.isArray(pairs)||pairs.length!==8||!pairs.every(v=>integer(v,0,1)))throw new Error('Assegna tutti gli otto uccelli a uno dei due gruppi.');
      const correct=pairs.filter((v,i)=>v===challenge.solution[i]).length;
      return correct+(correct===8?2:0);
    }
    if(type==='matching'&&challenge.visual==='audio-matching'){
      if(!array(submission.pairs,3,2))throw new Error('Completa i tre abbinamenti, senza usare due volte lo stesso animale.');
      const correct=submission.pairs.filter((v,i)=>v===challenge.solution[i]).length;
      return correct*3+(correct===3?1:0);
    }
    if(type==='matching'||type==='sequence'){
      const selected=type==='matching'?submission.pairs:submission.order;
      if(!array(selected,4,3))throw new Error(type==='matching'?'Completa i quattro abbinamenti, senza usare due volte lo stesso elemento.':'Ordina tutte e quattro le fasi.');
      const correct=selected.filter((value,index)=>value===challenge.solution[index]).length;
      return correct*2+(correct===4?2:0);
    }
    if(type==='find'){
      const frogs=challenge.visual==='frog-search',wildlife=challenge.visual==='wildlife-search',max=(frogs||wildlife)?challenge.choices.length:4;
      if(!Array.isArray(submission.targets)||submission.targets.length>max||!array(submission.targets,submission.targets.length,challenge.choices.length-1)||((frogs||wildlife)&&submission.targets.length===0))throw new Error((frogs||wildlife)?'Seleziona almeno un animale prima di confermare.':'Scegli al massimo quattro animali diversi.');
      const correct=submission.targets.filter(value=>challenge.solution.includes(value)).length;
      const wrong=submission.targets.length-correct;
      if(wildlife)return Math.floor(10*correct/challenge.solution.length);
      if(frogs)return Math.floor(8*Math.max(0,correct-wrong)/challenge.solution.length)+(correct===challenge.solution.length&&wrong===0?2:0);
      return Math.max(0,(correct-wrong)*2)+(correct===4&&wrong===0?2:0);
    }
    throw new Error('Tipo di prova non disponibile.');
  }
  function reduce(previous,score,total){
    if(previous?.closed)return{progress:previous,total};
    const attempts=(previous?.attempts||0)+1,best=Math.max(previous?.best_score??-2,score);
    const old=previous?.day_points||0,change=!previous||best>previous.best_score?best-old:0;
    const nextTotal=Math.max(0,total+change),delta=nextTotal-total;
    return{total:nextTotal,progress:{attempts,best_score:best,last_score:score,day_points:old+delta,last_delta:delta,closed:attempts>=2||best===10}};
  }
  const api={evaluate,reduce,wordPath,wordsearchMatches,memoryScore};scope.GiappGames=api;if(typeof module!=='undefined')module.exports=api;
})(globalThis);

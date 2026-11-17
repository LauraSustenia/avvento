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
  function evaluate(challenge,submission){
    if(!submission||typeof submission!=='object')throw new Error('Completa la prova prima di confermare.');
    const type=challenge.type;
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
    if(type==='matching'||type==='sequence'){
      const selected=type==='matching'?submission.pairs:submission.order;
      if(!array(selected,4,3))throw new Error(type==='matching'?'Abbina ogni animale a un rifugio diverso.':'Ordina tutte e quattro le fasi.');
      const correct=selected.filter((value,index)=>value===challenge.solution[index]).length;
      return correct*2+(correct===4?2:0);
    }
    if(type==='find'){
      if(!Array.isArray(submission.targets)||submission.targets.length>4||!array(submission.targets,submission.targets.length,challenge.choices.length-1))throw new Error('Scegli al massimo quattro animali diversi.');
      const correct=submission.targets.filter(value=>challenge.solution.includes(value)).length;
      const wrong=submission.targets.length-correct;
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
  const api={evaluate,reduce,wordPath,wordsearchMatches};scope.GiappGames=api;if(typeof module!=='undefined')module.exports=api;
})(globalThis);

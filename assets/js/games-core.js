(function(scope){
  'use strict';
  function integer(value,min,max){return Number.isInteger(value)&&value>=min&&value<=max;}
  function array(value,length,max){return Array.isArray(value)&&value.length===length&&value.every(item=>integer(item,0,max))&&new Set(value).size===value.length;}
  function evaluate(challenge,submission){
    if(!submission||typeof submission!=='object')throw new Error('Completa la prova prima di confermare.');
    const type=challenge.type;
    if(['quiz','mystery','audio'].includes(type)){
      if(!integer(submission.choice,0,challenge.options.length-1))throw new Error('Scegli una risposta.');
      return challenge.scores?challenge.scores[submission.choice]:(submission.choice===challenge.correct_index?10:-2);
    }
    if(type==='matching'||type==='sequence'){
      const selected=type==='matching'?submission.pairs:submission.order;
      if(!array(selected,4,3))throw new Error(type==='matching'?'Abbina ogni uccello a un nido diverso.':'Ordina tutte e quattro le fasi.');
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
  const api={evaluate,reduce};scope.GiappGames=api;if(typeof module!=='undefined')module.exports=api;
})(globalThis);

(() => {
  'use strict';
  const root=document.querySelector('[data-day]');if(!root)return;
  const $=s=>root.querySelector(s),day=Number(root.dataset.day),core=window.GiappGames;
  const read=(key,fallback=null)=>JSON.parse(localStorage.getItem(key)||'null')??fallback;
  const save=(key,value)=>localStorage.setItem(key,JSON.stringify(value));
  const asset=source=>new URL(source,location.origin+root.dataset.assetBase).href;
  let config,catalogue,entry,state,ui,busy=false,practice=false,practiceProgress=null,practiceScore=0,pending=null;
  const message=text=>$('[data-day-message]').textContent=text;
  function localState(submission=null,finish=false){
    const settings=catalogue.settings,profiles=read('giapp-demo-profiles-v1',[]),profile=practice?{score:practiceScore}:profiles.find(p=>p.id===read('giapp-demo-current-v1'));
    const parts=new Intl.DateTimeFormat('en',{timeZone:'Europe/Rome',year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());
    const date=Object.fromEntries(parts.map(p=>[p.type,p.value]));
    if(!settings.preview&&`${date.year}-${date.month}-${date.day}`<`${settings.year}-12-${String(day).padStart(2,'0')}`)return{locked:true,opens_on:`${day} dicembre ${settings.year}`};
    const all=practice?{}:read('giapp-demo-games-v2',{}),key=`${profile?.id}:${settings.year}:${day}:${entry.challenge.version||'prototype-v1'}`;
    let progress=practice?practiceProgress:all[key]||null;
    if(submission && profile){const next=core.reduce(progress,core.evaluate(entry.challenge,submission),profile.score||0);progress=next.progress;profile.score=next.total;}
    if(finish&&progress)progress={...progress,closed:true};
    if((submission||finish)&&profile){if(practice){practiceProgress=progress;practiceScore=profile.score;}else{all[key]=progress;save('giapp-demo-games-v2',all);save('giapp-demo-profiles-v1',profiles);}}
    return{preview:settings.preview,year:settings.year,name:entry.name,challenge:entry.challenge,login_required:!profile,profile:profile||null,progress,
      explanation:progress?.closed?entry.challenge.explanation:entry.challenge.hint||'Osserva gli indizi e riprova.',sources:progress?.closed?entry.challenge.sources:null,
      area:progress?.closed?{name:entry.name,description:entry.area_description,image:entry.area_image,url:entry.area_url}:null};
  }
  async function cloud(submission=null,finish=false){
    const key=`giapp-auth:${config.url}`;let session=read(key);
    if(session&&session.expires_at*1000<Date.now()+60000){const response=await fetch(`${config.url}/auth/v1/token?grant_type=refresh_token`,{method:'POST',headers:{apikey:config.key,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:session.refresh_token})});if(!response.ok)throw new Error('Accedi di nuovo dal tuo account.');session=await response.json();session.expires_at||=Math.floor(Date.now()/1000)+(session.expires_in||3600);save(key,session);}
    const body={p_day:day,p_finish:finish};
    if(submission){const fingerprint=JSON.stringify(submission);if(!pending||pending.fingerprint!==fingerprint)pending={fingerprint,id:crypto.randomUUID()};body.p_submission=submission;body.p_request=pending.id;}
    const response=await fetch(`${config.url}/rest/v1/rpc/calendar_game`,{method:'POST',headers:{apikey:config.key,'Content-Type':'application/json',...(session?{Authorization:`Bearer ${session.access_token}`}:{})},body:JSON.stringify(body)});
    const data=await response.json();if(!response.ok)throw new Error(data.code==='PGRST202'?'Il salvataggio dei nuovi giochi non è ancora attivo. Puoi provarli senza salvare punti.':'Non riesco a caricare o salvare la prova. Riprova tra poco.');
    if(data.error)throw new Error(data.error);pending=null;return data;
  }
  function gameStorageKey(){return `giapp-puzzle:${practice?'practice':state.profile?.id||'guest'}:${state.year||catalogue.settings.year}:${day}:${state.challenge.version||'prototype-v1'}`;}
  function mountGame(){ui?.destroy?.();const challenge=state.challenge.visual==='audio-matching'&&entry.challenge.version===state.challenge.version?{...state.challenge,recordings:entry.challenge.recordings}:state.challenge.visual==='emys-count'&&entry.challenge.version===state.challenge.version?{...state.challenge,image:entry.challenge.image,instructions:entry.challenge.instructions}:state.challenge;ui=window.GiappGameUI.render($('[data-answers]'),challenge,{asset,attempt:state.progress?.attempts||0,onMessage:message,storageKey:gameStorageKey()});}
  function render(){
    $('[data-preview]').hidden=!state.preview;$('[data-practice-notice]').hidden=!practice;
    if(state.locked){message(`La giornata si aprirà il ${state.opens_on}.`);$('[data-challenge]').hidden=true;$('[data-practice-offer]').hidden=true;return;}
    message('');const p=state.progress,c=state.challenge;
    $('[data-login]').hidden=practice||!state.login_required;$('[data-practice-offer]').hidden=practice;
    $('[data-challenge]').hidden=!!p||state.login_required;$('[data-result]').hidden=!p;$('[data-area]').hidden=true;
    $('[data-discover]').setAttribute('aria-expanded','false');$('[data-challenge-title]').textContent=c.title;$('[data-placeholder]').hidden=!c.placeholder;
    $('[data-points-rule]').textContent=c.type==='quiz'&&c.options.length===4?'Risposte da −2, 2, 5 o 10 punti. Due tentativi: conta il risultato migliore, senza sommarli.': ['quiz','mystery','audio'].includes(c.type)?'Risposta corretta: 10 punti; errata: −2. Due tentativi: conta il migliore.':'2 punti per elemento corretto e 2 punti extra se completi tutto. Massimo 10 punti, due tentativi: conta il migliore.'+(c.type==='find'?' Nell’elenco, una scelta errata annulla un elemento corretto.':'');
    if(c.type==='puzzle')$('[data-points-rule]').textContent='Il punteggio è proporzionale alle 12 tessere al posto giusto, fino a 10 punti a puzzle completo. Hai due tentativi; conserviamo il migliore. Gli scambi sono liberi fino alla conferma.';
    if(c.type==='wordsearch')$('[data-points-rule]').textContent='Fino a 8 punti per le parole trovate, più 2 se le trovi tutte e risolvi la parola nascosta. Due tentativi: conserviamo il migliore. Le selezioni non contano come tentativi finché non confermi.';
    if(c.visual==='frog-search')$('[data-points-rule]').textContent='Trova 6 dalmatine: fino a 8 punti per le selezioni corrette, più 2 se le trovi tutte senza errori. Ogni animale di un’altra specie selezionato annulla una scelta corretta. Due tentativi: conta il migliore.';
    if(c.visual==='wildlife-search')$('[data-points-rule]').textContent='Trova tutti i 20 animali. Il punteggio cresce con quelli trovati, fino a 10 punti. Due tentativi: conserviamo il migliore.';
    const wildlifeResult=$('[data-wildlife-result]');wildlifeResult.replaceChildren();
    if(p&&c.visual==='wildlife-search'&&entry.challenge.version===c.version)wildlifeResult.append(window.GiappWildlifeSearch.result(entry.challenge,{asset,storageKey:gameStorageKey(),closed:p.closed}));
    if(c.type==='memory')$('[data-points-rule]').textContent='Parti da 10 punti: ogni abbinamento errato toglie 1 punto, fino a 0. Due partite: conserviamo il risultato migliore. Nessun limite di tempo.';
    const memorySolution=$('[data-memory-solution]');memorySolution.replaceChildren();
    if(p?.closed&&c.type==='memory'&&entry.challenge.version===c.version)memorySolution.append(window.GiappMemory.solution(entry.challenge,{asset}));
    if(c.visual==='audio-matching')$('[data-points-rule]').textContent='3 punti per ogni abbinamento corretto, più 1 se li trovi tutti. Massimo 10 punti. Due tentativi: conserviamo il migliore.';
    const turtleSolution=$('[data-turtle-details-solution]');turtleSolution.replaceChildren();
    if(p?.closed&&c.visual==='turtle-details'&&entry.challenge.version===c.version)turtleSolution.append(window.GiappTurtleDetails.solution(entry.challenge,{asset}));
    if(c.visual==='turtle-details')$('[data-points-rule]').textContent='3 punti per ogni confronto corretto, più 1 se sono tutti giusti. Massimo 10 punti, due tentativi: conserviamo il migliore.';
    const birdwatchSolution=$('[data-birdwatch-solution]');birdwatchSolution.replaceChildren();
    if(p?.closed&&c.visual==='birdwatch-story'&&entry.challenge.version===c.version)birdwatchSolution.append(window.GiappBirdwatchStory.solution(entry.challenge,{asset}));
    if(c.visual==='birdwatch-story')$('[data-points-rule]').textContent='2 punti per ogni scelta corretta, più 2 se sono tutte giuste. Massimo 10 punti, due tentativi: conserviamo il migliore.';
    const waterSolution=$('[data-water-story-solution]');waterSolution.replaceChildren();
    if(p?.closed&&c.visual==='water-story'&&entry.challenge.version===c.version)waterSolution.append(window.GiappWaterStory.solution(entry.challenge,{asset}));
    if(c.visual==='water-story')$('[data-points-rule]').textContent='3 punti per ogni risposta corretta, più 1 se sono tutte giuste. Massimo 10 punti, due tentativi: conserviamo il migliore.';
    $('[data-answer-form] button[type=submit]').textContent=['water-story','turtle-details'].includes(c.visual)?'Conferma le tre risposte':c.visual==='birdwatch-story'?'Conferma le quattro scelte':'Conferma la risposta';
    const birdSortSolution=$('[data-bird-sort-solution]');birdSortSolution.replaceChildren();
    if(p?.closed&&c.visual==='bird-sorting'&&entry.challenge.version===c.version)birdSortSolution.append(window.GiappBirdSorting.solution(entry.challenge,{asset}));
    if(c.visual==='bird-sorting')$('[data-points-rule]').textContent='1 punto per ogni uccello nel gruppo giusto, più 2 punti se li assegni tutti correttamente. Massimo 10 punti, due tentativi: conserviamo il migliore.';
    const emysCountSolution=$('[data-emys-count-solution]');emysCountSolution.replaceChildren();
    if(p?.closed&&c.visual==='emys-count'&&entry.challenge.version===c.version)emysCountSolution.append(window.GiappEmysCount.solution(entry.challenge,{asset}));
    if(c.visual==='emys-count')$('[data-points-rule]').textContent='Conteggio esatto: 10 punti; errato: −2. Hai due tentativi: conserviamo il risultato migliore.';
    const pawDetailSolution=$('[data-paw-detail-solution]');pawDetailSolution.replaceChildren();
    if(p?.closed&&c.visual==='paw-detail'&&entry.challenge.version===c.version)pawDetailSolution.append(window.GiappPawDetail.solution(entry.challenge,{asset}));
    const birdHalvesSolution=$('[data-bird-halves-solution]');birdHalvesSolution.replaceChildren();
    if(p?.closed&&c.visual==='bird-halves'&&entry.challenge.version===c.version)birdHalvesSolution.append(window.GiappBirdHalves.solution(entry.challenge,{asset}));
    const foodSolution=$('[data-food-match-solution]');foodSolution.replaceChildren();
    if(p?.closed&&c.visual==='food-matching'&&entry.challenge.version===c.version)foodSolution.append(window.GiappFoodMatch.solution(entry.challenge,{asset}));
    const leafSolution=$('[data-leaf-match-solution]');leafSolution.replaceChildren();
    if(p?.closed&&c.visual==='leaf-matching'&&entry.challenge.version===c.version)leafSolution.append(window.GiappLeafMatch.solution(entry.challenge,{asset}));
    const audioSolution=$('[data-audio-match-solution]');audioSolution.replaceChildren();
    if(p?.closed&&c.visual==='audio-matching'&&entry.challenge.version===c.version)audioSolution.append(window.GiappAudioMatch.solution(entry.challenge,{asset}));
    const frogResult=$('[data-frog-result]');frogResult.replaceChildren();
    if(p&&c.visual==='frog-search'&&entry.challenge.version===c.version)frogResult.append(window.GiappFrogSearch.result(entry.challenge,{asset,storageKey:gameStorageKey(),closed:p.closed}));
    const riverSolution=$('[data-river-solution]');riverSolution.replaceChildren();
    if(p?.closed&&c.visual==='river-path'&&entry.challenge.version===c.version)riverSolution.append(window.GiappRiverPath.create({asset,image:c.image,reveal:true}));
    const beakSolution=$('[data-beak-solution]');beakSolution.replaceChildren();
    if(p?.closed&&c.visual==='beak-matching'&&entry.challenge.version===c.version)beakSolution.append(window.GiappBeakMatch.solution(entry.challenge,{asset}));
    const pictureSolution=$('[data-picture-match-solution]');pictureSolution.replaceChildren();
    if(p?.closed&&c.visual==='picture-matching'&&entry.challenge.version===c.version)pictureSolution.append(window.GiappPictureMatch.solution(entry.challenge));
    mountGame();
    if(p){
      $('[data-result-title]').textContent=p.best_score===10?(p.attempts===1?'Prova superata!':'Hai recuperato!'):(p.closed?'La prova è conclusa.':'Puoi migliorare il risultato!');
      $('[data-result]').dataset.outcome=p.best_score===10?'correct':'wrong';
      $('[data-result-points]').textContent=`${p.best_score} punti per la giornata`;
      $('[data-score-summary]').textContent=`Ultimo tentativo: ${p.last_score} · Variazione totale: ${p.last_delta>0?'+':''}${p.last_delta} · ${practice?'Totale di prova':'Il tuo totale'}: ${state.profile.score||0}. Il totale non scende sotto zero.`;
      const sameContent=entry.challenge.version===c.version;
      const explanation=p.closed&&sameContent?(entry.challenge.explanation??state.explanation):state.explanation;
      const explanationBox=$('[data-explanation]');explanationBox.replaceChildren();
      String(explanation||'').split(/\n\s*\n/).filter(text=>text.trim()).forEach(text=>{const paragraph=document.createElement('p');paragraph.textContent=text.trim();explanationBox.append(paragraph);});
      if(p.closed&&sameContent){
        const details=entry.challenge;
        if(details.explanation_image){
          const image=document.createElement('img');image.className='day-explanation-bird';
          image.src=asset(details.explanation_image);image.alt=details.explanation_image_alt||'';
          image.loading='lazy';
          if(details.explanation_image_caption){
            const figure=document.createElement('figure'),caption=document.createElement('figcaption');
            figure.className='day-explanation-species';caption.textContent=details.explanation_image_caption;
            figure.append(image,caption);explanationBox.append(figure);
          }else explanationBox.prepend(image);
        }
        if(details.type==='sequence'&&details.images?.length&&Array.isArray(details.solution)){
          const heading=document.createElement('h3');heading.textContent='Le fasi nell’ordine giusto';
          const phases=document.createElement('ol');phases.className='day-explanation-phases';phases.setAttribute('aria-label',details.cycle_label||'Ciclo della farfalla in ordine');
          details.solution.forEach((index,position)=>{
            const item=document.createElement('li'),image=document.createElement('img'),label=document.createElement('span');
            image.src=asset(details.images[index]);image.alt=details.items[index];image.loading='lazy';
            label.textContent=(position+1)+'. '+details.items[index];item.append(image,label);phases.append(item);
          });
          explanationBox.prepend(heading,phases);
        }
        if(details.explanation_note){const note=document.createElement('p');note.className='day-explanation-note';note.textContent=details.explanation_note;explanationBox.append(note);}
      }
      $('[data-retry]').hidden=p.closed;$('[data-finish]').hidden=p.closed;$('[data-discover]').hidden=!p.closed;
      $('[data-discover]').textContent=`Scopri l’area: ${state.name}`;
      const reveal=$('[data-result-reveal]');reveal.hidden=!(p.closed&&['mystery','puzzle'].includes(c.type)&&!['paw-detail','emys-count'].includes(c.visual));if(!reveal.hidden){reveal.src=asset(c.image);reveal.alt=c.image_alt||'Illustrazione completa dell’animale della prova';}
      const sourceList=p.closed&&sameContent?(entry.challenge.sources??state.sources):state.sources;
      const sources=$('[data-game-sources]');sources.replaceChildren();if(p.closed&&sourceList?.length){sources.append(document.createTextNode('Per approfondire:'));sourceList.forEach(source=>{if(!/^https:\/\//.test(source.url))return;const a=document.createElement('a');a.href=source.url;a.textContent=source.title;a.target='_blank';a.rel='noopener';sources.append(a);});}
    }
    if(!practice)window.dispatchEvent(new CustomEvent('giapp:profile',{detail:state.profile}));
  }
  async function commit(submission=null,finish=false){
    if(busy)return;busy=true;const enabled=[...root.querySelectorAll('button')].filter(b=>!b.disabled);enabled.forEach(b=>b.disabled=true);message('Verifica della prova…');
    try{const nextState=practice||config.mode==='demo'?localState(submission,finish):await cloud(submission,finish);if(submission)ui?.rememberSubmission?.(submission);state=nextState;render();$('[data-result]').focus();}
    catch(error){message(error.message);}
    finally{busy=false;enabled.filter(b=>b.isConnected).forEach(b=>b.disabled=false);}
  }
  $('[data-answer-form]').addEventListener('submit',event=>{event.preventDefault();const submission=ui.get();
    const c=state.challenge;if(['quiz','mystery','audio'].includes(c.type)&&!Number.isInteger(submission.choice)){message('Scegli una risposta.');return;}
    if(['frog-search','wildlife-search'].includes(c.visual)&&!submission.targets.length){message('Seleziona almeno un animale prima di confermare.');return;}
    if(c.visual==='turtle-details'&&(!Array.isArray(submission.pairs)||submission.pairs.length!==3||!submission.pairs.every(v=>Number.isInteger(v)&&v>=0&&v<=1))){message('Scegli un particolare per tutti e tre i confronti.');return;}
    if(c.visual==='birdwatch-story'&&(!Array.isArray(submission.pairs)||submission.pairs.length!==4||!submission.pairs.every(v=>Number.isInteger(v)&&v>=0&&v<=1))){message('Scegli un comportamento per tutte e quattro le situazioni.');return;}
    if(c.visual==='water-story'&&(!Array.isArray(submission.pairs)||submission.pairs.length!==3||!submission.pairs.every(v=>Number.isInteger(v)&&v>=0&&v<=2))){message('Rispondi a tutti e tre i momenti della piena.');return;}
    if(c.visual==='bird-sorting'&&(!Array.isArray(submission.pairs)||submission.pairs.length!==8||!submission.pairs.every(v=>Number.isInteger(v)&&v>=0&&v<=1))){message('Assegna tutti gli otto uccelli a uno dei due gruppi.');return;}
    if(c.type==='matching'&&!['bird-sorting','water-story','birdwatch-story','turtle-details'].includes(c.visual)&&(submission.pairs.includes(-1)||new Set(submission.pairs).size!==(c.visual==='audio-matching'?3:4))){message('Completa tutti gli abbinamenti, senza usare due volte lo stesso elemento.');return;}
    if(c.type==='memory'){try{core.memoryScore(submission);}catch(error){message(error.message);return;}}
    commit(submission);
  });
  $('[data-retry]').addEventListener('click',()=>{$('[data-result]').hidden=true;$('[data-area]').hidden=true;$('[data-challenge]').hidden=false;mountGame();ui.focus();});
  $('[data-finish]').addEventListener('click',()=>commit(null,true));
  $('[data-practice-start]').addEventListener('click',()=>{practice=true;practiceProgress=null;practiceScore=0;state=localState();render();});
  $('[data-discover]').addEventListener('click',()=>{if(!state.area)return;const a=state.area;$('[data-area-name]').textContent=a.name;
    const text=$('[data-area-description]');text.replaceChildren();
    String(entry.area_description??a.description??'').split(/\n\s*\n/).filter(paragraph=>paragraph.trim()).forEach(paragraph=>{const p=document.createElement('p');p.textContent=paragraph.trim();text.append(p);});
    const image=$('[data-area-image]'),placeholder=$('[data-area-placeholder]'),caption=$('[data-area-caption]');
    const source=entry.area_image||a.image;
    const safe=typeof source==='string'&&(/^https:\/\//.test(source)||/^\/(?!\/)/.test(source)||/^images\/[a-zA-Z0-9_./%-]+$/.test(source));
    image.hidden=true;placeholder.hidden=false;caption.hidden=true;
    $('[data-area-photo-status]').textContent='La foto sarà inserita qui.';
    image.onload=()=>{image.hidden=false;placeholder.hidden=true;caption.textContent=entry.area_image_caption||a.image_caption||'';caption.hidden=!caption.textContent;};
    image.onerror=()=>{image.hidden=true;placeholder.hidden=false;caption.hidden=true;$('[data-area-photo-status]').textContent='Foto al momento non disponibile.';};
    if(safe){image.alt=entry.area_image_alt||a.image_alt||`Veduta di ${a.name}`;image.loading='eager';image.src=asset(source);if(image.complete&&image.naturalWidth>0)image.onload();}
    else image.removeAttribute('src');
    const target=entry.area_url||a.url||'https://naturadipianura.it/luoghi/'; const link=$('[data-area-link]');link.href=/^https:\/\//.test(target)?target:'https://naturadipianura.it/luoghi/';link.textContent=link.href==='https://naturadipianura.it/luoghi/'?'Consulta l’elenco delle aree GIAPP ↗':'Visita la scheda di '+a.name+' ↗';$('[data-area]').hidden=false;$('[data-discover]').setAttribute('aria-expanded','true');$('[data-area]').focus();});
  (async()=>{try{
    const responses=await Promise.all([fetch(root.dataset.configUrl,{cache:'no-store'}),fetch(root.dataset.daysUrl,{cache:'no-store'})]);if(responses.some(r=>!r.ok))throw new Error('Giornata non disponibile.');[config,catalogue]=await Promise.all(responses.map(r=>r.json()));
    entry=catalogue.days.find(d=>d.day===day);if(!entry||!['demo','supabase'].includes(config.mode))throw new Error('Giornata non disponibile.');state=config.mode==='demo'?localState():await cloud();
    if(!state.locked&&(['puzzle','wordsearch','memory','sequence'].includes(entry.challenge.type)||['river-path','picture-matching','frog-search','beak-matching','wildlife-search','audio-matching','leaf-matching','food-matching','bird-halves','paw-detail','emys-count','bird-sorting','water-story','birdwatch-story','turtle-details'].includes(entry.challenge.visual))&&state.challenge?.version!==entry.challenge.version){$('[data-preview]').hidden=!state.preview;$('[data-practice-offer]').hidden=false;window.dispatchEvent(new CustomEvent('giapp:profile',{detail:state.profile}));message('Il nuovo gioco non è ancora attivo per il salvataggio. Puoi provarlo senza salvare punti.');return;}
    render();
  }catch(error){message(error.message);if(entry)$('[data-practice-offer]').hidden=false;}})();
})();

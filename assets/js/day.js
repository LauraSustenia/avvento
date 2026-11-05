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
  function mountGame(){ui=window.GiappGameUI.render($('[data-answers]'),state.challenge,{asset,attempt:state.progress?.attempts||0,onMessage:message});}
  function render(){
    $('[data-preview]').hidden=!state.preview;$('[data-practice-notice]').hidden=!practice;
    if(state.locked){message(`La giornata si aprirà il ${state.opens_on}.`);$('[data-challenge]').hidden=true;$('[data-practice-offer]').hidden=true;return;}
    message('');const p=state.progress,c=state.challenge;
    $('[data-login]').hidden=practice||!state.login_required;$('[data-practice-offer]').hidden=practice;
    $('[data-challenge]').hidden=!!p||state.login_required;$('[data-result]').hidden=!p;$('[data-area]').hidden=true;
    $('[data-discover]').setAttribute('aria-expanded','false');$('[data-challenge-title]').textContent=c.title;$('[data-placeholder]').hidden=!c.placeholder;
    $('[data-points-rule]').textContent=c.type==='quiz'&&c.options.length===4?'Risposte da −2, 2, 5 o 10 punti. Due tentativi: conta il risultato migliore, senza sommarli.': ['quiz','mystery','audio'].includes(c.type)?'Risposta corretta: 10 punti; errata: −2. Due tentativi: conta il migliore.':'2 punti per elemento corretto e 2 punti extra se completi tutto. Massimo 10 punti, due tentativi: conta il migliore.'+(c.type==='find'?' Nell’elenco, una scelta errata annulla un elemento corretto.':'');
    mountGame();
    if(p){
      $('[data-result-title]').textContent=p.best_score===10?(p.attempts===1?'Prova superata!':'Hai recuperato!'):(p.closed?'La prova è conclusa.':'Puoi migliorare il risultato!');
      $('[data-result]').dataset.outcome=p.best_score===10?'correct':'wrong';
      $('[data-result-points]').textContent=`${p.best_score} punti per la giornata`;
      $('[data-score-summary]').textContent=`Ultimo tentativo: ${p.last_score} · Variazione totale: ${p.last_delta>0?'+':''}${p.last_delta} · ${practice?'Totale di prova':'Il tuo totale'}: ${state.profile.score||0}. Il totale non scende sotto zero.`;
      $('[data-explanation]').textContent=state.explanation;
      $('[data-retry]').hidden=p.closed;$('[data-finish]').hidden=p.closed;$('[data-discover]').hidden=!p.closed;
      $('[data-discover]').textContent=`Scopri l’area: ${state.name}`;
      const reveal=$('[data-result-reveal]');reveal.hidden=!(p.closed&&c.type==='mystery');if(!reveal.hidden)reveal.src=asset(c.image);
      const sources=$('[data-game-sources]');sources.replaceChildren();if(p.closed&&state.sources?.length){sources.append(document.createTextNode('Per approfondire:'));state.sources.forEach(source=>{if(!/^https:\/\//.test(source.url))return;const a=document.createElement('a');a.href=source.url;a.textContent=source.title;a.target='_blank';a.rel='noopener';sources.append(a);});}
    }
    if(!practice)window.dispatchEvent(new CustomEvent('giapp:profile',{detail:state.profile}));
  }
  async function commit(submission=null,finish=false){
    if(busy)return;busy=true;const enabled=[...root.querySelectorAll('button')].filter(b=>!b.disabled);enabled.forEach(b=>b.disabled=true);message('Verifica della prova…');
    try{state=practice||config.mode==='demo'?localState(submission,finish):await cloud(submission,finish);render();$('[data-result]').focus();}
    catch(error){message(error.message);}
    finally{busy=false;enabled.filter(b=>b.isConnected).forEach(b=>b.disabled=false);}
  }
  $('[data-answer-form]').addEventListener('submit',event=>{event.preventDefault();const submission=ui.get();
    const c=state.challenge;if(['quiz','mystery','audio'].includes(c.type)&&!Number.isInteger(submission.choice)){message('Scegli una risposta.');return;}
    if(c.type==='matching'&&(submission.pairs.includes(-1)||new Set(submission.pairs).size!==4)){message('Abbina ogni uccello a un nido diverso.');return;}
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
    entry=catalogue.days.find(d=>d.day===day);if(!entry||!['demo','supabase'].includes(config.mode))throw new Error('Giornata non disponibile.');state=config.mode==='demo'?localState():await cloud();render();
  }catch(error){message(error.message);if(entry)$('[data-practice-offer]').hidden=false;}})();
})();

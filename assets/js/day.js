(() => {
  'use strict';
  const root=document.querySelector('[data-day]');
  if(!root)return;
  const $=selector=>root.querySelector(selector), day=Number(root.dataset.day);
  let config, catalogue, entry, state, busy=false, practice=false, practiceProgress=null, practiceScore=0, pending=null;
  const read=(key,fallback=null)=>JSON.parse(localStorage.getItem(key)||'null')??fallback;
  const save=(key,value)=>localStorage.setItem(key,JSON.stringify(value));
  function todayRome(){return new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Rome',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date());}
  function message(text){$('[data-day-message]').textContent=text;}
  function localProfile(){return read('giapp-demo-profiles-v1',[]).find(row=>row.id===read('giapp-demo-current-v1'));}
  function localState(answer=null){
    const settings=catalogue.settings, profile=practice?{score:practiceScore}:localProfile();
    if(!settings.preview && todayRome()<`${settings.year}-12-${String(day).padStart(2,'0')}`)return{locked:true,opens_on:`${day} dicembre ${settings.year}`};
    const key=profile?`${profile.id}:${settings.year}:${day}`:null;
    const all=practice?{}:read('giapp-demo-days-v1',{});
    let progress=practice?practiceProgress:all[key]||null;
    if(answer!==null && profile && (!progress || progress.status==='retry')){
      const attempts=(progress?.attempts||0)+1, correct=answer===entry.challenge.correct_index;
      const delta=correct?(attempts===1?settings.correct_points:settings.recovery_points):settings.wrong_points;
      const before=profile.score||0, after=Math.max(0,before+delta);
      progress={attempts,status:correct?(attempts===1?'correct':'recovered'):(attempts===1?'retry':'failed'),last_answer:answer,last_delta:after-before,day_points:(progress?.day_points||0)+after-before};
      profile.score=after;
      if(practice){practiceProgress=progress;practiceScore=after;}
      else{const rows=read('giapp-demo-profiles-v1',[]);const target=rows.find(row=>row.id===profile.id);target.score=after;save('giapp-demo-profiles-v1',rows);all[key]=progress;save('giapp-demo-days-v1',all);}
    }
    return{preview:settings.preview,year:settings.year,rules:settings,challenge:entry.challenge,name:entry.name,profile:profile||null,login_required:!profile,progress,explanation:progress?entry.challenge.explanation:null,area:progress?{name:entry.name,description:entry.area_description,image:entry.area_image}:null};
  }
  async function cloud(answer=null){
    const key=`giapp-auth:${config.url}`;
    let session=read(key);
    if(session && session.expires_at*1000<Date.now()+60000){
      const response=await fetch(`${config.url}/auth/v1/token?grant_type=refresh_token`,{method:'POST',headers:{apikey:config.key,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:session.refresh_token})});
      if(!response.ok)throw new Error('Accedi di nuovo dal tuo account.');
      session=await response.json();session.expires_at||=Math.floor(Date.now()/1000)+(session.expires_in||3600);save(key,session);
    }
    const body={p_day:day};
    if(answer!==null){pending ||= {answer,request:crypto.randomUUID()};if(pending.answer!==answer)pending={answer,request:crypto.randomUUID()};body.p_answer=answer;body.p_request=pending.request;}
    const response=await fetch(`${config.url}/rest/v1/rpc/calendar_day`,{method:'POST',headers:{apikey:config.key,'Content-Type':'application/json',...(session?{Authorization:`Bearer ${session.access_token}`}:{})},body:JSON.stringify(body)});
    const data=await response.json();
    if(!response.ok){const error=new Error(data.code==='PGRST202'?'Il salvataggio delle giornate non è ancora attivo. Puoi provare il gioco senza salvare punti.':'Non riesco a caricare o salvare la giornata. Riprova tra poco.');error.notReady=data.code==='PGRST202';throw error;}
    if(data.error)throw new Error(data.error);
    pending=null;return data;
  }
  function render(){
    $('[data-preview]').hidden=!state.preview;
    $('[data-practice-notice]').hidden=!practice;
    if(state.locked){message(`La giornata si aprirà il ${state.opens_on}.`);$('[data-challenge]').hidden=true;$('[data-practice-offer]').hidden=true;return;}
    message('');
    $('[data-login]').hidden=practice||!state.login_required;
    $('[data-practice-offer]').hidden=practice||!state.login_required;
    const progress=state.progress;
    $('[data-challenge]').hidden=!!progress||state.login_required;
    $('[data-result]').hidden=!progress;
    $('[data-area]').hidden=true;
    $('[data-discover]').setAttribute('aria-expanded','false');
    $('[data-challenge-title]').textContent=state.challenge.title;
    $('[data-placeholder]').hidden=!state.challenge.placeholder;
    const rules=state.rules;
    $('[data-points-rule]').textContent=`Risposta corretta: +${rules.correct_points} punti. Risposta errata: ${rules.wrong_points} punti. Recupero al secondo tentativo: +${rules.recovery_points} punti. Il totale non scende sotto zero.`;
    const answers=$('[data-answers]');answers.replaceChildren();
    state.challenge.options.forEach((text,index)=>{const label=document.createElement('label'),radio=document.createElement('input'),span=document.createElement('span');radio.type='radio';radio.name='answer';radio.value=String(index);radio.required=true;span.textContent=text;label.append(radio,span);answers.append(label);});
    if(progress){
      const titles={correct:'Risposta corretta!',recovered:'Hai recuperato!',retry:'Questa risposta non è corretta.',failed:'La prova è conclusa.'};
      $('[data-result-title]').textContent=titles[progress.status];
      $('[data-result]').dataset.outcome=['retry','failed'].includes(progress.status)?'wrong':progress.status;
      const delta=progress.last_delta;
      $('[data-result-points]').textContent=`${delta>0?'+':''}${delta} punti · Totale della giornata: ${progress.day_points} · ${practice?'Totale di prova': 'Il tuo totale'}: ${state.profile.score||0}`;
      $('[data-explanation]').textContent=state.explanation;
      $('[data-retry]').hidden=progress.status!=='retry';
      $('[data-discover]').textContent=`Scopri l’area: ${state.name}`;
    }
    if(!practice)window.dispatchEvent(new CustomEvent('giapp:profile',{detail:state.profile}));
  }
  $('[data-answer-form]').addEventListener('submit',async event=>{
    event.preventDefault();if(busy)return;
    const answer=Number(new FormData(event.currentTarget).get('answer'));
    if(!Number.isInteger(answer)||answer<0||answer>=state.challenge.options.length)return;
    busy=true;root.querySelectorAll('button').forEach(button=>button.disabled=true);message('Verifica della risposta…');
    try{state=practice||config.mode==='demo'?localState(answer):await cloud(answer);render();$('[data-result]').focus();}
    catch(error){message(error.message);}
    finally{busy=false;root.querySelectorAll('button').forEach(button=>button.disabled=false);}
  });
  $('[data-retry]').addEventListener('click',()=>{$('[data-result]').hidden=true;$('[data-area]').hidden=true;$('[data-challenge]').hidden=false;$('[data-answers] input').focus();});
  $('[data-discover]').addEventListener('click',()=>{
    if(!state.area)return;
    $('[data-area-name]').textContent=state.area.name;
    $('[data-area-description]').textContent=state.area.description;
    const image=$('[data-area-image]');
    // Consente immagini del progetto o HTTPS; nessun HTML editoriale viene eseguito.
    const source=state.area.image;
    const safeSource=typeof source==='string' && (/^https:\/\//.test(source)||/^\/(?!\/)/.test(source));
    image.hidden=!safeSource;if(safeSource)image.src=source;
    $('[data-area]').hidden=false;$('[data-discover]').setAttribute('aria-expanded','true');$('[data-area]').focus();
  });
  $('[data-practice-start]').addEventListener('click',()=>{practice=true;state=localState();render();});
  (async()=>{
    try{
      const responses=await Promise.all([fetch(root.dataset.configUrl,{cache:'no-store'}),fetch(root.dataset.daysUrl,{cache:'no-store'})]);
      if(responses.some(response=>!response.ok))throw new Error('Giornata non disponibile.');
      [config,catalogue]=await Promise.all(responses.map(response=>response.json()));
      entry=catalogue.days.find(item=>item.day===day);if(!entry)throw new Error('Giornata non disponibile.');
      if(!['demo','supabase'].includes(config.mode))throw new Error('Configurazione non disponibile.');
      state=config.mode==='demo'?localState():await cloud();render();
    }catch(error){message(error.message);if(entry){$('[data-practice-offer]').hidden=false;}}
  })();
})();

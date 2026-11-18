---
---
(() => {
  'use strict';
  const places=Object.freeze({{ site.data.league_places | jsonify }});
  const getPlace=id=>places.find(place=>place.id===id)||places[1];
  const read=(key,fallback=null)=>JSON.parse(localStorage.getItem(key)||'null')??fallback;
  const write=(key,value)=>localStorage.setItem(key,JSON.stringify(value));
  const validId=id=>typeof id==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);
  function demo(action,code,name,leagueId,place){
    const profiles=read('giapp-demo-profiles-v1',[]),id=read('giapp-demo-current-v1'),current=profiles.find(p=>p.id===id),leagues=read('giapp-demo-leagues-v1',[]);
    let migrated=false;leagues.forEach(l=>{if(!l.id){l.id=crypto.randomUUID();l.place='bosco';migrated=true;}});if(migrated)write('giapp-demo-leagues-v1',leagues);
    const count=l=>profiles.filter(p=>l.members.includes(p.id)).length;
    const publicLeague=l=>({id:l.id,name:l.name,place:l.place,members_count:count(l)});
    if(action==='search')return {leagues:leagues.filter(l=>l.name.toLocaleLowerCase('it').includes(name.toLocaleLowerCase('it'))).sort((a,b)=>a.name.localeCompare(b.name,'it')).slice(0,30).map(publicLeague)};
    if(action==='ranking'){const league=leagues.find(l=>l.id===leagueId);if(!league)throw new Error('Non trovo questa lega. Prova a cercarla di nuovo.');return {league:publicLeague(league),rows:profiles.filter(p=>league.members.includes(p.id)).map(p=>({name:p.name,animal:p.animal,score:p.score}))};}
    if(!current)throw new Error('Accedi con il tuo codice personale per partecipare a una lega.');
    if(action==='create'){if(name.length<2||name.length>50)throw new Error('Il nome della lega deve contenere da 2 a 50 caratteri.');if(!places.some(p=>p.id===place))throw new Error('Scegli uno dei sei luoghi per la lega.');if(leagues.some(l=>l.code===code))throw new Error('Questo codice è già usato da un’altra lega. Scegline un altro.');leagues.push({id:crypto.randomUUID(),code,name,place,members:[id]});}
    if(action==='join'||action==='leave'){const league=leagues.find(l=>l.id===leagueId);if(!league||(action==='join'&&league.code!==code))throw new Error('Il codice non corrisponde alla lega selezionata.');if(action==='join'&&!league.members.includes(id))league.members.push(id);if(action==='leave')league.members=league.members.filter(member=>member!==id);}
    if(action!=='list')write('giapp-demo-leagues-v1',leagues);
    return {code:action==='create'?code:null,leagues:leagues.filter(l=>l.members.includes(id)).map(l=>({...publicLeague(l),code:l.code}))};
  }
  window.GiappLeagues={places,getPlace,
    async connect(configUrl){
      const response=await fetch(configUrl,{cache:'no-store'});if(!response.ok)throw new Error('Impossibile caricare la configurazione.');const config=await response.json();
      if(!['demo','supabase'].includes(config.mode))throw new Error('Configurazione non disponibile.');
      if(config.mode==='supabase'&&(!/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(config.url)||!config.key||config.key.startsWith('sb_secret_')))throw new Error('Supabase non è ancora configurato.');
      return {config,mode:config.mode,hasSession:()=>config.mode==='demo'?!!read('giapp-demo-current-v1'):!!read(`giapp-auth:${config.url}`),
        async call(action,code='',name='',leagueId=null,place=null){
          if(!['search','list','create','join','leave','ranking'].includes(action))throw new Error('Operazione non valida.');code=String(code).trim();name=String(name).trim();
          if(['create','join'].includes(action)&&!/^\d{4}$/.test(code))throw new Error('Inserisci le quattro cifre del codice della lega.');
          if(['join','leave','ranking'].includes(action)&&!validId(leagueId))throw new Error('Seleziona prima una lega dall’elenco.');
          if(name.length>50)throw new Error('Usa un nome di massimo 50 caratteri.');
          if(config.mode==='demo')return demo(action,code,name,leagueId,place);
          const headers={apikey:config.key,'Content-Type':'application/json'};
          // Ricerca e consultazione non creano account e non richiedono una sessione.
          if(!['search','ranking'].includes(action)){
            const key=`giapp-auth:${config.url}`;let session=read(key);if(!session)throw new Error('Accedi con il tuo codice personale per partecipare a una lega.');
            if(session.expires_at*1000<Date.now()+60000){const result=await fetch(`${config.url}/auth/v1/token?grant_type=refresh_token`,{method:'POST',headers,body:JSON.stringify({refresh_token:session.refresh_token})});if(!result.ok)throw new Error('Accedi di nuovo con il tuo codice personale.');session=await result.json();session.expires_at||=Math.floor(Date.now()/1000)+(session.expires_in||3600);write(key,session);}
            headers.Authorization=`Bearer ${session.access_token}`;
          }
          const result=await fetch(`${config.url}/rest/v1/rpc/calendar_leagues`,{method:'POST',headers,body:JSON.stringify({p_action:action,p_code:code||null,p_name:name||null,p_league_id:leagueId,p_place:place})});const data=await result.json();if(!result.ok)throw new Error('Le leghe non sono disponibili al momento. Riprova tra poco.');if(data.error)throw new Error(data.error);return data;
        }
      };
    }
  };
})();

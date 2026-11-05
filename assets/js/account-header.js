(() => {
  'use strict';
  const root = document.querySelector('[data-header-account]');
  if (!root) return;
  const read = key => { const raw = localStorage.getItem(key); return raw ? JSON.parse(raw) : null; };
  let config, request = 0;
  function render(profile) {
    const valid = profile && ['emys','uccellino','insettino'].includes(profile.animal);
    root.querySelector('[data-header-guest]').hidden = !!valid;
    root.querySelector('[data-header-avatar]').hidden = !valid;
    root.querySelector('[data-header-identity]').hidden = !valid;
    if (!valid) { root.removeAttribute('title'); return; }
    root.querySelector('[data-header-avatar]').src = `${root.dataset.animalBase}${profile.animal}-segnaposto.png`;
    root.querySelector('[data-header-name]').textContent = profile.name;
    const score = Number.isSafeInteger(profile.score) && profile.score >= 0 ? profile.score : 0;
    root.querySelector('[data-header-score]').textContent = `${score} ${score === 1 ? 'punto' : 'punti'}`;
    root.title = `${profile.name} · ${score} punti · Il mio account`;
  }
  async function load() {
    const currentRequest = ++request;
    try {
      config ||= await fetch(root.dataset.configUrl, {cache:'no-store'}).then(response => {if (!response.ok) throw new Error('config'); return response.json();});
      if (config.mode === 'demo') {
        const id = read('giapp-demo-current-v1');
        const rows = read('giapp-demo-profiles-v1') || [];
        if (currentRequest === request) render(rows.find(row => row.id === id));
        return;
      }
      // Sulla pagina account la registrazione gestisce la sessione e invia l'aggiornamento.
      if (document.querySelector('[data-explorer], [data-day]')) return;
      if (config.mode !== 'supabase' || !/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(config.url)) return;
      const key = `giapp-auth:${config.url}`;
      let session = read(key);
      if (!session) { render(null); return; }
      if (session.expires_at * 1000 < Date.now() + 60000) {
        const response = await fetch(`${config.url}/auth/v1/token?grant_type=refresh_token`, {method:'POST',headers:{apikey:config.key,'Content-Type':'application/json'},body:JSON.stringify({refresh_token:session.refresh_token})});
        if (!response.ok) throw new Error('session');
        session = await response.json();
        session.expires_at ||= Math.floor(Date.now()/1000) + (session.expires_in || 3600);
        localStorage.setItem(key, JSON.stringify(session));
      }
      const response = await fetch(`${config.url}/rest/v1/rpc/calendar_profile`, {method:'POST',headers:{apikey:config.key,Authorization:`Bearer ${session.access_token}`,'Content-Type':'application/json'},body:JSON.stringify({p_action:'read'})});
      if (!response.ok) throw new Error('profile');
      const result = await response.json();
      if (currentRequest === request) render(result.profile);
    } catch { if (currentRequest === request) render(null); }
  }
  window.addEventListener('giapp:profile', event => { ++request; render(event.detail); });
  window.addEventListener('storage', event => {
    if (event.key === null || ['giapp-demo-current-v1','giapp-demo-profiles-v1'].includes(event.key) || event.key?.startsWith('giapp-auth:')) load();
  });
  load();
})();

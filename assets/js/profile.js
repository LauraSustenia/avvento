(() => {
  'use strict';
  const root = document.querySelector('[data-explorer]');
  if (!root) return;
  const $ = selector => root.querySelector(selector);
  const animals = {emys: 'Emys', uccellino: 'Uccellino', insettino: 'Insettino'};
  let config, profile, session, busy = false;
  const codeKey = () => config.mode === 'demo' ? 'giapp-demo-personal-code-v1' : `giapp-personal-code:${config.url}`;
  const storage = {
    get(key, fallback = null) { const raw = localStorage.getItem(key); return raw ? JSON.parse(raw) : fallback; },
    set(key, value) { localStorage.setItem(key, JSON.stringify(value)); },
    remove(key) { localStorage.removeItem(key); }
  };
  // Il trattino è un simbolo del codice, non un separatore da eliminare.
  const normalize = code => String(code || '').toUpperCase();
  function validCode(code) {
    if (!/^[A-Z0-9!@#$%&*+?_-]{10}$/.test(code)) throw new Error('Il codice deve avere esattamente 10 caratteri: lettere, numeri oppure ! @ # $ % & * + ? _ -. Non usare spazi.');
  }
  function validProfile(name, animal) {
    if (name.length < 2 || name.length > 40) throw new Error('Il nome deve contenere da 2 a 40 caratteri.');
    if (!Object.hasOwn(animals, animal)) throw new Error('Scegli uno degli animali disponibili.');
  }
  function message(text = '', error = false) { $('[data-message]').textContent = text; $('[data-message]').dataset.error = String(error); }
  function render() {
    $('[data-loading]').hidden = true;
    $('[data-entry]').hidden = !!profile;
    $('[data-profile]').hidden = !profile;
    window.dispatchEvent(new CustomEvent('giapp:profile', {detail: profile}));
    if (!profile) return;
    $('[data-profile-name]').textContent = profile.name;
    $('[data-profile-animal]').textContent = animals[profile.animal];
    $('[data-avatar]').src = root.querySelector(`input[value="${profile.animal}"]`).closest('label').querySelector('img').src;
    $('[data-edit] [name=name]').value = profile.name;
    $('[data-edit] [name=animal]').value = profile.animal;
    $('[data-edit] [name=show_in_leaderboard]').checked = profile.show_in_leaderboard === true;
    $('[data-ranking-status]').textContent = profile.show_in_leaderboard ? 'Hai scelto di comparire nella classifica generale con il tuo nome di fantasia e il tuo animale.' : 'Hai scelto di non comparire nella classifica generale. Puoi giocare lo stesso.';
    const savedCode = storage.get(codeKey());
    $('[data-saved-code-panel]').hidden = !savedCode;
    $('#saved-code').value = savedCode || '';
    $('#saved-code').type = 'password';
    $('[data-show-code]').textContent = 'Mostra codice';
    $('[data-show-code]').setAttribute('aria-pressed', 'false');
  }
  async function hash(code) {
    const bytes = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(code));
    return [...new Uint8Array(bytes)].map(b => b.toString(16).padStart(2, '0')).join('');
  }
  async function demo(action, values) {
    const records = storage.get('giapp-demo-profiles-v1', []);
    const current = records.find(row => row.id === storage.get('giapp-demo-current-v1'));
    const codeHash = values.code ? await hash(values.code) : null;
    if (action === 'read') return current || null;
    if (action === 'recover') {
      const found = records.find(row => row.code_hash === codeHash);
      if (!found) throw new Error('Codice non riconosciuto. In modalità prova puoi ritrovare solo i profili creati in questo browser.');
      storage.set('giapp-demo-current-v1', found.id);
      return found;
    }
    if (action === 'logout') { storage.remove('giapp-demo-current-v1'); return null; }
    if (action === 'create' || action === 'change_code') {
      if (records.some(row => row.code_hash === codeHash && (action === 'create' || row.id !== current?.id))) throw new Error('Questo codice è già utilizzato. Scegline un altro.');
    }
    if (action === 'create') {
      const created = {id: crypto.randomUUID(), name: values.name, animal: values.animal, score: 0, show_in_leaderboard: values.show_in_leaderboard, code_hash: codeHash};
      records.push(created);
      storage.set('giapp-demo-profiles-v1', records);
      storage.set('giapp-demo-current-v1', created.id);
      return created;
    }
    if (!current) throw new Error('Accedi di nuovo con il tuo codice.');
    if (action === 'update') { current.name = values.name; current.animal = values.animal; current.show_in_leaderboard = values.show_in_leaderboard; }
    if (action === 'change_code') current.code_hash = codeHash;
    storage.set('giapp-demo-profiles-v1', records);
    return current;
  }
  async function authRequest(path, body) {
    const response = await fetch(`${config.url}/auth/v1/${path}`, {method: 'POST', headers: {'apikey': config.key, 'Content-Type': 'application/json'}, body: JSON.stringify(body)});
    const data = await response.json();
    if (!response.ok) throw new Error('Accesso a Supabase non riuscito. Controlla la configurazione e che gli accessi anonimi siano attivi.');
    session = {...data, expires_at: data.expires_at || Math.floor(Date.now() / 1000) + (data.expires_in || 3600)};
    storage.set(`giapp-auth:${config.url}`, session);
  }
  async function cloud(action, values) {
    if (!session) await authRequest('signup', {});
    else if (session.expires_at * 1000 < Date.now() + 60000) await authRequest('token?grant_type=refresh_token', {refresh_token: session.refresh_token});
    const response = await fetch(`${config.url}/rest/v1/rpc/calendar_profile`, {method: 'POST', headers: {'apikey': config.key, 'Authorization': `Bearer ${session.access_token}`, 'Content-Type': 'application/json'}, body: JSON.stringify({p_action: action, p_name: values.name || null, p_animal: values.animal || null, p_code: values.code || null, p_show_in_leaderboard: values.show_in_leaderboard ?? null})});
    const data = await response.json();
    if (!response.ok) throw new Error('Non riesco a salvare il profilo su Supabase. Riprova tra poco.');
    if (data.error) throw new Error(data.error);
    return data.profile;
  }
  async function operation(action, values = {}) {
    if (busy) return;
    busy = true;
    root.querySelectorAll('button').forEach(button => { button.disabled = true; });
    message();
    try {
      if (!config) throw new Error('La configurazione non è ancora disponibile. Ricarica la pagina.');
      if (values.code !== undefined) { values.code = normalize(values.code); validCode(values.code); }
      if (values.name !== undefined) { values.name = values.name.trim(); validProfile(values.name, values.animal); values.show_in_leaderboard = values.show_in_leaderboard === 'on'; }
      profile = await (config.mode === 'demo' ? demo(action, values) : cloud(action, values));
      if (['create', 'recover', 'change_code'].includes(action)) storage.set(codeKey(), values.code);
      if (action === 'logout') storage.remove(codeKey());
      render();
      root.querySelectorAll('input[name=code]').forEach(input => { input.value = ''; });
      root.querySelectorAll('input[type=checkbox][required]').forEach(input => { input.checked = false; });
      if (action === 'create') message('Il tuo esploratore è pronto!');
      if (action === 'update') message('Nome, animale e scelta per la classifica aggiornati.');
      if (action === 'change_code') { message('Codice cambiato. Da ora usa quello nuovo.'); $('[data-change-code]').closest('details').open = false; }
      if (action === 'logout') { message('Sei uscito. Per tornare, usa il tuo codice personale.'); showTab('recover'); }
    } catch (error) { message(error.message || 'Operazione non riuscita. Riprova.', true); }
    finally { busy = false; root.querySelectorAll('button').forEach(button => { button.disabled = false; }); }
  }
  function showTab(tab) {
    $('[data-create]').hidden = tab !== 'create';
    $('[data-recover]').hidden = tab !== 'recover';
    root.querySelectorAll('[data-tab]').forEach(button => button.setAttribute('aria-pressed', String(button.dataset.tab === tab)));
  }
  root.querySelectorAll('[data-tab]').forEach(button => button.addEventListener('click', () => { showTab(button.dataset.tab); message(); }));
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*+?_-';
  function randomCode() {
    let code;
    do {
      code = '';
      while (code.length < 10) {
        const byte = crypto.getRandomValues(new Uint8Array(1))[0];
        if (byte < 256 - (256 % alphabet.length)) code += alphabet[byte % alphabet.length];
      }
    } while (!/[A-Z]/.test(code) || !/[0-9]/.test(code) || !/[!@#$%&*+?_-]/.test(code));
    return code;
  }
  root.querySelectorAll('[data-generate]').forEach(button => button.addEventListener('click', () => {
    button.closest('form').querySelector('input[name=code]').value = randomCode();
    button.closest('form').querySelector('input[type=checkbox][required]').checked = false;
  }));
  for (const [selector, action] of [['[data-create]', 'create'], ['[data-recover]', 'recover'], ['[data-edit]', 'update'], ['[data-change-code]', 'change_code']]) {
    $(selector).addEventListener('submit', event => { event.preventDefault(); operation(action, Object.fromEntries(new FormData(event.currentTarget))); });
  }
  $('[data-logout]').addEventListener('click', () => operation('logout'));
  $('[data-show-code]').addEventListener('click', event => {
    const show = $('#saved-code').type === 'password';
    $('#saved-code').type = show ? 'text' : 'password';
    event.currentTarget.textContent = show ? 'Nascondi codice' : 'Mostra codice';
    event.currentTarget.setAttribute('aria-pressed', String(show));
  });
  (async () => {
    try {
      const response = await fetch(root.dataset.configUrl, {cache: 'no-store'});
      if (!response.ok) throw new Error('Impossibile caricare la configurazione.');
      config = await response.json();
      if (!['demo', 'supabase'].includes(config.mode)) throw new Error('Modalità di registrazione non valida.');
      if (config.mode === 'demo') {
        $('[data-mode]').hidden = false;
        $('[data-mode]').textContent = 'Modalità prova: il profilo viene salvato solo in questo browser. Non è ancora collegato a Supabase e non si trasferisce su altri dispositivi.';
      } else {
        if (!/^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(config.url) || !config.key || config.key.startsWith('sb_secret_')) throw new Error('Supabase non è ancora configurato: servono URL del progetto e chiave pubblica.');
        session = storage.get(`giapp-auth:${config.url}`);
      }
      // Non crea utenti Supabase durante una semplice visita alla pagina.
      profile = config.mode === 'demo' ? await demo('read', {}) : session ? await cloud('read', {}) : null;
      if (!profile) storage.remove(codeKey());
      render();
    } catch (error) { $('[data-loading]').hidden = true; message(error.message, true); }
  })();
})();

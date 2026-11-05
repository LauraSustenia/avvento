(() => {
  const root = document.querySelector('[data-leaderboard]');
  if (!root) return;
  const status = root.querySelector('[data-leaderboard-status]');
  const list = root.querySelector('[data-leaderboard-list]');
  async function load() {
    try {
      const response = await fetch(root.dataset.configUrl, {cache:'no-store'});
      if (!response.ok) throw new Error();
      const config = await response.json();
      let rows;
      if (config.mode === 'demo') {
        root.querySelector('[data-leaderboard-demo]').hidden = false;
        rows = JSON.parse(localStorage.getItem('giapp-demo-profiles-v1') || '[]').filter(row => row.show_in_leaderboard === true);
      } else if (config.mode === 'supabase' && /^https:\/\/[a-z0-9-]+\.supabase\.co$/.test(config.url)) {
        const result = await fetch(`${config.url}/rest/v1/rpc/calendar_leaderboard`, {method:'POST', headers:{apikey:config.key,'Content-Type':'application/json'},body:'{}'});
        if (!result.ok) throw new Error();
        rows = await result.json();
      } else throw new Error();
      rows = rows.filter(row => ['emys','uccellino','insettino'].includes(row.animal)).map(row => ({name:String(row.name),animal:row.animal,score:Number.isSafeInteger(row.score) && row.score >= 0 ? row.score : 0})).sort((a,b) => b.score-a.score || a.name.localeCompare(b.name,'it')).slice(0,100);
      list.replaceChildren();
      let rank = 0, previousScore;
      rows.forEach((row,index) => {
        if (row.score !== previousScore) rank = index+1;
        previousScore = row.score;
        const item = document.createElement('li');
        const position = document.createElement('span'); position.textContent = `${rank}.`; position.className = 'leaderboard__rank';
        const image = document.createElement('img'); image.src = `${root.dataset.animalBase}${row.animal}-segnaposto.png`; image.alt = ''; image.width = 60; image.height = 60;
        const name = document.createElement('strong'); name.textContent = row.name;
        const score = document.createElement('span'); score.textContent = `${row.score} ${row.score === 1 ? 'punto' : 'punti'}`; score.className = 'leaderboard__score';
        item.append(position,image,name,score); list.append(item);
      });
      status.textContent = rows.length ? 'A parità di punti, la posizione è la stessa.' : 'Non ci sono ancora esploratori in classifica.';
    } catch { status.textContent = 'La classifica non è disponibile al momento. Riprova tra poco.'; }
  }
  window.addEventListener('storage', event => {if (event.key === 'giapp-demo-profiles-v1') load();});
  load();
})();

/* Variante cartografica: l'ordine e le coordinate sono fissi, il 24 resta sulla Bora. */
(() => {
  const calendar = document.querySelector('[data-map-calendar]');
  if (!calendar) return;
  const viewport = calendar.querySelector('[data-map-viewport]');
  const stage = calendar.querySelector('[data-map-stage]');
  const markers = [...calendar.querySelectorAll('[data-map-day]')];
  const popup = calendar.querySelector('[data-map-selection]');
  let selectedMarker = null;
  function positionPopup() {
    if (!selectedMarker || popup.hidden) return;
    popup.classList.remove('is-below');
    const half = selectedMarker.offsetHeight / 2;
    popup.style.left = `${selectedMarker.offsetLeft}px`;
    popup.style.top = `${selectedMarker.offsetTop - half - 9}px`;
    const view = viewport.getBoundingClientRect();
    const left = Math.max(0,view.left)+8, right = Math.min(innerWidth,view.right)-8;
    let rect = popup.getBoundingClientRect();
    if (rect.left < left) popup.style.left = `${selectedMarker.offsetLeft+left-rect.left}px`;
    else if (rect.right > right) popup.style.left = `${selectedMarker.offsetLeft+right-rect.right}px`;
    const intro = calendar.querySelector('.map-poster__intro')?.getBoundingClientRect();
    const overlapsIntro = intro && rect.left < intro.right && rect.right > intro.left && rect.top < intro.bottom+8 && rect.bottom > intro.top;
    if (rect.top < Math.max(0,view.top)+8 || overlapsIntro) {
      popup.classList.add('is-below');
      popup.style.top = `${selectedMarker.offsetTop+half+9}px`;
    }
  }
  function closePopup() {
    popup.hidden = true;
    markers.forEach(marker => {marker.classList.remove('is-selected');marker.setAttribute('aria-pressed','false');});
    selectedMarker = null;
  }

  // Distribute forms by geographic distance, independently of the fixed day numbers.
  const types = ['farnia', 'acero', 'pioppo', 'edera', 'agrifoglio'];
  const points = markers.map(marker => ({x: parseFloat(marker.style.left) * 7.2, y: parseFloat(marker.style.top) * 8}));
  const shuffle = values => {
    const result = [...values];
    for (let i = result.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
  };
  const distances = points.map(a => points.map(b => Math.hypot(a.x - b.x, a.y - b.y)));
  const neighbors = distances.map((row, i) => row.map((d, j) => ({d,j})).filter(v => v.j !== i).sort((a,b) => a.d-b.d).slice(0,2).map(v => v.j));
  const southern = points.map((p,i) => ({y:p.y,i})).sort((a,b) => b.y-a.y).slice(0,3).map(p => p.i);
  const isGreen = type => type === 'edera' || type === 'agrifoglio';
  function score(order) {
    let result = 0;
    order.forEach((type,i) => {
      for (let j=i+1;j<order.length;j++) {
        const distance = Math.max(25,distances[i][j]);
        if (type === order[j]) result += (neighbors[i].includes(j) || neighbors[j].includes(i) ? 500 : 0) + (150/distance)**3;
        if (isGreen(type) && isGreen(order[j])) result += .3*(110/distance)**2;
      }
    });
    if (southern.length === 3 && southern.every(i => isGreen(order[i]))) result += 25;
    return result;
  }
  const palette = shuffle(types);
  const pool = markers.map((_,i) => palette[i%palette.length]);
  let best = shuffle(pool), bestScore = score(best);
  for (let restart=0;restart<8;restart++) {
    let order = shuffle(pool), current = score(order);
    for (let attempt=0;attempt<700;attempt++) {
      const i=Math.floor(Math.random()*order.length),j=Math.floor(Math.random()*order.length);
      if (i===j || order[i]===order[j]) continue;
      [order[i],order[j]]=[order[j],order[i]];
      const next=score(order);
      if (next<current) current=next;
      else [order[i],order[j]]=[order[j],order[i]];
    }
    if (current<bestScore) {best=order;bestScore=current;}
  }
  markers.forEach((marker,i) => {
    types.forEach(type => marker.classList.remove(`calendar-leaf--${type}`));
    marker.classList.add(`calendar-leaf--${best[i]}`);
    marker.querySelector('img').src = `${calendar.dataset.leafBase}foglia-${best[i]}.png`;
  });
  const markerCenter = marker => {
    const rect = marker.getBoundingClientRect();
    const poster = stage.getBoundingClientRect();
    return {x: rect.left - poster.left + rect.width / 2, y: rect.top - poster.top + rect.height / 2};
  };

  function select(marker, reveal = false) {
    selectedMarker = marker;
    popup.hidden = false;
    markers.forEach(item => {
      const selected = item === marker;
      item.classList.toggle('is-selected', selected);
      item.setAttribute('aria-pressed', String(selected));
    });
    calendar.querySelector('[data-map-selected-day]').textContent = `${marker.dataset.mapDay} dicembre`;
    calendar.querySelector('[data-map-selected-name]').textContent = marker.dataset.areaName;
    if (reveal) {
      if (stage.getBoundingClientRect().width < 700) setWidth(760);
      const center = markerCenter(marker);
      viewport.scrollTo({left: center.x - viewport.clientWidth / 2, top: center.y - viewport.clientHeight / 2, behavior: 'smooth'});
      viewport.scrollIntoView({behavior: 'smooth', block: 'center'});
      marker.focus({preventScroll: true});
    }
    positionPopup();
    if (reveal) setTimeout(positionPopup,350);
  }
  function setWidth(width) {
    const previous = stage.getBoundingClientRect().width;
    const centerX = (viewport.scrollLeft + viewport.clientWidth / 2) / previous;
    const centerY = (viewport.scrollTop + viewport.clientHeight / 2) / stage.getBoundingClientRect().height;
    stage.style.width = `${width}px`;
    stage.style.minWidth = '0';
    viewport.scrollLeft = centerX * width - viewport.clientWidth / 2;
    viewport.scrollTop = centerY * stage.getBoundingClientRect().height - viewport.clientHeight / 2;
  }
  markers.forEach(marker => marker.addEventListener('click', () => select(marker)));
  calendar.querySelector('[data-map-close]').addEventListener('click', closePopup);
  calendar.addEventListener('click', event => {
    if (!event.target.closest('[data-map-day], [data-map-find], [data-map-selection]')) closePopup();
  });
  document.addEventListener('keydown', event => { if(event.key==='Escape')closePopup(); });
  calendar.querySelectorAll('[data-map-style]').forEach(button => button.addEventListener('click', () => {
    calendar.dataset.markerStyle = button.dataset.mapStyle;
    calendar.querySelectorAll('[data-map-style]').forEach(item => item.setAttribute('aria-pressed', String(item === button)));
  }));
  calendar.querySelectorAll('[data-map-zoom]').forEach(button => button.addEventListener('click', () => {
    const action = button.dataset.mapZoom;
    if (action === 'fit') {
      stage.style.width = '100%';
      stage.style.minWidth = '0';
      viewport.scrollTo({left: 0, top: 0});
      return;
    }
    const width = stage.getBoundingClientRect().width;
    const target = width * (action === 'in' ? 1.25 : .8);
    setWidth(Math.max(viewport.clientWidth, Math.min(1800, target)));
  }));
  window.addEventListener('resize', () => {
    stage.style.width = '';
    stage.style.minWidth = '';
    closePopup();
  });
  calendar.querySelectorAll('[data-map-find]').forEach(button => button.addEventListener('click', () => {
    const marker = markers.find(item => item.dataset.mapDay === button.dataset.mapFind);
    if (marker) select(marker, true);
  }));
  // On small screens, open on the central cluster while keeping the map pannable in both directions.
  if (window.matchMedia('(max-width: 700px)').matches && !calendar.classList.contains('map-calendar--poster')) {
    const bora = markers.find(marker => marker.dataset.mapDay === '24');
    if (bora) {
      const center = markerCenter(bora);
      viewport.scrollLeft = center.x - viewport.clientWidth / 2;
      viewport.scrollTop = center.y - viewport.clientHeight / 2;
    }
  }
})();

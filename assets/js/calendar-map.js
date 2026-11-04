/* Variante cartografica: l'ordine e le coordinate sono fissi, il 24 resta sulla Bora. */
(() => {
  const calendar = document.querySelector('[data-map-calendar]');
  if (!calendar) return;
  const viewport = calendar.querySelector('[data-map-viewport]');
  const stage = calendar.querySelector('[data-map-stage]');
  const markers = [...calendar.querySelectorAll('[data-map-day]')];
  const markerCenter = marker => {
    const rect = marker.getBoundingClientRect();
    const poster = stage.getBoundingClientRect();
    return {x: rect.left - poster.left + rect.width / 2, y: rect.top - poster.top + rect.height / 2};
  };

  function select(marker, reveal = false) {
    calendar.querySelector('[data-map-selection]')?.removeAttribute('hidden');
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

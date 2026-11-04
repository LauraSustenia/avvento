/* Sei fasce PNG illustrate, con raccordi corretti direttamente sulle immagini. */
(() => {
  const body = document.querySelector('[data-illustrated-body]');
  const content = document.querySelector('[data-page-content]');
  const bands = document.querySelector('[data-bands]');
  const library = [...document.querySelectorAll('[data-band-library] img')];
  if (!body || !content || !bands) return;

  const ready = image => image.complete
    ? Promise.resolve(image.naturalWidth > 0 ? image : null)
    : new Promise(resolve => {
      image.addEventListener('load', () => resolve(image), { once: true });
      image.addEventListener('error', () => resolve(null), { once: true });
    });

  Promise.all(library.map(ready)).then(images => {
    const available = images.filter(Boolean);
    if (!available.length) return;
    const sequence = [];
    let bag = [];
    let lastMeasurement = '';
    let frame;

    function nextBand() {
      if (!bag.length) {
        bag = [...available];
        for (let i = bag.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [bag[i], bag[j]] = [bag[j], bag[i]];
        }
        // Anche tra due gruppi, evita una ripetizione immediata.
        if (bag.length > 1 && bag[bag.length - 1] === sequence[sequence.length - 1]) {
          [bag[0], bag[bag.length - 1]] = [bag[bag.length - 1], bag[0]];
        }
      }
      return bag.pop();
    }

    function render() {
      const width = body.getBoundingClientRect().width;
      const height = content.getBoundingClientRect().height;
      const contentStyle = getComputedStyle(content);
      const topMargin = parseFloat(contentStyle.marginTop) || 0;
      const bottomMargin = parseFloat(contentStyle.marginBottom) || 0;
      const backgroundHeight = Math.max(0, height + topMargin + bottomMargin);
      const measurement = `${width}:${height}:${topMargin}:${bottomMargin}`;
      if (width <= 0 || measurement === lastMeasurement) return;
      lastMeasurement = measurement;
      const fragment = document.createDocumentFragment();
      let covered = 0;
      let index = 0;
      while (covered < backgroundHeight) {
        if (!sequence[index]) sequence.push(nextBand());
        const source = sequence[index++];
        const image = new Image();
        image.src = source.currentSrc || source.src;
        image.alt = '';
        image.width = source.naturalWidth;
        image.height = source.naturalHeight;
        image.dataset.band = source.dataset.band;
        const section = document.createElement('div');
        section.className = 'illustrated-page__band';
        section.style.aspectRatio = `${source.naturalWidth} / ${source.naturalHeight}`;
        section.append(image);
        fragment.append(section);
        covered += width * source.naturalHeight / source.naturalWidth;
      }
      bands.replaceChildren(fragment);
      // Il margine negativo lascia il contenuto sopra la coda, mantenendo interi i raccordi delle fasce.
      body.style.minHeight = `${covered}px`;
    }

    const schedule = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(render);
    };
    if ('ResizeObserver' in window) {
      const observer = new ResizeObserver(schedule);
      observer.observe(content);
      observer.observe(body);
    }
    window.addEventListener('resize', schedule, { passive: true });
    document.fonts?.ready.then(schedule);
    render();
  });
})();

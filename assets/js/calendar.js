/* Mescola le forme, non i giorni. L'intera sequenza varia a ogni caricamento. */
(() => {
  const grid = document.querySelector('[data-leaf-grid]');
  if (!grid) return;
  const types = grid.dataset.leafTypes.split(',');
  const cards = [...grid.querySelectorAll('.calendar-card')];
  if (types.length < 2 || !cards.length) return;

  function shuffle(values) {
    const result = [...values];
    for (let i = result.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
  }

  // Quantità equilibrate, ma nessun blocco ripetuto di cinque foglie.
  const palette = shuffle(types);
  const pool = cards.map((_, i) => palette[i % palette.length]);
  function repetitionScore(sequence) {
    let score = 0;
    sequence.forEach((type, i) => {
      if (i && type === sequence[i - 1]) score += 4;
      // Evita colonne ripetute sia nella griglia a due che in quella a quattro.
      if (i >= 2 && type === sequence[i - 2]) score += 2;
      if (i >= 4 && type === sequence[i - 4]) score += 2;
      // Penalizza file di tre foglie uguali sulle diagonali desktop.
      for (const step of [3, 5]) {
        if (i >= step * 2 && type === sequence[i - step] && type === sequence[i - step * 2]) score += 3;
      }
    });
    return score;
  }
  let order = shuffle(pool);
  let score = repetitionScore(order);
  for (let attempt = 0; attempt < 160 && score > 0; attempt++) {
    const candidate = shuffle(pool);
    const nextScore = repetitionScore(candidate);
    if (nextScore < score) { order = candidate; score = nextScore; }
  }

  cards.forEach((card, i) => {
    const type = order[i];
    types.forEach(name => card.classList.remove(`calendar-leaf--${name}`));
    card.classList.add(`calendar-leaf--${type}`);
    card.querySelector('img').src = `${grid.dataset.leafBase}foglia-${type}.png`;
    card.style.setProperty('--random-leaf-angle', `${(Math.random() * 20 - 10).toFixed(1)}deg`);
  });
})();

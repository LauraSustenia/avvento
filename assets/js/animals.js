---
---
(() => {
  'use strict';
  const catalogue = Object.freeze({{ site.data.registration.animals | jsonify }}.map(animal => Object.freeze(animal)));
  const byId = Object.freeze(Object.fromEntries(catalogue.map(animal => [animal.id, animal])));
  // I vecchi segnaposto vengono ricondotti ai personaggi scelti; non sono nuove opzioni.
  const previous = Object.freeze({uccellino: 'martin-pescatore', insettino: 'emys'});
  const normalize = id => {
    if (typeof id !== 'string') return null;
    const current = Object.hasOwn(previous, id) ? previous[id] : id;
    return Object.hasOwn(byId, current) ? current : null;
  };
  window.GiappAnimals = Object.freeze({
    catalogue,
    normalize,
    isSelectable: id => typeof id === 'string' && Object.hasOwn(byId, id),
    get: id => byId[normalize(id)] || null,
    src: (id, base) => { const animal = byId[normalize(id)]; return animal ? base + animal.image : ''; }
  });
})();

// Palette pairs for the owner's effect families. Promoted event styles are
// explicitly listed in the Halloween catalog; other lab styles remain private.
export const ownerStyleVariants = [
  ['lab-blue-9-red-orbit','Órbita Vermelha',9,'#7f1d1d','#ef4444','#fff1f2','#fecaca'],
  ['lab-blue-9-green-orbit','Órbita Verde',9,'#14532d','#22c55e','#ecfdf5','#bbf7d0'],
  ['lab-blue-4-rose-quartz','Quartzo Rosa',4,'#f26eb0','#ff72b8','#fff1f8','#ffbd47'],
  ['lab-blue-6-crimson-silk','Seda Carmim',6,'#fb5b94','#fd6a9f','#fff1f6','#fd9fc0'],
  ['lab-blue-7-acid-pulse','Pulso Ácido',7,'#a9de2c','#b8f52e','#f7ffe1','#4ee5a4'],
  ['lab-blue-9-meteorite','Meteorito',9,'#ea8958','#ff9961','#fff7ed','#ffdb49'],
  ['lab-blue-10-jade-sky','Céu de Jade',10,'#42d0a0','#48e6b0','#f0fff9','#46ddeb'],
] as const;
export type OwnerStyleVariant = typeof ownerStyleVariants[number][0];

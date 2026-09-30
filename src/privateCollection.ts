/** Owner-only previews, intentionally excluded from every box catalog. */
export const privateStyles = [
  ['preview-plasma', 'Plasma', '#ff4fc8,#b687ff,#73e7ff,#ff4fc8'],
  ['preview-boreal', 'Boreal', '#35efb2,#b4ffe8,#7997ff,#35efb2'],
  ['preview-pearl', 'Pérola', '#fff4db,#f3b9df,#b8e5ff,#fff4db'],
  ['preview-volcano', 'Vulcão', '#ff514b,#ffac63,#ffe5ae,#ff514b'],
  ['preview-atlantis', 'Atlantis', '#38bfff,#a0f9ff,#6381ed,#38bfff'],
  ['preview-sakura', 'Sakura', '#ff81b5,#ffe0ee,#d29bff,#ff81b5'],
  ['preview-toxic', 'Tóxico', '#afff38,#edffc6,#40e99a,#afff38'],
  ['preview-onyx', 'Ônix', '#9ea8bf,#ffffff,#76839d,#9ea8bf'],
  ['preview-supernova', 'Supernova', '#ffc65c,#fff3a3,#f582ee,#ffc65c'],
  ['preview-neon-ocean', 'Oceano Neon', '#40f4e7,#8cafff,#ed91ff,#40f4e7'],
] as const;

export const privateFonts = [
  ['preview-teko', 'Teko', 'Teko'],
  ['preview-oxanium', 'Oxanium', 'Oxanium'],
  ['preview-chakra', 'Chakra Petch', 'Chakra Petch'],
  ['preview-exo', 'Exo 2', 'Exo 2'],
  ['preview-satisfy', 'Satisfy', 'Satisfy'],
  ['preview-marck', 'Marck Script', 'Marck Script'],
  ['preview-gothic', 'UnifrakturCook', 'UnifrakturCook'],
  ['preview-graduate', 'Graduate', 'Graduate'],
  ['preview-londrina', 'Londrina Solid', 'Londrina Solid'],
  ['preview-faster', 'Faster One', 'Faster One'],
] as const;

export type PrivateStyle = typeof privateStyles[number][0];
export const isPrivateCosmetic = (id: string) => id.startsWith('preview-');

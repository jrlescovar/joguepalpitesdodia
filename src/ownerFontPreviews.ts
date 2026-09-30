/** Private font previews, deliberately excluded from every box catalog. */
export const ownerFontPreviews = [
  ['preview-rubikglitch', 'Rubik Glitch', 'Rubik Glitch'],
  ['preview-rubikwetpaint', 'Rubik Wet Paint', 'Rubik Wet Paint'],
  ['preview-rubikdirt', 'Rubik Dirt', 'Rubik Dirt'],
  ['preview-rampartone', 'Rampart One', 'Rampart One'],
  ['preview-tiltprism', 'Tilt Prism', 'Tilt Prism'],
  ['preview-shojumaru', 'Shojumaru', 'Shojumaru'],
  ['preview-tradewinds', 'Trade Winds', 'Trade Winds'],
  ['preview-sedgwickavedisplay', 'Sedgwick Ave Display', 'Sedgwick Ave Display'],
  ['preview-yatraone', 'Yatra One', 'Yatra One'],
  ['preview-fugazone', 'Fugaz One', 'Fugaz One'],
] as const;

export const isOwnerPreviewFont = (font: string) => ownerFontPreviews.some(([id]) => id === font);

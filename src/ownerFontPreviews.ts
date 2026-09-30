/** Private font preview, deliberately excluded from every box catalog. */
export const ownerFontPreviews = [
  ['preview-rubikpuddles', 'Rubik Puddles', 'Rubik Puddles'],
] as const;

export const isOwnerPreviewFont = (font: string) => ownerFontPreviews.some(([id]) => id === font);

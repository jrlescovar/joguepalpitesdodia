import { describe, expect, it } from 'vitest';
import { privateStyles, privateFonts, isPrivateCosmetic } from '../src/privateCollection';
import { boxCatalog, halloweenCatalog } from '../src/boxCatalog';
import { passStyleOptions } from '../src/passStyleOptions';
import { usernameFonts } from '../src/usernameFonts';

describe('private cosmetic collection', () => {
  it('keeps ten matching palettes and ten fonts after the public items', () => {
    expect(privateStyles).toHaveLength(10);
    expect(privateFonts).toHaveLength(10);
    expect(passStyleOptions.slice(-10).map(([id]) => id)).toEqual(privateStyles.map(([id]) => id));
    expect(usernameFonts.slice(-10)).toEqual(privateFonts);
  });
  it('never puts a private item in either loot box', () => {
    expect([...boxCatalog, ...halloweenCatalog].some(item => isPrivateCosmetic(item.style))).toBe(false);
  });
});

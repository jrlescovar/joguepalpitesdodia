import { describe, expect, it } from 'vitest';
import { boxCarouselPageCount, boxCarouselPageStart, boxCarouselTargetPage, boxCarouselThemes } from '../src/boxCarouselPages';
import type { BoxTheme } from '../src/types';

describe('owned box carousel pages',()=>{
  it('uses one box per page on mobile and pairs on desktop',()=>{
    expect(boxCarouselPageCount(5,1)).toBe(5);
    expect(boxCarouselPageCount(5,2)).toBe(3);
    expect(boxCarouselPageCount(0,1)).toBe(0);
    expect(boxCarouselPageCount(1,2)).toBe(1);
  });
  it('shows the last owned box without an empty half-page on desktop',()=>{
    expect([0,1,2].map(page=>boxCarouselPageStart(5,page,2))).toEqual([0,2,3]);
    expect(boxCarouselPageStart(3,1,2)).toBe(1);
    expect(boxCarouselPageStart(1,0,2)).toBe(0);
  });
  it('keeps wheel navigation pointed at the awarded box with missing inventories',()=>{
    const themes:BoxTheme[]=['halloween','frame'];
    expect(boxCarouselTargetPage(themes,'frame',1)).toBe(1);
    expect(boxCarouselTargetPage(themes,'frame',2)).toBe(0);
    expect(boxCarouselTargetPage(themes,'classic',1)).toBeNull();
    expect(boxCarouselTargetPage([], 'font',1)).toBeNull();
  });
  it('all five reward destinations are present on the selected page at either breakpoint',()=>{
    for(const perPage of [1,2])for(const theme of boxCarouselThemes){
      const page=boxCarouselTargetPage(boxCarouselThemes,theme,perPage)!;
      const start=boxCarouselPageStart(boxCarouselThemes.length,page,perPage);
      expect(boxCarouselThemes.slice(start,start+perPage)).toContain(theme);
    }
  });
  it('clamps the selected page when opening the last box removes a slide',()=>{
    expect(boxCarouselPageStart(4,2,2)).toBe(2);
    expect(boxCarouselPageStart(2,4,1)).toBe(1);
  });
});

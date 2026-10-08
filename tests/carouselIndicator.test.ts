import { describe, expect, it } from 'vitest';
import { CarouselIndicator } from '../src/carouselIndicator';

describe('box carousel indicator during scroll',()=>{
  const offsets=[0,350,700,1050,1400];
  it('does not flash intermediate dots after selecting the last box',()=>{
    const indicator=new CarouselIndicator();indicator.select(4);
    expect([0,200,550,860,1100,1390,1400].map(left=>indicator.read(left,offsets))).toEqual([4,4,4,4,4,4,4]);
    expect(indicator.read(1050,offsets)).toBe(3);
  });
  it('keeps the previous-box target selected while leaving the last card',()=>{
    const indicator=new CarouselIndicator();indicator.select(3);
    expect([1400,1360,1230,1060,1050].map(left=>indicator.read(left,offsets))).toEqual([3,3,3,3,3]);
  });
  it('uses the latest target during rapid clicks',()=>{
    const indicator=new CarouselIndicator();indicator.select(4);indicator.select(2);
    expect(indicator.read(350,offsets)).toBe(2);
    expect(indicator.read(700,offsets)).toBe(2);
  });
  it('lets a manual swipe interrupt a requested page',()=>{
    const indicator=new CarouselIndicator();indicator.select(4);indicator.cancel();
    expect(indicator.read(710,offsets)).toBe(2);
  });
  it('recovers from interrupted scrolling and a removed box',()=>{
    const indicator=new CarouselIndicator();indicator.select(4);
    indicator.cancel();
    expect(indicator.read(350,offsets)).toBe(1);
    indicator.select(4);
    expect(indicator.read(350,[0,350])).toBe(1);
  });
});

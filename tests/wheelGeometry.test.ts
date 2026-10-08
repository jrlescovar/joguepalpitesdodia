import { describe, expect, it } from 'vitest';
import { wheelLandingAngle, wheelSegments } from '../src/wheelGeometry';
import { wheelPrizeSummary } from '../src/wheelPrizeSummary';
import { catalogForBox } from '../src/boxThemes';
import { boxCatalog } from '../src/boxCatalog';
import type { WheelPrize } from '../src/types';

const kinds:WheelPrize['kind'][]=['empty','classic','halloween','font','empty','empty','name','frame','supporter','empty','empty'];
const prizes:WheelPrize[]=kinds.map((kind,position)=>({position,kind,label:'Prêmio',weight:position===5?2850:kind==='supporter'?1200:kind==='empty'?1845:kind==='font'?2130:kind==='halloween'?1890:2850,chance:position===5?11.875:kind==='supporter'?5:kind==='empty'?30.75/4:kind==='font'?8.875:kind==='halloween'?7.875:11.875}));
describe('wheel displayed odds and server prize landing',()=>{
  it('uses the actual weights, with exactly 5% of the circle for Apoiador',()=>{
    const segments=wheelSegments(prizes);
    expect(segments[0].start).toBe(0);
    expect(segments.at(-1)?.end).toBeCloseTo(360);
    const supporter=segments.find(segment=>segment.kind==='supporter')!;
    expect(supporter.end-supporter.start).toBeCloseTo(18);
    expect(segments.filter(s=>['classic','name','frame'].includes(s.kind)).every(s=>Math.abs(s.end-s.start-42.75)<0.0001)).toBe(true);
    const font=segments.find(segment=>segment.kind==='font')!;
    expect((font.end-font.start)/360*100).toBeCloseTo(8.875);
    const halloween=segments.find(segment=>segment.kind==='halloween')!;
    expect((halloween.end-halloween.start)/360*100).toBeCloseTo(7.875);
    expect(segments.filter(s=>s.kind==='empty').reduce((sum,segment)=>sum+segment.end-segment.start,0)/360*100).toBeCloseTo(42.625);
  });
  it('puts each returned server position exactly under the top pointer',()=>{
    for(const segment of wheelSegments(prizes)){
      expect((segment.middle+wheelLandingAngle(prizes,segment.position))%360).toBeCloseTo(0);
    }
  });
  it('supports reordered server positions and future probability changes',()=>{
    const changed=[{...prizes[8],weight:1},{...prizes[0],weight:3}];
    expect(wheelLandingAngle(changed,8)).toBe(315);
    expect(wheelLandingAngle(changed,0)).toBe(135);
    expect(wheelSegments([])).toEqual([]);
  });
  it('places an empty slot on each side of Apoiador, preserving the server prizes',()=>{
    const segments=wheelSegments(prizes);
    const supporter=segments.findIndex(segment=>segment.kind==='supporter');
    expect(segments[(supporter+segments.length-1)%segments.length].kind).toBe('empty');
    expect(segments[(supporter+1)%segments.length].kind).toBe('empty');
    expect(segments.map(segment=>segment.position).sort()).toEqual(prizes.map(prize=>prize.position).sort());
    expect(segments.filter(segment=>segment.kind==='classic')).toHaveLength(1);
  });
  it('puts fonts between two empty slots before the name-color box',()=>{
    const segments=wheelSegments(prizes);
    const halloween=segments.findIndex(segment=>segment.kind==='halloween');
    expect(segments[halloween+1].kind).toBe('empty');
    expect(segments[halloween+2].kind).toBe('font');
    expect(segments[halloween+3].kind).toBe('empty');
    expect(segments[halloween+4].kind).toBe('name');
  });
  it('shows no reward between the name-color and frame boxes',()=>{
    const segments=wheelSegments(prizes);
    const name=segments.findIndex(segment=>segment.kind==='name');
    expect(segments[name+1].kind).toBe('empty');
    expect(segments[name+2].kind).toBe('frame');
  });
  it('restores older personalization rewards without changing their stored result',()=>{
    const previous={position:5,kind:'classic' as const};
    expect(wheelLandingAngle(prizes,previous.position,previous.kind)).toBe(wheelLandingAngle(prizes,1));
    expect(wheelLandingAngle(prizes,5,'empty')).toBe(wheelLandingAngle(prizes,5));
    expect(previous).toEqual({position:5,kind:'classic'});
  });
});
describe('wheel help grouped probabilities',()=>{
  it('shows each reward once and totals duplicate sector chances without changing prizes',()=>{
    const summary=wheelPrizeSummary(prizes);
    expect(summary).toHaveLength(7);
    expect(summary.find(prize=>prize.kind==='classic')?.chance).toBeCloseTo(11.875);
    expect(summary.find(prize=>prize.kind==='empty')?.chance).toBeCloseTo(42.625);
    expect(summary.find(prize=>prize.kind==='halloween')?.chance).toBeCloseTo(7.875);
    expect(summary.find(prize=>prize.kind==='font')?.chance).toBeCloseTo(8.875);
    expect(summary.find(prize=>prize.kind==='supporter')?.chance).toBeCloseTo(5);
    expect(summary.reduce((sum,prize)=>sum+prize.chance,0)).toBeCloseTo(100);
    expect(prizes).toHaveLength(11);
    expect(wheelPrizeSummary([])).toEqual([]);
  });
});
describe('reward-only specialized boxes',()=>{
  it.each(['name','frame'] as const)('%s contains exactly its normal-box items without event/private additions',kind=>{
    const items=catalogForBox(kind);
    expect(items).toEqual(boxCatalog.filter(item=>item.kind===kind));
    expect(new Set(items.map(item=>item.rarity)).size).toBe(5);
    expect(items.every(item=>item.kind===kind)).toBe(true);
  });
});

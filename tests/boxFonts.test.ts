import {describe,it,expect} from 'vitest';
import {boxCatalog,boxRarities,boxStyleLabel} from '../src/boxCatalog';
import {usernameFonts} from '../src/usernameFonts';
describe('font catalog',()=>{
 it('contains each custom font exactly once with the configured rarity, excludes Normal',()=>{
 const fonts=boxCatalog.filter(item=>item.kind==='font');
 expect(fonts.map(item=>item.style).sort()).toEqual(usernameFonts.filter(([id])=>id!=='normal').map(([id])=>id).sort());
 expect(Object.fromEntries(fonts.map(item=>[item.style,item.rarity]))).toEqual({monocraft:'legendary',dancingscript:'legendary',bebasneue:'epic',amaticsc:'mythic',kalam:'mythic'});
 expect(fonts.every(item=>boxStyleLabel(item.style)!==item.style)).toBe(true);
 });
 it('keeps color/frame pairs separate and total rarity odds unchanged',()=>{
 for(const item of boxCatalog.filter(item=>item.kind==='name'))expect(boxCatalog.filter(other=>other.style===item.style&&other.kind==='frame')).toHaveLength(1);
 expect(boxRarities.reduce((sum,item)=>sum+item.chance,0)).toBe(100);
 expect(boxRarities.find(item=>item.id==='legendary')).toMatchObject({chance:5,duplicateXp:500});
 });
});

import {describe,it,expect} from 'vitest';
import {boxCatalog,halloweenCatalog,halloweenRarities,boxRarities,boxStyleLabel,fontRarity} from '../src/boxCatalog';
import {usernameFonts} from '../src/usernameFonts';
describe('font catalog',()=>{
 it('contains each custom font exactly once with the configured rarity, excludes Normal',()=>{
 const fonts=[...boxCatalog,...halloweenCatalog].filter(item=>item.kind==='font');
 expect(fonts.map(item=>item.style).sort()).toEqual(usernameFonts.filter(([id])=>fontRarity(id)!==null).map(([id])=>id).sort());
 expect(Object.fromEntries(fonts.map(item=>[item.style,item.rarity]))).toEqual({marckscript:'legendary',unifrakturcook:'mythic',monocraft:'legendary',dancingscript:'legendary',bebasneue:'epic',amaticsc:'mythic',kalam:'mythic',orbitron:'epic',permanentmarker:'mythic',blackopsone:'rare',audiowide:'rare',specialelite:'mythic',luckiestguy:'epic',creepster:'epic',eater:'legendary',butcherman:'mythic',metalmania:'epic',frijole:'mythic',rye:'mythic',quantico:'rare'});
 expect(fonts.every(item=>boxStyleLabel(item.style)!==item.style)).toBe(true);
 expect(halloweenCatalog.filter(item=>item.kind==='font').map(item=>item.style).sort()).toEqual(['butcherman','creepster','eater']);
 });
 it('keeps owner preview fonts unclassified and outside boxes',()=>{for(const [id] of usernameFonts.filter(([font])=>font!=='normal'&&fontRarity(font)===null)){expect(fontRarity(id)).toBeNull();expect(boxCatalog.some(item=>item.style===id)).toBe(false);}});
 it('keeps color/frame pairs separate and total rarity odds unchanged',()=>{
 for(const item of boxCatalog.filter(item=>item.kind==='name'))expect(boxCatalog.filter(other=>other.style===item.style&&other.kind==='frame')).toHaveLength(1);
 expect(boxRarities.reduce((sum,item)=>sum+item.chance,0)).toBe(100);
 expect(boxRarities.find(item=>item.id==='legendary')).toMatchObject({chance:5,duplicateXp:500});
 });
 it('keeps Halloween items in their own box with every rarity available',()=>{
    expect(halloweenCatalog).toHaveLength(13);
   expect(halloweenRarities.map(tier=>tier.chance)).toEqual([60,30,10]);
   for(const tier of halloweenRarities)expect(halloweenCatalog.some(item=>item.rarity===tier.id)).toBe(true);
   for(const item of halloweenCatalog)expect(boxCatalog.some(other=>other.kind===item.kind&&other.style===item.style)).toBe(false);
 });
});

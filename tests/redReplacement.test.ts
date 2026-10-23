import {describe,it,expect} from 'vitest';
import {passStyleOptions,creatorStyleOptions,commonPassStyles} from '../src/passStyleOptions';
import {boxCatalog,halloweenCatalog} from '../src/boxCatalog';
import {creatorEffectGroups} from '../src/creatorEffectModels';
describe('retired Red style',()=>{
 it('removes Red from both pickers, creator, loot, and effect templates',()=>{
  expect([...passStyleOptions,...creatorStyleOptions].some(([id])=>id==='blood')).toBe(false);
  expect(commonPassStyles.has('blood')).toBe(false);
  expect([...boxCatalog,...halloweenCatalog].some(item=>item.style==='blood')).toBe(false);
  expect(Object.values(creatorEffectGroups).flat(2)).not.toContain('blood');
 });
 it('keeps Lua Sangrenta as the event name/frame pair with its rarity',()=>{
  expect(passStyleOptions).toContainEqual(['halloween-bloodmoon','Lua Sangrenta']);
  expect(halloweenCatalog.filter(item=>item.style==='halloween-bloodmoon')).toEqual([
   {kind:'name',style:'halloween-bloodmoon',rarity:'mythic'},
   {kind:'frame',style:'halloween-bloodmoon',rarity:'mythic'},
  ]);
  expect(boxCatalog.some(item=>item.style==='halloween-bloodmoon')).toBe(false);
 });
});

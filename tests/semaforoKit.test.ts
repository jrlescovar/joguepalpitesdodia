import {describe,it,expect} from 'vitest';
import {boxRarity,boxStyleLabel,halloweenCatalog,boxCatalog} from '../src/boxCatalog';
import {canonicalCreatorModel} from '../src/creatorEffectModels';
describe('Semáforo',()=>{
 it('drops as a separate mythic name/frame pair only in the event box',()=>{
  expect(boxStyleLabel('halloween-semaforo')).toBe('Semáforo');
  expect(boxRarity('halloween-semaforo')).toBe('mythic');
  expect(halloweenCatalog.filter(item=>item.style==='halloween-semaforo')).toEqual([{kind:'name',style:'halloween-semaforo',rarity:'mythic'},{kind:'frame',style:'halloween-semaforo',rarity:'mythic'}]);
  expect(boxCatalog.some(item=>item.style==='halloween-semaforo')).toBe(false);
  expect(boxRarity('halloween-clown')).toBe('legendary');
 });
 it('uses the correct independent effect families in the creator',()=>{
  expect(canonicalCreatorModel('halloween-semaforo','name')).toBe(canonicalCreatorModel('halloween-clown','name'));
  expect(canonicalCreatorModel('halloween-semaforo','frame')).toBe(canonicalCreatorModel('legend-nebula','frame'));
 });
});

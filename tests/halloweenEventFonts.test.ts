import {describe,it,expect} from 'vitest';
import {boxCatalog,halloweenCatalog,isHalloweenFont,fontRarity,fontBoxCatalog} from '../src/boxCatalog';
import {catalogForBox} from '../src/boxThemes';

describe.each([['caesardressing','legendary'],['frederickathegreat','mythic'],['hennypenny','legendary'],['eater','legendary']] as const)('%s Halloween exclusivity',(font,rarity)=>{
 it('keeps its rarity and remains an event font',()=>{
  expect(fontRarity(font)).toBe(rarity);
  expect(isHalloweenFont(font)).toBe(true);
  expect(halloweenCatalog.filter(item=>item.style===font)).toEqual([{kind:'font',style:font,rarity}]);
 });
 it('is excluded from ordinary boxes and the level-drop catalog',()=>{
  expect(boxCatalog.some(item=>item.style===font)).toBe(false);
  expect(fontBoxCatalog.some(item=>item.style===font)).toBe(false);
  for(const theme of ['classic','font','frame','name'] as const){
   expect(catalogForBox(theme).some(item=>item.style===font)).toBe(false);
  }
 });
});

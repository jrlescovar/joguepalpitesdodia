import {describe,it,expect} from 'vitest';
import {readFileSync} from 'node:fs';
import {ownerFontPreviews,isOwnerPreviewFont} from '../src/ownerFontPreviews';
import {usernameFonts} from '../src/usernameFonts';
import {boxCatalog,fontBoxCatalog,halloweenCatalog,fontRarity} from '../src/boxCatalog';

describe('private font previews',()=>{
 it('provides thirty-five distinct private fonts outside every loot pool',()=>{
  expect(ownerFontPreviews).toHaveLength(35);
  expect(new Set(ownerFontPreviews.map(([,label])=>label)).size).toBe(35);
  for(const [id,label] of ownerFontPreviews){
   expect(isOwnerPreviewFont(id)).toBe(true);
   expect(usernameFonts.filter(([font])=>font===id)).toHaveLength(1);
   expect(usernameFonts.filter(([,name])=>name===label)).toHaveLength(1);
   expect(fontRarity(id)).toBeNull();
   expect([...boxCatalog,...fontBoxCatalog,...halloweenCatalog].some(item=>item.style===id)).toBe(false);
  }
  expect(isOwnerPreviewFont('marckscript')).toBe(false);
 });
 it('ships valid self-hosted WOFF2 assets and their original licenses',()=>{
  for(const [id] of ownerFontPreviews){
   const bytes=readFileSync(new URL('../public/fonts/'+id+'.woff2',import.meta.url));
   expect(bytes.toString('ascii',0,4)).toBe('wOF2');
   expect(bytes.readUInt32BE(8)).toBe(bytes.length);
   expect(readFileSync(new URL('../public/fonts/'+id+'-OFL.txt',import.meta.url),'utf8')).toContain('SIL OPEN FONT LICENSE');
  }
 });
 it('promotes Marck Script to legendary in both ordinary font pools',()=>{
  expect(fontRarity('marckscript')).toBe('legendary');
  expect(boxCatalog.find(item=>item.style==='marckscript')).toMatchObject({kind:'font',rarity:'legendary'});
  expect(fontBoxCatalog.find(item=>item.style==='marckscript')).toMatchObject({kind:'font',rarity:'legendary'});
 });
});

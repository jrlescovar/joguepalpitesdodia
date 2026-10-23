import {describe,it,expect} from 'vitest';
import {readFileSync,existsSync} from 'node:fs';
import {releasedUsernameFonts} from '../src/releasedUsernameFonts';
import {usernameFonts} from '../src/usernameFonts';
import {boxCatalog,fontBoxCatalog,halloweenCatalog,fontRarity,boxStyleLabel,isHalloweenFont} from '../src/boxCatalog';

const expectedRarities={
 rubikglitch:'mythic',rubikwetpaint:'mythic',tradewinds:'mythic',sedgwickavedisplay:'legendary',
 fugazone:'rare',reggaeone:'epic',alfaslabone:'rare',
 caesardressing:'legendary',fascinateinline:'mythic',fingerpaint:'mythic',frederickathegreat:'mythic',hennypenny:'legendary',lacquer:'epic',
 sancreek:'mythic',megrim:'mythic',
};
const expectedLabels={sedgwickavedisplay:'HipHop',caesardressing:'Noruega',frederickathegreat:'Darkness',hennypenny:'Magic',};
const removed=['blackopsone','audiowide','arbutus','miltoniantattoo','creepster','specialelite','rubikdirt','shojumaru','allertastencil','barrio','rubikmoonrocks','rampartone','kumaroneoutline','ewert','kiranghaerang','dancingscript','tiltprism','akronim','arizonia','bigelowrules','rubikvinyl','butcherman','unifrakturcook','frijole','geostarfill','bungeeshade','rubikbeastly','diplomatasc','yatraone','asset','biorhymeexpanded','bokor','bowlbyonesc','changaone','diplomata','geostar','rubikspraypaint'];
describe('reviewed font release',()=>{
 it('applies every requested rarity and keeps HipHop in the normal and font boxes',()=>{
  expect(releasedUsernameFonts).toHaveLength(15);
  expect(Object.fromEntries(releasedUsernameFonts.map(([id])=>[id,fontRarity(id)]))).toEqual(expectedRarities);
  for(const [id,,family] of releasedUsernameFonts){
   expect(usernameFonts.filter(([key])=>key===id)).toHaveLength(1);
   expect(usernameFonts.find(([key])=>key===id)?.[2]).toBe(family);
   const event=['caesardressing','frederickathegreat','hennypenny'].includes(id);
   expect(isHalloweenFont(id)).toBe(event);
   expect(halloweenCatalog.filter(item=>item.style===id)).toHaveLength(event?1:0);
   expect(boxCatalog.filter(item=>item.style===id)).toHaveLength(event?0:1);
   expect(fontBoxCatalog.filter(item=>item.style===id)).toHaveLength(event?0:1);
  }
  for(const [id,label] of Object.entries(expectedLabels))expect(boxStyleLabel(id)).toBe(label);
  expect(fontRarity('bebasneue')).toBe('rare');
  expect(isHalloweenFont('eater')).toBe(true);
 });
 it('keeps exact requested size changes and valid font assets',()=>{
  expect(Object.fromEntries(releasedUsernameFonts.filter(row=>row[5]!==0).map(row=>[row[0],row[5]]))).toEqual({fascinateinline:-1,frederickathegreat:1,hennypenny:1,megrim:1});
  for(const [id] of releasedUsernameFonts){
   const bytes=readFileSync(new URL('../public/fonts/'+id+'.woff2',import.meta.url));
   expect(bytes.toString('ascii',0,4)).toBe('wOF2');
   expect(bytes.readUInt32BE(8)).toBe(bytes.length);
   expect(readFileSync(new URL('../public/fonts/'+id+'-OFL.txt',import.meta.url),'utf8')).toContain('SIL OPEN FONT LICENSE');
  }
 });
 it('removes retired fonts and old preview aliases from active registries',()=>{
  for(const id of removed){
   expect(usernameFonts.some(([key])=>key===id||key==='preview-'+id)).toBe(false);
   expect([...boxCatalog,...halloweenCatalog].some(item=>item.style===id||item.style==='preview-'+id)).toBe(false);
   expect(existsSync(new URL('../public/fonts/preview-'+id+'.woff2',import.meta.url))).toBe(false);
   expect(existsSync(new URL('../public/fonts/'+id+'.woff2',import.meta.url))).toBe(false);
  }
  for(const [id] of releasedUsernameFonts)expect(usernameFonts.some(([key])=>key==='preview-'+id)).toBe(false);
 });
});

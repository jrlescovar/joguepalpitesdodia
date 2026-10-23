import {describe,it,expect} from 'vitest';
import {ownerFontPreviews,isOwnerPreviewFont} from '../src/ownerFontPreviews';
import {usernameFonts} from '../src/usernameFonts';
import {boxCatalog,halloweenCatalog} from '../src/boxCatalog';
describe('retired owner font previews',()=>{
 it('removes Rubik Puddles from every font selector',()=>{expect(ownerFontPreviews).toHaveLength(0);expect(usernameFonts.some(([id])=>String(id)==='preview-rubikpuddles')).toBe(false);expect(isOwnerPreviewFont('preview-rubikpuddles')).toBe(false)});
 it('keeps the retired font out of loot pools',()=>{expect([...boxCatalog,...halloweenCatalog].some(i=>String(i.style)==='preview-rubikpuddles')).toBe(false)});
});

import { describe, it, expect } from 'vitest';
import { ownerStyleVariants } from '../src/ownerStyleVariants';
import { passStyleOptions } from '../src/passStyleOptions';
import { boxCatalog, halloweenCatalog, fontBoxCatalog } from '../src/boxCatalog';
import { usernameFonts } from '../src/usernameFonts';

describe('owner palette variants',()=>{
  it('has seven pairs per approved family and no reused display names',()=>{
    expect(ownerStyleVariants).toHaveLength(35);
    for(const family of [4,6,7,9,10]) expect(ownerStyleVariants.filter(row=>row[2]===family)).toHaveLength(7);
    const ids=ownerStyleVariants.map(row=>row[0]);
    expect(new Set(ids).size).toBe(35);
    const normalize=(s:string)=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    const labels=ownerStyleVariants.map(row=>normalize(row[1]));
    expect(new Set(labels).size).toBe(35);
    const existing=[...passStyleOptions.filter(([id])=>!ids.includes(id as typeof ids[number])).map(([,label])=>normalize(label)),...usernameFonts.map(([,label])=>normalize(label))];
    expect(labels.some(label=>existing.includes(label))).toBe(false);
  });
  it('keeps every new palette outside purchasable box pools',()=>{
    for(const [style,label] of ownerStyleVariants){
      expect(passStyleOptions.filter(([id])=>id===style)).toEqual([[style,label]]);
      expect([...boxCatalog,...halloweenCatalog,...fontBoxCatalog].some(item=>item.style===style)).toBe(false);
    }
  });
});

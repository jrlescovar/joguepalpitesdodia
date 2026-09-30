import { describe, it, expect } from 'vitest';
import { ownerStyleVariants } from '../src/ownerStyleVariants';
import { passStyleOptions } from '../src/passStyleOptions';
import { boxCatalog, halloweenCatalog, fontBoxCatalog, boxRarity } from '../src/boxCatalog';
import { usernameFonts } from '../src/usernameFonts';

describe('owner palette variants',()=>{
  it('classifies the original Blue 9 as mythic without adding it to any box',()=>{
    expect(passStyleOptions.find(([style])=>style==='lab-blue-9')?.[1]).toBe('Órbita Azul');
    expect(boxRarity('lab-blue-9')).toBe('mythic');
    expect([...boxCatalog,...halloweenCatalog,...fontBoxCatalog].some(item=>item.style==='lab-blue-9')).toBe(false);
    const position=passStyleOptions.findIndex(([style])=>style==='lab-blue-9');
    expect(position).toBeGreaterThan(passStyleOptions.findIndex(([style])=>style==='myth-fuchsia-petroleum'));
    expect(position).toBeLessThan(passStyleOptions.findIndex(([style])=>style==='gold'));
  });
  it('keeps colored sweeps distinct and readable on dark cards throughout the gradient',()=>{
    const rgb=(hex:string)=>hex.match(/[a-f0-9]{2}/gi)!.map(value=>parseInt(value,16));
    const luminance=(channels:number[])=>channels.map(value=>{
      const c=value/255;
      return c<=.04045?c/12.92:((c+.055)/1.055)**2.4;
    }).reduce((sum,value,i)=>sum+value*[.2126,.7152,.0722][i],0);
    const background=luminance(rgb('#242a35'));
    for(const [id,, ,dark,mid,,accent] of ownerStyleVariants){
      const base=rgb(mid),sweep=rgb(accent);
      expect(Math.hypot(...base.map((channel,i)=>channel-sweep[i])),id+' colored sweep').toBeGreaterThan(45);
      const stops=[rgb(dark),base,sweep,base,rgb(dark)];
      for(let segment=0;segment<stops.length-1;segment++){
        for(let step=0;step<=20;step++){
          const t=step/20;
          const sample=stops[segment].map((channel,i)=>channel*(1-t)+stops[segment+1][i]*t);
          expect((luminance(sample)+.05)/(background+.05),id+' gradient contrast').toBeGreaterThanOrEqual(4.5);
        }
      }
    }
  });
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

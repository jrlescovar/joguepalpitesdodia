import { describe, it, expect } from 'vitest';
import { ownerStyleVariants } from '../src/ownerStyleVariants';
import { passStyleOptions } from '../src/passStyleOptions';
import { boxCatalog, halloweenCatalog, fontBoxCatalog, boxRarity, isHalloweenStyle } from '../src/boxCatalog';
import { usernameFonts } from '../src/usernameFonts';

describe('owner palette variants',()=>{
  it('keeps the promoted styles exclusive to Halloween with their intended rarities',()=>{
    expect(passStyleOptions.find(([style])=>style==='lab-blue-9')?.[1]).toBe('Órbita Azul');
    expect(boxRarity('lab-blue-9')).toBe('legendary');
    expect(halloweenCatalog.filter(item=>item.style==='lab-blue-9')).toEqual([{kind:'name',style:'lab-blue-9',rarity:'legendary'},{kind:'frame',style:'lab-blue-9',rarity:'legendary'}]);
    const position=passStyleOptions.findIndex(([style])=>style==='lab-blue-9');
    expect(position).toBeGreaterThan(passStyleOptions.findIndex(([style])=>style==='legend-ruby-eclipse'));
    expect(position).toBeLessThan(passStyleOptions.length);
    const jade='lab-blue-10-jade-sky';
    expect(boxRarity(jade)).toBe('mythic');
    expect(halloweenCatalog.filter(item=>item.style===jade)).toEqual([{kind:'name',style:jade,rarity:'mythic'},{kind:'frame',style:jade,rarity:'mythic'}]);
    expect(passStyleOptions.find(([style])=>style==='lab-blue-6')?.[1]).toBe('Luz de Alma');
    expect(boxRarity('lab-blue-6')).toBe('legendary');
    expect(halloweenCatalog.filter(item=>item.style==='lab-blue-6')).toEqual([{kind:'name',style:'lab-blue-6',rarity:'legendary'},{kind:'frame',style:'lab-blue-6',rarity:'legendary'}]);
    for(const style of ['lab-blue-6','lab-blue-9',jade]){
      expect(isHalloweenStyle(style)).toBe(true);
      expect([...boxCatalog,...fontBoxCatalog].some(item=>item.style===style)).toBe(false);
    }
    const jadePosition=passStyleOptions.findIndex(([style])=>style===jade);
    expect(jadePosition).toBeGreaterThan(passStyleOptions.findIndex(([style])=>style==='myth-fuchsia-petroleum'));
    expect(jadePosition).toBeLessThan(passStyleOptions.findIndex(([style])=>style==='gold'));
  });
  it('keeps colored sweeps distinct and readable on dark cards throughout the gradient',()=>{
    const rgb=(hex:string)=>hex.match(/[a-f0-9]{2}/gi)!.map(value=>parseInt(value,16));
    const luminance=(channels:number[])=>channels.map(value=>{
      const c=value/255;
      return c<=.04045?c/12.92:((c+.055)/1.055)**2.4;
    }).reduce((sum,value,i)=>sum+value*[.2126,.7152,.0722][i],0);
    const background=luminance(rgb('#242a35'));
    for(const [id,,family,dark,mid,,accent] of ownerStyleVariants){
      // Promoted Orbit variants intentionally reproduce the blue original rather than this palette sweep.
      if(id==='lab-blue-9-red-orbit'||id==='lab-blue-9-green-orbit') {
        expect(boxRarity(id)).toBe('legendary');
        expect(halloweenCatalog.filter(item=>item.style===id)).toHaveLength(2);
        expect(boxCatalog.some(item=>item.style===id)).toBe(false);
        continue;
      }
      const base=rgb(mid),sweep=rgb(accent);
      if(family!==6) expect(Math.hypot(...base.map((channel,i)=>channel-sweep[i])),id+' colored sweep').toBeGreaterThan(45);
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
  it('keeps the remaining pairs without retired styles or reused display names',()=>{
    expect(ownerStyleVariants).toHaveLength(7);
    for(const [family,count] of [[4,1],[6,1],[7,1],[9,3],[10,1]]) expect(ownerStyleVariants.filter(row=>row[2]===family)).toHaveLength(count);
    const ids=ownerStyleVariants.map(row=>row[0]);
    expect(new Set(ids).size).toBe(7);
    expect(passStyleOptions.some(([id])=>['lab-blue-9-amber-cosmos','lab-blue-10-tropical-light','lab-blue-4-polar-amber','lab-blue-4-vivid-topaz','lab-blue-6-golden-mirage'].includes(id))).toBe(false);
    const normalize=(s:string)=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
    const labels=ownerStyleVariants.map(row=>normalize(row[1]));
    expect(new Set(labels).size).toBe(7);
    const existing=[...passStyleOptions.filter(([id])=>!ids.includes(id as typeof ids[number])).map(([,label])=>normalize(label)),...usernameFonts.map(([,label])=>normalize(label))];
    expect(labels.some(label=>existing.includes(label))).toBe(false);
  });
  it('keeps private palettes outside box pools except the promoted Halloween event style',()=>{
    for(const [style,label] of ownerStyleVariants){
      expect(passStyleOptions.filter(([id])=>id===style)).toEqual(isHalloweenStyle(style)?[[style,label]]:[]);
      expect([...boxCatalog,...fontBoxCatalog].some(item=>item.style===style)).toBe(false);
      expect(halloweenCatalog.some(item=>item.style===style)).toBe(['lab-blue-10-jade-sky','lab-blue-9-red-orbit','lab-blue-9-green-orbit'].includes(style));
    }
  });
});

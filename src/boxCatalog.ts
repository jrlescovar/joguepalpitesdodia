import { commonPassStyles, passStyleOptions } from './passStyleOptions';
import type { BoxRarity, PassNameStyle } from './types';

const epic = new Set<PassNameStyle>(['midnight-electric','graphite-silver','wine-rose','neon-circuit','sunset-ocean','rare-plum-beige']);
export const boxRarities: {id:BoxRarity;label:string;chance:number;duplicateXp:number}[] = [
  {id:'common',label:'Comum',chance:40,duplicateXp:25},
  {id:'rare',label:'Raro',chance:30,duplicateXp:50},
  {id:'epic',label:'Épico',chance:15,duplicateXp:100},
  {id:'mythic',label:'Mítico',chance:10,duplicateXp:250},
  {id:'legendary',label:'Lendário',chance:5,duplicateXp:500},
];
export function boxRarity(style:PassNameStyle):BoxRarity {
  if(style==='gold'||style==='rainbow'||style.startsWith('legend-'))return 'legendary';
  if(style.startsWith('myth-'))return 'mythic';
  if(epic.has(style))return 'epic';
  return commonPassStyles.has(style)?'common':'rare';
}
export const boxCatalog = passStyleOptions.filter(([style])=>style!=='none').map(([style,label])=>({style,label,rarity:boxRarity(style)}));
export function boxStyleLabel(style:PassNameStyle){return passStyleOptions.find(([id])=>id===style)?.[1]??style;}

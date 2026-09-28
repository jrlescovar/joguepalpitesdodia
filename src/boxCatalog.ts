import { commonPassStyles, passStyleOptions } from './passStyleOptions';
import { usernameFonts, type UsernameFont } from './usernameFonts';
import type { BoxItem, BoxRarity, PassNameStyle } from './types';

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
export function fontRarity(font:UsernameFont):BoxRarity|null {const rarities:Partial<Record<UsernameFont,BoxRarity>>={"blackopsone":"rare","audiowide":"rare","bebasneue":"epic","orbitron":"epic","luckiestguy":"epic","creepster":"epic","amaticsc":"mythic","kalam":"mythic","permanentmarker":"mythic","specialelite":"mythic","monocraft":"legendary","dancingscript":"legendary"};return rarities[font]??null;}
export const boxCatalog: BoxItem[] = [...passStyleOptions.filter(([style])=>style!=='none').flatMap(([style])=>(['name','frame'] as const).map(kind=>({kind,style,rarity:boxRarity(style)}))),...usernameFonts.filter(([font])=>fontRarity(font)!==null).map(([font])=>({kind:'font' as const,style:font as Exclude<UsernameFont,'normal'>,rarity:fontRarity(font)!}))];
export function boxStyleLabel(style:PassNameStyle|UsernameFont){return passStyleOptions.find(([id])=>id===style)?.[1]??usernameFonts.find(([id])=>id===style)?.[1]??style;}

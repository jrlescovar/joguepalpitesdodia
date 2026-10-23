import { commonPassStyles, passStyleOptions } from './passStyleOptions';
import { usernameFonts, type UsernameFont } from './usernameFonts';
import { releasedUsernameFonts } from './releasedUsernameFonts';
import type { BoxItem, BoxRarity, PassNameStyle } from './types';

const epic = new Set<PassNameStyle>(['midnight-electric','graphite-silver','wine-rose','neon-circuit','sunset-ocean','rare-plum-beige','halloween-pumpkin']);
export const boxRarities: {id:BoxRarity;label:string;chance:number;duplicateXp:number}[] = [
  {id:'common',label:'Comum',chance:40,duplicateXp:50},
  {id:'rare',label:'Raro',chance:30,duplicateXp:100},
  {id:'epic',label:'Épico',chance:15,duplicateXp:200},
  {id:'mythic',label:'Mítico',chance:10,duplicateXp:500},
  {id:'legendary',label:'Lendário',chance:5,duplicateXp:1000},
];
export function boxRarity(style:PassNameStyle):BoxRarity {
  if(style==='halloween-semaforo'||style==='lilac-silver'||style==='lab-blue-10-jade-sky'||style==='halloween-mist'||style==='halloween-bloodmoon')return 'mythic';
  if(style==='lab-blue-6'||style==='lab-blue-9'||style==='lab-blue-9-red-orbit'||style==='lab-blue-9-green-orbit'||style==='halloween-cleopatra'||style==='halloween-clown'||style==='gold'||style==='rainbow'||style.startsWith('legend-'))return 'legendary';
  if(style.startsWith('myth-'))return 'mythic';
  if(epic.has(style))return 'epic';
  return commonPassStyles.has(style)?'common':'rare';
}
export function fontRarity(font:UsernameFont):BoxRarity|null {const rarities:Partial<Record<UsernameFont,BoxRarity>>={"marckscript":"legendary","quantico":"rare","bebasneue":"rare","orbitron":"epic","luckiestguy":"epic","eater":"legendary","metalmania":"epic","rye":"epic","amaticsc":"mythic","kalam":"mythic","permanentmarker":"mythic","monocraft":"legendary"};return rarities[font]??releasedUsernameFonts.find(([id])=>id===font)?.[3]??null;}
export const isHalloweenFont=(font:string)=>font==='eater'||releasedUsernameFonts.some(([id,,,,theme])=>id===font&&theme==='halloween');
export const halloweenStyles = ['halloween-semaforo','legend-arcane-twilight','halloween-cleopatra','halloween-clown','halloween-pumpkin','halloween-bloodmoon','halloween-mist','lab-blue-9','lab-blue-9-red-orbit','lab-blue-9-green-orbit','lab-blue-10-jade-sky','lab-blue-6'] as const;
export const isHalloweenStyle=(style:string)=>halloweenStyles.some(item=>item===style);
export const halloweenRarities=boxRarities.filter(tier=>['epic','mythic','legendary'].includes(tier.id)).map(tier=>({...tier,chance:tier.id==='epic'?60:tier.id==='mythic'?30:10}));
export const halloweenCatalog:BoxItem[]=[...halloweenStyles.flatMap(style=>(['name','frame'] as const).map(kind=>({kind,style,rarity:boxRarity(style)}))),...usernameFonts.filter(([font])=>isHalloweenFont(font)).map(([font])=>({kind:'font' as const,style:font as Exclude<UsernameFont,'normal'>,rarity:fontRarity(font)!}))];
export const boxCatalog: BoxItem[] = [...passStyleOptions.filter(([style])=>style!=='none'&&!style.startsWith('lab-blue-')&&!halloweenStyles.includes(style as typeof halloweenStyles[number])).flatMap(([style])=>(['name','frame'] as const).map(kind=>({kind,style,rarity:boxRarity(style)}))),...usernameFonts.filter(([font])=>fontRarity(font)!==null&&!isHalloweenFont(font)).map(([font])=>({kind:'font' as const,style:font as Exclude<UsernameFont,'normal'>,rarity:fontRarity(font)!}))];
export function boxStyleLabel(style:PassNameStyle|UsernameFont|string){return passStyleOptions.find(([id])=>id===style)?.[1]??usernameFonts.find(([id])=>id===style)?.[1]??style;}

export const fontBoxCatalog:BoxItem[]=boxCatalog.filter(item=>item.kind==='font');
export const fontBoxRarities=boxRarities.filter(tier=>tier.id!=='common').map(tier=>({...tier,chance:tier.id==='rare'?45:tier.id==='epic'?35:tier.id==='mythic'?15:5}));

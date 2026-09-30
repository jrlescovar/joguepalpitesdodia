import { isPrivateCosmetic } from './privateCollection';
import { commonPassStyles, passStyleOptions } from './passStyleOptions';
import { usernameFonts, type UsernameFont } from './usernameFonts';
import type { BoxItem, BoxRarity, PassNameStyle } from './types';

const epic = new Set<PassNameStyle>(['midnight-electric','graphite-silver','wine-rose','neon-circuit','sunset-ocean','rare-plum-beige','halloween-pumpkin']);
export const boxRarities: {id:BoxRarity;label:string;chance:number;duplicateXp:number}[] = [
  {id:'common',label:'Comum',chance:40,duplicateXp:25},
  {id:'rare',label:'Raro',chance:30,duplicateXp:50},
  {id:'epic',label:'Épico',chance:15,duplicateXp:100},
  {id:'mythic',label:'Mítico',chance:10,duplicateXp:250},
  {id:'legendary',label:'Lendário',chance:5,duplicateXp:500},
];
export function boxRarity(style:PassNameStyle):BoxRarity {
  if(style==='halloween-mist'||style==='halloween-bloodmoon')return 'mythic';
  if(style==='gold'||style==='rainbow'||style.startsWith('legend-'))return 'legendary';
  if(style.startsWith('myth-'))return 'mythic';
  if(epic.has(style))return 'epic';
  return commonPassStyles.has(style)?'common':'rare';
}
export function fontRarity(font:UsernameFont):BoxRarity|null {const rarities:Partial<Record<UsernameFont,BoxRarity>>={"quantico":"rare","blackopsone":"rare","audiowide":"rare","bebasneue":"epic","orbitron":"epic","luckiestguy":"epic","creepster":"epic","eater":"legendary","butcherman":"mythic","metalmania":"epic","frijole":"mythic","rye":"mythic","amaticsc":"mythic","kalam":"mythic","permanentmarker":"mythic","specialelite":"mythic","monocraft":"legendary","dancingscript":"legendary"};return rarities[font]??null;}
export const halloweenStyles = ['halloween-pumpkin','halloween-bloodmoon','halloween-mist'] as const;
export const halloweenRarities=boxRarities.filter(tier=>['epic','mythic','legendary'].includes(tier.id)).map(tier=>({...tier,chance:tier.id==='epic'?60:tier.id==='mythic'?30:10}));
export const halloweenCatalog:BoxItem[]=[...halloweenStyles.flatMap(style=>(['name','frame'] as const).map(kind=>({kind,style,rarity:boxRarity(style)}))),{kind:'font',style:'creepster',rarity:'epic'},{kind:'font',style:'eater',rarity:'legendary'},{kind:'font',style:'butcherman',rarity:'mythic'}];
export const boxCatalog: BoxItem[] = [...passStyleOptions.filter(([style])=>style!=='none'&&!isPrivateCosmetic(style)&&!halloweenStyles.includes(style as typeof halloweenStyles[number])).flatMap(([style])=>(['name','frame'] as const).map(kind=>({kind,style,rarity:boxRarity(style)}))),...usernameFonts.filter(([font])=>fontRarity(font)!==null&&!['creepster','eater','butcherman'].includes(font)).map(([font])=>({kind:'font' as const,style:font as Exclude<UsernameFont,'normal'>,rarity:fontRarity(font)!}))];
export function boxStyleLabel(style:PassNameStyle|UsernameFont|string){return passStyleOptions.find(([id])=>id===style)?.[1]??usernameFonts.find(([id])=>id===style)?.[1]??style;}

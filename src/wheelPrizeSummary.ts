import type { WheelPrize } from './types';

export function wheelPrizeSummary(prizes:WheelPrize[]){
  const total=prizes.reduce((sum,prize)=>sum+prize.weight,0);
  const grouped=new Map<WheelPrize['kind'],{kind:WheelPrize['kind'];label:string;weight:number}>();
  for(const prize of prizes){
    const existing=grouped.get(prize.kind);
    if(existing)existing.weight+=prize.weight;
    else grouped.set(prize.kind,{kind:prize.kind,label:prize.label,weight:prize.weight});
  }
  return Array.from(grouped.values(),prize=>({...prize,chance:total>0?prize.weight/total*100:0}));
}

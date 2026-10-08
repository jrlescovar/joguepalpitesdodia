import type { WheelPrize } from './types';

export function wheelSegments(prizes:WheelPrize[]){
  const total=prizes.reduce((sum,prize)=>sum+prize.weight,0);
  // Stable server IDs also keep previous spin results on their original prize.
  const layout=[0,1,2,9,3,10,6,5,7,4,8];
  const ordered=prizes.length===layout.length&&layout.every(position=>prizes.some(prize=>prize.position===position))
    ?layout.map(position=>prizes.find(prize=>prize.position===position)!)
    :[...prizes];
  const supporter=ordered.findIndex(prize=>prize.kind==='supporter');
  if(supporter>=0&&ordered.filter(prize=>prize.kind==='empty').length===2){
    const neighbors=[(supporter+ordered.length-1)%ordered.length,(supporter+1)%ordered.length];
    for(const neighbor of neighbors){
      if(ordered[neighbor].kind!=='empty'){
        const empty=ordered.findIndex((prize,index)=>prize.kind==='empty'&&!neighbors.includes(index));
        if(empty>=0)[ordered[neighbor],ordered[empty]]=[ordered[empty],ordered[neighbor]];
      }
    }
  }
  let start=0;
  return ordered.map(prize=>{
    const end=start+(total>0?prize.weight/total*360:0);
    const segment={...prize,start,end,middle:(start+end)/2};
    start=end;
    return segment;
  });
}
export function wheelLandingAngle(prizes:WheelPrize[],position:number,kind?:WheelPrize['kind']){
  const segments=wheelSegments(prizes);
  const exact=segments.find(prize=>prize.position===position);
  // Earlier results keep their stored reward even if its sector was replaced.
  const segment=kind&&exact?.kind!==kind?segments.find(prize=>prize.kind===kind):exact;
  return segment?360-segment.middle:0;
}

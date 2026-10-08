import { boxLabels } from './boxThemes';
import type { BoxTheme, WheelReward } from './types';

export function wheelRewardBoxes(reward:WheelReward|null){
  return (Object.keys(boxLabels) as BoxTheme[]).flatMap(theme=>{
    const quantity=reward?.boxes[theme]??0;
    return quantity>0?[{theme,quantity,label:boxLabels[theme]}]:[];
  });
}

export function wheelRewardDestination(reward:WheelReward,selected?:BoxTheme):BoxTheme|'supporter'|null{
  if(reward.kind==='supporter'&&!reward.replacement)return 'supporter';
  const boxes=wheelRewardBoxes(reward);
  return boxes.find(box=>box.theme===selected)?.theme??boxes[0]?.theme??null;
}

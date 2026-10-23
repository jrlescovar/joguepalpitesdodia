import { boxLabels } from './boxThemes';
import type { WheelBoxTheme, WheelReward } from './types';

export function wheelRewardBoxes(reward:WheelReward|null){
  const labels:Record<WheelBoxTheme,string>={...boxLabels,legendary:'Caixa Lendária'};
  return (Object.keys(labels) as WheelBoxTheme[]).flatMap(theme=>{
    const quantity=reward?.boxes[theme]??0;
    return quantity>0?[{theme,quantity,label:labels[theme]}]:[];
  });
}

export function wheelRewardDestination(reward:WheelReward,selected?:WheelBoxTheme):WheelBoxTheme|'supporter'|null{
  if(reward.kind==='supporter'&&!reward.replacement)return 'supporter';
  const boxes=wheelRewardBoxes(reward);
  return boxes.find(box=>box.theme===selected)?.theme??boxes[0]?.theme??null;
}

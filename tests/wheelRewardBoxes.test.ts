import { describe, expect, it } from 'vitest';
import { wheelRewardBoxes, wheelRewardDestination } from '../src/wheelRewardBoxes';
import type { BoxTheme, WheelReward } from '../src/types';

function reward(kind:WheelReward['kind'],boxes:WheelReward['boxes'],replacement=false):WheelReward{
  return {kind,boxes,replacement,dayId:'2026-10-01',position:0,label:'Prêmio'};
}
describe('wheel reward destination',()=>{
  it.each(['classic','halloween','font','name','frame'] as BoxTheme[])('takes a %s prize to its own box',theme=>{
    const won=reward(theme,{[theme]:1});
    expect(wheelRewardBoxes(won)).toMatchObject([{theme,quantity:1}]);
    expect(wheelRewardDestination(won)).toBe(theme);
  });
  it('takes a new supporter pass to Apoiador and its replacement only to awarded boxes',()=>{
    expect(wheelRewardDestination(reward('supporter',{classic:7,font:1}))).toBe('supporter');
    const replacement=reward('supporter',{classic:3,name:0,frame:4},true);
    expect(wheelRewardBoxes(replacement).map(box=>box.theme)).toEqual(['classic','frame']);
    expect(wheelRewardDestination(replacement,'frame')).toBe('frame');
    expect(wheelRewardDestination(replacement,'halloween')).toBe('classic');
  });
  it('offers no box for an empty reward or absent result',()=>{
    expect(wheelRewardBoxes(null)).toEqual([]);
    expect(wheelRewardDestination(reward('empty',{}))).toBeNull();
  });
});

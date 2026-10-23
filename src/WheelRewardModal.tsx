import { useEffect, useRef, useState } from 'react';
import { Modal } from './components';
import WheelPrizeIcon from './WheelPrizeIcon';
import { wheelRewardBoxes, wheelRewardDestination } from './wheelRewardBoxes';
import type { WheelBoxTheme, WheelReward } from './types';

export default function WheelRewardModal({reward,onClose,onNavigate}:{reward:WheelReward|null;onClose:()=>void;onNavigate:(destination:WheelBoxTheme|'supporter')=>void}){
  const [selected,setSelected]=useState<WheelBoxTheme|null>(null);
  const navigating=useRef(false);
  useEffect(()=>setSelected(null),[reward]);
  const boxes=wheelRewardBoxes(reward);
  const chosen=boxes.find(box=>box.theme===selected)??boxes[0];
  const supporter=reward?.kind==='supporter'&&!reward.replacement;
  return <Modal className="wheel-reward-dialog" open={Boolean(reward)} onOpenChange={open=>{if(!open)onClose();}} title="Você ganhou!" onCloseAutoFocus={event=>{if(navigating.current){event.preventDefault();navigating.current=false;}}}>
    {reward&&<>
      <div className="wheel-reward-card">
        <div className="wheel-reward-art" aria-hidden="true"><WheelPrizeIcon kind={supporter?'supporter':chosen?.theme??reward.kind} size={150}/></div>
        <strong>{supporter?'Apoiador por 1 mês':reward.replacement?'7 caixas aleatórias':`${chosen?.quantity&&chosen.quantity>1?`${chosen.quantity} × `:''}${chosen?.label??reward.label}`}</strong>
        {supporter&&<p>Seu Apoiador está ativo, com medalha, XP em dobro, 7 caixas de personalização e 1 caixa de fontes.</p>}
      </div>
      {reward.replacement&&boxes.length>1&&<fieldset className="wheel-reward-options"><legend>Qual caixa você quer acessar?</legend>{boxes.map(box=><label key={box.theme} className={chosen?.theme===box.theme?'is-selected':''}><input type="radio" name="wheel-reward-box" value={box.theme} checked={chosen?.theme===box.theme} onChange={()=>setSelected(box.theme)}/><WheelPrizeIcon kind={box.theme} small/><span>{box.quantity} × {box.label}</span></label>)}</fieldset>}
      <button className="primary-button wheel-reward-claim" type="button" onClick={()=>{
        const destination=wheelRewardDestination(reward,chosen?.theme);
        navigating.current=Boolean(destination);
        onClose();
        if(destination)onNavigate(destination);
      }}>Resgatar já</button>
    </>}
  </Modal>;
}

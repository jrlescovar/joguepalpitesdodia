import {useEffect,useState,type MouseEvent} from 'react';
import {ChevronLeft,ChevronRight} from 'lucide-react';
import {BattleContent,formatBattleDate,type Battle} from './BattleContent';

export default function BattlePager({today,previous,instant=false,stackDesktop=true,onOpenProfile}:{today:Battle|null;previous:Battle|null;instant?:boolean;stackDesktop?:boolean;onOpenProfile?:(uid:string)=>void}) {
  const [page,setPage]=useState<'today'|'previous'>('today');
  const [motion,setMotion]=useState(true);
  const [desktop,setDesktop]=useState(()=>window.matchMedia('(min-width:1024px)').matches);
  useEffect(()=>{const query=window.matchMedia('(min-width:1024px)');const update=()=>setDesktop(query.matches);query.addEventListener('change',update);return()=>query.removeEventListener('change',update);},[]);
  const shown=previous?page:'today';
  const switchPage=(next:'today'|'previous',event:MouseEvent<HTMLButtonElement>)=>{
    setMotion(event.detail!==0);
    setPage(next);
  };
  if(!today||!previous){
    const battle=today??previous;
    return battle?<BattleContent key={battle.dayId+'-'+battle.opponent?.uid} battle={battle} instant={instant||Boolean(battle.historical)} onOpenProfile={onOpenProfile}/>:null;
  }
  if(desktop&&stackDesktop)return <div className="battle-desktop-history"><BattleContent key={today.dayId+'-'+today.opponent?.uid} battle={today} instant={instant} onOpenProfile={onOpenProfile}/><BattleContent key={previous.dayId+'-'+previous.opponent?.uid} battle={previous} instant onOpenProfile={onOpenProfile}/></div>;
  return <div className="daily-battle-view has-history" data-page={shown} data-motion={motion?'on':'off'}>
    <div className="battle-pager-window">
      <div className="battle-page battle-page-previous" aria-hidden={shown!=='previous'} inert={shown!=='previous'}><BattleContent key={previous.dayId+'-'+previous.opponent?.uid} battle={previous} instant onOpenProfile={onOpenProfile}/></div>
      <div className="battle-page battle-page-today" aria-hidden={shown!=='today'} inert={shown!=='today'}><BattleContent key={today.dayId+'-'+today.opponent?.uid} battle={today} instant={instant} onOpenProfile={onOpenProfile}/></div>
    </div>
    <nav className="battle-day-nav" aria-label="Dias do Confronto do Dia">
      <button type="button" aria-label={'Ver confronto de ontem, '+formatBattleDate(previous.dayId)} disabled={shown==='previous'} onClick={event=>switchPage('previous',event)}><ChevronLeft size={20} aria-hidden="true"/></button>
      <span aria-live="polite">{shown==='previous'?'1 / 2':'2 / 2'}</span>
      <button type="button" aria-label={'Ver confronto de hoje, '+formatBattleDate(today.dayId)} disabled={shown==='today'} onClick={event=>switchPage('today',event)}><ChevronRight size={20} aria-hidden="true"/></button>
    </nav>
  </div>;
}

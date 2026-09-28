import {useEffect,useState} from 'react';
import {ChevronLeft,ChevronRight} from 'lucide-react';
import {call,errorMessage} from './backend';
import {ErrorNotice} from './components';
import {BattleContent,formatBattleDate,type Battle} from './DailyBattle';

type ProfileBattles={today:Battle|null;previous:Battle|null};
export default function ProfileBattle({uid,refreshTick}:{uid:string;refreshTick:number}) {
  const [battles,setBattles]=useState<ProfileBattles|null>(null);
  const [page,setPage]=useState<'today'|'previous'>('today');
  const [error,setError]=useState('');
  const [retry,setRetry]=useState(0);
  useEffect(()=>{
    let active=true;let timer:number|undefined;
    const load=async()=>{
      try {
        const value=await call<ProfileBattles>('getProfileDailyBattles',{uid});
        if(!active)return;
        setBattles(value);setError('');
        if(value.today?.result==='open')timer=window.setTimeout(()=>{if(document.visibilityState==='visible')void load();},30000);
      }catch(cause){if(active)setError(errorMessage(cause));}
    };
    void load();
    return()=>{active=false;if(timer!==undefined)clearTimeout(timer);};
  },[uid,refreshTick,retry]);
  if(error)return <ErrorNotice message={'Batalha do Dia: '+error} retry={()=>setRetry(value=>value+1)}/>;
  const shown=page==='previous'?battles?.previous??battles?.today:battles?.today??battles?.previous;
  if(!shown)return null;
  const hasHistory=Boolean(battles?.today&&battles?.previous);
  return <div className={'daily-battle-view'+(hasHistory?' has-history':'')}>
    <BattleContent key={shown.dayId+'-'+shown.me?.uid} battle={shown} instant/>
    {hasHistory&&<nav className="battle-day-nav" aria-label="Dias da Batalha do Dia">
      <button type="button" aria-label={'Ver batalha de ontem, '+formatBattleDate(battles!.previous!.dayId)} disabled={page==='previous'} onClick={()=>setPage('previous')}><ChevronLeft size={20} aria-hidden="true"/></button>
      <span aria-live="polite">{page==='previous'?'1 / 2':'2 / 2'}</span>
      <button type="button" aria-label={'Ver batalha de hoje, '+formatBattleDate(battles!.today!.dayId)} disabled={page==='today'} onClick={()=>setPage('today')}><ChevronRight size={20} aria-hidden="true"/></button>
    </nav>}
  </div>;
}

import {useEffect,useState} from 'react';
import {call,errorMessage} from './backend';
import {ErrorNotice} from './components';
import type {Battle} from './BattleContent';
import BattlePager from './BattlePager';

type ProfileBattles={today:Battle|null;previous:Battle|null};
export default function ProfileBattle({uid,refreshTick,onOpenProfile}:{uid:string;refreshTick:number;onOpenProfile?:(uid:string)=>void}) {
  const [battles,setBattles]=useState<ProfileBattles|null>(null);
  const [error,setError]=useState('');
  const [retry,setRetry]=useState(0);
  useEffect(()=>{
    let active=true;let inFlight=false;let shouldPoll=true;
    const load=async()=>{
      if(inFlight)return;
      inFlight=true;
      try {
        const value=await call<ProfileBattles>('getProfileDailyBattles',{uid});
        if(!active)return;
        setBattles(value);setError('');
        shouldPoll=!value.today||value.today.result==='open'||value.previous?.result==='open';
      }catch(cause){if(active){setError(errorMessage(cause));shouldPoll=true;}}
      finally{inFlight=false;}
    };
    const onVisible=()=>{if(document.visibilityState==='visible')void load();};
    const timer=window.setInterval(()=>{if(shouldPoll&&document.visibilityState==='visible')void load();},30000);
    document.addEventListener('visibilitychange',onVisible);
    void load();
    return()=>{active=false;clearInterval(timer);document.removeEventListener('visibilitychange',onVisible);};
  },[uid,refreshTick,retry]);
  if(error)return <ErrorNotice message={'Confronto do Dia: '+error} retry={()=>setRetry(value=>value+1)}/>;
  if(!battles?.today&&!battles?.previous)return null;
  return <BattlePager key={battles.today?.dayId??battles.previous!.dayId} today={battles.today} previous={battles.previous} instant onOpenProfile={onOpenProfile}/>;
}

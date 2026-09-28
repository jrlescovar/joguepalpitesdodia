import {useEffect,useState} from 'react';
import {call,errorMessage} from './backend';
import {ErrorNotice} from './components';
import type {Battle} from './BattleContent';
import BattlePager from './BattlePager';

type ProfileBattles={today:Battle|null;previous:Battle|null};
export default function ProfileBattle({uid,refreshTick}:{uid:string;refreshTick:number}) {
  const [battles,setBattles]=useState<ProfileBattles|null>(null);
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
  if(!battles?.today&&!battles?.previous)return null;
  return <BattlePager key={battles.today?.dayId??battles.previous!.dayId} today={battles.today} previous={battles.previous} instant/>;
}

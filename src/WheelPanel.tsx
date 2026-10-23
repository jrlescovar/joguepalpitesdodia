import { useCallback, useEffect, useRef, useState } from 'react';
import { CircleHelp, Gift, LoaderCircle, LockKeyhole, RotateCw } from 'lucide-react';
import { call, errorMessage } from './backend';
import { ErrorNotice, Modal } from './components';
import { wheelLandingAngle } from './wheelGeometry';
import { wheelPrizeSummary } from './wheelPrizeSummary';
import { animateWheel, setWheelAngle } from './wheelMotion';
import WheelPrizeIcon from './WheelPrizeIcon';
import WheelRewardModal from './WheelRewardModal';
import WheelArt from './WheelArt';
import type { WheelBoxTheme, WheelReward, WheelState } from './types';
import './wheel.css';

const pendingKey=(profileId:string)=>`apostadodia:daily-wheel:${profileId}`;

export default function WheelPanel({profileId,refreshTick,onChanged,onOpenReward}:{profileId:string;refreshTick:number;onChanged:()=>void;onOpenReward:(destination:WheelBoxTheme|'supporter')=>void}){
  const [state,setState]=useState<WheelState|null>(null);
  const [error,setError]=useState('');
  const [retry,setRetry]=useState(0);
  const [busy,setBusy]=useState(false);
  const [animating,setAnimating]=useState(false);
  const [help,setHelp]=useState(false);
  const [reward,setReward]=useState<WheelReward|null>(null);
  const [revealedReward,setRevealedReward]=useState<WheelReward|null>(null);
  const [pending,setPending]=useState(()=>Boolean(sessionStorage.getItem(pendingKey(profileId))));
  const disc=useRef<HTMLDivElement>(null);
  const animation=useRef<ReturnType<typeof animateWheel>|null>(null);
  const mounted=useRef(true);
  const inFlight=useRef(false);
  const loadVersion=useRef(0);
  const receivedAt=useRef(Date.now());
  const updateRef=useRef(onChanged);
  updateRef.current=onChanged;
  const load=useCallback(async()=>{
    const version=++loadVersion.current;
    const next=await call<WheelState>('getDailyWheelState');
    if(mounted.current&&version===loadVersion.current){receivedAt.current=Date.now();setState(next);setError('');}
    return next;
  },[]);

  useEffect(()=>{
    mounted.current=true;
    return()=>{mounted.current=false;animation.current?.cancel();};
  },[]);
  useEffect(()=>{
    let active=true;
    const version=++loadVersion.current;
    void call<WheelState>('getDailyWheelState').then(next=>{
      if(!active||version!==loadVersion.current)return;
      receivedAt.current=Date.now();
      setState(next);setError('');
      if(next.used&&!next.unlimited){sessionStorage.removeItem(pendingKey(profileId));setPending(false);}
    }).catch(cause=>{if(active&&version===loadVersion.current)setError(errorMessage(cause));});
    return()=>{active=false;};
  },[profileId,refreshTick,retry]);
  useEffect(()=>{
    if(!state)return;
    // Server-relative delay avoids client clock errors at Brasília midnight.
    const delay=Math.max(1000,Date.parse(state.resetsAt)-state.serverTime-(Date.now()-receivedAt.current)+250);
    const timer=window.setTimeout(()=>{setReward(null);void load().catch(cause=>setError(errorMessage(cause)));},Math.min(delay,2147483647));
    return()=>window.clearTimeout(timer);
  },[state,load]);
  useEffect(()=>{
    if(!disc.current||animating)return;
    const result=reward??state?.result;
    setWheelAngle(disc.current,result&&state?wheelLandingAngle(state.prizes,result.position,result.kind):0);
  },[state,reward,animating]);
  useEffect(()=>{
    if(!animating)return;
    const finish=()=>{animation.current?.finish();setAnimating(false);};
    const media=window.matchMedia('(prefers-reduced-motion: reduce)');
    const onReduced=()=>{if(media.matches)finish();};
    document.addEventListener('visibilitychange',finish);
    media.addEventListener('change',onReduced);
    return()=>{document.removeEventListener('visibilitychange',finish);media.removeEventListener('change',onReduced);};
  },[animating]);

  async function spin(){
    if(inFlight.current||!state||spinDisabled)return;
    inFlight.current=true;setBusy(true);setError('');setRevealedReward(null);
    const requestId=sessionStorage.getItem(pendingKey(profileId))??crypto.randomUUID();
    sessionStorage.setItem(pendingKey(profileId),requestId);setPending(true);
    try{
      const result=await call<WheelReward>('spinDailyWheel',{requestId});
      sessionStorage.removeItem(pendingKey(profileId));
      ++loadVersion.current;
      updateRef.current();
      if(!mounted.current)return;
      setPending(false);setReward(result);
      setState(current=>current?{...current,used:!current.unlimited&&result.dayId===current.dayId,result:result.dayId===current.dayId?result:current.result}:current);
      const end=wheelLandingAngle(state.prizes,result.position,result.kind);
      const reduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches;
      if(disc.current?.animate&&!reduced&&!document.hidden){
        animation.current?.cancel();
        const previous=reward??state.result;
        const start=wheelLandingAngle(state.prizes,previous?.position??-1,previous?.kind);
        let target=end+360*5;
        if(target<start+360*5)target+=360;
        setAnimating(true);
        const group=animateWheel(disc.current,start,target);
        animation.current=group;
        group.motion.onfinish=()=>{
          if(mounted.current){setWheelAngle(disc.current!,end);setAnimating(false);setRevealedReward(result.kind==='empty'?null:result);}
          group.cancel();
          if(animation.current===group)animation.current=null;
        };
      }else setRevealedReward(result.kind==='empty'?null:result);
    }catch(cause){if(mounted.current)setError(errorMessage(cause));}
    finally{inFlight.current=false;if(mounted.current)setBusy(false);}
  }

  const spinning=busy||animating;
  const unlocked=state?.unlimited||(state?.eligible&&!state.used);
  const spinDisabled=spinning||!state||(!state.unlimited&&state.used)||(!pending&&!unlocked);
  const remaining=state?.remaining??0;
  const prizeSummary=wheelPrizeSummary(state?.prizes??[]);
  return <><section className="card wheel-panel" aria-labelledby="daily-wheel-title">
    <header className="wheel-heading"><div><span className="wheel-eyebrow"><Gift size={15}/> SEU BÔNUS DIÁRIO</span><h2 id="daily-wheel-title">Roleta da Sorte<span>.</span></h2></div><button className="icon-button" type="button" aria-label="Como funciona a Roleta da Sorte" onClick={()=>setHelp(true)}><CircleHelp size={20}/></button></header>
    <div className="wheel-layout">
      <WheelArt prizes={state?.prizes??[]} ref={disc}/>
      <div className="wheel-controls">
        {(!state?.used||state.unlimited)&&<span className={`wheel-status ${unlocked?'wheel-status-ready':''}`}>{unlocked?<><Gift size={16}/> Seu giro está liberado!</>:<><LockKeyhole size={16}/> Complete seus palpites</>}</span>}
        {(!state||(!state.used&&!unlocked))&&<p>{!state?'Carregando seu giro…':remaining>0?`Falta${remaining===1?'':'m'} ${remaining} palpite${remaining===1?'':'s'} aberto${remaining===1?'':'s'} para liberar seu giro grátis.`:'Faça os palpites do dia para liberar um giro grátis.'}</p>}
        <button type="button" className="primary-button wheel-spin-button" disabled={spinDisabled} onClick={()=>void spin()}>{spinning?<LoaderCircle size={19} className="spin"/>:pending?<RotateCw size={19}/>:unlocked?<Gift size={19}/>:<LockKeyhole size={19}/>} {busy?'Preparando giro…':animating?'Girando…':pending?'Retomar meu giro':state?.used?'Volte amanhã':'Girar grátis'}</button>
        {!state?.unlimited&&<small className="wheel-reset">1 giro por dia · Renova às 00:00 de Brasília</small>}
        {error&&<ErrorNotice message={error} retry={()=>setRetry(value=>value+1)}/>}
      </div>
    </div>
    <Modal open={help} onOpenChange={setHelp} title="Seu giro diário"><div className="wheel-help"><p>Faça todos os palpites que estiverem abertos hoje para liberar um giro grátis. Quem já completou os palpites de hoje também pode girar.</p><p>O giro renova às 00:00 de Brasília e não acumula. Depois de liberado, continua disponível até o fim do dia.</p><p>Ao ganhar, ela fica disponível em Minhas caixas, pronta para abrir. Ela garante um item lendário; itens repetidos viram XP.</p><p>As caixas de cor de nome e moldura usam os mesmos itens e chances por raridade da caixa de personalização. Itens repetidos viram XP.</p>
      <section className="wheel-prizes" aria-labelledby="wheel-prizes-title"><h3 id="wheel-prizes-title">Prêmios e chances</h3>{state?<ol>{prizeSummary.map(prize=><li key={prize.kind}><WheelPrizeIcon kind={prize.kind} small/><span>{prize.label}</span><b>{prize.chance.toLocaleString('pt-BR',{maximumFractionDigits:3})}%</b></li>)}</ol>:<p>Carregando prêmios…</p>}</section>
    </div></Modal>
  </section><WheelRewardModal reward={revealedReward} onClose={()=>setRevealedReward(null)} onNavigate={onOpenReward}/></>;
}

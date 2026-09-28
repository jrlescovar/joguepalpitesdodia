import { useEffect, useRef, useState } from 'react';
import { Box, CircleHelp, Gift, LoaderCircle, Sparkles, Zap } from 'lucide-react';
import { call, errorMessage } from './backend';
import { Avatar, ErrorNotice, Modal } from './components';
import { boxCatalog, boxRarities, boxStyleLabel } from './boxCatalog';
import type { BoxItem, BoxOpening, BoxState, PassStatus, Profile } from './types';
import './box.css';

const pendingKey=(uid:string)=>`apostadodia:box-opening:${uid}`;

function PrizePreview({item,profile}:{item:BoxItem;profile:Profile}){
  return item.kind==='frame'
    ? <Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.useGoogleAvatar===false?null:profile.avatarUrl} borderStyle={item.style} large/>
    : <strong className={`box-name-preview pass-name-${item.style}`}>@{profile.username}</strong>;
}

function BoxArt({opening=false}:{opening?:boolean}){
  return <div className={`box-art${opening?' box-art-opening':''}`} aria-hidden="true"><span className="box-art-glow"/><span className="box-art-lid"/><span className="box-art-body"><Gift size={62} strokeWidth={1.5}/></span></div>;
}

export default function BoxPanel({profile,onChanged,refreshTick=0}:{profile:Profile;onChanged:()=>void;refreshTick?:number}){
  const [state,setState]=useState<BoxState|null>(null);
  const [opening,setOpening]=useState<BoxOpening|null>(null);
  const [helpOpen,setHelpOpen]=useState(false);
  const [strip,setStrip]=useState<BoxItem[]>([]);
  const [phase,setPhase]=useState<'box'|'reel'|'result'>('result');
  const [dotCount,setDotCount]=useState(1);
  const [busy,setBusy]=useState(false);
  const [equipBusy,setEquipBusy]=useState(false);
  const [error,setError]=useState('');
  const [pending,setPending]=useState(()=>Boolean(sessionStorage.getItem(pendingKey(profile.uid))));
  const trackRef=useRef<HTMLDivElement>(null);
  const animationRef=useRef<Animation|null>(null);

  useEffect(()=>{let active=true;call<BoxState>('getBoxState').then(value=>{if(active)setState(value);}).catch(cause=>{if(active)setError(errorMessage(cause));});return()=>{active=false;};},[profile.uid,refreshTick]);
  useEffect(()=>{
    if(new URLSearchParams(location.search).get('boxes')!=='paid')return;
    let active=true;
    let attempts=0;
    const timer=window.setInterval(()=>{
      attempts+=1;
      void call<BoxState>('getBoxState').then(value=>{if(active)setState(value);}).catch(()=>{});
      if(attempts>=6)window.clearInterval(timer);
    },5000);
    return()=>{active=false;window.clearInterval(timer);};
  },[profile.uid]);
  useEffect(()=>()=>animationRef.current?.cancel(),[]);

  useEffect(()=>{
    if(!opening||phase==='result')return;
    const dots=window.setInterval(()=>setDotCount(current=>current===3?1:current+1),450);
    return()=>window.clearInterval(dots);
  },[opening,phase]);

  useEffect(()=>{
    if(!opening||phase==='result')return;
    if(document.hidden||window.matchMedia('(prefers-reduced-motion: reduce)').matches){setPhase('result');return;}
    const finish=()=>setPhase('result');
    document.addEventListener('visibilitychange',finish);
    if(phase==='box'){
      const timer=window.setTimeout(()=>setPhase('reel'),500);
      return()=>{window.clearTimeout(timer);document.removeEventListener('visibilitychange',finish);};
    }
    if(!trackRef.current){setPhase('result');document.removeEventListener('visibilitychange',finish);return;}
    const track=trackRef.current;
    const card=track.firstElementChild?.getBoundingClientRect();
    if(!card||typeof track.animate!=='function'){
      setPhase('result');
      document.removeEventListener('visibilitychange',finish);
      return;
    }
    const prizeIndex=strip.length-3;
    const distance=prizeIndex*(card.width+10);
    const animation=track.animate([
      {transform:'translateX(0px)'},
      {transform:`translateX(${-distance}px)`},
    ],{
      duration:4400,easing:'cubic-bezier(0.23, 1, 0.32, 1)',fill:'forwards',
    });
    animationRef.current=animation;
    animation.onfinish=finish;
    return()=>{document.removeEventListener('visibilitychange',finish);animation.onfinish=null;animation.cancel();if(animationRef.current===animation)animationRef.current=null;};
  },[opening,phase,strip]);

  async function openBox(){
    const key=pendingKey(profile.uid);
    const requestId=sessionStorage.getItem(key)||crypto.randomUUID();
    sessionStorage.setItem(key,requestId);
    setBusy(true);setError('');
    try{
      const result=await call<BoxOpening>('openBox',{requestId});
      sessionStorage.removeItem(key);setPending(false);
      setState(current=>({balance:result.balance,inventory:result.duplicate?current?.inventory??[]:[...(current?.inventory??[]),{kind:result.kind,style:result.style,rarity:result.rarity}]}));
      const candidates=boxCatalog;
      const visualDraws=crypto.getRandomValues(new Uint32Array(26));
      const reel=Array.from(visualDraws.slice(0,23),(draw,index)=>({kind:index%2===0?'name':'frame',...candidates[draw%candidates.length]} as BoxItem));
      reel.push({kind:result.kind,style:result.style,rarity:result.rarity});
      reel.push(...Array.from(visualDraws.slice(23,25),(draw,index)=>({kind:index%2===0?'name':'frame',...candidates[draw%candidates.length]} as BoxItem)));
      if(result.rarity==='common'){
        const legendaryStyles=candidates.filter(item=>item.rarity==='legendary');
        const nearMiss=visualDraws[25]%3;
        if(nearMiss!==1)reel[22]={kind:reel[22].kind,...legendaryStyles[visualDraws[22]%legendaryStyles.length]};
        if(nearMiss!==0)reel[24]={kind:reel[24].kind,...legendaryStyles[visualDraws[24]%legendaryStyles.length]};
      }
      setStrip(reel);setDotCount(1);setOpening(result);setPhase('box');
      onChanged();
    }catch(cause){setPending(true);setError(errorMessage(cause));}finally{setBusy(false);}
  }

  async function equip(){
    if(!opening||opening.duplicate)return;
    setEquipBusy(true);setError('');
    try{
      const current=await call<PassStatus>('getPassStatus');
      await call('setPassStyles',{
        nameStyle:opening.kind==='name'?opening.style:current.nameStyle,
        borderStyle:opening.kind==='frame'?opening.style:current.borderStyle,
      });
      setOpening(null);onChanged();
    }catch(cause){setError(errorMessage(cause));}finally{setEquipBusy(false);}
  }

  function close(){animationRef.current?.cancel();setOpening(null);setPhase('result');}
  return <>
    {((state?.balance ?? 0) > 0 || pending) && <section className="card box-panel" aria-label="Caixa de estilos">
    <div className="box-panel-heading"><div className="box-topline"><h2>Caixa de estilos</h2><div className="box-topline-actions"><span className="box-balance"><Box size={16}/>{state===null?'…':state.balance} {state?.balance===1?'caixa':'caixas'}</span><button className="box-help-button" type="button" aria-label="Como funcionam as caixas" onClick={()=>setHelpOpen(true)}><CircleHelp size={21}/></button></div></div></div>
    <BoxArt/>
    <div className="box-panel-actions"><button className="primary-button" type="button" disabled={busy||(!pending&&(state?.balance??0)<1)} onClick={()=>void openBox()}>{busy?<LoaderCircle className="spin" size={18}/>:pending||(state?.balance??0)>0?<Sparkles size={18}/>:<Box size={18}/>} {busy?'Preparando abertura…':pending?'Retomar abertura':state===null?'Carregando…':state.balance>0?'Abrir caixa':'Indisponível'}</button></div>
    {error&&!opening&&<ErrorNotice message={error}/>}
    </section>}
    <Modal open={helpOpen} onOpenChange={setHelpOpen} title="Como funcionam as caixas"><div className="box-help-content"><p>Cada abertura entrega um item: nome colorido ou moldura de perfil. Se você já tiver o mesmo item, recebe XP.</p><div className="box-odds"><h3>Chances por raridade</h3><div>{boxRarities.map(tier=><span key={tier.id} className={`box-tier box-tier-${tier.id}`}><b>{tier.label}</b><strong>{tier.chance}%</strong><small>Repetido: +{tier.duplicateXp} XP</small></span>)}</div></div></div></Modal>
    <Modal open={Boolean(opening)} onOpenChange={value=>{if(!value)close();}} title={phase!=='result'?`Abrindo caixa${'.'.repeat(dotCount)}`:opening?.duplicate?'Item Repetido':'Novo estilo'}>
      {opening&&<div className="box-reveal">
        {phase==='box'?<div className="box-opening-stage"><BoxArt opening/></div>:phase==='reel'?<div className="box-reel-window"><div className="box-reel-marker"/><div className="box-reel-track" ref={trackRef}>{strip.map((item,index)=><div className={`box-reel-item box-tier-${item.rarity}`} key={index}><PrizePreview item={item} profile={profile}/><span>{boxStyleLabel(item.style)}</span>{item.kind==='frame'&&<small>Moldura</small>}</div>)}</div></div>:
          <><div className={`box-result box-tier-${opening.rarity}`}><span className="box-result-rarity">{boxRarities.find(tier=>tier.id===opening.rarity)?.label}</span><PrizePreview item={opening} profile={profile}/><strong>{boxStyleLabel(opening.style)}</strong><span>{opening.kind==='name'?'Cor de nome':'Moldura de perfil'}</span>{opening.duplicate&&<span className="box-xp-reward" role="status"><Zap size={18} aria-hidden="true"/> +{opening.xpAwarded} XP</span>}</div>
          {error&&<ErrorNotice message={error}/>}<div className="box-result-actions">{!opening.duplicate&&<button type="button" className="primary-button" disabled={equipBusy} onClick={()=>void equip()}>{equipBusy?<LoaderCircle className="spin" size={18}/>:<Sparkles size={18}/>} Equipar agora</button>}<button type="button" className="secondary-button" onClick={close} disabled={equipBusy}>Fechar</button></div></>}
      </div>}
    </Modal>
  </>;
}

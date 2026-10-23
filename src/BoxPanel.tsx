import UsernameText from './UsernameText';
import { useEffect, useRef, useState } from 'react';
import { Box, CircleHelp, LoaderCircle, Sparkles, Zap } from 'lucide-react';
import { call, errorMessage } from './backend';
import { Avatar, ErrorNotice, Modal } from './components';
import { boxRarities, boxStyleLabel } from './boxCatalog';
import { boxLabels, boxStateCalls, boxOpenCalls, catalogForBox } from './boxThemes';
import type { BoxItem, BoxOpening, BoxState, BoxTheme, PassStatus, Profile } from './types';
import './box.css';
import BoxHelp from './BoxHelp';
import ChestIcon from './ChestIcon';
import './halloween.css';

const pendingKey=(uid:string,theme:string)=>theme==='classic'?`apostadodia:box-opening:${uid}`:`apostadodia:box-opening:${theme}:${uid}`;

export function PrizePreview({item,profile}:{item:BoxItem;profile:Profile}){
  return item.kind==='frame'
    ? <Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.useGoogleAvatar===false?null:profile.avatarUrl} borderStyle={item.style} large/>
    : <strong className={`box-name-preview pass-name-${item.kind==='font'?(profile.passNameStyle??'none'):item.style}`}><UsernameText name={profile.username} font={item.kind==='font'?item.style:'normal'}/></strong>;
}

export function BoxArt({opening=false,theme='classic'}:{opening?:boolean;theme?:BoxTheme}){
  return <div className={`box-art box-art-${theme}${theme!=='classic'&&theme!=='halloween'?' box-art-classic':''}${opening?' box-art-opening':''}`} aria-hidden="true"><span className="box-art-glow"/><ChestIcon size={190} className="box-art-chest" opening={opening} theme={theme} halloween={theme==='halloween'} graffiti={theme==='font'}/></div>;
}

export default function BoxPanel({profile,onChanged,refreshTick=0,refreshAfterCheckout=false,theme='classic',navigateTo=false,onNavigated,onAvailabilityChange}:{profile:Profile;onChanged:()=>void;refreshTick?:number;refreshAfterCheckout?:boolean;theme?:BoxTheme;navigateTo?:boolean;onNavigated?:()=>void;onAvailabilityChange?:(theme:BoxTheme,available:boolean)=>void}){
  const themed=theme==='halloween';
  const catalog=catalogForBox(theme);
  const [loadRetry,setLoadRetry]=useState(0);
  const [loadError,setLoadError]=useState('');
  const [state,setState]=useState<BoxState|null>(null);
  const [opening,setOpening]=useState<BoxOpening|null>(null);
  const [helpOpen,setHelpOpen]=useState(false);
  const [strip,setStrip]=useState<BoxItem[]>([]);
  const [phase,setPhase]=useState<'box'|'reel'|'result'>('result');
  const [dotCount,setDotCount]=useState(1);
  const [busy,setBusy]=useState(false);
  const [equipBusy,setEquipBusy]=useState(false);
  const [error,setError]=useState('');
  const [pending,setPending]=useState(()=>Boolean(sessionStorage.getItem(pendingKey(profile.uid,theme))));
  const trackRef=useRef<HTMLDivElement>(null);
  const animationRef=useRef<Animation|null>(null);
  const panelRef=useRef<HTMLElement>(null);
  const requestInFlight=useRef(false);

  useEffect(()=>{
    if(state===null&&!pending&&!loadError)return;
    onAvailabilityChange?.(theme,(state?.balance??0)>0||pending||Boolean(opening)||busy||Boolean(loadError));
  },[state?.balance,pending,opening,busy,loadError,theme,onAvailabilityChange]);

  useEffect(()=>{
    if(!navigateTo||!state||state.balance<1||!panelRef.current)return;
    const frame=requestAnimationFrame(()=>{
      const panel=panelRef.current;
      if(!panel)return;
      panel.scrollIntoView({block:'center',behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});
      panel.querySelector<HTMLButtonElement>('.box-panel-actions .primary-button')?.focus({preventScroll:true});
      onNavigated?.();
    });
    return()=>cancelAnimationFrame(frame);
  },[navigateTo,state,onNavigated]);

  useEffect(()=>{let active=true;setLoadError('');call<BoxState>(boxStateCalls[theme]).then(value=>{if(active)setState(value);}).catch(cause=>{if(active)setLoadError(errorMessage(cause));});return()=>{active=false;};},[profile.uid,refreshTick,theme,loadRetry]);
  useEffect(()=>{
    if(!refreshAfterCheckout)return;
    let active=true;
    let attempts=0;
    const timer=window.setInterval(()=>{
      attempts+=1;
      void call<BoxState>(boxStateCalls[theme]).then(value=>{if(active)setState(value);}).catch(()=>{});
      if(attempts>=6)window.clearInterval(timer);
    },5000);
    return()=>{active=false;window.clearInterval(timer);};
  },[profile.uid,theme,refreshAfterCheckout]);
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
      // Let the lid finish its 500ms movement, then hold it open for 200ms.
      const timer=window.setTimeout(()=>setPhase('reel'),700);
      return()=>{window.clearTimeout(timer);document.removeEventListener('visibilitychange',finish);};
    }
    if(!trackRef.current){setPhase('result');document.removeEventListener('visibilitychange',finish);return;}
    const track=trackRef.current;
    const card=track.firstElementChild as HTMLElement|null;
    if(!card||typeof track.animate!=='function'){
      setPhase('result');
      document.removeEventListener('visibilitychange',finish);
      return;
    }
    const prizeIndex=strip.length-3;
    const distance=prizeIndex*(card.offsetWidth+10);
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
    if(requestInFlight.current||opening)return;
    requestInFlight.current=true;
    const key=pendingKey(profile.uid,theme);
    const requestId=sessionStorage.getItem(key)||crypto.randomUUID();
    sessionStorage.setItem(key,requestId);
    setBusy(true);setError('');
    let confirmed:BoxOpening|null=null;
    try{
      const result=await call<BoxOpening>(boxOpenCalls[theme],{requestId});
      confirmed=result;
      sessionStorage.removeItem(key);setPending(false);
      setState(current=>({balance:result.balance,inventory:result.duplicate?current?.inventory??[]:[...(current?.inventory??[]),result]}));
      const candidates=catalog;
      const visualDraws=crypto.getRandomValues(new Uint32Array(26));
      const reel=Array.from(visualDraws.slice(0,23),draw=>candidates[draw%candidates.length]);
      reel.push(result);
      reel.push(...Array.from(visualDraws.slice(23,25),draw=>candidates[draw%candidates.length]));
      if(!themed&&result.rarity==='common'){
        const legendaryStyles=candidates.filter(item=>item.rarity==='legendary');
        const nearMiss=visualDraws[25]%3;
        if(nearMiss!==1)reel[22]=legendaryStyles[visualDraws[22]%legendaryStyles.length];
        if(nearMiss!==0)reel[24]=legendaryStyles[visualDraws[24]%legendaryStyles.length];
      }
      setStrip(reel);setDotCount(1);setOpening(result);setPhase('box');
      onChanged();
    }catch(cause){
      if(confirmed){
        // A local presentation/refresh failure must never replay a confirmed purchase.
        setPending(false);setOpening(confirmed);setPhase('result');
      }else{setPending(true);setError(errorMessage(cause));}
    }finally{requestInFlight.current=false;setBusy(false);}
  }

  async function equip(){
    if(!opening||opening.duplicate)return;
    setEquipBusy(true);setError('');
    try{
      if(opening.kind==='font')await call('setUsernameFont',{font:opening.style});
      else {
      const current=await call<PassStatus>('getPassStatus');
      await call('setPassStyles',{
        nameStyle:opening.kind==='name'?opening.style:current.nameStyle,
        borderStyle:opening.kind==='frame'?opening.style:current.borderStyle,
      });
      }
      setOpening(null);onChanged();
    }catch(cause){setError(errorMessage(cause));}finally{setEquipBusy(false);}
  }

  function close(){if(phase!=='result'||equipBusy)return;animationRef.current?.cancel();setOpening(null);setPhase('result');}
  return <>
    {loadError&&<ErrorNotice message={loadError} retry={()=>setLoadRetry(value=>value+1)}/>}
    {state===null&&!loadError&&onAvailabilityChange&&<p className="muted" role="status">Carregando suas caixas…</p>}
    {((state?.balance ?? 0) > 0 || pending || Boolean(opening) || busy) && <section ref={panelRef} className={`card box-panel box-panel-${theme}`} aria-label={boxLabels[theme]}>
    <div className="box-panel-heading"><div className="box-topline"><h2>{boxLabels[theme]}</h2><div className="box-topline-actions"><span className="box-balance"><Box size={16}/>{state===null?'…':state.balance} {state?.balance===1?'caixa':'caixas'}</span><button className="box-help-button" type="button" aria-label="Como funcionam as caixas" onClick={()=>setHelpOpen(true)}><CircleHelp size={21}/></button></div></div></div>
    <BoxArt theme={theme}/>
    <div className="box-panel-actions"><button className="primary-button" type="button" disabled={busy||(!pending&&(state?.balance??0)<1)} onClick={()=>void openBox()}>{busy?<LoaderCircle className="spin" size={18}/>:pending||(state?.balance??0)>0?<Sparkles size={18}/>:<Box size={18}/>} {busy?'Preparando abertura…':pending?'Retomar abertura':state===null?'Carregando…':state.balance>0?'Abrir caixa':'Indisponível'}</button></div>
    {error&&!opening&&<ErrorNotice message={error}/>}
    </section>}
    <BoxHelp open={helpOpen} onOpenChange={setHelpOpen} theme={theme} profile={profile}/>
    <Modal className={`box-opening-dialog${busy||phase!=='result'?' box-opening-animation':''}`} open={busy||Boolean(opening)} dismissible={!busy&&phase==='result'&&!equipBusy} onOpenChange={value=>{if(!value)close();}} title={busy?'Preparando abertura…':phase!=='result'?`Abrindo caixa${'.'.repeat(dotCount)}`:opening?.duplicate?'Item Repetido':'Novo estilo'}>
      {busy&&!opening&&<div className="box-opening-stage" role="status"><BoxArt theme={theme}/></div>}
      {opening&&<div className="box-reveal">
        {phase==='box'?<div className="box-opening-stage"><BoxArt opening theme={theme}/></div>:phase==='reel'?<div className="box-reel-window"><div className="box-reel-marker"/><div className="box-reel-track" ref={trackRef}>{strip.map((item,index)=><div className={`box-reel-item box-tier-${item.rarity}${themed?' halloween-item':''}`} key={index}><PrizePreview item={item} profile={profile}/><span>{boxStyleLabel(item.style)}</span>{item.kind!=='name'&&<small>{item.kind==='font'?'Fonte':'Moldura'}</small>}</div>)}</div></div>:
          <><div className={`box-result box-tier-${opening.rarity}${themed?' halloween-item':''}`}><span className="box-result-rarity">{boxRarities.find(tier=>tier.id===opening.rarity)?.label}</span><PrizePreview item={opening} profile={profile}/><strong>{boxStyleLabel(opening.style)}</strong><span>{opening.kind==='name'?'Cor de nome':opening.kind==='font'?'Fonte do nome':'Moldura de perfil'}</span>{opening.duplicate&&<span className="box-xp-reward" role="status"><Zap size={18} aria-hidden="true"/> +{opening.xpAwarded} XP</span>}</div>
          {error&&<ErrorNotice message={error}/>}<div className="box-result-actions">{!opening.duplicate&&<button type="button" className="primary-button" disabled={equipBusy} onClick={()=>void equip()}>{equipBusy?<LoaderCircle className="spin" size={18}/>:<Sparkles size={18}/>} Equipar agora</button>}<button type="button" className="secondary-button" onClick={close} disabled={equipBusy}>Fechar</button></div></>}
      </div>}
    </Modal>
  </>;
}

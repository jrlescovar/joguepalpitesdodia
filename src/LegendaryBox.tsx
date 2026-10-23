import BoxHelp from './BoxHelp';
import {useEffect,useRef,useState} from 'react';
import {CircleHelp,Gift,Sparkles,Zap} from 'lucide-react';
import {call,errorMessage} from './backend';
import {Modal,ErrorNotice} from './components';
import {boxCatalog,boxRarities,boxStyleLabel} from './boxCatalog';
import {PrizePreview} from './BoxPanel';
import type {Profile,BoxOpening,BoxItem,PassStatus} from './types';
import './levelDrops.css';
import CustomizationBoxIcon from './CustomizationBoxIcon';
export type LevelDrop={id:string;milestone:number;drop_kind?:'normal'|'legendary';tier:number;clicks_left:number;status:'playing'|'ready'|'claimed';reward:BoxOpening|null;received_at:string|null};
type State={level:number;drops:LevelDrop[]};
function DropReveal({opening,profile,onClose,onChanged,direct=false}:{opening:BoxOpening|null;direct?:boolean;profile:Profile;onClose:()=>void;onChanged:()=>void}){
 const [phase,setPhase]=useState<'split'|'reel'|'result'>('split'),[strip,setStrip]=useState<BoxItem[]>([]);
 const [equipBusy,setEquipBusy]=useState(false),[equipError,setEquipError]=useState('');
 async function equip(){if(!opening||opening.duplicate)return;setEquipBusy(true);setEquipError('');try{if(opening.kind==='font')await call('setUsernameFont',{font:opening.style});else{const current=await call<PassStatus>('getPassStatus');await call('setPassStyles',{nameStyle:opening.kind==='name'?opening.style:current.nameStyle,borderStyle:opening.kind==='frame'?opening.style:current.borderStyle});}onClose();onChanged();}catch(e){setEquipError(errorMessage(e));}finally{setEquipBusy(false);}}
 const track=useRef<HTMLDivElement>(null);
 useEffect(()=>{if(!opening)return;const pool=boxCatalog.filter(i=>i.rarity===opening.rarity);const items=Array.from({length:26},()=>pool[Math.floor(Math.random()*pool.length)]||opening);items[23]=opening;setStrip(items);setPhase(window.matchMedia('(prefers-reduced-motion:reduce)').matches?'result':direct?'reel':'split');},[opening,direct]);
 useEffect(()=>{
  if(!opening||phase==='result')return;
  const finish=()=>setPhase('result');document.addEventListener('visibilitychange',finish);
  if(phase==='split'){const timer=setTimeout(()=>setPhase('reel'),800);return()=>{clearTimeout(timer);document.removeEventListener('visibilitychange',finish);};}
  let frame=0,attempts=0,animation:Animation|undefined;
  const start=()=>{const el=track.current,card=el?.firstElementChild as HTMLElement|null;
   // Dialog portals mount after the parent effect; wait for the actual reel DOM.
   if(!el||!card){if(++attempts<60)frame=requestAnimationFrame(start);else finish();return;}
   animation=el.animate([{transform:'translateX(0px)'},{transform:'translateX('+(-(strip.length-3)*(card.offsetWidth+10))+'px)'}],{duration:4400,easing:'cubic-bezier(0.23, 1, 0.32, 1)',fill:'forwards'});animation.onfinish=finish;
  };frame=requestAnimationFrame(start);
  return()=>{cancelAnimationFrame(frame);if(animation){animation.onfinish=null;animation.cancel();}document.removeEventListener('visibilitychange',finish);};
 },[opening,phase,strip]);
 return <Modal className={`box-opening-dialog${phase!=='result'?' box-opening-animation':''}${phase==='result'&&!opening?.duplicate?' drop-new-reward':''}`} open={!!opening} onOpenChange={value=>{if(!value)onClose();}} dismissible={phase==='result'&&!equipBusy} title={phase==='result'?(opening?.duplicate?'Item Repetido':'Novo estilo'):`Abrindo caixa ${boxRarities.find(r=>r.id===opening?.rarity)?.label??''}`}><div className="box-reveal">{opening&&(phase==='split'?<div className={`drop-split box-tier-${opening.rarity}`}><div className="drop-half drop-half-top"><CustomizationBoxIcon theme="legendary" size={240}/></div><div className="drop-half drop-half-bottom"><CustomizationBoxIcon theme="legendary" size={240}/></div></div>:phase==='reel'?<div className="box-reel-window"><div className="box-reel-marker"/><div className="box-reel-track" ref={track}>{strip.map((item,index)=><div className={`box-reel-item box-tier-${item.rarity}`} key={index}><PrizePreview item={item} profile={profile}/><span>{boxStyleLabel(item.style)}</span><small>{item.kind==='font'?'Fonte':item.kind==='frame'?'Moldura':'Cor de nome'}</small></div>)}</div></div>:<><div className={`box-result box-tier-${opening.rarity}`}><span className="box-result-rarity">{boxRarities.find(r=>r.id===opening.rarity)?.label}</span><PrizePreview item={opening} profile={profile}/><strong>{boxStyleLabel(opening.style)}</strong><span>{opening.kind==='name'?'Cor de nome':opening.kind==='frame'?'Moldura de perfil':'Fonte do nome'}</span>{opening.duplicate&&<span className="box-xp-reward" role="status"><Zap size={18}/> +{opening.xpAwarded} XP</span>}</div>{equipError&&<ErrorNotice message={equipError}/>}<div className="box-result-actions">{!opening.duplicate&&<button className="primary-button" disabled={equipBusy} onClick={()=>void equip()}><Sparkles size={18}/>Equipar agora</button>}<button className="secondary-button" disabled={equipBusy} onClick={onClose}>Fechar</button></div></>)}</div></Modal>;
}
export default function LegendaryBox({profile,onChanged,onAvailabilityChange,refreshTick=0}:{profile:Profile;onChanged:()=>void;onAvailabilityChange?:(available:boolean)=>void;refreshTick?:number}){
 const [state,setState]=useState<State|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState(''),[opening,setOpening]=useState<BoxOpening|null>(null),[retry,setRetry]=useState(0),[help,setHelp]=useState(false);
 const inFlight=useRef(false);
 useEffect(()=>{let alive=true;setError('');call<State>('getLevelDrops').then(s=>{if(alive)setState(s);}).catch(e=>{if(alive)setError(errorMessage(e));});return()=>{alive=false;};},[profile.uid,retry,refreshTick]);
 const available=state?.drops.filter(d=>d.drop_kind==='legendary'&&d.status!=='claimed'&&!!d.received_at)??[];
 useEffect(()=>{if(state)onAvailabilityChange?.(available.length>0||!!opening);},[state,available.length,opening,onAvailabilityChange]);
 async function openBox(){const box=available[0];if(!box||inFlight.current)return;inFlight.current=true;setBusy(true);setError('');try{const next=await call<LevelDrop>('interactLevelDrop',{dropId:box.id,requestId:crypto.randomUUID(),open:true});if(next.reward){setOpening(next.reward);setState(s=>s?{...s,drops:s.drops.map(d=>d.id===next.id?next:d)}:s);onChanged();}}catch(e){setError(errorMessage(e));}finally{inFlight.current=false;setBusy(false);}}
 return <section className="card box-panel legendary-level-drop legendary-box-panel" aria-label="Caixa Lendária"><div className="box-panel-heading"><div className="box-topline"><h2>Caixa Lendária</h2><div className="box-topline-actions"><span className="box-balance"><Gift size={16}/>{state?available.length:'…'} {available.length===1?'caixa':'caixas'}</span><button className="box-help-button" aria-label="Como funciona a Caixa Lendária" onClick={()=>setHelp(true)}><CircleHelp size={21}/></button></div></div></div><div className="legendary-box-art"><CustomizationBoxIcon theme="legendary" size={190}/></div><div className="box-panel-actions"><button className="primary-button" disabled={!available.length||busy||!!opening} onClick={()=>void openBox()}><Sparkles size={18}/>{busy?'Abrindo…':'Abrir caixa'}</button></div>{!state&&!error&&<p role="status">Carregando caixas…</p>}{error&&<ErrorNotice message={error} retry={()=>setRetry(v=>v+1)}/>}<BoxHelp open={help} onOpenChange={setHelp} profile={profile} legendary/><DropReveal direct opening={opening} profile={profile} onChanged={onChanged} onClose={()=>{setOpening(null);setRetry(v=>v+1);}}/></section>;
}

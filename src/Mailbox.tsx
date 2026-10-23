import ChestIcon from './ChestIcon';
import {useEffect,useRef,useState} from 'react';
import {Mail,LoaderCircle,Crown} from 'lucide-react';
import {call,errorMessage} from './backend';
import {Avatar,Modal,ErrorNotice} from './components';
import CustomizationBoxIcon from './CustomizationBoxIcon';
import './levelDrops.css';
import type {Profile,PassNameStyle} from './types';
import {boxStyleLabel} from './boxCatalog';
type BoxDeliveryKind='legendary_drop'|'classic'|'font'|'halloween'|'premium';
type Delivery={kind:BoxDeliveryKind|`frame:${PassNameStyle}`;quantity:number};
export function mailFrameStyle(kind:Delivery['kind']):PassNameStyle|null{return kind.startsWith('frame:')?kind.slice(6) as PassNameStyle:null;}
const names={legendary_drop:'Caixa Lendária',classic:'Caixa de Personalização',font:'Caixa de Fontes',halloween:'Caixa de Halloween',premium:'Premium'};
export default function Mailbox({profile,refreshTick,onReceived}:{profile:Profile;refreshTick:number;onReceived:(kind:Delivery['kind'])=>void}){
 const [open,setOpen]=useState(false),[items,setItems]=useState<Delivery[]>([]),[error,setError]=useState(''),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[retry,setRetry]=useState(0);
 const receiving=useRef(false),refreshVersion=useRef(0);
 useEffect(()=>{
  let alive=true,inFlight=false;
  async function refresh(showLoading=false){
   if(!alive||inFlight||receiving.current)return;
   inFlight=true;const version=refreshVersion.current;
   if(showLoading){setLoading(true);setError('');}
   try{const deliveries=await call<Delivery[]>('getMailbox');if(alive&&version===refreshVersion.current){setItems(deliveries);if(showLoading)setError('');}}
   catch(e){if(alive&&version===refreshVersion.current&&showLoading)setError(errorMessage(e));}
   finally{inFlight=false;if(alive&&version===refreshVersion.current)setLoading(false);}
  }
  const refreshVisible=()=>{if(document.visibilityState==='visible')void refresh();};
  void refresh(true);
  const timer=window.setInterval(refreshVisible,5000);
  document.addEventListener('visibilitychange',refreshVisible);
  window.addEventListener('focus',refreshVisible);
  window.addEventListener('pageshow',refreshVisible);
  return()=>{alive=false;clearInterval(timer);document.removeEventListener('visibilitychange',refreshVisible);window.removeEventListener('focus',refreshVisible);window.removeEventListener('pageshow',refreshVisible);};
 },[profile.uid,profile.level,refreshTick,retry,open]);
 async function receive(kind:Delivery['kind']){if(receiving.current)return;receiving.current=true;refreshVersion.current++;setBusy(true);setError('');try{await call('receiveMail',{kind});setItems(ds=>ds.filter(d=>d.kind!==kind));setOpen(false);onReceived(kind);}catch(e){setError(errorMessage(e));}finally{receiving.current=false;setBusy(false);}}
 return <><button className="icon-button mailbox-button" aria-label={`Correio${items.length?' · recompensas pendentes':''}`} onClick={()=>setOpen(true)}><Mail size={20}/>{items.length>0&&<i className="mailbox-dot lit" aria-hidden="true"/>}</button><Modal open={open} onOpenChange={value=>{if(!busy)setOpen(value);}} dismissible={!busy} title="Correio"><div className="mailbox-content">{loading&&<p role="status">Carregando…</p>}{error&&<ErrorNotice message={error} retry={()=>setRetry(v=>v+1)}/>} {!loading&&!error&&!items.length&&<p>Você está em dia. Nenhuma recompensa para resgatar.</p>}{items.map(d=><article className={`mailbox-message mail-delivery mail-delivery-${mailFrameStyle(d.kind)?'frame':d.kind}`} key={d.kind}><div className="mail-delivery-art">{mailFrameStyle(d.kind)?<Avatar name={profile.username} color={profile.avatarColor} imageUrl={profile.avatarUrl} borderStyle={mailFrameStyle(d.kind)!}/>:d.kind==='legendary_drop'?<CustomizationBoxIcon theme="legendary" size={60}/>:d.kind==='premium'?<Crown size={48}/>:<ChestIcon size={60} halloween={d.kind==='halloween'} graffiti={d.kind==='font'}/>}</div><div className="mail-delivery-copy"><h3>{mailFrameStyle(d.kind)?`Moldura ${boxStyleLabel(mailFrameStyle(d.kind)!)}`:names[d.kind as BoxDeliveryKind]}</h3><span className="mail-delivery-count">{d.kind==='premium'?`${d.quantity} ${d.quantity===1?'dia':'dias'}`:`×${d.quantity}`}</span></div><button className="primary-button mail-delivery-receive" disabled={busy||loading} onClick={()=>void receive(d.kind)}>{busy?<LoaderCircle size={16} className="spin"/>:null}Receber</button></article>)}</div></Modal></>;
}

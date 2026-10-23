import { useEffect, useRef, useState } from 'react';
import { Zap, Crown, LoaderCircle } from 'lucide-react';
import { call, errorMessage, passRedirect } from './backend';
import { ErrorNotice } from './components';
import type { PassStatus, Profile } from './types';
import './supporter.css';
import SupporterEmblem from './SupporterEmblem';
import ChestIcon from './ChestIcon';
import EmeraldIcon from './EmeraldIcon';

export default function SupporterPanel({ profile, refreshTick, onChanged }: { profile: Profile; refreshTick: number; onChanged: () => void }) {
  const [pass, setPass] = useState<PassStatus | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const requestId=useRef<string|null>(null),submitting=useRef(false);
  const [retry,setRetry]=useState(0);
  useEffect(() => {
    const reset = (event:PageTransitionEvent) => {submitting.current=false;requestId.current=null;setBusy(false);if(event.persisted)setRetry(value=>value+1);};
    window.addEventListener('pageshow', reset);
    return () => window.removeEventListener('pageshow', reset);
  }, []);
  useEffect(() => {
    let current = true;setError('');
    call<PassStatus>('getPassStatus').then(status => {
      if (current) { setPass(status); }
    }).catch(cause => { if (current) setError(errorMessage(cause)); });
    return () => { current = false; };
  }, [profile.uid, refreshTick,retry]);
  async function buy() {
    if(submitting.current)return;
    submitting.current=true;setBusy(true);setError('');
    requestId.current??=crypto.randomUUID();
    try { await passRedirect('infinitepay-checkout',{kind:'supporter',quantity:1,requestId:requestId.current}); }
    catch(cause){setError(errorMessage(cause));submitting.current=false;setBusy(false);}
  }
  const prepaidActive=Boolean(pass?.prepaidActive&&pass.prepaidEndsAt&&Date.parse(pass.prepaidEndsAt)>Date.now());
  const endsAt=[pass?.periodEndsAt,pass?.prepaidEndsAt,pass?.freeEndsAt].filter((value):value is string=>Boolean(value)).sort((a,b)=>Date.parse(b)-Date.parse(a))[0];
  const date=endsAt?new Date(endsAt).toLocaleDateString('pt-BR',{timeZone:'America/Sao_Paulo'}):null;
  return <section className="card pass-panel" aria-label="Seja um Apoiador">
    <div className="pass-offer-copy">
      <div className="pass-heading"><SupporterEmblem/><div><span className="pass-offer-eyebrow">SEJA UM APOIADOR</span><h2>Evolua mais rápido. Jogue com seu estilo.</h2></div></div>
      <ul className="pass-offer-benefits">
        <li><Zap size={23} aria-hidden="true"/><div><strong>XP em dobro</strong><span>Em todos os ganhos.</span></div></li>
        <li><ChestIcon size={28}/><div><strong>7 caixas de personalização</strong><span>Em cada compra de 30 dias.</span></div></li>
        <li><ChestIcon size={28} graffiti/><div><strong>1 Caixa de Fontes</strong><span>Em cada compra de 30 dias.</span></div></li>
        <li><EmeraldIcon size={28}/><div><strong>1.000 moedas</strong><span>Em cada compra de 30 dias.</span></div></li>
        <li><SupporterEmblem/><div><strong>Emblema de apoiador</strong><span>Seu apoio em destaque no perfil.</span></div></li>
      </ul>
    </div>
    <div className="pass-offer-purchase">
      <p className="pass-offer-price">R$ 7,77<span>por 30 dias</span></p>
    {pass?.active ? <p className={`pass-current${!prepaidActive?' pass-current-free':''}`} role="status">{date?`Termina em ${date}`:'Apoiador ativo'}</p> : pass ? <button type="button" className="primary-button" disabled={busy} onClick={()=>void buy()}>{busy?<LoaderCircle className="spin" size={18}/>:<Crown size={18}/>} Quero ser Apoiador</button> : <p className="muted text-sm">Carregando Apoiador…</p>}
    </div>
    {error && <ErrorNotice message={error} retry={onChanged}/>}
  </section>;
}

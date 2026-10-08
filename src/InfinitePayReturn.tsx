import { useEffect, useRef, useState } from 'react';
import { Check, LoaderCircle, X } from 'lucide-react';
import { errorMessage, infinitePayStatus } from './backend';

export type InfinitePayReturnData = { order_nsu: string; transaction_nsu?: string; slug?: string; destination?: 'torneio' };
export function readInfinitePayReturn(): InfinitePayReturnData | null {
  const params = new URLSearchParams(location.search);
  if (params.get('payment') !== 'infinitepay') return null;
  return { order_nsu: params.get('order_nsu') ?? '', transaction_nsu: params.get('transaction_nsu') ?? undefined, slug: params.get('slug') ?? undefined,
    ...(params.get('destination') === 'torneio' ? { destination: 'torneio' as const } : {}) };
}

export default function InfinitePayReturn({payment,onPaid}:{payment:InfinitePayReturnData;onPaid:()=>void}) {
  const [state,setState] = useState<'checking'|'pending'|'paid'|'error'|'closed'>('checking');
  const [message,setMessage] = useState('');
  const [retry,setRetry] = useState(0);
  const [paidKind,setPaidKind] = useState<string>();
  const callback = useRef(onPaid);
  callback.current = onPaid;
  useEffect(() => {
    let active = true;
    let timer: number | undefined;
    let attempts = 0;
    setState('checking');
    async function check() {
      try {
        const result = await infinitePayStatus(payment);
        if (!active) return;
        if (result.paid) { setPaidKind(result.kind); setState('paid'); callback.current(); return; }
        attempts += 1;
        if (attempts < 6) timer = window.setTimeout(() => void check(),5000);
        else setState('pending');
      } catch (error) { if (active) { setMessage(errorMessage(error)); setState('error'); } }
    }
    void check();
    return () => { active=false; if(timer!==undefined)window.clearTimeout(timer); };
  },[payment,retry]);
  if (state==='closed') return null;
  return <div className="card infinitepay-return" role="status" aria-live="polite">
    {state==='checking'?<LoaderCircle size={20} className="spin" aria-hidden="true"/>:state==='paid'?<Check size={20} aria-hidden="true"/>:null}
    <span>{state==='checking'?'Conferindo seu pagamento…':state==='paid'?(paidKind==='tournament'?'Pagamento confirmado! Você está inscrito no torneio.':'Pagamento confirmado! Seus benefícios já foram liberados.'):state==='pending'?'O pagamento ainda não foi confirmado. Você pode conferir novamente.':message}</span>
    {(state==='pending'||state==='error')&&<button className="text-button" type="button" onClick={()=>setRetry(value=>value+1)}>Conferir novamente</button>}
    {state!=='checking'&&<button className="box-help-button" type="button" onClick={()=>setState('closed')} aria-label="Fechar aviso do pagamento"><X size={18}/></button>}
  </div>;
}

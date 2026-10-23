import { useEffect, useRef } from 'react';
import { infinitePayStatus } from './backend';

export type InfinitePayReturnData = { order_nsu: string; transaction_nsu?: string; slug?: string; destination?: 'torneio' };
export function readInfinitePayReturn(): InfinitePayReturnData | null {
  const params = new URLSearchParams(location.search);
  if (params.get('payment') !== 'infinitepay') return null;
  return { order_nsu: params.get('order_nsu') ?? '', transaction_nsu: params.get('transaction_nsu') ?? undefined, slug: params.get('slug') ?? undefined,
    ...(params.get('destination') === 'torneio' ? { destination: 'torneio' as const } : {}) };
}

export default function InfinitePayReturn({payment,onPaid}:{payment:InfinitePayReturnData;onPaid:()=>void}) {
  const callback = useRef(onPaid);
  callback.current = onPaid;
  const {order_nsu,transaction_nsu,slug} = payment;
  useEffect(() => {
    let active = true;
    let timer: number | undefined;
    let attempts = 0;
    async function check() {
      attempts += 1;
      try {
        const result = await infinitePayStatus({order_nsu,transaction_nsu,slug});
        if (!active) return;
        if (result.paid) { callback.current(); return; }
      } catch { /* The webhook also confirms payments; keep retries silent. */ }
      if (active && attempts < 6) timer = window.setTimeout(() => void check(),5000);
    }
    void check();
    return () => { active=false; if(timer!==undefined)window.clearTimeout(timer); };
  },[order_nsu,transaction_nsu,slug]);
  return null;
}

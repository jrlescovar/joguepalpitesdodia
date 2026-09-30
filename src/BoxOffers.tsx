import { useEffect, useState } from 'react';
import { Box, CircleHelp, LoaderCircle, Sparkles } from 'lucide-react';
import { errorMessage, passRedirect } from './backend';
import { ErrorNotice } from './components';
import BoxHelp from './BoxHelp';
import ChestIcon from './ChestIcon';
import type { Profile } from './types';
import './box-offers.css';

export default function BoxOffers({theme='classic',profile}:{theme?:'classic'|'halloween'|'font';profile?:Profile}) {
  const themed=theme==='halloween';
  const fonts=theme==='font';
  const packs=fonts?[{quantity:1,price:'3,21'},{quantity:3,price:'5,67'}]:themed?[{quantity:2,price:'3,21'},{quantity:6,price:'5,67'}]:[{quantity:3,price:'3,21'},{quantity:7,price:'5,67'}];
  const [busy, setBusy] = useState<number | null>(null);
  const [error, setError] = useState('');
  const [help, setHelp] = useState(false);
  useEffect(() => {
    const reset = () => setBusy(null);
    window.addEventListener('pageshow', reset);
    return () => window.removeEventListener('pageshow', reset);
  }, []);
  async function buy(quantity: number) {
    setBusy(quantity); setError('');
    try { await passRedirect('box-checkout', { quantity, theme, requestId: crypto.randomUUID() }); }
    catch (cause) { setError(errorMessage(cause)); setBusy(null); }
  }
  return <section className={`card box-offers${themed?' box-offers-halloween':''}`} aria-label={fonts?'Caixa de Fontes':themed?'Caixas de Halloween':'Oferta de Lançamento de Personalização'}>
    <div className="box-offers-heading"><div><span className="box-offers-eyebrow"><Sparkles size={13} aria-hidden="true"/> NOVIDADE NA LOJA</span><h2>{fonts?'Caixa de Fontes':themed?'Caixas de Halloween':'Oferta de Lançamento de Personalização'}</h2></div><button type="button" className="box-help-button" aria-label="Sobre os pacotes de caixas" onClick={() => setHelp(true)}><CircleHelp size={21}/></button></div>
    <div className="box-offers-grid">{packs.map(pack => <article className={`box-offer${pack.quantity === packs[1].quantity ? ' box-offer-best' : ''}`} key={pack.quantity}>
      <div className="box-offer-tag">{pack.quantity === packs[1].quantity ? 'Em Alta' : null}</div>
      <div className="box-offer-art" aria-hidden="true"><ChestIcon halloween={themed} graffiti={fonts}/><span>×{pack.quantity}</span></div>
      <h3>{pack.quantity} {pack.quantity===1?'caixa':'caixas'}</h3><p>{fonts?'de fontes':themed?'de Halloween':'de personalização'}</p>
      <button type="button" className="box-offer-buy" disabled={busy !== null} onClick={() => void buy(pack.quantity)} aria-label={`Comprar ${pack.quantity} {pack.quantity===1?'caixa':'caixas'} por R$ ${pack.price}`}>{busy === pack.quantity ? <LoaderCircle size={17} className="spin"/> : <Box size={17} aria-hidden="true"/>} R$ {pack.price}</button>
    </article>)}</div>
    <button type="button" className="box-offers-view-items" onClick={()=>setHelp(true)}>Ver itens possíveis</button>
    {error && <ErrorNotice message={error}/>}
    <BoxHelp open={help} onOpenChange={setHelp} theme={theme} profile={profile}/>
  </section>;
}

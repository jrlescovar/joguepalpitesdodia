import { useState } from 'react';
import { Box, CircleHelp, LoaderCircle, Sparkles } from 'lucide-react';
import { errorMessage, passRedirect } from './backend';
import { ErrorNotice } from './components';
import BoxHelp from './BoxHelp';
import ChestIcon from './ChestIcon';
import './box-offers.css';

export default function BoxOffers() {
  const [busy, setBusy] = useState<number | null>(null);
  const [error, setError] = useState('');
  const [help, setHelp] = useState(false);
  const [returned] = useState(() => new URLSearchParams(location.search).get('boxes'));
  async function buy(quantity: number) {
    setBusy(quantity); setError('');
    try { await passRedirect('box-checkout', { quantity, requestId: crypto.randomUUID() }); }
    catch (cause) { setError(errorMessage(cause)); setBusy(null); }
  }
  return <section className="card box-offers" aria-label="Oferta de Lançamento de Personalização">
    <div className="box-offers-heading"><div><span className="box-offers-eyebrow"><Sparkles size={13} aria-hidden="true"/> NOVIDADE NA LOJA</span><h2>Oferta de Lançamento de Personalização</h2></div><button type="button" className="box-help-button" aria-label="Sobre os pacotes de caixas" onClick={() => setHelp(true)}><CircleHelp size={21}/></button></div>
    <p className="box-offers-choice">Cada caixa comprada pode abrir a Caixa de Personalização ou a Caixa de Halloween.</p>
    <div className="box-offers-grid">{[{ quantity: 3, price: '3,21' }, { quantity: 7, price: '5,67' }].map(pack => <article className={`box-offer${pack.quantity === 7 ? ' box-offer-best' : ''}`} key={pack.quantity}>
      <div className="box-offer-tag">{pack.quantity === 7 ? 'Em Alta' : null}</div>
      <div className="box-offer-art" aria-hidden="true"><ChestIcon/><span>×{pack.quantity}</span></div>
      <h3>{pack.quantity} caixas</h3><p>de personalização</p>
      <button type="button" className="box-offer-buy" disabled={busy !== null} onClick={() => void buy(pack.quantity)} aria-label={`Comprar ${pack.quantity} caixas por R$ ${pack.price}`}>{busy === pack.quantity ? <LoaderCircle size={17} className="spin"/> : <Box size={17} aria-hidden="true"/>} R$ {pack.price}</button>
    </article>)}</div>
    {returned === 'paid' && <p className="box-offers-status" role="status">Aguardando confirmação do pagamento. Suas caixas aparecem assim que ele for confirmado.</p>}
    {error && <ErrorNotice message={error}/>}
    <BoxHelp open={help} onOpenChange={setHelp}/>
  </section>;
}

import { useEffect, useRef, useState } from 'react';
import { ArrowRight, CircleHelp, LoaderCircle, Minus, Plus } from 'lucide-react';
import { call, errorMessage, passRedirect } from './backend';
import { ErrorNotice, Modal } from './components';
import EmeraldIcon from './EmeraldIcon';
import { BoxArt } from './BoxPanel';
import BoxHelp from './BoxHelp';
import { boxLabels } from './boxThemes';
import CarouselControls from './CarouselControls';
import { useCardCarousel } from './useCardCarousel';
import { boxCarouselPageStart } from './boxCarouselPages';
import type { BoxTheme, Profile } from './types';
import './boxCarousel.css';
import './coinShop.css';
export type CoinWallet={balance:number;unitPrices:Record<BoxTheme,number>};
export const coinPacks=[{quantity:450,price:'3,21'},{quantity:1000,price:'5,67'},{quantity:2200,price:'9,17'}] as const;
const shopThemes:BoxTheme[]=['halloween','font','classic','name','frame'];
const amounts=(value:number)=>value.toLocaleString('pt-BR');
export default function CoinShop({profile,refreshTick,onBought}:{profile:Profile;refreshTick:number;onBought:(theme:BoxTheme)=>void}) {
 const [wallet,setWallet]=useState<CoinWallet|null>(null),[loadError,setLoadError]=useState(''),[retry,setRetry]=useState(0);
 const [theme,setTheme]=useState<BoxTheme|null>(null),[quantity,setQuantity]=useState(1),[busy,setBusy]=useState(false),[error,setError]=useState('');
 const [packBusy,setPackBusy]=useState<number|null>(null),[packError,setPackError]=useState(''),[help,setHelp]=useState<BoxTheme|null>(null),[retryPurchase,setRetryPurchase]=useState(false);
 const request=useRef<{id:string;theme:BoxTheme;quantity:number}|null>(null),submitting=useRef(false);
 const checkoutRequests=useRef<Record<number,string>>({}),packSubmitting=useRef(false);
 const packsRef=useRef<HTMLElement>(null),quantityInput=useRef<HTMLInputElement>(null);
 const {rail,slides,active,shown,snapStarts,perPage,pageCount,goTo,gestureHandlers}=useCardCarousel(shopThemes,{settleNavigation:true});
 const pageLabels=Array.from({length:pageCount},(_,page)=>{
  const start=boxCarouselPageStart(shopThemes.length,page,perPage);
  return shopThemes.slice(start,start+perPage).map(value=>boxLabels[value]).join(' e ');
 });
 useEffect(()=>{let alive=true;setLoadError('');call<CoinWallet>('getCoinWallet').then(value=>{if(alive)setWallet(value);}).catch(cause=>{if(alive){setWallet(null);setLoadError(errorMessage(cause));}});return()=>{alive=false;};},[profile.uid,refreshTick,retry]);
 useEffect(()=>{const reset=(event:PageTransitionEvent)=>{packSubmitting.current=false;checkoutRequests.current={};setPackBusy(null);if(event.persisted)setRetry(value=>value+1);};window.addEventListener('pageshow',reset);return()=>window.removeEventListener('pageshow',reset);},[]);
 function scrollToPacks(){packsRef.current?.scrollIntoView({block:'center',behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'instant':'smooth'});}
 const price=theme&&wallet?wallet.unitPrices[theme]:0,total=quantity*price;
 function choose(value:BoxTheme){setTheme(value);setQuantity(1);setError('');setRetryPurchase(false);request.current=null;}
 function changeQuantity(value:number){setQuantity(value);setError('');setRetryPurchase(false);request.current=null;}
 async function buy(){
  if(!theme||!wallet||submitting.current||(!retryPurchase&&wallet.balance<total))return;
  const target=theme;submitting.current=true;setBusy(true);setError('');
  if(!request.current||request.current.theme!==target||request.current.quantity!==quantity)request.current={id:crypto.randomUUID(),theme:target,quantity};
  try{const result=await call<{balance:number;theme:BoxTheme}>('buyBoxesWithCoins',{theme:target,quantity,requestId:request.current.id});setWallet(previous=>previous?{...previous,balance:result.balance}:previous);setTheme(null);request.current=null;onBought(target);}
  catch(cause){setError(errorMessage(cause));setRetryPurchase(true);setRetry(value=>value+1);}
  finally{submitting.current=false;setBusy(false);}
 }
 async function buyCoins(pack:typeof coinPacks[number]){if(packSubmitting.current)return;packSubmitting.current=true;setPackBusy(pack.quantity);setPackError('');checkoutRequests.current[pack.quantity]??=crypto.randomUUID();try{await passRedirect('infinitepay-checkout',{kind:'coins',quantity:pack.quantity,requestId:checkoutRequests.current[pack.quantity]});}catch(cause){setPackError(errorMessage(cause));packSubmitting.current=false;setPackBusy(null);}}
 return <section className="coin-shop" aria-label="Loja de moedas e caixas">
  <section className="card coin-packs" ref={packsRef} aria-label="Comprar moedas"><div className="coin-section-heading coin-packs-heading"><div><span className="eyebrow">MAIS POSSIBILIDADES PARA SEU PERFIL</span><h2>Comprar moedas</h2></div><div className="coin-header-balance" role="status" aria-live="polite" aria-label={wallet?`Saldo: ${amounts(wallet.balance)} moedas`:loadError?'Saldo indisponível':'Carregando saldo'}><EmeraldIcon size={30}/><strong>{wallet?amounts(wallet.balance):loadError?'—':'…'}</strong></div></div><div className="coin-packs-grid">{coinPacks.map(pack=><article className="coin-pack" key={pack.quantity}><EmeraldIcon size={68}/><h3>{amounts(pack.quantity)}</h3><button type="button" className="primary-button" disabled={packBusy!==null} onClick={()=>void buyCoins(pack)} aria-label={`Comprar ${pack.quantity} moedas por R$ ${pack.price}`}>{packBusy===pack.quantity?<LoaderCircle size={17} className="spin"/>:null}R$ {pack.price}<ArrowRight size={16}/></button></article>)}</div>{packError&&<ErrorNotice message={packError}/>}</section>
  {loadError&&<ErrorNotice message={loadError} retry={()=>setRetry(value=>value+1)}/>}
  <section className="coin-box-store" aria-label="Comprar caixas" aria-roledescription="carrossel">
   <h2 className="box-carousel-title">Comprar caixas</h2>
   <div className="box-carousel-rail coin-box-pages" ref={rail} {...gestureHandlers}>
    {shopThemes.map(value=><div key={value} className="box-carousel-slide" data-page-start={snapStarts.has(value)} ref={element=>{if(element)slides.current[value]=element;else delete slides.current[value];}} inert={!shown.includes(value)} role="group" aria-roledescription="slide" aria-label={boxLabels[value]}>
     <article className={`card box-panel box-panel-${value} coin-box coin-box-${value}`}>
      <div className="box-panel-heading"><div className="box-topline"><h2>{boxLabels[value]}</h2><button type="button" className="box-help-button" onClick={()=>setHelp(value)} aria-label={`Ver itens possíveis da ${boxLabels[value]}`}><CircleHelp size={21}/></button></div></div>
      <BoxArt theme={value}/>
      <div className="box-panel-actions"><button type="button" className="primary-button coin-box-buy" disabled={!wallet} onClick={()=>choose(value)} aria-label={`Comprar ${boxLabels[value]}`}>Comprar <span className="coin-box-price"><strong>{wallet?amounts(wallet.unitPrices[value]):'—'}</strong><EmeraldIcon size={24}/></span></button></div>
     </article>
    </div>)}
   </div>
   <CarouselControls active={active} labels={pageLabels} onSelect={goTo} previousLabel="Caixas da loja anteriores" nextLabel="Próximas caixas da loja"/>
  </section>
  <Modal open={theme!==null} onOpenChange={open=>{if(!busy&&!open){setTheme(null);setError('');}}} title={theme?boxLabels[theme]:'Comprar caixa'} description="Escolha a quantidade e confirme a compra com suas moedas." dismissible={!busy} className="coin-purchase-dialog" onOpenAutoFocus={event=>{event.preventDefault();quantityInput.current?.closest<HTMLElement>('[role="dialog"]')?.focus({preventScroll:true});}}>
   <div className="coin-quantity"><button type="button" className="icon-button" aria-label="Diminuir quantidade" disabled={quantity===1||busy} onClick={()=>changeQuantity(quantity-1)}><Minus size={20}/></button><label>Quantidade<input ref={quantityInput} type="number" min={1} max={99} value={quantity} disabled={busy} onChange={event=>{const value=Number(event.target.value);if(Number.isInteger(value))changeQuantity(Math.min(99,Math.max(1,value)));}}/></label><button type="button" className="icon-button" aria-label="Aumentar quantidade" disabled={quantity===99||busy} onClick={()=>changeQuantity(quantity+1)}><Plus size={20}/></button></div>
   <div className="coin-purchase-total"><span>Total</span><strong><EmeraldIcon size={28}/>{amounts(total)} moedas</strong></div><p className="coin-purchase-balance">Seu saldo: {wallet?amounts(wallet.balance):'—'} moedas{wallet&&wallet.balance>=total?` · Após a compra: ${amounts(wallet.balance-total)}`:''}</p>
   {wallet&&wallet.balance<total&&<div className="coin-shortfall"><p>Faltam {amounts(total-wallet.balance)} moedas para esta compra.</p><button type="button" className="secondary-button" onClick={()=>{setTheme(null);scrollToPacks();}}>Comprar moedas</button></div>}
   {error&&<ErrorNotice message={error}/>}<button type="button" className="primary-button w-full" disabled={busy||!wallet||(!retryPurchase&&wallet.balance<total)} onClick={()=>void buy()}>{busy?<><LoaderCircle size={18} className="spin"/>Comprando…</>:<>{retryPurchase?'Tentar novamente':'Confirmar e comprar'}<ArrowRight size={18}/></>}</button>
  </Modal>
  <BoxHelp open={help!==null} onOpenChange={open=>{if(!open)setHelp(null);}} theme={help??'classic'} profile={profile}/>
 </section>;
}

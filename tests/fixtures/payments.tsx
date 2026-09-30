// Local visual/interaction fixture. Every backend call is intercepted; no charge
// or real player data is created. Vite does not include this page in the build.
import React from 'react';
import { createRoot } from 'react-dom/client';
import '../../src/styles.css';
import '../../src/design.css';
import '../../src/usernameFonts.css';
const realFetch=window.fetch.bind(window);
window.fetch=async (url,init)=>{
  const address=String(url);
  if(!address.includes('.supabase.co'))return realFetch(url,init);
  if(address.includes('/rpc/get_pass_status'))return Response.json({active:false,status:'none',periodEndsAt:null,cancelAtPeriodEnd:false,borderStyle:'none',nameStyle:'none'});
  if(address.includes('/functions/v1/infinitepay-status'))return Response.json({paid:new URLSearchParams(location.search).get('result')!=='pending'});
  if(address.includes('/functions/')){
    const element=document.getElementById('last-request')!;
    element.textContent=JSON.stringify({destination:address.split('/').pop(),body:init?.body?JSON.parse(String(init.body)):null});
    return Response.json({error:'Verificação local: pagamento não foi iniciado.'},{status:502});
  }
  return Response.json({});
};
const [{default:BoxOffers},{default:SupporterPanel},{default:InfinitePayReturn}]=await Promise.all([import('../../src/BoxOffers'),import('../../src/SupporterPanel'),import('../../src/InfinitePayReturn')]);
const profile={uid:'00000000-0000-4000-8000-000000000001',playerId:1000001,email:'',username:'Jogador',usernameLower:'jogador',avatarColor:'#3b82f6',level:10,xp:10,green:5,red:2,greenStreakCurrent:2,greenStreakMax:3,dailyStreakCurrent:1,lastPlayedDate:null,balance:0};
const payment={order_nsu:'00000000-0000-4000-8000-000000000002',transaction_nsu:'test',slug:'test'};
createRoot(document.getElementById('root')!).render(<div className="app-shell"><header className="app-header"><strong>Verificação local da loja</strong></header><main className="app-main"><InfinitePayReturn payment={payment} onPaid={()=>{document.getElementById('last-request')!.dataset.delivered='true';}}/><div className="shop-layout"><SupporterPanel profile={profile} refreshTick={0} onChanged={()=>{}}/><BoxOffers profile={profile}/><BoxOffers theme="font" profile={profile}/><BoxOffers theme="halloween" profile={profile}/></div><pre id="last-request" style={{whiteSpace:'pre-wrap',overflowWrap:'anywhere'}}/></main></div>);

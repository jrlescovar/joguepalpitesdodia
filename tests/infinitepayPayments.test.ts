import { readFileSync } from 'node:fs';
import { webcrypto } from 'node:crypto';
import ts from 'typescript';
import { describe, expect, it, vi } from 'vitest';

const origin='https://joguepalpitesdodia.web.app';
const id='00000000-0000-4000-8000-000000000001';
const otherId='00000000-0000-4000-8000-000000000002';
const profileId='00000000-0000-4000-8000-000000000003';
const order={id,profile_id:profileId,handle:'jrlescovar',kind:'font',quantity:1,amount_cents:321,checkout_url:null,paid_at:null};

function load(name:string, { saved={...order},fetcher=vi.fn(async()=>Response.json({success:true,paid:true,amount:321,paid_amount:321,capture_method:'pix'})),user=true,reservationError=null,settlementError=null } : {saved?:typeof order|null;fetcher?:ReturnType<typeof vi.fn>;user?:boolean;reservationError?:unknown;settlementError?:unknown}={}) {
  let handler:(request:Request)=>Promise<Response>;
  const rpc=vi.fn(async(name:string,args:unknown)=>name==='get_or_claim_profile'?{data:{uid:profileId},error:null}:name==='reserve_infinitepay_order'?{data:saved,error:reservationError}:{data:true,error:settlementError});
  const query:any={select:()=>query,eq:()=>query,maybeSingle:async()=>({data:saved,error:null}),update:()=>query,then:(resolve:any)=>Promise.resolve({error:null}).then(resolve)};
  const client=()=>({auth:{getUser:async()=>({data:{user:user?{id:profileId}:null},error:null})},rpc,from:()=>query});
  const shared=readFileSync('supabase/functions/_shared/infinitepay.ts','utf8').replace(/^import.*\r?\n/gm,'').replace(/^export /gm,'');
  const endpoint=readFileSync(`supabase/functions/${name}/index.ts`,'utf8').replace(/^import.*\r?\n/gm,'');
  const source=ts.transpileModule(shared+'\n'+endpoint,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.None}}).outputText;
  const deno={env:{get:(key:string)=>key==='INFINITEPAY_HANDLE'?'jrlescovar':'https://example.supabase.co'},serve:(value:typeof handler)=>{handler=value;}};
  new Function('Deno','createClient','fetch','crypto',source)(deno,client,fetcher,webcrypto);
  return {request:(body:unknown,auth=true)=>handler(new Request('https://example.com',{method:'POST',headers:{origin,...(auth?{authorization:'Bearer test'}:{})},body:JSON.stringify(body)})),rpc,fetcher};
}
const payment={order_nsu:id,transaction_nsu:'transaction-1',invoice_slug:'invoice-1'};
describe('Pix InfinitePay',()=>{
  it.each([['classic',3,321],['classic',7,567],['classic',11,917],['font',1,321],['font',3,567],['halloween',2,321],['halloween',6,567],['halloween',10,917],['supporter',1,497]])('define o preço de %s/%i no servidor',async(kind,quantity,amount)=>{
    const fetcher=vi.fn(async()=>Response.json({url:'https://checkout.infinitepay.io/jrlescovar?lenc=test'}));
    const app=load('infinitepay-checkout',{fetcher});
    expect((await app.request({kind,quantity,amount:1,profileId:otherId,requestId:otherId})).status).toBe(200);
    const payload=JSON.parse(fetcher.mock.calls[0][1].body);
    expect(payload.handle).toBe('jrlescovar');expect(payload.items[0].price).toBe(amount);expect(payload.order_nsu).toBe(id);
    expect(payload.webhook_url).toMatch(/infinitepay-webhook$/);
    expect(payload.redirect_url).toBe(origin+'/?payment=infinitepay');
    expect(app.rpc).toHaveBeenCalledWith('reserve_infinitepay_order',expect.objectContaining({p_profile_id:profileId,p_kind:kind,p_quantity:quantity,p_amount_cents:amount}));
  });
  it('reutiliza o checkout reservado em uma nova tentativa',async()=>{
    const app=load('infinitepay-checkout',{saved:{...order,checkout_url:'https://checkout.infinitepay.io/jrlescovar?lenc=test'}});
    expect((await app.request({kind:'font',quantity:1,requestId:otherId})).status).toBe(200);expect(app.fetcher).not.toHaveBeenCalled();
  });
  it.each([['font',7],['font',11],['classic',1],['classic',10],['halloween',3],['halloween',11],['supporter',2],['__proto__',1]])('recusa pacote inválido %s/%i',async(kind,quantity)=>{
    const app=load('infinitepay-checkout');expect((await app.request({kind,quantity,requestId:otherId})).status).toBe(400);expect(app.fetcher).not.toHaveBeenCalled();
  });
  it('exige usuário autenticado',async()=>{
    const app=load('infinitepay-checkout',{user:false});expect((await app.request({kind:'font',quantity:1,requestId:otherId})).status).toBe(401);expect(app.fetcher).not.toHaveBeenCalled();
  });
  it('recusa destino de checkout externo',async()=>{
    const app=load('infinitepay-checkout',{fetcher:vi.fn(async()=>Response.json({url:'https://checkout.infinitepay.io.evil.com/pagar'}))});
    expect((await app.request({kind:'font',quantity:1,requestId:otherId})).status).toBe(502);
  });
  it('verifica a transação na InfinitePay, ignorando valor e usuário do webhook',async()=>{
    const app=load('infinitepay-webhook');expect((await app.request({...payment,paid:true,amount:1,profile_id:otherId},false)).status).toBe(200);
    expect(JSON.parse(app.fetcher.mock.calls[0][1].body)).toEqual({handle:'jrlescovar',order_nsu:id,transaction_nsu:'transaction-1',slug:'invoice-1'});
    expect(app.rpc).toHaveBeenCalledWith('settle_infinitepay_order',{p_order_id:id,p_transaction_nsu:'transaction-1',p_invoice_slug:'invoice-1',p_amount_cents:321,p_capture_method:'pix'});
  });
  it.each([['classic',11],['halloween',10]])('confirma o pacote maior %s/%i somente pelo valor reservado',async(kind,quantity)=>{
    const app=load('infinitepay-webhook',{saved:{...order,kind,quantity,amount_cents:917},fetcher:vi.fn(async()=>Response.json({success:true,paid:true,amount:917,paid_amount:917,capture_method:'pix'}))});
    expect((await app.request({...payment,amount:1,quantity:100},false)).status).toBe(200);
    expect(app.rpc).toHaveBeenCalledWith('settle_infinitepay_order',expect.objectContaining({p_order_id:id,p_amount_cents:917}));
  });
  it.each([{success:true,paid:false,amount:321,paid_amount:321,capture_method:'pix'}, {success:true,paid:true,amount:1,paid_amount:1,capture_method:'pix'}, {success:false,paid:true,amount:321,paid_amount:321,capture_method:'pix'}, {success:true,paid:true,amount:321,paid_amount:320,capture_method:'pix'}])('não entrega pagamento inválido/pendente %j',async(verified)=>{
    const app=load('infinitepay-webhook',{fetcher:vi.fn(async()=>Response.json(verified))});
    expect((await app.request(payment,false)).status).toBe(400);expect(app.rpc).not.toHaveBeenCalledWith('settle_infinitepay_order',expect.anything());
  });
  it('não expõe pedido de outro jogador no retorno',async()=>{
    const app=load('infinitepay-status',{saved:{...order,profile_id:otherId}});expect((await app.request(payment)).status).toBe(404);expect(app.fetcher).not.toHaveBeenCalled();
  });
  it('rejeita pedido inexistente sem chamar a InfinitePay',async()=>{
    const app=load('infinitepay-webhook',{saved:null});expect((await app.request(payment,false)).status).toBe(400);expect(app.fetcher).not.toHaveBeenCalled();
  });
  it('pede repetição do webhook quando a entrega falha',async()=>{
    const app=load('infinitepay-webhook',{settlementError:{code:'08006'}});expect((await app.request(payment,false)).status).toBe(400);
  });
  it('reconhece uma entrega concluída sem entregá-la de novo',async()=>{
    const app=load('infinitepay-webhook',{saved:{...order,paid_at:'2026-09-30T12:00:00Z'}});
    expect((await app.request(payment,false)).status).toBe(200);expect(app.fetcher).not.toHaveBeenCalled();expect(app.rpc).not.toHaveBeenCalled();
  });
});

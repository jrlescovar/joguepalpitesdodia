import { readFileSync } from 'node:fs';
import { webcrypto } from 'node:crypto';
import ts from 'typescript';
import { describe, expect, it, vi } from 'vitest';

const origin = 'https://joguepalpitesdodia.web.app';
const profileId = '00000000-0000-4000-8000-000000000001';
function load(name: string, fetcher: typeof fetch, rpc = vi.fn(async () => ({ data: { uid: profileId }, error: null }))) {
  let handler: (request: Request) => Promise<Response>;
  const source = readFileSync(`supabase/functions/${name}/index.ts`, 'utf8').replace(/^import .*\r?\n/, '');
  const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.None } }).outputText;
  const deno = { env: { get: (key: string) => key === 'STRIPE_WEBHOOK_SECRET' ? 'test-secret' : 'test-value' }, serve: (value: typeof handler) => { handler = value; } };
  const client = () => ({ auth: { getUser: async () => ({ data: { user: { email: 'test@example.com' } }, error: null }) }, rpc });
  new Function('Deno', 'createClient', 'fetch', 'crypto', js)(deno, client, fetcher, webcrypto);
  return { request: (request: Request) => handler(request), rpc };
}
async function signedEvent() {
  const payload = JSON.stringify({ type: 'checkout.session.completed', data: { object: { id: 'cs_test' } } });
  const timestamp = Math.floor(Date.now() / 1000);
  const key = await webcrypto.subtle.importKey('raw', new TextEncoder().encode('test-secret'), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const digest = await webcrypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${timestamp}.${payload}`));
  const signature = Buffer.from(digest).toString('hex');
  return new Request('https://example.com', { method: 'POST', headers: { 'stripe-signature': `t=${timestamp},v1=${signature}` }, body: payload });
}
describe('pagamento dos pacotes de caixas', () => {
  it.each([[3, '321','classic'], [7, '567','classic'],[2,'321','halloween'],[6,'567','halloween'],[1,'321','font'],[3,'567','font']])('cria compra avulsa de %i caixas com preço definido no servidor', async (quantity, amount, theme) => {
    let body: URLSearchParams;
    const fetcher = vi.fn(async (_url, init) => { body = init.body as URLSearchParams; return Response.json({ url: 'https://checkout.stripe.com/test' }); });
    const app = load('box-checkout', fetcher as typeof fetch);
    const response = await app.request(new Request('https://example.com', { method: 'POST', headers: { origin, authorization: 'Bearer test' }, body: JSON.stringify({ quantity, theme, amount: 1, requestId: '00000000-0000-4000-8000-000000000002' }) }));
    expect(response.status).toBe(200);
    expect(body!.get('metadata[purchase_kind]')).toBe(theme==='font'?'font_boxes':theme==='halloween'?'halloween_boxes':'style_boxes');
    expect(body!.get('mode')).toBe('payment');
    expect(body!.get('line_items[0][price_data][unit_amount]')).toBe(amount);
    expect(body!.get('metadata[profile_id]')).toBe(profileId);
  });
  it('recusa pacote inexistente antes de chamar a Stripe', async () => {
    const fetcher = vi.fn(); const app = load('box-checkout', fetcher);
    const response = await app.request(new Request('https://example.com', { method: 'POST', headers: { origin, authorization: 'Bearer test' }, body: JSON.stringify({ quantity: 99, requestId: '00000000-0000-4000-8000-000000000002' }) }));
    expect(response.status).toBe(400); expect(fetcher).not.toHaveBeenCalled();
  });
  it.each([['unpaid', 321, 0], ['paid', 1, 0], ['paid', 321, 1]])('confere status %s e valor %i antes de creditar', async (status, amount, credits) => {
    const rpc = vi.fn(async () => ({ error: null }));
    const checkout = { id: 'cs_test', mode: 'payment', payment_status: status, currency: 'brl', amount_total: amount, client_reference_id: profileId, metadata: { profile_id: profileId, purchase_kind: 'style_boxes', box_quantity: '3' } };
    const app = load('pass-webhook', vi.fn(async () => Response.json(checkout)), rpc);
    const response = await app.request(await signedEvent());
    expect(response.status).toBe(amount === 1 ? 400 : 200);
    expect(rpc).toHaveBeenCalledTimes(credits);
    if (credits) expect(rpc).toHaveBeenCalledWith('credit_box_purchase', { p_profile_id: profileId, p_session_id: 'cs_test', p_quantity: 3, p_amount_cents: 321 });
  });
  it.each([[2,321,200],[6,567,200],[3,321,400],[2,1,400]])('credita somente compras Halloween válidas %i/%i',async(quantity,amount,status)=>{
    const rpc=vi.fn(async()=>({error:null}));
    const checkout={id:'cs_test',mode:'payment',payment_status:'paid',currency:'brl',amount_total:amount,client_reference_id:profileId,metadata:{profile_id:profileId,purchase_kind:'halloween_boxes',box_quantity:String(quantity)}};
    const app=load('pass-webhook',vi.fn(async()=>Response.json(checkout)),rpc);
    expect((await app.request(await signedEvent())).status).toBe(status);
    if(status===200)expect(rpc).toHaveBeenCalledWith('credit_halloween_box_purchase',{p_profile_id:profileId,p_session_id:'cs_test',p_quantity:quantity,p_amount_cents:amount});
    else expect(rpc).not.toHaveBeenCalled();
  });
  it.each([[1,321,200],[3,567,200],[7,567,400],[3,321,400]])('valida pacote de fontes %i/%i',async(quantity,amount,status)=>{
    const rpc=vi.fn(async()=>({error:null}));
    const checkout={id:'cs_test',mode:'payment',payment_status:'paid',currency:'brl',amount_total:amount,client_reference_id:profileId,metadata:{profile_id:profileId,purchase_kind:'font_boxes',box_quantity:String(quantity)}};
    const app=load('pass-webhook',vi.fn(async()=>Response.json(checkout)),rpc);
    expect((await app.request(await signedEvent())).status).toBe(status);
    if(status===200)expect(rpc).toHaveBeenCalledWith('credit_font_box_purchase',{p_profile_id:profileId,p_session_id:'cs_test',p_quantity:quantity,p_amount_cents:amount});
    else expect(rpc).not.toHaveBeenCalled();
  });
  it('recusa webhook sem assinatura válida', async () => {
    const fetcher = vi.fn(); const app = load('pass-webhook', fetcher);
    const response = await app.request(new Request('https://example.com', { method: 'POST', body: '{}' }));
    expect(response.status).toBe(400); expect(fetcher).not.toHaveBeenCalled();
  });
});

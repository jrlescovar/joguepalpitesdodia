import { createClient, type SupabaseClient } from 'npm:@supabase/supabase-js@2';

export const origins = new Set(['https://jogueapostadodia.web.app', 'https://joguepalpitesdodia.web.app']);
export const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export type Order = { id: string; profile_id: string; handle: string; kind: string; quantity: number; amount_cents: number; checkout_url: string | null; paid_at: string | null };

export function product(kind: unknown, quantity: unknown) {
  if (typeof quantity !== 'number' || !Number.isInteger(quantity)) return null;
  const packs: Record<string, Record<number, number>> = {
    classic: { 3: 321, 7: 567, 11: 917 }, halloween: { 2: 321, 6: 567, 10: 917 }, font: { 1: 321, 3: 567, 5: 917 }, supporter: { 1: 497 },
  };
  if (typeof kind !== 'string' || !Object.hasOwn(packs, kind) || !packs[kind][quantity]) return null;
  const names: Record<string, string> = { classic: 'de Personalização', halloween: 'de Halloween', font: 'de Fontes' };
  return { kind, quantity, amount: packs[kind][quantity], description: kind === 'supporter'
    ? 'Apoiador por 30 dias — +50% de XP, emblema, 7 Caixas de Personalização e 1 Caixa de Fontes. Sem renovação automática.'
    : `${quantity} ${quantity === 1 ? 'Caixa' : 'Caixas'} ${names[kind]}` };
}

export function checkoutUrl(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password && !url.port
      && ['checkout.infinitepay.io', 'buy.infinitepay.io'].includes(url.hostname) ? url.href : null;
  } catch { return null; }
}

export function cors(request: Request) {
  const origin = request.headers.get('origin') ?? '';
  return { 'Access-Control-Allow-Origin': origins.has(origin) ? origin : '', 'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
}
export function reply(value: unknown, status = 200, headers: Record<string,string> = {}) {
  return new Response(JSON.stringify(value), { status, headers: { ...headers, 'Content-Type': 'application/json', 'Cache-Control': 'no-store' } });
}
export function serviceDb() {
  return createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
}
export async function ownProfile(request: Request) {
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return null;
  const client = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } } });
  const { data: { user }, error } = await client.auth.getUser(authorization.slice(7));
  if (error || !user) return null;
  const { data: profile, error: profileError } = await client.rpc('get_or_claim_profile');
  return !profileError && typeof profile?.uid === 'string' ? profile.uid as string : null;
}

export type PaymentInput = { order_nsu?: unknown; transaction_nsu?: unknown; slug?: unknown; invoice_slug?: unknown };
export async function confirmPayment(db: SupabaseClient, input: PaymentInput, profileId?: string) {
  if (typeof input.order_nsu !== 'string' || !uuid.test(input.order_nsu)) return { status: 400, error: 'Pedido inválido.' };
  const { data: order, error } = await db.from('infinitepay_orders').select('*').eq('id', input.order_nsu).maybeSingle();
  if (error) return { status: 503, error: 'Não foi possível consultar o pedido.' };
  if (!order || (profileId && order.profile_id !== profileId)) return { status: 404, error: 'Pedido não encontrado.' };
  if (order.paid_at) return { status: 200, paid: true, kind: order.kind };
  const slug = input.invoice_slug ?? input.slug;
  if (typeof input.transaction_nsu !== 'string' || input.transaction_nsu.length < 1 || input.transaction_nsu.length > 200
    || typeof slug !== 'string' || slug.length < 1 || slug.length > 200) return { status: 400, error: 'Dados do pagamento inválidos.' };
  // Never trust amounts, buyer IDs, or the paid status in an incoming webhook/URL.
  const response = await fetch('https://api.checkout.infinitepay.io/payment_check', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(10000),
    body: JSON.stringify({ handle: order.handle, order_nsu: order.id, transaction_nsu: input.transaction_nsu, slug }),
  });
  if (!response.ok) return { status: 400, error: 'A InfinitePay ainda não confirmou este pagamento.' };
  const verified = await response.json();
  if (verified.success !== true || verified.paid !== true) return { status: 200, paid: false, kind: order.kind };
  if (verified.amount !== order.amount_cents || !Number.isInteger(verified.paid_amount) || verified.paid_amount < order.amount_cents
    || !['pix','credit_card'].includes(verified.capture_method)) return { status: 400, error: 'Pagamento não corresponde ao pedido.' };
  const { error: settlementError } = await db.rpc('settle_infinitepay_order', {
    p_order_id: order.id, p_transaction_nsu: input.transaction_nsu, p_invoice_slug: slug,
    p_amount_cents: verified.amount, p_capture_method: verified.capture_method,
  });
  if (settlementError) { console.error('infinitepay_settlement', settlementError.code); return { status: 503, error: 'Pagamento em verificação. Tente atualizar em instantes.' }; }
  return { status: 200, paid: true, kind: order.kind };
}

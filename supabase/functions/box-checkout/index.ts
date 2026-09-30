import { createClient } from 'npm:@supabase/supabase-js@2';

const allowedOrigins = new Set(['https://jogueapostadodia.web.app', 'https://joguepalpitesdodia.web.app']);
const packs: Record<string, { quantity: number; amount: number }> = {
  '3': { quantity: 3, amount: 321 },
  '7': { quantity: 7, amount: 567 },
};

Deno.serve(async request => {
  const origin = request.headers.get('origin') ?? '';
  const cors = { 'Access-Control-Allow-Origin': origin, 'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
  const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
  if (!allowedOrigins.has(origin)) return json({ error: 'Requisição inválida.' }, 403);
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') return json({ error: 'Requisição inválida.' }, 405);
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return json({ error: 'Entre na sua conta.' }, 401);
  const input = await request.json().catch(() => null);
  const theme=input?.theme??'classic';
  const halloweenPacks: typeof packs={'2':{quantity:2,amount:321},'6':{quantity:6,amount:567}};
  const pack = theme==='font'?({'1':{quantity:1,amount:321},'3':{quantity:3,amount:567}} as typeof packs)[String(input?.quantity)]:theme==='halloween'?halloweenPacks[String(input?.quantity)]:theme==='classic'?packs[String(input?.quantity)]:undefined;
  if (!pack || typeof input?.requestId !== 'string' || !/^[0-9a-f-]{36}$/i.test(input.requestId)) return json({ error: 'Pacote inválido.' }, 400);
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
  if (!stripeKey) return json({ error: 'Pagamento ainda não configurado.' }, 503);
  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const auth = createClient(url, anonKey);
  const { data: { user }, error: authError } = await auth.auth.getUser(authorization.slice(7));
  if (authError || !user) return json({ error: 'Sessão expirada.' }, 401);
  const own = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: profile, error: profileError } = await own.rpc('get_or_claim_profile');
  const profileId = profile?.uid as string | undefined;
  if (profileError || !profileId) return json({ error: 'Crie seu perfil primeiro.' }, 400);
  const body = new URLSearchParams({
    mode: 'payment',
    'payment_method_types[0]': 'card',
    'line_items[0][price_data][currency]': 'brl',
    'line_items[0][price_data][unit_amount]': String(pack.amount),
    'line_items[0][price_data][product_data][name]': `${pack.quantity} Caixas de ${theme==='halloween'?'Halloween':'Personalização'}`,
    'line_items[0][price_data][product_data][description]': `Compra avulsa de caixas de ${theme==='halloween'?'Halloween':'Personalização'} com cores de nome, molduras ou fontes aleatórias. Itens repetidos se convertem em XP.`,
    'line_items[0][quantity]': '1',
    'metadata[profile_id]': profileId,
    'metadata[purchase_kind]': theme==='font'?'font_boxes':theme==='halloween'?'halloween_boxes':'style_boxes',
    'metadata[box_quantity]': String(pack.quantity),
    client_reference_id: profileId,
    success_url: `${origin}/?boxes=paid#temporada`,
    cancel_url: `${origin}/?boxes=cancel#temporada`,
  });
  if (user.email) body.set('customer_email', user.email);
  const response = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${stripeKey}`, 'Content-Type': 'application/x-www-form-urlencoded', 'Idempotency-Key': `boxes-${theme}-${profileId}-${pack.quantity}-${input.requestId}` },
    body,
  });
  const checkout = await response.json();
  if (!response.ok || !checkout.url) {
    console.error('box_checkout', checkout?.error?.message ?? response.status);
    return json({ error: 'Não foi possível abrir o pagamento. Tente novamente.' }, 502);
  }
  return json({ url: checkout.url });
});

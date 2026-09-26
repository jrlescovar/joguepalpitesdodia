import { createClient } from 'npm:@supabase/supabase-js@2';

const allowedOrigins = new Set(['https://jogueapostadodia.web.app', 'https://joguepalpitesdodia.web.app']);

Deno.serve(async request => {
  const origin = request.headers.get('origin') ?? '';
  if (!allowedOrigins.has(origin)) return new Response(JSON.stringify({ error: 'Requisição inválida.' }), { status: 403, headers: { 'Content-Type': 'application/json' } });
  const cors = { 'Access-Control-Allow-Origin': origin, 'Access-Control-Allow-Headers': 'authorization, apikey, x-client-info, content-type', 'Access-Control-Allow-Methods': 'POST, OPTIONS' };
  const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
  if (request.method === 'OPTIONS') return new Response(null, { headers: cors });
  if (request.method !== 'POST') return json({ error: 'Requisição inválida.' }, 403);
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) return json({ error: 'Entre na sua conta.' }, 401);
  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
  const priceId = Deno.env.get('STRIPE_PRICE_ID');
  if (!stripeKey || !priceId) return json({ error: 'Assinaturas ainda não configuradas.' }, 503);
  const auth = createClient(url, anonKey);
  const { data: { user }, error: authError } = await auth.auth.getUser(authorization.slice(7));
  if (authError || !user) return json({ error: 'Sessão expirada.' }, 401);
  const own = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data: profile, error: profileError } = await own.rpc('get_or_claim_profile');
  const profileId = profile?.uid as string | undefined;
  if (profileError || !profileId) return json({ error: 'Crie seu perfil primeiro.' }, 400);
  const db = createClient(url, serviceKey);
  const { data: pass } = await db.from('pass_subscriptions').select('*').eq('profile_id', profileId).maybeSingle();
  if (pass && ['active'].includes(pass.status) && Date.parse(pass.current_period_ends_at ?? '') > Date.now()) {
    return json({ error: 'Seu Passe já está ativo.' }, 409);
  }
  let customerId = pass?.stripe_customer_id as string | undefined;
  if (!customerId) {
    const customer = new URLSearchParams({ email: user.email ?? '', 'metadata[profile_id]': profileId });
    const response = await fetch('https://api.stripe.com/v1/customers', { method: 'POST', headers: { Authorization: `Bearer ${stripeKey}`, 'Content-Type': 'application/x-www-form-urlencoded' }, body: customer });
    const data = await response.json();
    if (!response.ok || !data.id) return json({ error: 'Não foi possível abrir a assinatura.' }, 502);
    customerId = data.id;
    const { error } = await db.from('pass_subscriptions').upsert({ profile_id: profileId, stripe_customer_id: customerId }, { onConflict: 'profile_id' });
    if (error) { console.error('pass_upsert', error); return json({ error: 'Não foi possível preparar a assinatura.' }, 500); }
  }
  const body = new URLSearchParams({
    mode: 'subscription', customer: customerId!,
    'line_items[0][price]': priceId, 'line_items[0][quantity]': '1',
    payment_method_collection: 'always',
    'subscription_data[metadata][profile_id]': profileId,
    client_reference_id: profileId,
    success_url: `${origin}/?pass=success#temporada`,
    cancel_url: `${origin}/?pass=cancel#temporada`,
  });
  const response = await fetch('https://api.stripe.com/v1/checkout/sessions', { method: 'POST', headers: { Authorization: `Bearer ${stripeKey}`, 'Content-Type': 'application/x-www-form-urlencoded', 'Idempotency-Key': `pass-checkout-${profileId}-${Math.floor(Date.now() / 60000)}` }, body });
  const checkout = await response.json();
  if (!response.ok || !checkout.url) return json({ error: 'Não foi possível abrir o pagamento.' }, 502);
  return json({ url: checkout.url });
});

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
  const db = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: pass } = await db.from('pass_subscriptions').select('stripe_customer_id,status,current_period_ends_at').eq('profile_id', profileId).maybeSingle();
  if (pass?.status === 'active' && Date.parse(pass.current_period_ends_at ?? '') > Date.now()) return json({ error: 'Você já tem uma assinatura ativa.' }, 409);
  const { data: prepaid } = await db.from('pass_prepaid').select('ends_at').eq('profile_id', profileId).maybeSingle();
  if (Date.parse(prepaid?.ends_at ?? '') > Date.now()) return json({ error: 'Seu período de 30 dias ainda está ativo.' }, 409);

  const body = new URLSearchParams({
    mode: 'payment',
    'payment_method_types[0]': 'pix',
    'line_items[0][price_data][currency]': 'brl',
    'line_items[0][price_data][unit_amount]': '497',
    'line_items[0][price_data][product_data][name]': 'Premium por 30 dias',
    'line_items[0][price_data][product_data][description]': 'XP 1,5× em todos os ganhos, emblema de apoiador e 5 Caixas de Personalização para abrir itens de nome ou moldura.',
    'line_items[0][quantity]': '1',
    'metadata[profile_id]': profileId,
    'metadata[pass_kind]': 'pix_30_days',
    client_reference_id: profileId,
    success_url: `${origin}/?pass=pix-pending#temporada`,
    cancel_url: `${origin}/?pass=cancel#temporada`,
  });
  if (user.email) body.set('customer_email', user.email);
  const response = await fetch('https://api.stripe.com/v1/checkout/sessions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${stripeKey}`, 'Content-Type': 'application/x-www-form-urlencoded', 'Idempotency-Key': `pass-pix-${profileId}-${Math.floor(Date.now() / 60000)}` },
    body,
  });
  const checkout = await response.json();
  if (!response.ok || !checkout.url) {
    console.error('pass_pix_checkout', checkout?.error?.message ?? response.status);
    return json({ error: 'Não foi possível abrir o Pix. Confira se o Pix está habilitado na Stripe.' }, 502);
  }
  return json({ url: checkout.url });
});

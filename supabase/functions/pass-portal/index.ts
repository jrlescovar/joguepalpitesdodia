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
  const auth = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!);
  const { data: { user }, error } = await auth.auth.getUser(authorization.slice(7));
  if (error || !user) return json({ error: 'Sessão expirada.' }, 401);
  const own = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: authorization } } });
  const { data: profile } = await own.rpc('get_or_claim_profile');
  const profileId = profile?.uid as string | undefined;
  if (!profileId) return json({ error: 'Perfil não encontrado.' }, 404);
  const db = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: pass } = await db.from('pass_subscriptions').select('stripe_customer_id').eq('profile_id', profileId).maybeSingle();
  if (!pass?.stripe_customer_id) return json({ error: 'Assinatura não encontrada.' }, 404);
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
  if (!stripeKey) return json({ error: 'Assinaturas ainda não configuradas.' }, 503);
  const body = new URLSearchParams({ customer: pass.stripe_customer_id, return_url: `${origin}/#temporada` });
  const response = await fetch('https://api.stripe.com/v1/billing_portal/sessions', { method: 'POST', headers: { Authorization: `Bearer ${stripeKey}`, 'Content-Type': 'application/x-www-form-urlencoded' }, body });
  const portal = await response.json();
  if (!response.ok || !portal.url) return json({ error: 'Não foi possível abrir sua assinatura.' }, 502);
  return json({ url: portal.url });
});

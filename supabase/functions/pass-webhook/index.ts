import { createClient } from 'npm:@supabase/supabase-js@2';

const encode = new TextEncoder();
const json = (value: unknown, status = 200) => new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json' } });

async function validSignature(payload: string, header: string, secret: string): Promise<boolean> {
  const parts = Object.fromEntries(header.split(',').map(part => part.split('=', 2)));
  const timestamp = Number(parts.t);
  if (!Number.isFinite(timestamp) || Math.abs(Date.now() / 1000 - timestamp) > 300 || !parts.v1) return false;
  const key = await crypto.subtle.importKey('raw', encode.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const digest = new Uint8Array(await crypto.subtle.sign('HMAC', key, encode.encode(`${timestamp}.${payload}`)));
  const signature = parts.v1.match(/.{2}/g)?.map(pair => Number.parseInt(pair, 16)) ?? [];
  if (signature.length !== digest.length) return false;
  let mismatch = 0;
  digest.forEach((byte, index) => { mismatch |= byte ^ signature[index]; });
  return mismatch === 0;
}

Deno.serve(async request => {
  if (request.method !== 'POST') return json({ error: 'Requisição inválida.' }, 405);
  const secret = Deno.env.get('STRIPE_WEBHOOK_SECRET');
  const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
  const priceId = Deno.env.get('STRIPE_PRICE_ID');
  if (!secret || !stripeKey || !priceId) return json({ error: 'Webhook não configurado.' }, 503);
  const payload = await request.text();
  if (!await validSignature(payload, request.headers.get('stripe-signature') ?? '', secret)) return json({ error: 'Assinatura inválida.' }, 400);
  const event = JSON.parse(payload);
  if (event.type === 'checkout.session.completed' || event.type === 'checkout.session.async_payment_succeeded') {
    const sessionId = event.data?.object?.id;
    if (typeof sessionId === 'string') {
      const checkoutResponse = await fetch(`https://api.stripe.com/v1/checkout/sessions/${encodeURIComponent(sessionId)}`, { headers: { Authorization: `Bearer ${stripeKey}` } });
      if (!checkoutResponse.ok) return json({ error: 'Não foi possível verificar o pagamento.' }, 502);
      const checkout = await checkoutResponse.json();
      if (checkout.mode === 'payment' && ['style_boxes','halloween_boxes','font_boxes'].includes(checkout.metadata?.purchase_kind)) {
        if (checkout.payment_status !== 'paid') return json({ received: true });
        const profileId = checkout.metadata?.profile_id;
        const quantity = Number(checkout.metadata?.box_quantity);
        const halloween=checkout.metadata.purchase_kind==='halloween_boxes';
        const fonts=checkout.metadata.purchase_kind==='font_boxes';
        const expectedAmount = fonts?(quantity===1?321:quantity===3?567:null):halloween?(quantity===2?321:quantity===6?567:null):(quantity===3?321:quantity===7?567:null);
        if (expectedAmount === null || checkout.id !== sessionId || typeof profileId !== 'string' || checkout.client_reference_id !== profileId || checkout.currency !== 'brl' || checkout.amount_total !== expectedAmount) return json({ error: 'Compra de caixas inválida.' }, 400);
        const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
        const { error } = await db.rpc(fonts?'credit_font_box_purchase':halloween?'credit_halloween_box_purchase':'credit_box_purchase', { p_profile_id: profileId, p_session_id: sessionId, p_quantity: quantity, p_amount_cents: expectedAmount });
        if (error) { console.error('credit_box_purchase', error); return json({ error: 'Não foi possível entregar as caixas.' }, 500); }
        return json({ received: true });
      }
      if (checkout.mode === 'payment' && checkout.metadata?.pass_kind === 'pix_30_days') {
        if (checkout.payment_status !== 'paid') return json({ received: true });
        const profileId = checkout.metadata?.profile_id;
        if (checkout.id !== sessionId || checkout.client_reference_id !== profileId || checkout.currency !== 'brl' || checkout.amount_total !== 497 || !checkout.payment_method_types?.includes('pix') || typeof profileId !== 'string') return json({ error: 'Pagamento inválido.' }, 400);
        const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
        const { error } = await db.rpc('activate_prepaid_pix', { p_profile_id: profileId, p_session_id: sessionId });
        if (error) { console.error('activate_prepaid_pix', error); return json({ error: 'Não foi possível liberar o Premium.' }, 500); }
        return json({ received: true });
      }
    }
  }
  if (event.type !== 'checkout.session.completed' && !String(event.type).startsWith('customer.subscription.')) return json({ received: true });
  const subscriptionId = event.type === 'checkout.session.completed' ? event.data.object.subscription : event.data.object.id;
  if (typeof subscriptionId !== 'string') return json({ received: true });
  const response = await fetch(`https://api.stripe.com/v1/subscriptions/${encodeURIComponent(subscriptionId)}`, { headers: { Authorization: `Bearer ${stripeKey}` } });
  const subscription = response.ok ? await response.json() : event.data.object;
  const acceptedPrices = new Set([priceId, 'price_1UJGuTDK92yMyavYBYhioAK7']);
  if (subscription.id !== subscriptionId || !subscription.items?.data?.some((item: { price?: { id?: string } }) => item.price?.id && acceptedPrices.has(item.price.id))) return json({ received: true });
  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  let profileId = subscription.metadata?.profile_id as string | undefined;
  const customerId = typeof subscription.customer === 'string' ? subscription.customer : subscription.customer?.id;
  if (!profileId && customerId) {
    const { data } = await db.from('pass_subscriptions').select('profile_id').eq('stripe_customer_id', customerId).maybeSingle();
    profileId = data?.profile_id;
  }
  if (!profileId || !customerId) return json({ error: 'Assinatura sem perfil.' }, 400);
  const { data: saved } = await db.from('pass_subscriptions').select('stripe_subscription_id,status,current_period_ends_at').eq('profile_id', profileId).maybeSingle();
  if (saved?.stripe_subscription_id && saved.stripe_subscription_id !== subscriptionId && saved.status === 'active' && Date.parse(saved.current_period_ends_at ?? '') > Date.now()) return json({ received: true });
  const currentItem = subscription.items?.data?.find((item: { price?: { id?: string }; current_period_end?: number }) => item.price?.id && acceptedPrices.has(item.price.id));
  const periodSeconds = currentItem?.current_period_end ?? subscription.current_period_end;
  const periodEnd = periodSeconds ? new Date(periodSeconds * 1000).toISOString() : null;
  const { error } = await db.from('pass_subscriptions').upsert({
    profile_id: profileId,
    stripe_customer_id: customerId,
    stripe_subscription_id: subscriptionId,
    status: subscription.status,
    current_period_ends_at: periodEnd,
    cancel_at_period_end: Boolean(subscription.cancel_at_period_end),
    updated_at: new Date().toISOString(),
  }, { onConflict: 'profile_id' });
  if (error) return json({ error: 'Não foi possível salvar a assinatura.' }, 500);
  return json({ received: true });
});

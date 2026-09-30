import { checkoutUrl, cors, origins, ownProfile, product, reply, serviceDb, uuid, type Order } from '../_shared/infinitepay.ts';

Deno.serve(async request => {
  const headers = cors(request);
  if (!origins.has(request.headers.get('origin') ?? '')) return reply({ error: 'Requisição inválida.' }, 403, headers);
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (request.method !== 'POST') return reply({ error: 'Requisição inválida.' }, 405, headers);
  try {
    const input = await request.json().catch(() => null);
    const pack = product(input?.kind, input?.quantity);
    if (!pack || typeof input?.requestId !== 'string' || !uuid.test(input.requestId)) return reply({ error: 'Pacote inválido.' }, 400, headers);
    const profileId = await ownProfile(request);
    if (!profileId) return reply({ error: 'Entre na sua conta e crie seu perfil.' }, 401, headers);
    const handle = Deno.env.get('INFINITEPAY_HANDLE');
    if (!handle || !/^[a-zA-Z0-9_-]{1,80}$/.test(handle)) return reply({ error: 'Pix ainda não configurado.' }, 503, headers);
    const db = serviceDb();
    const { data, error } = await db.rpc('reserve_infinitepay_order', {
      p_profile_id: profileId, p_request_id: input.requestId, p_handle: handle,
      p_kind: pack.kind, p_quantity: pack.quantity, p_amount_cents: pack.amount,
    });
    if (error || !data) return reply({ error: error?.code === 'P0001' ? error.message : 'Não foi possível criar o pedido.' }, 409, headers);
    const order = (Array.isArray(data) ? data[0] : data) as Order;
    if (!order || !uuid.test(order.id) || order.profile_id !== profileId) return reply({ error: 'Pedido inválido.' }, 503, headers);
    if (order.paid_at) return reply({ error: 'Este pedido já foi pago. Atualize seu saldo.' }, 409, headers);
    if (order.checkout_url) return reply({ url: order.checkout_url }, 200, headers);
    const origin = request.headers.get('origin')!;
    const response = await fetch('https://api.checkout.infinitepay.io/links', {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(10000),
      body: JSON.stringify({ handle, order_nsu: order.id, items: [{ quantity: 1, price: pack.amount, description: pack.description }],
        redirect_url: `${origin}/?payment=infinitepay`,
        webhook_url: `${Deno.env.get('SUPABASE_URL')}/functions/v1/infinitepay-webhook` }),
    });
    const checkout = await response.json();
    const url = checkoutUrl(checkout.url);
    if (!response.ok || !url) return reply({ error: 'Não foi possível abrir o Pix. Tente novamente.' }, 502, headers);
    const { error: saveError } = await db.from('infinitepay_orders').update({ checkout_url: url }).eq('id', order.id);
    if (saveError) return reply({ error: 'Não foi possível salvar o pagamento. Tente novamente.' }, 503, headers);
    return reply({ url }, 200, headers);
  } catch { return reply({ error: 'A conexão com o Pix demorou. Tente novamente.' }, 503, headers); }
});

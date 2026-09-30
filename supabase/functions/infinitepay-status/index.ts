import { confirmPayment, cors, origins, ownProfile, reply, serviceDb } from '../_shared/infinitepay.ts';

Deno.serve(async request => {
  const headers = cors(request);
  if (!origins.has(request.headers.get('origin') ?? '')) return reply({ error: 'Requisição inválida.' }, 403, headers);
  if (request.method === 'OPTIONS') return new Response(null, { headers });
  if (request.method !== 'POST') return reply({ error: 'Requisição inválida.' }, 405, headers);
  try {
    const profileId = await ownProfile(request);
    if (!profileId) return reply({ error: 'Entre na sua conta.' }, 401, headers);
    const input = await request.json().catch(() => null);
    if (!input || typeof input !== 'object') return reply({ error: 'Pedido inválido.' }, 400, headers);
    const result = await confirmPayment(serviceDb(), input, profileId);
    return reply(result, result.status, headers);
  } catch { return reply({ error: 'Não foi possível conferir o pagamento. Tente novamente.' }, 503, headers); }
});

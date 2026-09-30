import { confirmPayment, reply, serviceDb } from '../_shared/infinitepay.ts';

Deno.serve(async request => {
  if (request.method !== 'POST') return reply({ error: 'Requisição inválida.' }, 405);
  try {
    const input = await request.json().catch(() => null);
    if (!input || typeof input !== 'object') return reply({ error: 'Requisição inválida.' }, 400);
    const result = await confirmPayment(serviceDb(), input);
    // InfinitePay documents retries on HTTP 400. Never acknowledge a transient
    // failure as success, or a paid player could miss their delivery.
    return reply(result.error ? { error: result.error } : { received: true, paid: result.paid }, result.status === 200 && result.paid ? 200 : 400);
  } catch { return reply({ error: 'Não foi possível verificar o pagamento.' }, 400); }
});

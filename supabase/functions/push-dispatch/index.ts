// Compatibility endpoint for older clients. Notification delivery is retired.
const allowedOrigins = new Set(['https://joguepalpitesdodia.web.app', 'https://jogueapostadodia.web.app']);
Deno.serve(request => {
  const origin = request.headers.get('origin') ?? '';
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': allowedOrigins.has(origin) ? origin : '',
    'Access-Control-Allow-Headers': 'authorization,apikey,content-type,x-client-info',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
  };
  if (request.method === 'OPTIONS') return new Response(null, {status: 204, headers});
  return new Response(JSON.stringify({error: 'O sistema de notificações foi removido.'}), {status: 410, headers});
});
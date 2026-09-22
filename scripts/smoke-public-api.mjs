import { readFileSync } from 'node:fs';

const env = Object.fromEntries(readFileSync('.env', 'utf8').split(/\r?\n/)
  .filter(line => line && !line.startsWith('#') && line.includes('='))
  .map(line => { const index = line.indexOf('='); return [line.slice(0, index), line.slice(index + 1).replace(/^['"]|['"]$/g, '')]; }));
const url = env.VITE_SUPABASE_URL;
const key = env.VITE_SUPABASE_PUBLISHABLE_KEY;
if (!url || !key) throw new Error('Supabase não configurado.');

for (const path of ['/rest/v1/rpc/get_session', '/rest/v1/private_profiles?select=*', '/rest/v1/public_profiles?select=*']) {
  const response = await fetch(`${url}${path}`, {
    method: path.includes('/rpc/') ? 'POST' : 'GET',
    headers: { apikey: key, 'Content-Type': 'application/json' },
    ...(path.includes('/rpc/') ? { body: '{}' } : {}),
  });
  const body = await response.text();
  if (/invalid api key/i.test(body)) throw new Error('Chave pública inválida.');
  if (response.ok) throw new Error(`Acesso anônimo inesperado em ${path}.`);
  console.log(`${path}: bloqueado (${response.status})`);
}

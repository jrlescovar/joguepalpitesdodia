import { readFileSync } from 'node:fs';

let source = '';
try { source = readFileSync('.env', 'utf8'); } catch { /* handled below */ }

const values = Object.fromEntries(source
  .split(/\r?\n/)
  .map(line => line.trim())
  .filter(line => line && !line.startsWith('#') && line.includes('='))
  .map(line => {
    const split = line.indexOf('=');
    return [line.slice(0, split).trim(), line.slice(split + 1).trim().replace(/^['"]|['"]$/g, '')];
  }));

const url = values.VITE_SUPABASE_URL;
const key = values.VITE_SUPABASE_PUBLISHABLE_KEY;
const forbidden = Object.keys(values).filter(name => /SERVICE.?ROLE|SUPABASE_SECRET|DATABASE_URL|DB_PASSWORD|PRIVATE_KEY/i.test(name));
if (forbidden.length) {
  console.error(`Deploy bloqueado: remova credenciais privilegiadas do arquivo .env (${forbidden.join(', ')}).`);
  process.exit(1);
}
if (!url || !/^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(url) || !/^sb_publishable_[A-Za-z0-9_-]{16,}$/.test(key)) {
  console.error('Deploy bloqueado: configure VITE_SUPABASE_URL e VITE_SUPABASE_PUBLISHABLE_KEY no arquivo .env.');
  process.exit(1);
}

console.log('Configuração do Supabase pronta para o deploy.');

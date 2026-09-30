import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

type Game = { day_id: string; slot: number; title: string; status: string; closes_at: string; settled_at: string | null };
type Recipient = { profile_id: string; endpoint: string; p256dh: string; auth_secret: string };

const allowedOrigins = new Set(['https://joguepalpitesdodia.web.app', 'https://jogueapostadodia.web.app']);
const url = Deno.env.get('SUPABASE_URL')!;
const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const vapidPublic = Deno.env.get('PUSH_VAPID_PUBLIC_KEY');
const vapidPrivate = Deno.env.get('PUSH_VAPID_PRIVATE_KEY');
if (vapidPublic && vapidPrivate) webpush.setVapidDetails('mailto:admin@example.invalid', vapidPublic, vapidPrivate);

function json(body: unknown, status = 200, origin = '') {
  return new Response(JSON.stringify(body), { status, headers: {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': allowedOrigins.has(origin) ? origin : '',
    'Access-Control-Allow-Headers': 'authorization,apikey,content-type,x-client-info',
    'Access-Control-Allow-Methods': 'POST,OPTIONS',
  } });
}

function notification(dayId: string) {
  return JSON.stringify({
    title: 'Novos palpites disponíveis',
    body: 'Você tem palpites abertos para fazer. Escolha antes do prazo.',
    url: '/#inicio', tag: `available-${dayId}`,
  });
}

function brasiliaToday() {
  const parts = new Intl.DateTimeFormat('en-US', { timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date());
  const part = (name: string) => parts.find(item => item.type === name)?.value ?? '';
  return `${part('year')}-${part('month')}-${part('day')}`;
}

async function dispatch(games: Game[]) {
  const grouped = new Map<string, { recipient: Recipient; games: Game[] }>();
  for (const game of games) {
    const { data, error } = await admin.rpc('get_push_recipients', { p_kind: 'available', p_day: game.day_id, p_slot: game.slot });
    if (error) throw error;
    for (const recipient of (data ?? []) as Recipient[]) {
      const entry = grouped.get(recipient.endpoint);
      if (entry) entry.games.push(game);
      else grouped.set(recipient.endpoint, { recipient, games: [game] });
    }
  }
  let sent = 0, failed = 0;
  const users = new Set<string>();
  const entries = [...grouped.values()];
  for (let i = 0; i < entries.length; i += 8) {
    await Promise.all(entries.slice(i, i + 8).map(async ({ recipient, games: pendingGames }) => {
      const claims = await Promise.all(pendingGames.map(async game => {
        const args = { p_kind: 'available', p_day: game.day_id, p_slot: game.slot, p_endpoint: recipient.endpoint };
        const claim = await admin.rpc('claim_push_delivery', args);
        if (claim.error) { failed++; return null; }
        return claim.data ? args : null;
      }));
      const claimed = claims.filter((args): args is NonNullable<typeof args> => args !== null);
      if (claimed.length === 0) return;
      try {
        await webpush.sendNotification({ endpoint: recipient.endpoint, keys: { p256dh: recipient.p256dh, auth: recipient.auth_secret } }, notification(pendingGames[0].day_id), { TTL: 3600 });
        await Promise.all(claimed.map(args => admin.rpc('finish_push_delivery', { ...args, p_sent: true })));
        sent++;
        users.add(recipient.profile_id);
      } catch (cause) {
        const status = typeof cause === 'object' && cause && 'statusCode' in cause ? Number(cause.statusCode) : 0;
        if (status === 404 || status === 410) await admin.rpc('remove_dead_push_subscription', { p_endpoint: recipient.endpoint });
        else await Promise.all(claimed.map(args => admin.rpc('finish_push_delivery', { ...args, p_sent: false })));
        failed++;
      }
    }));
  }
  return { sent, failed, users: users.size };
}

Deno.serve(async request => {
  const origin = request.headers.get('origin') ?? '';
  if (request.method === 'OPTIONS') return allowedOrigins.has(origin) ? json({}, 200, origin) : json({ error: 'Origem inválida.' }, 403);
  if (request.method !== 'POST') return json({ error: 'Método inválido.' }, 405, origin);
  if (origin && !allowedOrigins.has(origin)) return json({ error: 'Origem inválida.' }, 403, origin);
  if (!vapidPublic || !vapidPrivate) return json({ error: 'Notificações indisponíveis.' }, 503, origin);
  const input = await request.json().catch(() => null);
  if (!input || typeof input !== 'object') return json({ error: 'Pedido inválido.' }, 400, origin);

  if (input.mode !== 'available-all')
    return json({ error: 'Pedido inválido.' }, 400, origin);
  const bearer = request.headers.get('authorization')?.replace(/^Bearer /i, '');
  if (!bearer) return json({ error: 'Entre como administrador.' }, 401, origin);
  const auth = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!);
  const { data: userData, error: userError } = await auth.auth.getUser(bearer);
  if (userError || !userData.user) return json({ error: 'Sessão expirada.' }, 401, origin);
  const own = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: `Bearer ${bearer}` } } });
  const { data: session, error: sessionError } = await own.rpc('get_session');
  if (sessionError || session?.admin !== true) return json({ error: 'Somente o administrador pode enviar avisos.' }, 403, origin);
  const { data: games, error: gameError } = await admin.rpc('get_push_games_today');
  if (gameError) return json({ error: 'Não foi possível consultar os palpites.' }, 500, origin);
  const today = brasiliaToday();
  const available = ((games ?? []) as Game[]).filter(game => game.day_id === today && game.status === 'open' && Date.parse(game.closes_at) > Date.now());
  if (available.length === 0) return json({ sent: 0, failed: 0, users: 0 }, 200, origin);
  try { return json(await dispatch(available), 200, origin); }
  catch { return json({ error: 'Não foi possível enviar os avisos.' }, 500, origin); }
});

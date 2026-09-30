import { createClient } from 'npm:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3.6.7';

type Kind = 'available' | 'reminder' | 'result';
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

function notification(kind: Kind, game: Game) {
  const label = game.slot === 0 ? 'Palpite do Dia' : `Palpite Extra ${game.slot}`;
  return JSON.stringify({
    title: kind === 'result' ? 'Resultado disponível' : kind === 'reminder' ? 'Seu palpite termina em breve' : 'Novo palpite disponível',
    body: kind === 'result' ? `O resultado de ${label} saiu. Confira no app.` : kind === 'reminder' ? `${label} fecha em menos de 30 minutos. Faça seu palpite.` : `${label} está disponível. Escolha antes do prazo.`,
    url: '/#inicio', tag: `${kind}-${game.day_id}-${game.slot}`,
  });
}

function brasiliaToday() {
  const parts = new Intl.DateTimeFormat('en-US', { timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit' }).formatToParts(new Date());
  const part = (name: string) => parts.find(item => item.type === name)?.value ?? '';
  return `${part('year')}-${part('month')}-${part('day')}`;
}

async function dispatch(kind: Kind, game: Game) {
  const { data, error } = await admin.rpc('get_push_recipients', { p_kind: kind, p_day: game.day_id, p_slot: game.slot });
  if (error) throw error;
  const recipients = (data ?? []) as Recipient[];
  let sent = 0, failed = 0;
  const users = new Set<string>();
  for (let i = 0; i < recipients.length; i += 8) {
    await Promise.all(recipients.slice(i, i + 8).map(async recipient => {
      const args = { p_kind: kind, p_day: game.day_id, p_slot: game.slot, p_endpoint: recipient.endpoint };
      const claim = await admin.rpc('claim_push_delivery', args);
      if (claim.error || !claim.data) { if (claim.error) failed++; return; }
      try {
        await webpush.sendNotification({ endpoint: recipient.endpoint, keys: { p256dh: recipient.p256dh, auth: recipient.auth_secret } }, notification(kind, game), { TTL: 3600 });
        await admin.rpc('finish_push_delivery', { ...args, p_sent: true });
        sent++;
        users.add(recipient.profile_id);
      } catch (cause) {
        const status = typeof cause === 'object' && cause && 'statusCode' in cause ? Number(cause.statusCode) : 0;
        if (status === 404 || status === 410) await admin.rpc('remove_dead_push_subscription', { p_endpoint: recipient.endpoint });
        else await admin.rpc('finish_push_delivery', { ...args, p_sent: false });
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

  if (input.mode === 'scheduled') {
    const expected = Deno.env.get('PUSH_DISPATCH_SECRET');
    if (!expected || request.headers.get('x-push-schedule-secret') !== expected) return json({ error: 'Acesso negado.' }, 403, origin);
    const { data, error } = await admin.rpc('get_push_games_today');
    if (error) return json({ error: 'Não foi possível consultar os palpites.' }, 500, origin);
    let sent = 0, failed = 0;
    const now = Date.now();
    for (const game of (data ?? []) as Game[]) {
      let kind: Kind | null = null;
      const remaining = Date.parse(game.closes_at) - now;
      if (game.status === 'open' && remaining > 0 && remaining <= 30 * 60_000) kind = 'reminder';
      else if (game.status === 'settled' && game.settled_at && now - Date.parse(game.settled_at) < 60 * 60_000) kind = 'result';
      if (kind) { const outcome = await dispatch(kind, game); sent += outcome.sent; failed += outcome.failed; }
    }
    return json({ sent, failed }, 200, origin);
  }

  if (input.mode !== 'available' || typeof input.dayId !== 'string' || !Number.isInteger(input.slot) || input.slot < 0 || input.slot > 9)
    return json({ error: 'Pedido inválido.' }, 400, origin);
  const bearer = request.headers.get('authorization')?.replace(/^Bearer /i, '');
  if (!bearer) return json({ error: 'Entre como administrador.' }, 401, origin);
  const auth = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!);
  const { data: userData, error: userError } = await auth.auth.getUser(bearer);
  if (userError || !userData.user) return json({ error: 'Sessão expirada.' }, 401, origin);
  const own = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, { global: { headers: { Authorization: `Bearer ${bearer}` } } });
  const { data: session, error: sessionError } = await own.rpc('get_session');
  if (sessionError || session?.admin !== true) return json({ error: 'Somente o administrador pode enviar avisos.' }, 403, origin);
  const today = brasiliaToday();
  if (input.dayId !== today) return json({ error: 'Escolha um palpite disponível hoje.' }, 400, origin);
  const { data: games, error: gameError } = await admin.rpc('get_push_games_today');
  const game = ((games ?? []) as Game[]).find(row => row.day_id === input.dayId && row.slot === input.slot);
  if (gameError || !game || game.status !== 'open' || Date.parse(game.closes_at) <= Date.now())
    return json({ error: 'Este palpite não está mais disponível.' }, 400, origin);
  try { return json(await dispatch('available', game as Game), 200, origin); }
  catch { return json({ error: 'Não foi possível enviar os avisos.' }, 500, origin); }
});

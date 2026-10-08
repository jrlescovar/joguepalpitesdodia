import { createClient } from 'npm:@supabase/supabase-js@2';
import { evaluate, matchFixture, type Fixture, type Stats, type Target } from './rules.ts';

const url = Deno.env.get('SUPABASE_URL')!;
const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
async function api<T>(path: string, key: string): Promise<T[]> {
  const result = await fetch(`https://v3.football.api-sports.io/${path}`, { headers: { 'x-apisports-key': key }, signal: AbortSignal.timeout(12000) });
  const json = await result.json();
  if (!result.ok || Object.keys(json.errors ?? {}).length || !Array.isArray(json.response) || json.paging?.total > 1) throw new Error('provider_unavailable');
  return json.response;
}
Deno.serve(async request => {
  if (request.method !== 'POST') return response({ error: 'method' }, 405);
  const secret = Deno.env.get('AUTO_RESULTS_SCHEDULE_SECRET');
  if (!secret || request.headers.get('x-auto-results-secret') !== secret) return response({ error: 'unauthorized' }, 401);
  const key = Deno.env.get('API_FOOTBALL_KEY');
  if (!key) return response({ error: 'API_FOOTBALL_KEY not configured', active: false }, 503);
  const { data: settings, error: settingsError } = await admin.from('automatic_results_settings').select('enabled,mode').eq('singleton', true).single();
  if (settingsError) return response({ error: 'settings_unavailable' }, 503);
  if (!settings.enabled) return response({ active: false });
  // Only one worker can poll at a time; its lease also bounds overlapping cron runs.
  const token = crypto.randomUUID();
  const { data: lease, error: leaseError } = await admin.rpc('claim_automatic_results_run', { p_token: token });
  if (leaseError || !lease) return response({ skipped: 'busy' });
  let checked = 0, suggested = 0, settled = 0, failed = 0;
  const deadline = Date.now() + 100_000;
  try {
    const { data, error } = await admin.rpc('get_automatic_result_targets');
    if (error) throw new Error('targets_unavailable');
    const targets = (data ?? []) as Target[];
    const dates = [...new Set(targets.map(t => t.day))];
    const shots = new Map<number, Stats[]>();
    for (const date of dates) {
      if (Date.now() >= deadline) break;
      // A single fixture lookup per date serves all tickets for that date.
      const fixtures = await api<Fixture>(`fixtures?date=${date}&timezone=America%2FSao_Paulo`, key);
      for (const target of targets.filter(t => t.day === date)) {
        if (Date.now() >= deadline) break;
        checked++;
        const fixture = matchFixture(target, fixtures);
        if (!fixture) {
          await admin.rpc('record_automatic_result_issue', { p_key: target.key, p_issue: 'Partida não identificada com segurança na API.' });
          continue;
        }
        if (fixture.fixture.status.short !== 'FT') continue;
        if (target.kind === 'tournament' && !shots.has(fixture.fixture.id)) shots.set(fixture.fixture.id, await api<Stats>(`fixtures/statistics?fixture=${fixture.fixture.id}`, key));
        const evidence = evaluate(target, fixture, shots.get(fixture.fixture.id));
        if (!evidence) {
          await admin.rpc('record_automatic_result_issue', { p_key: target.key, p_issue: 'Resultado final ou estatísticas incompletas.' });
          continue;
        }
        const outcome = await admin.rpc('observe_automatic_result', { p_target: target, p_evidence: evidence });
        if (outcome.error) { failed++; continue; }
        if (outcome.data?.status === 'suggested') suggested++;
        if (outcome.data?.status === 'settled') settled++;
      }
    }
    return response({ mode: settings.mode, checked, suggested, settled, failed });
  } catch {
    failed++;
    return response({ error: 'Dados indisponíveis. Nenhum resultado foi presumido.', checked, suggested, settled }, 503);
  } finally {
    await admin.rpc('finish_automatic_results_run', { p_token: token, p_summary: { checked, suggested, settled, failed } });
  }
});

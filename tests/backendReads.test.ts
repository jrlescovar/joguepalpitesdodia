import { beforeEach, describe, expect, it, vi } from 'vitest';

const fake = vi.hoisted(() => ({
  rpc: vi.fn(),
  listeners: [] as Array<(event: string, session: { user: { id: string } } | null) => void>,
}));
vi.mock('@supabase/supabase-js', () => ({
  createClient: () => ({
    rpc: fake.rpc,
    auth: { onAuthStateChange: (listener: typeof fake.listeners[number]) => { fake.listeners.push(listener); } },
  }),
}));
vi.stubEnv('VITE_SUPABASE_URL', 'https://example.supabase.co');
vi.stubEnv('VITE_SUPABASE_PUBLISHABLE_KEY', 'test-public-key');
const { call, invalidateReads } = await import('../src/backend');

beforeEach(() => { fake.rpc.mockReset(); invalidateReads(); });
describe('backend read policy', () => {
  it('reuses Apoiador status across components without re-reading the database', async () => {
    fake.rpc.mockResolvedValue({ data: { active: true }, error: null });
    await Promise.all([call('getPassStatus'), call('getPassStatus'), call('getPassStatus')]);
    await call('getPassStatus');
    expect(fake.rpc).toHaveBeenCalledTimes(1);
  });
  it('invalidates status after a reward or profile mutation', async () => {
    fake.rpc.mockResolvedValue({ data: { active: true }, error: null });
    await call('getPassStatus');
    await call('spinDailyWheel', { requestId: 'test' });
    await call('getPassStatus');
    expect(fake.rpc.mock.calls.map(([name]) => name)).toEqual(['get_pass_status', 'spin_daily_wheel', 'get_pass_status']);
  });
  it('clears account-specific data on user changes but retains it on token refresh', async () => {
    fake.rpc.mockResolvedValue({ data: { active: true }, error: null });
    const auth = fake.listeners[0];
    auth('SIGNED_IN', { user: { id: 'one' } });
    await call('getPassStatus');
    auth('TOKEN_REFRESHED', { user: { id: 'one' } });
    await call('getPassStatus');
    expect(fake.rpc).toHaveBeenCalledTimes(1);
    auth('SIGNED_OUT', null);
    auth('SIGNED_IN', { user: { id: 'two' } });
    await call('getPassStatus');
    expect(fake.rpc).toHaveBeenCalledTimes(2);
  });
  it('preserves fresh box balances and prediction timestamp conversion', async () => {
    fake.rpc.mockResolvedValueOnce({ data: [{ dayId: '2026-10-01', slot: 0, title: 'Game', options: [], closesAt: '2026-10-01T12:00:00Z', status: 'open' }], error: null });
    const [a, b] = await Promise.all([call<Array<{ closesAt: { toMillis(): number } }>>('getCurrentPredictions'), call('getCurrentPredictions')]);
    expect(a).toBe(b);
    expect(a[0].closesAt.toMillis()).toBe(Date.parse('2026-10-01T12:00:00Z'));
    fake.rpc.mockResolvedValue({ data: { balance: 3 }, error: null });
    await call('getBoxState');
    await call('getBoxState');
    expect(fake.rpc).toHaveBeenCalledTimes(3);
  });
  it('does not coalesce RPCs that may claim a profile or settle a competition', async () => {
    fake.rpc.mockResolvedValue({ data: {}, error: null });
    await Promise.all([call('getPlayerBootstrap'), call('getPlayerBootstrap'), call('getArena'), call('getArena')]);
    expect(fake.rpc).toHaveBeenCalledTimes(4);
  });
});

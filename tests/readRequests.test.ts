import { afterEach, describe, expect, it, vi } from 'vitest';
import { ReadRequests } from '../src/readRequests';

afterEach(() => vi.useRealTimers());
describe('shared reads', () => {
  it('shares simultaneous calls but re-reads completed data without an explicit TTL', async () => {
    const reads = new ReadRequests();
    const fetch = vi.fn(async () => ({ balance: 2 }));
    const first = reads.run('boxes', fetch);
    const second = reads.run('boxes', fetch);
    expect(second).toBe(first);
    await Promise.all([first, second]);
    await reads.run('boxes', fetch);
    expect(fetch).toHaveBeenCalledTimes(2);
  });
  it('reuses a short-lived result then fetches after expiry', async () => {
    vi.useFakeTimers();
    const reads = new ReadRequests();
    const fetch = vi.fn(async () => ({ active: true }));
    await reads.run('pass', fetch, 15000);
    vi.advanceTimersByTime(14999);
    await reads.run('pass', fetch, 15000);
    expect(fetch).toHaveBeenCalledTimes(1);
    vi.advanceTimersByTime(1);
    await reads.run('pass', fetch, 15000);
    expect(fetch).toHaveBeenCalledTimes(2);
  });
  it('does not cache failures', async () => {
    const reads = new ReadRequests();
    const fetch = vi.fn().mockRejectedValueOnce(new Error('offline')).mockResolvedValueOnce(3);
    await expect(reads.run('pass', fetch, 15000)).rejects.toThrow('offline');
    await expect(reads.run('pass', fetch, 15000)).resolves.toBe(3);
    expect(fetch).toHaveBeenCalledTimes(2);
  });
  it('does not let an old request refill the cache after a mutation or account change', async () => {
    const reads = new ReadRequests();
    let resolveOld!: (value: string) => void;
    const first = reads.run('pass', () => new Promise<string>(resolve => { resolveOld = resolve; }), 15000);
    await Promise.resolve();
    reads.clear();
    const current = vi.fn(async () => 'new');
    await reads.run('pass', current, 15000);
    resolveOld('old');
    await first;
    await expect(reads.run('pass', current, 15000)).resolves.toBe('new');
    expect(current).toHaveBeenCalledTimes(1);
    reads.clear();
    await reads.run('pass', current, 15000);
    expect(current).toHaveBeenCalledTimes(2);
  });
});

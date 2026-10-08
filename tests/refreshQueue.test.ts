import { describe, expect, it, vi } from 'vitest';
import { refreshQueue } from '../src/refreshQueue';

describe('profile refresh queue', () => {
  it('collapses a burst but re-reads changes requested during the first refresh', async () => {
    let finish!: () => void;
    const run = vi.fn().mockImplementationOnce(() => new Promise<void>(resolve => { finish = resolve; })).mockResolvedValue(undefined);
    const refresh = refreshQueue(run);
    const first = refresh();
    expect(refresh()).toBe(first);
    expect(refresh()).toBe(first);
    expect(run).toHaveBeenCalledTimes(1);
    finish();
    await first;
    expect(run).toHaveBeenCalledTimes(2);
    await refresh();
    expect(run).toHaveBeenCalledTimes(3);
  });
  it('releases the queue after a failure so retry is possible', async () => {
    const run = vi.fn().mockRejectedValueOnce(new Error('offline')).mockResolvedValue(undefined);
    const refresh = refreshQueue(run);
    await expect(refresh()).rejects.toThrow('offline');
    await refresh();
    expect(run).toHaveBeenCalledTimes(2);
  });
});

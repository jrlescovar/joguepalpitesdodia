import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { pollWhileVisible } from '../src/visiblePolling';

beforeEach(() => vi.useFakeTimers());
afterEach(() => vi.useRealTimers());
describe('visible polling', () => {
  it('stops requesting once the Arena is finished', async () => {
    const run = vi.fn(async () => false);
    const stop = pollWhileVisible(run, 30000, () => true);
    await vi.advanceTimersByTimeAsync(300000);
    expect(run).toHaveBeenCalledTimes(1);
    stop();
  });
  it('skips hidden periods and resumes on the next visible tick', async () => {
    let visible = false;
    const run = vi.fn(async () => true);
    const stop = pollWhileVisible(run, 30000, () => visible);
    await vi.advanceTimersByTimeAsync(60000);
    expect(run).toHaveBeenCalledTimes(1);
    visible = true;
    await vi.advanceTimersByTimeAsync(30000);
    expect(run).toHaveBeenCalledTimes(2);
    stop();
  });
  it('never overlaps slow requests and schedules no work after unmount', async () => {
    let finish!: (value: boolean) => void;
    const run = vi.fn(() => new Promise<boolean>(resolve => { finish = resolve; }));
    const stop = pollWhileVisible(run, 30000, () => true);
    await vi.advanceTimersByTimeAsync(120000);
    expect(run).toHaveBeenCalledTimes(1);
    stop();
    finish(true);
    await vi.advanceTimersByTimeAsync(120000);
    expect(run).toHaveBeenCalledTimes(1);
  });
  it('allows retry after a transient failure', async () => {
    const run = vi.fn().mockRejectedValueOnce(new Error('offline')).mockResolvedValueOnce(false);
    const stop = pollWhileVisible(run, 30000, () => true);
    await vi.advanceTimersByTimeAsync(60000);
    expect(run).toHaveBeenCalledTimes(2);
    stop();
  });
});

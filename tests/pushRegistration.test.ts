import { afterEach, describe, expect, it, vi } from 'vitest';
import { activePushRegistration } from '../src/pushRegistration';

afterEach(() => vi.useRealTimers());
describe('push worker activation', () => {
  it('waits for a first installation before allowing subscription', async () => {
    const registered = {scope:'https://app.test/',active:null} as unknown as ServiceWorkerRegistration;
    const activated = {scope:registered.scope,active:{state:'activated'}} as unknown as ServiceWorkerRegistration;
    let activate!: (value:ServiceWorkerRegistration) => void;
    const ready = new Promise<ServiceWorkerRegistration>(resolve => { activate=resolve; });
    let completed=false;
    const result=activePushRegistration({register:vi.fn().mockResolvedValue(registered),ready}).then(value=>{completed=true;return value;});
    await Promise.resolve(); await Promise.resolve();
    expect(completed).toBe(false);
    activate(activated);
    expect(await result).toBe(activated);
  });
  it('uses an already active worker immediately', async () => {
    const active={scope:'https://app.test/',active:{state:'activated'}} as unknown as ServiceWorkerRegistration;
    expect(await activePushRegistration({register:vi.fn().mockResolvedValue(active),ready:new Promise(()=>{})})).toBe(active);
  });
  it('ends a stalled activation so the user can retry', async () => {
    vi.useFakeTimers();
    const result=activePushRegistration({register:vi.fn().mockResolvedValue({scope:'https://app.test/'}),ready:new Promise(()=>{})});
    const check=expect(result).rejects.toThrow('demorou');
    await vi.advanceTimersByTimeAsync(15000);
    await check;
    expect(vi.getTimerCount()).toBe(0);
  });
});

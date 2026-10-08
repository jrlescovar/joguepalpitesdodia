import {describe, expect, it, vi} from 'vitest';
import {retirePushNotifications} from '../src/retirePushNotifications';

function registration(scriptURL: string) {
  const close = vi.fn(), unsubscribe = vi.fn().mockResolvedValue(true);
  return {active:{scriptURL},waiting:null,installing:null,
    getNotifications:vi.fn().mockResolvedValue([{close}]),
    pushManager:{getSubscription:vi.fn().mockResolvedValue({unsubscribe})},
    unregister:vi.fn().mockResolvedValue(true),close,unsubscribe};
}
describe('retired notifications', () => {
  it('closes notifications, unsubscribes and unregisters only the former push worker', async () => {
    const push=registration('https://app.test/push-sw.js'),other=registration('https://app.test/offline-sw.js');
    const getRegistrations=vi.fn().mockResolvedValue([push,other]);
    await retirePushNotifications({getRegistrations});
    expect(push.close).toHaveBeenCalledOnce();expect(push.unsubscribe).toHaveBeenCalledOnce();
    expect(push.unregister).toHaveBeenCalledOnce();expect(other.getNotifications).not.toHaveBeenCalled();
    expect(other.unregister).not.toHaveBeenCalled();
  });
  it('still removes the worker if subscription cleanup fails', async () => {
    const push=registration('https://app.test/push-sw.js');
    push.pushManager.getSubscription.mockRejectedValue(new Error('Browser failure'));
    await retirePushNotifications({getRegistrations:vi.fn().mockResolvedValue([push])});
    expect(push.unregister).toHaveBeenCalledOnce();
  });
  it('does not prevent startup when service worker access fails', async () => {
    await expect(retirePushNotifications({getRegistrations:vi.fn().mockRejectedValue(new Error('Browser failure'))})).resolves.toBeUndefined();
  });
});

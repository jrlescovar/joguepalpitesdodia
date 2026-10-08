/** Retire only this app's former push worker; leave other workers alone. */
export async function retirePushNotifications(container: Pick<ServiceWorkerContainer, 'getRegistrations'>) {
  try {
    const registrations = await container.getRegistrations();
    await Promise.all(registrations.map(async registration => {
      const workers = [registration.active, registration.waiting, registration.installing];
      if (!workers.some(worker => worker && new URL(worker.scriptURL).pathname === '/push-sw.js')) return;
      try {
        const notifications = await registration.getNotifications();
        notifications.forEach(notification => notification.close());
        const subscription = await registration.pushManager.getSubscription();
        await subscription?.unsubscribe();
      } catch { /* Unregister even when the browser cannot clean up its subscription. */ }
      await registration.unregister();
    }));
  } catch { /* Cleanup must not prevent the app from loading. */ }
}

// Kept at the former URL so installed copies can update and retire themselves.
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    try {
      const notifications = await self.registration.getNotifications();
      notifications.forEach(notification => notification.close());
      const subscription = await self.registration.pushManager.getSubscription();
      await subscription?.unsubscribe();
    } finally {
      await self.registration.unregister();
    }
  })());
});
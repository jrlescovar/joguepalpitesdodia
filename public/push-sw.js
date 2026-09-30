self.addEventListener('install', event => { event.waitUntil(self.skipWaiting()); });
self.addEventListener('activate', event => { event.waitUntil(self.clients.claim()); });
self.addEventListener('push', event => {
  let message = {};
  try { message = event.data?.json() ?? {}; } catch { message = {}; }
  const title = typeof message.title === 'string' ? message.title : 'Palpitesdodia';
  const body = typeof message.body === 'string' ? message.body : 'Abra o app para conferir.';
  const target = typeof message.url === 'string' && message.url.startsWith('/#') ? message.url : '/#inicio';
  event.waitUntil(self.registration.showNotification(title, {
    body, icon: '/icon-192.png', badge: '/icon-192.png',
    tag: typeof message.tag === 'string' ? message.tag : undefined,
    data: { target },
  }));
});

self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target = event.notification.data?.target ?? '/#inicio';
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const existing = windows.find(client => new URL(client.url).origin === self.location.origin);
    if (existing) { await existing.navigate(target); await existing.focus(); }
    else await self.clients.openWindow(target);
  })());
});

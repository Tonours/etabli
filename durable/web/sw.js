// No fetch handler or CacheStorage: credentials and run data stay online only.
self.addEventListener("push", (event) => {
  event.waitUntil(self.registration.showNotification("Etabli", {
    body: "A run finished or needs your attention. Open Etabli to check.",
    icon: "/icon-192.png",
  }));
});
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  event.waitUntil((async () => {
    const windows = await self.clients.matchAll({ type: "window" });
    const existing = windows.find((client) => new URL(client.url).origin === self.location.origin);
    if (existing) await existing.focus();
    else await self.clients.openWindow("/");
  })());
});

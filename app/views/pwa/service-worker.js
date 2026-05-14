// COMUNIA service worker — cache-first para assets estáticos,
// network-first para navegación HTML, con fallback offline básico.

const VERSION = "comunia-v2";
const STATIC_CACHE = `${VERSION}-static`;
const RUNTIME_CACHE = `${VERSION}-runtime`;
const OFFLINE_FALLBACK = "/offline.html";

const PRECACHE_URLS = [
  "/icon.png",
  "/icon.svg",
  OFFLINE_FALLBACK,
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => cache.addAll(PRECACHE_URLS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => !k.startsWith(VERSION))
          .map((k) => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

// Solo manejamos GET. Auth/POST/PATCH/DELETE pasan directos al network.
self.addEventListener("fetch", (event) => {
  const { request } = event;
  if (request.method !== "GET") return;

  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  // Navegaciones HTML → network-first, fallback al cache, último recurso offline page.
  if (request.mode === "navigate") {
    event.respondWith(
      fetch(request)
        .then((response) => {
          const copy = response.clone();
          caches.open(RUNTIME_CACHE).then((cache) => cache.put(request, copy));
          return response;
        })
        .catch(() =>
          caches.match(request).then((cached) => cached || caches.match(OFFLINE_FALLBACK))
        )
    );
    return;
  }

  // Assets fingerprinted (`/assets/*-<hash>.{css,js,png,...}`) → cache-first.
  // Estos archivos son inmutables: si el contenido cambia, el hash cambia y
  // la URL es distinta, por lo que es seguro cachearlos indefinidamente.
  const isFingerprintedAsset = url.pathname.startsWith("/assets/");

  if (
    isFingerprintedAsset ||
    request.destination === "script" ||
    request.destination === "style" ||
    request.destination === "image" ||
    request.destination === "font"
  ) {
    event.respondWith(
      caches.match(request).then((cached) => {
        if (cached) return cached;
        return fetch(request).then((response) => {
          if (response.ok) {
            const copy = response.clone();
            caches.open(STATIC_CACHE).then((cache) => cache.put(request, copy));
          }
          return response;
        }).catch(() => cached);
      })
    );
  }
});

// ── Push Notifications ──────────────────────────────────────
self.addEventListener("push", (event) => {
  const data = event.data ? event.data.json() : {};
  const title = data.title || "COMUNIA";
  const options = {
    body: data.body || "",
    icon: "/icon.png",
    badge: "/icon.png",
    data: { url: data.url || "/dashboard" },
    tag: data.tag || "comunia-default",
    renotify: true,
  };

  event.waitUntil(
    self.registration.showNotification(title, options).then(() => {
      if (data.badge_count !== undefined && navigator.setAppBadge) {
        navigator.setAppBadge(data.badge_count);
      }
    })
  );
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = event.notification.data?.url || "/dashboard";

  event.waitUntil(
    clients.matchAll({ type: "window", includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if ("focus" in client) {
          client.navigate(url);
          return client.focus();
        }
      }
      return clients.openWindow(url);
    })
  );
});

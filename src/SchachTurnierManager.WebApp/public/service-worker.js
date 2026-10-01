// Cache-policy namespace, not an application/release version. Never read legacy data.
const CACHE_NAME = 'schach-turnier-manager-public-shell';
// Two exact slots: a new worker fills the inactive slot completely and activation
// switches to it, so a failed update never mixes old and new shell files. Only these
// exact names are ever opened or deleted; caches are never enumerated.
const SLOTS = { a: `${CACHE_NAME}-a`, b: `${CACHE_NAME}-b` };
const STATE_CACHE = `${CACHE_NAME}-state`;
const LEGACY_CACHE_NAME = 'schach-turnier-manager-shell-v0.45.0';
const APP_SHELL = ['/', '/index.html', '/manifest.webmanifest', '/icons/stm-icon.svg', '/icons/stm-maskable.svg'];
const internalRequest = path => new Request(new URL(path, self.location.origin).href);
const COMPLETE_MARKER = '/__stm-shell/complete';

async function readSlot(name) {
  const cache = await caches.open(STATE_CACHE);
  const value = await cache.match(internalRequest(`/__stm-shell/${name}`));
  const slot = value ? (await value.text()).trim() : '';
  return Object.prototype.hasOwnProperty.call(SLOTS, slot) ? slot : null;
}

async function writeSlot(name, slot) {
  const cache = await caches.open(STATE_CACHE);
  await cache.put(internalRequest(`/__stm-shell/${name}`), new Response(slot));
}

async function activeCacheName() {
  return SLOTS[(await readSlot('active')) ?? 'a'];
}

function resourceKind(url) {
  if (url.origin !== self.location.origin || url.search || url.hash) return null;
  if (url.pathname === '/' || url.pathname === '/index.html') return 'html';
  if (url.pathname === '/manifest.webmanifest') return 'manifest';
  if (url.pathname === '/icons/stm-icon.svg' || url.pathname === '/icons/stm-maskable.svg') return 'svg';
  // Only build-owned JS/CSS; never arbitrary JSON, source maps, exports or API paths.
  const asset = /^\/assets\/[a-zA-Z0-9_-]+(?:\.[a-zA-Z0-9_-]+)*\.(js|css)$/.exec(url.pathname);
  return asset ? asset[1] : null;
}

function publicResponse(response, kind) {
  if (!response || response.status !== 200 || response.type !== 'basic' || response.redirected) return false;
  const directives = (response.headers.get('cache-control') || '').toLowerCase();
  if (/(?:^|,)\s*(?:private|no-store|no-cache)(?:\s|=|,|$)/.test(directives)) return false;
  const vary = (response.headers.get('vary') || '').toLowerCase().split(',').map(value => value.trim());
  if (vary.some(value => ['*', 'cookie', 'authorization'].includes(value))) return false;
  const contentType = (response.headers.get('content-type') || '').split(';', 1)[0].trim().toLowerCase();
  const types = {
    html: ['text/html'],
    manifest: ['application/manifest+json', 'application/json'],
    svg: ['image/svg+xml'],
    js: ['text/javascript', 'application/javascript'],
    css: ['text/css'],
  };
  return types[kind]?.includes(contentType) === true;
}

async function cacheRead(request, kind) {
  try {
    const cache = await caches.open(await activeCacheName());
    const response = await cache.match(request);
    return publicResponse(response, kind) ? response : undefined;
  } catch {
    return undefined; // Denied/unavailable storage must not break online operation.
  }
}

async function cacheUpdate(request, response, kind) {
  try {
    const cache = await caches.open(await activeCacheName());
    if (publicResponse(response, kind)) await cache.put(request, response.clone());
    else await cache.delete(request); // Do not keep a now-private or failed resource offline.
  } catch {
    // Quota or storage errors do not turn a successful network response into a failure.
  }
}

async function networkFirst(request, kind) {
  try {
    const response = await fetch(request);
    await cacheUpdate(request, response, kind);
    return response; // HTTP errors remain errors; only transport failures use offline data.
  } catch {
    const cached = await cacheRead(request, kind);
    if (cached) return cached;
    return offlineResponse();
  }
}

function offlineResponse() {
  return new Response('Offline: Diese App-Datei ist noch nicht lokal verfuegbar. Bitte den Turnierrechner verbinden und erneut laden.', {
    status: 503,
    headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' },
  });
}

// QR links (/?dice=...&round=...&board=...) are navigations with a query: never cached,
// but a transport failure must still end in the controlled offline message.
async function networkOnlyNavigation(request) {
  try { return await fetch(request); } catch { return offlineResponse(); }
}

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    // Validate all responses before writing. Never pre-cache a login redirect or private response.
    const fetchPublic = async path => {
      const url = new URL(path, self.location.origin);
      const request = new Request(url.href, { credentials: 'omit', redirect: 'error', cache: 'no-cache' });
      const response = await fetch(request);
      if (!publicResponse(response, resourceKind(url))) throw new Error('Public app shell unavailable.');
      return [request, response];
    };
    const shellEntries = await Promise.all(APP_SHELL.map(fetchPublic));
    // The new slot must also hold the build bundles its index.html references; the old slot
    // (with the previous bundles) is removed at activation. Only allowlisted /assets/*.js|css.
    const [, indexResponse] = shellEntries.find(([request]) => new URL(request.url).pathname === '/index.html');
    const html = await indexResponse.clone().text();
    const bundles = [...new Set([...html.matchAll(/(?:src|href)="(\/assets\/[^"?#]+)"/g)].map(match => match[1]))]
      .filter(path => ['js', 'css'].includes(resourceKind(new URL(path, self.location.origin))));
    const entries = [...shellEntries, ...await Promise.all(bundles.map(fetchPublic))];
    // Fill the inactive slot from empty; the active slot keeps serving until activation.
    const staging = (await readSlot('active')) === 'b' ? 'a' : 'b';
    await caches.delete(SLOTS[staging]);
    try {
      const cache = await caches.open(SLOTS[staging]);
      for (const [request, response] of entries) await cache.put(request, response);
      await cache.put(internalRequest(COMPLETE_MARKER), new Response('complete'));
      await writeSlot('pending', staging);
    } catch (error) {
      try { await caches.delete(SLOTS[staging]); } catch { /* Best effort; it is never marked complete. */ }
      throw error; // The new worker does not install; the active shell stays untouched.
    }
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    // Delete only the exact cache owned by the previous implementation, never other apps.
    try { await caches.delete(LEGACY_CACHE_NAME); } catch { /* Storage may be unavailable. */ }
    try {
      const pending = await readSlot('pending');
      if (pending) {
        const slot = await caches.open(SLOTS[pending]);
        if (await slot.match(internalRequest(COMPLETE_MARKER))) {
          await writeSlot('active', pending);
          await caches.delete(SLOTS[pending === 'a' ? 'b' : 'a']);
        }
        const state = await caches.open(STATE_CACHE);
        await state.delete(internalRequest('/__stm-shell/pending'));
      }
    } catch { /* Storage may be unavailable; the previously active slot stays in use. */ }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  const request = event.request;
  if (request.method !== 'GET' || request.cache === 'no-store'
      || request.headers.has('authorization') || request.headers.has('range')) return;
  let url;
  try { url = new URL(request.url); } catch { return; }
  if (request.mode === 'navigate' && url.origin === self.location.origin && url.pathname === '/' && url.search && !url.hash) {
    const navigation = networkOnlyNavigation(request);
    event.respondWith(navigation);
    event.waitUntil(navigation.then(() => undefined, () => undefined));
    return;
  }
  const kind = resourceKind(url);
  if (!kind || (request.mode === 'navigate' && kind !== 'html')) return;
  const response = networkFirst(request, kind);
  event.respondWith(response);
  // Register synchronously and include cache writes in the fetch event's lifetime.
  event.waitUntil(response.then(() => undefined, () => undefined));
});

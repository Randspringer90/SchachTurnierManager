import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { runInNewContext } from 'node:vm';

const source = readFileSync(new URL('../../src/SchachTurnierManager.WebApp/public/service-worker.js', import.meta.url), 'utf8');
const origin = 'https://synthetic.invalid';
// Two exact slots; without a recorded state slot "a" is active.
const current = 'schach-turnier-manager-public-shell-a';
const otherSlot = 'schach-turnier-manager-public-shell-b';
const stateCache = 'schach-turnier-manager-public-shell-state';
const legacy = 'schach-turnier-manager-shell-v0.45.0';
const key = value => new URL(typeof value === 'string' ? value : value.url, origin).href;
function response(body = 'synthetic', { status = 200, type = 'basic', redirected = false, headers = {} } = {}) {
  const result = new Response(body, { status, headers: { 'Content-Type': 'text/javascript', ...headers } });
  Object.defineProperties(result, { type: { value: type }, redirected: { value: redirected } });
  result.clone = () => response(body, { status, type, redirected, headers });
  return result;
}
function request(path, options = {}) {
  return { url: new URL(path, origin).href, method: 'GET', mode: 'cors', cache: 'default', headers: new Headers(), ...options };
}
function harness(options = {}) {
  const listeners = new Map(); const stores = new Map(); const calls = [];
  const state = { skips: 0, claims: 0, deleted: [], puts: [], failOpen: false, failRead: false, failPut: false, failDelete: false };
  const cache = name => {
    if (!stores.has(name)) stores.set(name, new Map());
    return {
      async match(req) { if (state.failRead) throw Error('read'); return stores.get(name).get(key(req))?.clone(); },
      async put(req, value) { if (state.failPut) throw Error('quota'); state.puts.push(key(req)); stores.get(name).set(key(req), value.clone()); },
      async delete(req) { return stores.get(name).delete(key(req)); },
    };
  };
  const self = { location: { origin }, addEventListener: (type, listener) => listeners.set(type, listener),
    async skipWaiting() { state.skips++; }, clients: { async claim() { state.claims++; } } };
  const context = { self, URL, Request, Response, fetch: async req => { calls.push(req); return options.fetch ? options.fetch(req) : response(); },
    caches: {
      async open(name) { if (state.failOpen) throw Error('denied'); return cache(name); },
      async delete(name) { if (state.failDelete) throw Error('denied'); state.deleted.push(name); return stores.delete(name); },
      async match() { throw Error('Cross-cache lookup is forbidden.'); },
      async keys() { throw Error('Global cache sweeping is forbidden.'); },
    } };
  runInNewContext(source, context, { filename: 'service-worker.js', timeout: 1000 });
  return { state, stores, calls,
    async seed(name, path, value) { await cache(name).put(request(path), value); state.puts = []; },
    async lifecycle(type) { const waits = []; listeners.get(type)({ waitUntil: promise => waits.push(promise) }); await Promise.all(waits); },
    dispatch(req) { let result; const waits = []; listeners.get('fetch')({ request: req, respondWith: promise => { result = promise; }, waitUntil: promise => waits.push(promise) }); return { result, waits }; },
  };
}
const offline = () => { throw Error('network offline'); };

for (const path of ['/api', '/api/', '/api/health', '/API/health', '/%61pi/health', '/export.csv', '/backup.json', '/.env', '/unrelated', '/assets/map.js.map', '/assets/players.json', '/assets/data.csv', '/assets/a/b.js', '/assets/%61.js', '/assets/app.js?token=synthetic', '/?token=synthetic', 'https://elsewhere.invalid/assets/app.js']) {
  test(`does not intercept ${path}`, () => {
    const app = harness(); const event = app.dispatch(request(path));
    assert.equal(event.result, undefined); assert.equal(event.waits.length, 0); assert.equal(app.calls.length, 0);
  });
}
for (const options of [ { method: 'POST' }, { method: 'PUT' }, { method: 'DELETE' }, { method: 'HEAD' }, { cache: 'no-store' }, { headers: new Headers({ Authorization: 'synthetic' }) }, { headers: new Headers({ Range: 'bytes=0-10' }) }, { mode: 'navigate' } ]) {
  test(`bypasses non-public request ${JSON.stringify(options)}`, () => {
    const event = harness().dispatch(request('/assets/app-abc.js', options)); assert.equal(event.result, undefined);
  });
}
test('malformed request URL is not intercepted', () => assert.equal(harness().dispatch(request('/', { url: 'not a URL' })).result, undefined));

test('online navigation cannot replace completed v1 HTML with uninstalled v2 bundles', async () => {
  let online = true;
  const app = harness({ fetch: () => online ? response('<script src="/assets/v2.js"></script>', { headers: { 'Content-Type': 'text/html' } }) : offline() });
  await app.seed(current, '/__stm-shell/complete', response('complete'));
  await app.seed(current, '/', response('<script src="/assets/v1.js"></script>', { headers: { 'Content-Type': 'text/html' } }));
  await app.seed(current, '/assets/v1.js', response('v1 bundle'));
  assert.match(await (await app.dispatch(request('/', { mode: 'navigate' })).result).text(), /v1\.js/);
  online = false;
  assert.match(await (await app.dispatch(request('/', { mode: 'navigate' })).result).text(), /v1\.js/);
  assert.equal(await (await app.dispatch(request('/assets/v1.js')).result).text(), 'v1 bundle');
  assert.deepEqual(app.calls.map(req => new URL(req.url).pathname), ['/assets/v1.js']);
});

test('startup guard files have exact public allowlist entries', async () => {
  for (const [path, mime] of [['/startup-guard.js', 'text/javascript'], ['/startup-guard.css', 'text/css']]) {
    const app = harness({ fetch: offline });
    await app.seed(current, path, response('guard', { headers: { 'Content-Type': mime } }));
    assert.equal(await (await app.dispatch(request(path)).result).text(), 'guard');
    assert.equal(app.dispatch(request(path + '?private=synthetic')).result, undefined);
  }
});

for (const [path, mime, mode] of [ ['/', 'text/html', 'navigate'], ['/index.html', 'text/html', 'navigate'], ['/manifest.webmanifest', 'application/manifest+json', 'cors'], ['/icons/stm-icon.svg', 'image/svg+xml', 'cors'], ['/icons/stm-maskable.svg', 'image/svg+xml', 'cors'], ['/assets/index-A_9.js', 'text/javascript', 'cors'], ['/assets/index.A_9.css', 'text/css', 'cors'] ]) {
  test(`stores only public resource ${path}`, async () => {
    const app = harness({ fetch: () => response('new', { headers: { 'Content-Type': mime } }) });
    const event = app.dispatch(request(path, { mode })); assert.equal(event.waits.length, 1);
    assert.equal(await (await event.result).text(), 'new'); await Promise.all(event.waits);
    assert.deepEqual(app.state.puts, mime === 'text/html' ? [] : [key(path)]);
  });
}
for (const metadata of [ { status: 401 }, { status: 403 }, { status: 404 }, { status: 500 }, { type: 'cors' }, { type: 'opaque' }, { redirected: true }, { headers: { 'Cache-Control': 'private' } }, { headers: { 'Cache-Control': 'PUBLIC, private="field"' } }, { headers: { 'Cache-Control': 'max-age=0, no-store' } }, { headers: { 'Cache-Control': 'no-cache' } }, { headers: { Vary: '*' } }, { headers: { Vary: 'Accept-Encoding, Cookie' } }, { headers: { Vary: 'Authorization' } }, { headers: { 'Content-Type': 'application/json' } }, { headers: { 'Content-Type': 'text/html' } } ]) {
  test(`does not store unsafe response ${JSON.stringify(metadata)}`, async () => {
    const app = harness({ fetch: () => response('network', metadata) });
    await app.seed(current, '/assets/app.js', response('old'));
    const event = app.dispatch(request('/assets/app.js')); const result = await event.result;
    assert.equal(await result.text(), 'network'); assert.equal(result.status, metadata.status ?? 200);
    await Promise.all(event.waits); assert.deepEqual(app.state.puts, []);
    assert.equal(app.stores.get(current).has(key('/assets/app.js')), false);
  });
}
test('online response replaces previously cached resource', async () => {
  const app = harness({ fetch: () => response('new') }); await app.seed(current, '/assets/app.js', response('old'));
  const event = app.dispatch(request('/assets/app.js')); assert.equal(await (await event.result).text(), 'new');
  assert.equal(await app.stores.get(current).get(key('/assets/app.js')).text(), 'new');
});
test('offline reads only current cache, never legacy or another app', async () => {
  const app = harness({ fetch: offline });
  await app.seed('other-app', '/assets/app.js', response('other')); await app.seed(legacy, '/assets/app.js', response('legacy'));
  const result = await app.dispatch(request('/assets/app.js')).result;
  assert.equal(result.status, 503); assert.match(await result.text(), /Offline:/);
});
test('offline returns cached public resource', async () => {
  const app = harness({ fetch: offline }); await app.seed(current, '/assets/app.js', response('public'));
  assert.equal(await (await app.dispatch(request('/assets/app.js')).result).text(), 'public');
});
test('offline does not trust private content even inside current cache', async () => {
  const app = harness({ fetch: offline }); await app.seed(current, '/assets/app.js', response('private', { headers: { 'Cache-Control': 'private' } }));
  assert.equal((await app.dispatch(request('/assets/app.js')).result).status, 503);
});
test('uncached navigation produces a real no-store 503 response', async () => {
  const result = await harness({ fetch: offline }).dispatch(request('/', { mode: 'navigate' })).result;
  assert.ok(result instanceof Response); assert.equal(result.status, 503); assert.equal(result.headers.get('cache-control'), 'no-store');
});
for (const failure of ['failOpen', 'failPut']) {
  test(`${failure} does not break successful network response`, async () => {
    const app = harness(); app.state[failure] = true;
    const event = app.dispatch(request('/assets/app.js')); assert.equal((await event.result).status, 200); await Promise.all(event.waits);
  });
}
for (const failure of ['failOpen', 'failRead']) {
  test(`${failure} offline returns controlled 503`, async () => {
    const app = harness({ fetch: offline }); app.state[failure] = true;
    const event = app.dispatch(request('/assets/app.js')); assert.equal((await event.result).status, 503); await Promise.all(event.waits);
  });
}
test('activation deletes only exact legacy cache and claims clients', async () => {
  const app = harness(); for (const name of [legacy, current, 'other-app', `${legacy}-foreign`]) await app.seed(name, '/assets/app.js', response());
  await app.lifecycle('activate'); assert.deepEqual(app.state.deleted, [legacy]); assert.equal(app.state.claims, 1);
  assert.deepEqual([...app.stores.keys()].sort(), [current, 'other-app', `${legacy}-foreign`, stateCache].sort());
});
test('activation survives denied cache storage', async () => {
  const app = harness(); app.state.failDelete = true; await app.lifecycle('activate'); assert.equal(app.state.claims, 1);
});
const shellMime = req => req.url.endsWith('.svg') ? 'image/svg+xml' : req.url.endsWith('.webmanifest') ? 'application/manifest+json' : req.url.endsWith('.js') ? 'text/javascript' : req.url.endsWith('.css') ? 'text/css' : 'text/html';
const shellResponse = req => response('shell', { headers: { 'Content-Type': shellMime(req) } });
test('installation pre-caches validated shell without credentials or redirects', async () => {
  const app = harness({ fetch: shellResponse }); await app.lifecycle('install');
  assert.equal(app.calls.length, 24); assert.equal(app.state.skips, 1);
  // All 14 original shell files plus 10 recovery files, then complete + pending.
  assert.equal(app.stores.get(otherSlot).size, 25); assert.equal(app.state.puts.length, 26);
  assert.equal(app.stores.has(current), false);
  assert.ok(app.calls.every(req => req.credentials === 'omit' && req.redirect === 'error'));
});
// PR #71 review (MAJOR): an update must never mix old and new shell files.
const versioned = version => req => response(version, { headers: { 'Content-Type': shellMime(req) } });
async function offlineShell(app) {
  const saved = app.fetchImpl; app.fetchImpl = offline;
  try { return await (await app.dispatch(request('/', { mode: 'navigate' })).result).text(); } finally { app.fetchImpl = saved; }
}
test('successful update switches to the new shell only at activation', async () => {
  const app = harness({ fetch: req => app.fetchImpl(req) });
  app.fetchImpl = versioned('v1'); await app.lifecycle('install'); await app.lifecycle('activate');
  assert.equal(await offlineShell(app), 'v1');
  app.fetchImpl = versioned('v2'); await app.lifecycle('install');
  assert.equal(await offlineShell(app), 'v1'); // still the active, complete v1 slot
  await app.lifecycle('activate');
  assert.equal(await offlineShell(app), 'v2');
  assert.equal(app.stores.has(otherSlot), false, 'the replaced exact slot is removed');
});
test('failed update keeps the previously active shell intact', async () => {
  const app = harness({ fetch: req => app.fetchImpl(req) });
  app.fetchImpl = versioned('v1'); await app.lifecycle('install'); await app.lifecycle('activate');
  app.fetchImpl = versioned('v2'); app.state.failPut = true;
  await assert.rejects(app.lifecycle('install')); app.state.failPut = false;
  await app.lifecycle('activate');
  assert.equal(await offlineShell(app), 'v1');
  assert.equal(app.stores.has(current), false, 'the incomplete staging slot is discarded');
});
// Final review (MAJOR): the new slot must also hold the bundles its index.html references,
// otherwise an offline reload after an update gets the new HTML but 503 for its bundles.
const builtApp = version => req => {
  const path = new URL(req.url).pathname;
  if (path === '/' || path === '/index.html') {
    return response(`<script type="module" src="/assets/index-${version}.js"></script><link rel="stylesheet" href="/assets/index-${version}.css">`, { headers: { 'Content-Type': 'text/html' } });
  }
  if (path.endsWith('.js')) return response(`js-${version}`, { headers: { 'Content-Type': 'text/javascript' } });
  if (path.endsWith('.css')) return response(`css-${version}`, { headers: { 'Content-Type': 'text/css' } });
  return shellResponse(req);
};
async function offlineAsset(app, path) {
  const saved = app.fetchImpl; app.fetchImpl = offline;
  try { const result = await app.dispatch(request(path)).result; return [result.status, await result.text()]; } finally { app.fetchImpl = saved; }
}
test('an update precaches the bundles of the new index.html before switching slots', async () => {
  const app = harness({ fetch: req => app.fetchImpl(req) });
  app.fetchImpl = builtApp('v1'); await app.lifecycle('install'); await app.lifecycle('activate');
  app.fetchImpl = builtApp('v2'); await app.lifecycle('install'); await app.lifecycle('activate');
  assert.match(await offlineShell(app), /index-v2\.js/);
  assert.deepEqual(await offlineAsset(app, '/assets/index-v2.js'), [200, 'js-v2']);
  assert.deepEqual(await offlineAsset(app, '/assets/index-v2.css'), [200, 'css-v2']);
});
test('an update fails without switching when a referenced bundle is not public', async () => {
  const app = harness({ fetch: req => app.fetchImpl(req) });
  app.fetchImpl = builtApp('v1'); await app.lifecycle('install'); await app.lifecycle('activate');
  app.fetchImpl = req => new URL(req.url).pathname === '/assets/index-v2.js'
    ? response('private', { headers: { 'Content-Type': 'text/javascript', 'Cache-Control': 'private' } }) : builtApp('v2')(req);
  await assert.rejects(app.lifecycle('install'));
  await app.lifecycle('activate');
  assert.match(await offlineShell(app), /index-v1\.js/);
  assert.deepEqual(await offlineAsset(app, '/assets/index-v1.js'), [200, 'js-v1']);
});
// PR #71 review (MINOR): QR links like /?dice=...&round=...&board=... are navigations with a query.
test('offline QR navigation with query gets a controlled no-store 503 and is never cached', async () => {
  const app = harness({ fetch: offline });
  const result = await app.dispatch(request('/?dice=4&round=2&board=7', { mode: 'navigate' })).result;
  assert.equal(result.status, 503); assert.equal(result.headers.get('cache-control'), 'no-store');
  assert.deepEqual(app.state.puts, []);
});
test('online QR navigation passes through without cache writes', async () => {
  const app = harness({ fetch: () => response('page', { headers: { 'Content-Type': 'text/html' } }) });
  const event = app.dispatch(request('/?dice=4&round=2&board=7', { mode: 'navigate' }));
  assert.equal(await (await event.result).text(), 'page'); await Promise.all(event.waits);
  assert.deepEqual(app.state.puts, []);
});
for (const metadata of [ { status: 500 }, { redirected: true }, { headers: { 'Cache-Control': 'private', 'Content-Type': 'text/html' } }, { headers: { 'Content-Type': 'application/json' } } ]) {
  test(`installation fails before writes on unsafe shell ${JSON.stringify(metadata)}`, async () => {
    const app = harness({ fetch: req => req.url === `${origin}/` ? response('unsafe', metadata) : shellResponse(req) });
    await assert.rejects(app.lifecycle('install')); assert.equal(app.state.skips, 0); assert.equal(app.state.puts.length, 0);
  });
}
test('failed precache storage does not activate new worker', async () => {
  const app = harness({ fetch: shellResponse }); app.state.failPut = true; await assert.rejects(app.lifecycle('install')); assert.equal(app.state.skips, 0);
});

// STM-UX-002: exactly two local recovery tools, never selected backup contents.
const recoveryPaths = ['backup-reader', 'backup-lock'].flatMap(folder =>
  ['index.html', 'main.js', 'ui.js', 'core.js', 'style.css'].map(name => `/${folder}/${name}`));
const recoveryResponse = (path, version = 'v1') => response(`${version}:${path}`, {
  headers: { 'Content-Type': shellMime(request(path)) },
});
function recoveryFetch(version) {
  return req => recoveryPaths.includes(new URL(req.url).pathname)
    ? recoveryResponse(new URL(req.url).pathname, version) : shellResponse(req);
}
async function installedRecovery() {
  const app = harness({ fetch: req => app.fetchImpl(req) });
  app.fetchImpl = recoveryFetch('v1');
  await app.lifecycle('install'); await app.lifecycle('activate');
  return app;
}
test('both recovery pages and their entire static dependency sets are precached', async () => {
  const app = await installedRecovery();
  const fetched = app.calls.map(req => new URL(req.url).pathname);
  assert.equal(fetched.length, 24);
  for (const path of recoveryPaths) assert.equal(fetched.filter(value => value === path).length, 1, path);
  assert.ok(app.calls.every(req => req.credentials === 'omit' && req.redirect === 'error'));
  app.calls.length = 0; app.fetchImpl = offline;
  for (const path of recoveryPaths) {
    const event = app.dispatch(request(path, { mode: path.endsWith('.html') ? 'navigate' : 'cors' }));
    assert.ok(event.result, path);
    assert.equal(await (await event.result).text(), `v1:${path}`, path);
    assert.equal(event.waits.length, 1); await Promise.all(event.waits);
  }
  assert.equal(app.calls.length, 0, 'the first tool visit after installation needs no network');
});
test('real recovery HTML and module imports stay inside the exact cached closure', () => {
  const root = new URL('../../src/SchachTurnierManager.WebApp/public/', import.meta.url);
  for (const path of recoveryPaths) {
    const content = readFileSync(new URL(path.slice(1), root), 'utf8');
    const dependencies = path.endsWith('.html')
      ? [...content.matchAll(/<(?:script|link)\b[^>]*?(?:src|href)="([^"]+)"/g)].map(match => match[1])
      : path.endsWith('.js') ? [...content.matchAll(/\b(?:from\s*|import\s*)['"]([^'"]+)['"]/g)].map(match => match[1]) : [];
    for (const dependency of dependencies) {
      const resolved = new URL(dependency, origin + path);
      assert.equal(resolved.origin, origin); assert.equal(resolved.search, '');
      assert.ok(recoveryPaths.includes(resolved.pathname), `${path} -> ${dependency}`);
    }
  }
});
test('an online new version cannot replace individual active recovery modules', async () => {
  const app = await installedRecovery(); app.calls.length = 0; app.state.puts.length = 0;
  app.fetchImpl = recoveryFetch('v2');
  for (const path of recoveryPaths) assert.equal(await (await app.dispatch(request(path)).result).text(), `v1:${path}`);
  assert.equal(app.calls.length, 0); assert.equal(app.state.puts.length, 0);
  await app.lifecycle('install');
  for (const path of recoveryPaths) assert.equal(await (await app.dispatch(request(path)).result).text(), `v1:${path}`);
  await app.lifecycle('activate'); app.fetchImpl = offline;
  for (const path of recoveryPaths) assert.equal(await (await app.dispatch(request(path)).result).text(), `v2:${path}`);
});
for (const metadata of [
  { status: 404 }, { redirected: true }, { type: 'opaque' },
  { headers: { 'Cache-Control': 'private' } }, { headers: { 'Cache-Control': 'no-store' } },
  { headers: { Vary: 'Cookie' } }, { headers: { 'Content-Type': 'application/json' } },
]) test(`unsafe recovery module cannot replace the complete active slot ${JSON.stringify(metadata)}`, async () => {
  const app = await installedRecovery(); const skipped = app.state.skips;
  app.fetchImpl = req => new URL(req.url).pathname === '/backup-lock/core.js' ? response('unsafe', metadata) : recoveryFetch('v2')(req);
  await assert.rejects(app.lifecycle('install')); assert.equal(app.state.skips, skipped);
  await app.lifecycle('activate'); app.fetchImpl = offline;
  for (const path of recoveryPaths) assert.equal(await (await app.dispatch(request(path)).result).text(), `v1:${path}`);
});
test('a recovery write failure leaves the previous tools intact', async () => {
  const app = await installedRecovery(); app.fetchImpl = recoveryFetch('v2'); app.state.failPut = true;
  await assert.rejects(app.lifecycle('install')); app.state.failPut = false;
  await app.lifecycle('activate'); app.fetchImpl = offline;
  for (const path of recoveryPaths) assert.equal(await (await app.dispatch(request(path)).result).text(), `v1:${path}`);
});
test('missing complete marker cannot serve a partial recovery snapshot offline', async () => {
  const app = harness({ fetch: offline });
  for (const path of recoveryPaths) await app.seed(current, path, recoveryResponse(path));
  for (const path of recoveryPaths) {
    const event = app.dispatch(request(path)); assert.ok(event.result, path);
    const result = await event.result; assert.equal(result.status, 503);
    assert.equal(result.headers.get('cache-control'), 'no-store');
  }
});
test('private data under recovery-like paths is never intercepted or cached', () => {
  const paths = ['/backup-reader/local.json', '/backup-reader/index.html?file=synthetic', '/backup-reader/',
    '/backup-reader-other/index.html', '/backup-reader/extra.js', '/backup-reader/core.js.map',
    '/backup-lock/secret.stmenc', '/backup-lock/core.js?token=synthetic', '/backup-lock/private.csv',
    '/backup-lock/session', '/backup-locking/core.js', 'https://elsewhere.invalid/backup-lock/core.js', 'blob:https://synthetic.invalid/example'];
  for (const path of paths) {
    const app = harness(); const event = app.dispatch(request(path));
    assert.equal(event.result, undefined, path); assert.equal(app.calls.length, 0);
    assert.equal(app.state.puts.length, 0);
  }
});
test('recovery paths keep method, credential, range and no-store exclusions', () => {
  for (const options of [{ method: 'POST' }, { method: 'PUT' }, { method: 'DELETE' }, { method: 'HEAD' },
    { cache: 'no-store' }, { headers: new Headers({ Authorization: 'synthetic' }) }, { headers: new Headers({ Range: 'bytes=0-1' }) }]) {
    const app = harness();
    for (const path of recoveryPaths) assert.equal(app.dispatch(request(path, options)).result, undefined, path);
    assert.equal(app.calls.length, 0);
  }
});
test('an unavailable recovery cache still permits a normal online request without writes', async () => {
  const app = harness({ fetch: req => recoveryFetch('online')(req) }); app.state.failOpen = true;
  for (const path of recoveryPaths) assert.equal(await (await app.dispatch(request(path)).result).text(), `online:${path}`);
  assert.equal(app.state.puts.length, 0);
});
test('private cached recovery content is rejected even with a complete marker', async () => {
  const app = harness({ fetch: offline }); await app.seed(current, '/__stm-shell/complete', response('complete'));
  for (const path of recoveryPaths) {
    await app.seed(current, path, response('PRIVATE-SYNTHETIC', { headers: { 'Content-Type': shellMime(request(path)), 'Cache-Control': 'private' } }));
    const result = await app.dispatch(request(path)).result;
    assert.equal(result.status, 503); assert.doesNotMatch(await result.text(), /PRIVATE-SYNTHETIC/);
  }
});

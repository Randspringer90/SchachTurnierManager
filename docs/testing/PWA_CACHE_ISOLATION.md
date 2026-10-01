# STM-UX-002: PWA cache isolation

The service worker now intercepts only explicit public shell paths and build-owned
JS/CSS in /assets/. API paths, arbitrary JSON/CSV, source maps, query strings,
other origins, authorization, ranges, no-store requests and mutations bypass it.

Every request is network-first. HTTP failures stay failures, not stale success.
Only transport failure reads the dedicated cache, with response validation again.
Missing cached content returns a real HTTP 503 no-store response. Quota/storage
errors never turn a successful network response into a failure. Cache writes are
included in event.waitUntil, registered synchronously with the fetch event.

The new public-shell namespace is a cache-policy migration, not a product version
bump. The old exact schach-turnier-manager-shell-v0.45.0 cache is never read and is
deleted at activation. No unrelated cache is enumerated, read or deleted.

Only basic, non-redirected HTTP 200 responses with expected content types can be
stored. private/no-store/no-cache and Vary: Cookie/Authorization/* are excluded.
Installation fetches five public shell resources without credentials, forbids
redirects, validates all responses before writes, and does not activate when its
precache fails. Existing skipWaiting/claim behaviour is retained.

## Verification

npm run test:pwa runs 66 behaviour tests against the actual worker source in a
Node VM, using synthetic CacheStorage/fetch events and real Request/Response APIs.
npm run build automatically runs them via prebuild. No dependencies, lockfile or
application versions changed. Node 22.16.0: 66 PASS, 0 FAIL, 0 SKIP. Same tests
against the original worker: 12 PASS, 54 FAIL. Repeated prebuild run also passed;
these are the same 66 cases, not additional tests.

NOT_RUN: real Chromium/Firefox service-worker lifecycle, browser quota/update
race tests, complete TypeScript/Vite/.NET build, repository PowerShell gates and
independent reviewer. VM tests are not a browser acceptance test.

## Scope limits and integration

This does not make tournament data or result submission work offline. JS/CSS are
cached only after visiting the app online; no complete hashed asset precache or
atomic build-version update is promised. Deployment must really serve public
static content at the allowlisted paths with appropriate headers. A server that
marks the shell private/no-cache will deliberately prevent offline installation.

This is a draft partial delivery of STM-UX-002, refs #70. Reconcile package scripts
with #69 and old UX integration PRs: keep their tests and add test:pwa/prebuild;
do not overwrite their dependency/Android changes with this branch's older base.
Canonical BACKLOG/CHANGELOG synchronization and green overall CI remain required
in the local integration run; STM-UX-002 is not Done or closed by this package.

Primary specification checked 2026-10-01: https://www.w3.org/TR/service-workers/ .

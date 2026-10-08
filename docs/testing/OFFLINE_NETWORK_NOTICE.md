# STM-UX-002: a cautious inline browser-network notice

The application entry includes a normally hidden notice BEFORE the React root.
It becomes visible if the browser explicitly reports offline. Reconnection
shows a caution, not a claim that the backend is reachable or data was saved.
An unknown reading after an offline episode is also not treated as success.
An initial online/unknown reading stays quiet. Existing health checks, requests,
mutation buttons, data handling and backend error handling are unchanged.

Events online/offline/pageshow re-read the live navigator.onLine value rather
than trusting an old queued event. Unchanged hints are deduplicated. Dismissing
the notice hides it for the current state; a later actual transition can show
new information. The inline message is never a blocking dialog and does not
move keyboard focus or open a window. No timer, polling, permission request,
API call, storage access, reload, cache invalidation or offline queue is added.

Messages exist in de/en/es. A document-language observer refreshes visible text;
other languages fall back to English with explicit lang attribution. Observer,
listeners and pending callbacks have an idempotent cleanup contract. Missing
markup is a no-op. Default-hidden markup does not overlay a working app if the
script fails to load. Existing #92 root/startup-panel adjacency is preserved.

## Verification

39/39 Node tests PASS on Node 22.16.0, 0 FAIL/SKIP. Network subscriptions run on
real Node EventTarget objects; DOM/observer adapters remain synthetic. Tests
cover stale events, offline/reconnected/unknown states, dismissal, deduplication,
blocked getters, localization, cleanup, partial setup failure and no forbidden
API/identity/storage access. npm run test:offline:notice passed; JS syntax and
scoped diff checks passed. New-package total: 81; selected combined total: 195.
No repeated-run double counting and no claim of a real browser pass.

## Boundaries and integration

navigator.onLine is an unreliable hint. A local backend can remain reachable
without Internet, and a network connection does not prove backend health.
The notice never promises synchronization or recovery and does not prevent
explicit user edits. This is NOT completion of STM-UX-002's offline/sync scope.
New assets are not yet in #71's pending cache allowlist; a first-ever offline
load of an uncached page cannot load them. Do not claim a full PWA offline mode.

Keep all existing entry links, #92 startup markup and package.json commands.
The proposed #102 runner discovers the new suite after integration. Full pinned
app/Vite/ASP.NET hosting, real browser/keyboard/screen-reader tests, Windows,
.NET/PowerShell gates, independent review and green CI remain required.
Canonical BACKLOG/CHANGELOG synchronization is still a merge requirement.
No dependencies, lockfiles, model policy, versions, release artifacts or other
PR branches changed. Base: f6f9e342277385ee3807008d2dafabdbb84cba47.

Primary contract checked 2026-10-05:
https://html.spec.whatwg.org/multipage/system-state.html#navigator.online

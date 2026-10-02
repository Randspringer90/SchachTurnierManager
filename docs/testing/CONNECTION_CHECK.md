# STM-UX-002: explicit bounded connection check

Open /connection-check/index.html. Only an explicit button click sends one GET
to the same-origin /api/health endpoint already present in Program.cs. No
automatic health polling occurs on page load or on online/offline events.
Those events only update a hint: navigator.onLine is not backend availability.

Fetch uses same-origin mode, omitted credentials, no-store, redirect:error and
no-referrer. There is no user-supplied target URL, token, cross-origin request,
retry storm, cache deletion, server start or database mutation. The 5-second
deadline spans headers AND complete response-body reading, with an abort and
a settling timeout even when an injected transport ignores AbortSignal.

The body is limited to 16 KiB, strict UTF-8 and application/json. The expected
app and status fields are checked. UI messages distinguish reachable, timeout,
HTTP error, unexpected reply, network error and cancellation, without raw
server payloads or error text. Database paths, logging settings and version
strings are neither displayed nor returned from the core.

REACHABLE means the known health response was received, not a database write
check, authoritative process identity, freshness guarantee against arbitrary
service-worker interception, or Internet reachability. The current health
endpoint itself still returns configuration fields; this page discards them.
The separate Vite dev server needs correct same-origin API routing. Future
authenticated deployments may return an HTTP error because credentials are
intentionally omitted here. No global security configuration is changed.

55/55 focused tests PASS, including real Response/ReadableStream handling,
fixed request scope, redirects, malformed/oversize data, stalled body, aborts,
deadline cleanup, no automatic requests and stale UI completions. An initial
UTF-8 error classification defect was caught by a failing test and corrected.

Fetch contract consulted 2026-10-02: https://fetch.spec.whatwg.org/

## Integration and evidence boundaries

Base: development cc47f1101983d3f3272a893dbf54bd66fa2355b4.
Entry HTML and package.json were reconstructed and byte-verified against their
Git blob hashes before modification. No user workstation or existing PR branch
was modified. The new entry link and npm test command must be merged additively
with ALL other pending links/build commands; never replace an integrated file
with this branch's older baseline. The shared ui-harness.mjs is identical across
the three packages. No dependencies, lockfiles, versions or security policies
were changed. The existing full TypeScript/Vite build follows the added tests.

The focused Node tests run on Node 22.16.0. Tests using DOM adapters are not
browser, accessibility, React, ASP.NET hosting or full application evidence.
Full pinned build, .NET/PowerShell gates, Commit-If-Green, independent
Codex/CODEOWNERS review and green remote CI remain required. No browser
acceptance test was executed in this run. New static .js assets are not
automatically added to the pending PWA precache; no full offline-app guarantee.

Keep the existing parent task open until its entire original acceptance scope
is fulfilled. The linked PR supplies only the feature described here, not a
release/merge authorization. Synchronize the canonical BACKLOG/CHANGELOG on
integration before marking anything Done. No runtime logs, real rating lists,
personal backups, secrets, screenshots or other visual artifacts are published.

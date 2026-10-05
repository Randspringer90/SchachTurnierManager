# Read-only workflow transport and integration contract

All three workflow packages share the same dependency-free transport, text-only
DOM helpers, style and synthetic test adapter. Identical files should merge
once, not be maintained as divergent copies. They do not require each other's
feature folder. Each feature exposes a focused npm test command before the
unchanged TypeScript/Vite production build. Keep all existing test commands,
prebuild hooks, audits and entry links when combining pending PRs. The #102
Node suite runner can discover every new top-level *.test.mjs file automatically;
verify its inventory, then avoid duplicate executions of these same suites.

The transport only allows the existing tournament list/standings/JSON export
and FIDE provider/search GET routes. It cannot issue writes or choose another
origin. Redirects and credentials are excluded, cache mode is no-store and a
shared deadline covers fetch AND response-body reads. Strict UTF-8, JSON MIME
and explicit size limits fail closed. Errors display fixed guidance, not raw
response bodies. These are client-side restrictions, NOT a server auth policy.
A service worker or the backend remains responsible for its own cache/security
behavior; integrating #71 and testing the real deployment remain necessary.

IMPORTANT: GET /api/tournaments currently returns complete TournamentState
objects, not a minimal public list. These tools keep only ID/name choices after
processing the response, but the complete body reaches the browser. Do not
publish this application to untrusted viewers assuming the new UI hides the
underlying API or private data. The live view is an operator/club LAN display,
not a separately secured spectator endpoint. No API exposure or auth is changed.

Production integration requires the existing same-origin /api routing and
correct JavaScript MIME for .mjs assets in ASP.NET/static hosting. No global
settings, installs, external provider setup, new windows or native dialogs are
introduced. No new PWA precache entries are added, so initial offline loading
of these pages is not guaranteed. Persistent/browser storage is not used.

Source contracts were read on development
9bf429dd803f751e7e88d1b789afab3f505351f0: Program.cs, TournamentService.cs,
StandingRow.cs and ExternalPlayerLookup.cs were first read at 338d271; the
comparison to 9bf429d changes documentation only. Base index.html and package.json
were reconstructed byte-identically and verified against their Git blob SHAs.
A full clone was not available in this execution environment (DNS failure).

Verification: Node 22.16.0, synthetic data only. The shared HTTP tests execute
real Response/ReadableStream/AbortController behavior with a synthetic transport;
DOM tests use a small adapter. Backup tests additionally use real File, Blob
and WebCrypto primitives. The combined source subset passed 137 unique tests.
Repeated per-PR runs include the same shared HTTP tests and must not be added
as new unique coverage.

Real headless Chromium navigation to the owned loopback fixture server failed
at the FIRST URL with ERR_BLOCKED_BY_ADMINISTRATOR. Zero browser assertions
executed. No alternate route, browser-policy change or screenshot upload.
Full pinned React/Vite build, ASP.NET/.NET/PowerShell/Windows gates, keyboard/
screen-reader checks, independent Codex/CODEOWNERS review and green CI remain
open. Source checks do not replace these gates or Commit-If-Green.

References consulted 2026-10-05:
https://fetch.spec.whatwg.org/
https://html.spec.whatwg.org/multipage/interaction.html
https://www.w3.org/TR/webcrypto/

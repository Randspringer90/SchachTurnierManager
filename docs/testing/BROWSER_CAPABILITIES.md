# STM-UX-010: local browser prerequisite check

The entry page links to /browser-check/index.html. An explicit click inspects
only the presence/type of ten APIs needed by existing backup, SHA-256,
streaming-rating and service-worker features. Each check is available, missing
or unknown. Access-denied getters become unknown independently; raw failures
are not displayed. Insecure/unknown context prevents a positive secure-context
prerequisite result, even if a digest or registration property is visible.

No File/Blob read, digest, service-worker registration, network request, storage
access, permission query, clipboard operation, window open or installation is
performed. No user agent, device identifiers, IP address, screen size, filenames
or settings are collected. Output has a fixed schema and static labels; no
unknown source fields are copied. The page forbids connections via CSP.

This is a prerequisite snapshot, NOT a functional compatibility test or a
security/installation decision. An available function can still fail because
of permissions, implementation details or later runtime conditions. The check
does not prove the PWA is installed, assets are cached, a database is reachable
or any pending feature PR has been integrated. It never recommends disabling
certificate, browser or company policy checks. Text states these limits.

## Evidence and integration

41/41 Node tests PASS on Node 22.16.0, 0 failures/skips. API getters are exercised
with controlled surfaces; operation methods deliberately throw if invoked.
Privacy traps cover storage, location, identity, permissions, media and window
APIs. DOM adapters test explicit invocation, clearing, disposal, fixed output
and error redaction. The real test:browser:capabilities npm command was run.
The normal build runs it before existing TypeScript and Vite steps.

Real browser/keyboard/screen-reader tests, ASP.NET static hosting, full pinned
React/Vite/.NET/PowerShell/Windows gates and independent Codex/CODEOWNERS review
are NOT_RUN here. No screenshot or user input is published. This is one support
feature under STM-UX-010, not a completed cross-device test matrix.

Basis: development cc47f1101983d3f3272a893dbf54bd66fa2355b4. Original index.html
and package.json are byte-verified against their Git blobs. The new link is
added after the main module tag so #92's root/startup-panel adjacency can stay
intact. Preserve all other entry links and test/build commands on integration.
New assets are not automatically in the PWA precache. Canonical BACKLOG and
CHANGELOG synchronization remain required before merge. No dependencies,
lockfiles, product versions, other branches, worktrees or permissions changed.

Primary references consulted 2026-10-04:
https://www.w3.org/TR/secure-contexts/
https://html.spec.whatwg.org/multipage/webstorage.html

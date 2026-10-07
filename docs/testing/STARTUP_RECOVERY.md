# STM-UX-015: recoverable application startup

The entry HTML includes separate noscript guidance and a initially hidden
startup panel. A small same-origin classic deferred script observes only the
empty root until the application inserts its first element. At that point
it hides the panel and removes its listeners, deadline and observer. This is
mount detection, not proof of a healthy backend, complete React render or DoD.

With an empty root, the guard displays a loading message. A script/runtime
error, unhandled rejection, or a 15-second deadline produces fixed recovery
guidance and an ordinary manual link back to the start page. Image/CSS/video
load failures alone do not establish startup failure. A later successful mount
hides the recovery panel. The guard never renders error values, URLs or stack
traces and never suppresses the browser's normal error reporting.

No automatic reload, API health probe, cache deletion, storage access, data
import or root-content replacement is performed. Assets are same-origin.
German bootstrap text is deliberately independent of the unavailable React
translation context. The panel is hidden by default so a missing guard script
cannot leave a stale overlay above a working application. If JavaScript is
turned off entirely, the independent noscript section is visible instead.

This does not guarantee recovery when both the application and guard assets
cannot load. It is not a new offline/synchronization system. The pending #71
service-worker policy does not yet precache the new guard assets; do not claim
full offline recovery. Retain normal application/ErrorBoundary behaviour.

## Verification

36/36 Node 22.16.0 tests passed, including real execution of the guard source
against synthetic DOM/event/timer adapters. npm prebuild executed the same
36 cases. Timing, late mount, teardown, duplicate installation, privacy,
resource errors, no-observer fallbacks and HTML/CSS contracts are covered.
The VM is a test harness, not a security sandbox or browser substitute.

A real Chromium/Playwright smoke was attempted. Navigation failed BEFORE any
UI assertion with ERR_BLOCKED_BY_ADMINISTRATOR. Browser assertions are NOT_RUN;
no permissions, browser policies or alternative access paths were used to
bypass that restriction. Full React/Vite/ASP.NET hosting, offline behaviour,
responsive layout, keyboard and screen-reader verification remain open.

## Integration

Preserve #77's backup-check entry link when merging index.html. Merge the new
test:startup/prebuild entry additively with i18n/PWA/backup/QR/progress tests;
never restore the branch's older package metadata over a newer integrated file.
The main module path/root are unchanged; #55's refactor stays untouched.

Canonical integration entries: STM-UX-015, In Review, ui, owner, v1.0.0.
CHANGELOG: no-JavaScript guidance and bounded startup recovery instead of an
unexplained empty page. BACKLOG/CHANGELOG synchronization, independent review,
full project gates and green CI remain required before merge. No product
versions, dependencies, lockfiles, security policies or releases changed.

# STM-QR-001: QR runtime input contract

Scope: existing local QR encoder; no new connection UI or mobile feature.

The encoder rejects non-string input without coercion, invalid ECC values and
payloads beyond the selected ECC byte capacity before constructing a matrix.
An impossible UTF-16 length is rejected before TextEncoder allocation. The
bounded fallback produces the same UTF-8 scalar-value bytes as TextEncoder,
including replacement of lone surrogates with U+FFFD. getModule returns false for
non-integral/out-of-range coordinates instead of throwing or returning undefined.
Existing valid payloads, default Medium ECC, matrix API and error-correction
algorithm are preserved. Nothing is sent to a server.

Reference: https://encoding.spec.whatwg.org/#interface-textencoder (2026-10-01).

## Verification

Run npm --prefix src/SchachTurnierManager.WebApp run test:qr:runtime.
The normal npm build executes the same test before tsc/Vite. Uses the already
pinned TypeScript dependency to transpile the real source into an isolated test
context. The VM is NOT claimed as a security boundary.

Historical package verification: 45/45 tests passed on Node 22.16.0; the original source failed 29/45. Standalone
strict TypeScript checking passed with locally available TypeScript 5.8.3.
The independent QR golden suite (STM-QR-002) also passed on the combined source.
Four synthetic matrices were decoded back to their exact payloads with OpenCV.
These are not phone-camera, full-browser, .NET, or full-app integration tests.
No dependency or version was updated by this package.

Integration verification on 2026-10-05: 209/209 tests passed against the combined
source (45 runtime and 164 golden tests; zero failures/skips). The complete static
review and independent review of head dc68825a0da766f7e1cac857d2f2579f7860c1d0
against development eecb882c8eca0c34107d7265151f9672534bd713 passed. Both suites
remain build prerequisites with the existing pinned TypeScript toolchain.
Complete CommitGuard, fresh review of any further head and current GitHub CI
are still required before merge; these targeted results are not a merge approval.

## Integration

Both QR packages share an identical tests/scripts/helpers/qr-runtime.mjs. Keep
both npm test commands and both build prerequisites when merging package.json;
retain the test/prebuild changes from #69/#71/#72/#77 and later branches.
The existing owner branch was synchronized by a normal merge from current
development. The sole package.json conflict was resolved additively; dependency
fields and lockfile are unchanged. Canonical BACKLOG/CHANGELOG now describe
STM-QR-001 as In Review. This package does not complete STM-MOB-005.

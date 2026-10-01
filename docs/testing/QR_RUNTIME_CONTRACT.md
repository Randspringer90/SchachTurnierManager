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

45/45 tests passed on Node 22.16.0; the original source failed 29/45. Standalone
strict TypeScript checking passed with locally available TypeScript 5.8.3.
The independent QR golden suite (STM-QR-002) also passed on the combined source.
Four synthetic matrices were decoded back to their exact payloads with OpenCV.
These are not phone-camera, full-browser, .NET, or full-app integration tests.
Pinned TypeScript 6.0.3, complete project gates and independent Codex/CODEOWNERS
review remain integration requirements. No dependency or version was updated.

## Integration

Both QR packages share an identical tests/scripts/helpers/qr-runtime.mjs. Keep
both npm test commands and both build prerequisites when merging package.json;
retain the test/prebuild changes from #69/#71/#72/#77 and later branches.
No existing PR branch was edited. Canonical BACKLOG/CHANGELOG synchronization
is still required before merge: STM-QR-001 is In Review, not Done. Suggested
changelog: QR inputs are bounded/validated; UTF-8 fallback and coordinate access
are consistent. This package does not complete STM-MOB-005.

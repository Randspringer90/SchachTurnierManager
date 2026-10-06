# STM-QR-002: independent QR matrix regression coverage

160 golden vectors exercise versions 1-40 with Low/Medium/Quartile/High ECC.
Each uses the maximum byte-mode payload for that version/ECC. Payload byte i is
33 + (i * 17) % 90. No real address, user data, credentials or image is stored.

The checked-in fixture was computed independently with python-qrcode 8.2,
explicit byte mode, fixed mask 0, no border and no ECC boost. Source-file hashes
are recorded in the fixture. Reference implementation:
https://github.com/lincolnloop/python-qrcode/blob/v8.2/qrcode/util.py

Tests load the actual TypeScript encoder using the existing compiler dependency.
They verify both format-field copies and BCH/ECC, normalize only the chosen mask
to mask 0, then compare the SHA-256 of the entire matrix: data, Reed-Solomon ECC,
remainder modules, finders, alignment and version patterns. Mask normalization
permits valid mask-choice differences instead of mistaking them for corruption.
Three mutation controls prove that data/finder corruption and inconsistent format
fields are detected. Fixture coverage is checked for exactly 160 distinct pairs.

Run npm --prefix src/SchachTurnierManager.WebApp run test:qr:golden.
The npm build runs these tests before tsc/Vite. No Python package is needed to
run the tests and no new dependency is introduced. Optional fixture regeneration
uses tests/scripts/fixtures/generate-qr-golden.py, Python with qrcode==8.2 already
installed, and must be a deliberate separately reviewed fixture update.

## Evidence / limits

164/164 tests passed against the existing baseline and the combined STM-QR-001
fix, Node 22.16.0 / TypeScript 5.8.3. This is new regression coverage, not evidence
that the original QR bit algorithm was broken. It does not prove photographic
scanner tolerance, mask optimality, browser rendering or arbitrary UTF-8 payloads.
The runtime package separately tests Unicode and four local OpenCV decode smokes.
Full pinned-toolchain builds, CI and independent review remain required.

Owner integration run 2026-10-05: `npm ci` completed and the 164 golden
tests passed locally against head dc67ce5b1632ce2e38f7c91f20dfa0f2c28b1200,
after the complete SHA-bound static review on base 9bf429d. Full project
gates and CI are recorded separately; this result is not a merge approval.

## Integration

Preserve both test:qr:runtime and test:qr:golden prerequisites when combining
package.json, as well as existing prebuild/i18n/PWA/backup tests and newer metadata.
The shared QR test helper is byte-identical in both PRs. Canonical BACKLOG and
CHANGELOG were synchronized in d690767a. PR #84 merged as 50a3367 after full
local gates and current-head CI passed; the same tree was fast-forwarded to main.
The canonical STM-QR-002 row is Done. No source/runtime/API change or reserved
mobile feature implementation is implied.

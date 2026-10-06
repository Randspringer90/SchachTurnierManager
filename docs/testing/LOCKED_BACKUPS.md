# STM-SEC-003: password-protected local backups

The linked /backup-lock/index.html encrypts or decrypts explicitly selected
JSON backup bytes, including multi-tournament JSON containers. No server,
provider, upload, persistent storage or automatic download is involved. A link
is prepared and the user clicks it. The original file is never deleted.

## Wire contract and standard primitives

The binary STMENC01 envelope is 44 header bytes, ciphertext and a 16-byte tag.
Header: magic[0..7], fixed 600000 PBKDF2 iterations as big-endian uint32[8..11],
random salt[12..27], random 96-bit IV[28..39], plaintext length uint32[40..43].
The entire header is AES-GCM additional authenticated data. Password derivation
uses PBKDF2-HMAC-SHA256, 600000 iterations, then a nonextractable AES-256-GCM key.
Salt and IV are freshly generated with getRandomValues for every encryption.
No cryptographic primitive is implemented in application code.

Nonempty plaintext is bounded to 24 MiB. Unknown magic, work factor, length
or truncation is rejected before deriving a key; hostile input cannot choose
an excessive KDF cost. Wrong passwords and authentication failures return the
same neutral error, with no partial plaintext. All source bytes survive,
including BOMs, line endings, large JSON numbers and opaque binary bytes.
The UI is intended for JSON backups; decryption does not validate JSON/restore
semantics. It uses a fixed output filename, never an archive-controlled path.

Passwords: at least 12 Unicode code points, at most 1024 UTF-8 bytes; malformed
Unicode and all-whitespace input are rejected. No normalization or trimming.
Strength still depends on the chosen password, not merely its length. There
is no recovery without it. Passwords and generated Blob URLs are cleared on
reset/pagehide; owned mutable buffers are zeroed where possible. JavaScript
strings, browser copies and freed memory cannot be guaranteed erased. Native
crypto may finish after cancellation; old results are never offered and no
concurrent replacement operation begins until settlement.

## Security limits and evidence

This is a new custom envelope around standard browser cryptography, not a
security certification. Independent security review and real browser acceptance
are required before trusting it with the only copy of important data. It does
not protect an unlocked/compromised browser, disclose-free filenames chosen by
the user, pre-existing plaintext copies or plaintext downloads. Size and format
are public; file names and original metadata are not embedded. Authentication
with a shared password does not prove who created the backup.

38 focused tests passed: real WebCrypto roundtrips, cross-checks using Node's
separate pbkdf2Sync/createCipheriv/createDecipheriv APIs, randomization, altered
salt/IV/header/tag/ciphertext, input bounds, Unicode, cancellation and UI state.
An initial Buffer.slice aliasing bug was reproduced with a failing regression;
byteInput now copies with new Uint8Array(value), preserving caller-owned bytes.
The independent API check is not an independent security review.

References checked 2026-10-06:
https://www.w3.org/TR/webcrypto/ (Web Crypto AES-GCM, PBKDF2, getRandomValues)
https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
OWASP's PBKDF2 cost guidance informed the fixed work factor; no claim of FIPS
validation or of PBKDF2 being the preferred algorithm for all password systems.

## Integration / remaining DoD

Base: development abecd00c93d8c651f362d8ef3f0098200fe385ba; inspected 2026-10-06. Original index.html and
package.json were reconstructed exactly and bound to their Git blob SHAs.
Both integrated QR test commands are preserved. Each feature has its own
focused npm test before the existing build chain; shared read-tools-test-dom
is byteidentical across the three PRs. The combined source subset passes 135
unique tests (38 + 49 + 48); repeat runs are not additional coverage.

Preserve every other entry link, #92 root/startup-panel adjacency, prebuild hook
and test/audit command when integrating other pending PRs. New links are after
the main module. The #102 suite runner can discover these top-level tests;
verify discovery, then avoid running the same suites twice. No new dependency,
lockfile, product version, model catalog, API schema or security policy changed.
Only public .js assets are used; these are not added to the PWA precache.

A headless Playwright smoke was attempted, but Chromium's executable is absent
in this environment. The browser did not launch; zero browser assertions ran.
This is NOT the older ERR_BLOCKED_BY_ADMINISTRATOR case. Full pinned React/Vite,
ASP.NET, Windows, .NET/PowerShell, repository/Release/Commit-If-Green gates and
independent Codex/CODEOWNERS review remain NOT_RUN. Focused Node tests are not
full DoD or merge approval. Required CI and canonical BACKLOG/CHANGELOG
synchronization remain before merge. Parent tasks are not declared Done.

No changes to existing PR/integration branches, user checkouts, development/main,
permissions, external accounts or release/deployment artifacts. All tests use
synthetic data; no user backups, passwords, screenshots or raw runtime logs
are committed. Source verification used a subset, not a successful full clone.

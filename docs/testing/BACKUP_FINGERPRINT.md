# STM-UX-003: local backup fingerprint

Open `/backup-fingerprint/index.html` from the application entry. Select a file
(maximum 5 MiB), optionally paste its known SHA-256 and explicitly start the
check. The browser hashes the original bytes, not parsed JSON. Empty files
are supported; no valid-backup claim is inferred. Displayed hashes can be
copied manually; clipboard permissions and file writes are not requested.

A match only compares bytes with the supplied hash. It is neither a signature,
trusted provenance nor proof that a backup can be restored. JSON whitespace,
line endings and BOMs change the hash. Comparison accepts only 64 hexadecimal
characters with optional outer whitespace, no filename or prefix. Hashing needs
Web Crypto in a secure context; unavailable crypto is an explicit error, not a
fallback to a weaker algorithm. No upload, API request, cache or storage access.

The controller invalidates pending output on file/expected-hash changes, reset
or disposal. Failed reads clear prior results. Errors are mapped to fixed text;
raw errors and filename metadata are not displayed. Node tests include actual
Web Crypto SHA-256 against independent node:crypto vectors and UI races.

References checked 2026-10-02:
- https://www.w3.org/TR/webcrypto/#subtlecrypto-interface
- https://www.w3.org/TR/FileAPI/#blob-section

## Verification and integration

65/65 Node 22.16.0 tests PASS, 0 FAIL, 0 SKIP. The npm command
`test:backup:fingerprint` was actually executed; repeat runs are not additional cases.
The same test command runs before the existing tsc/Vite build. All tests are
synthetic. No new dependency, lockfile or version is introduced.

A shared Chromium 144 smoke was attempted on loopback. Its first navigation
to the fingerprint page was blocked; the comparison page was not reached.
The browser reported
ERR_BLOCKED_BY_ADMINISTRATOR before the first assertion. BROWSER=NOT_RUN;
no alternate route or policy changes were used. Full ASP.NET MIME/static
hosting, full React/Vite build, Windows, .NET/PowerShell project gates,
Commit-If-Green and independent Codex/CODEOWNERS review remain NOT_RUN here.
Source-level tests are not a complete UI or accessibility acceptance.

Direct basis: development cc47f1101983d3f3272a893dbf54bd66fa2355b4.
No prior PR branches, integration worktrees, user files, main or development
were modified. Preserve the entry links and ALL prior test/build commands
from #69/#71/#72/#77/#82/#84/#88/#92 during integration. Both new backup tools
have independent scripts/folders; neither requires the other's PR. New assets
are not added to #71's precache. This is not a complete offline-app guarantee.

Part of existing STM-UX-003, related to #73. Do not count this as an extra
v1.0 requirement or mark the parent Done. Canonical BACKLOG/CHANGELOG must be
reconciled in the integration branch before merge; no status is silently
promoted. This PR's feature description and evidence live in this document.

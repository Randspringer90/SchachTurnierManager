# Backup fingerprint: scoped verification

Base: cc47f1101983d3f3272a893dbf54bd66fa2355b4.
Scope: additional read-only browser feature under STM-UX-003. Separate branch;
no writes to existing PRs or local consolidation. Entry HTML/package.json
reconstructed byte-identically and verified against Git blob hashes first.

Executed: 65 Node behavior/controller tests, all PASS, no failures/skips.
The same npm test command also passed (not counted twice). Node syntax,
UTF-8 and git diff --check tested for the scoped sources.
Static self-review performed. Independent Codex review NOT_RUN.
Chromium navigation BLOCKED before first assertion; browser acceptance NOT_RUN.
Full application/pinned build/.NET/PowerShell/CI gates NOT_RUN at publication.
No PII, credentials, actual backup content or screenshots committed.
No dependency/version/lockfile changes, release, deploy or merge.

# STM-UX-003: duplicates feature

A linked local page reads 2-20 explicitly selected files sequentially and
groups matching SHA-256 AND byte sizes. Limits: 5 MiB per file and 50 MiB total.
A full budget check precedes reading; size metadata is snapshotted and checked
again per file. No deletion, import, restore, API call, upload or filesystem
write exists. The result contains selection indexes, byte counts and hashes;
filenames are shown only locally, bounded and as text.

Progress is per file. Cancel, clear or new selection invalidate prior results.
An in-flight Blob read/digest may finish, but no new batch starts until it has
settled. There is no fake cancellation guarantee for native Web Crypto. Any
failed file rejects the whole result rather than calling a partial scan done.
A cryptographic or secure-context failure is explicit; no weak fallback.

Identical hashes and sizes are useful evidence of identical bytes, not a
signature, origin check or backup validation. Empty/invalid backups may match.
Different JSON whitespace/line endings/BOMs cause different fingerprints.
This complements the single-file fingerprint (#93), not a duplicate restore
or delete workflow. No actual backup content is shipped in this PR.

27 Node tests include real File/Blob and WebCrypto calls, independent SHA-256
vectors, bounds, sequential reads, metadata drift, abort and UI races. The
size-drift regression failed before the fix and passes afterwards.
References: https://www.w3.org/TR/FileAPI/
https://www.w3.org/TR/WebCryptoAPI/

## Integration and remaining gates

Basis: development 338d27186238659463d4f8eef78f62f08a4860da, read live
2026-10-05. Only this package's new files and two small entry/build integrations
are included. Original index.html and package.json were reconstructed from
complete connector text and matched their Git blob hashes before editing.
No successful repository clone is claimed (container DNS unavailable).

Preserve ALL other entry links, #92 root/startup-panel adjacency, #104 offline
notice and previous test/audit commands when merging. New controls are BEFORE
root or links AFTER the main module, not between root and startup panel. The
#102 runner can discover the new top-level test suite; do not run it twice in
a combined build. No new dependency, lockfile, model or policy change. No PWA
precache update: these assets are not guaranteed to load offline.

A real headless Chromium smoke was attempted; its FIRST navigation to the
owned loopback server returned ERR_BLOCKED_BY_ADMINISTRATOR, zero browser
assertions ran. No alternate route or browser-policy change was attempted.
BROWSER=NOT_RUN. Full pinned React/Vite/ASP.NET hosting, keyboard/screen-reader,
Windows/.NET/PowerShell, repository/ReleaseGate and Commit-If-Green checks,
independent Codex/CODEOWNERS review and final green CI remain open.

The canonical BACKLOG/CHANGELOG must be reconciled before merge; this scoped
partial feature does not mark its parent Done. No local user worktree, existing
PR branch, development/main ref, permission setting, release or deployment was
changed. Tests use only synthetic data. No screenshots or raw logs are committed.

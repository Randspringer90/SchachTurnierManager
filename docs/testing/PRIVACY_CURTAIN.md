# STM-SEC-003: privacy feature

A small control immediately before the existing React root can hide and show
that root on explicit user action. No new window, timer, dialog, network or
storage action is added. Root contents and unsaved fields are not replaced.
The button remains outside the hidden root and reports the visible state.
A root already hidden by another feature is not taken over. Teardown restores
only a curtain installed by this controller and removes its listener.

This is visual concealment in ONE tab, not authentication, encryption, an OS
lock or a guarantee against screenshots or developer tools. Other tabs,
downloads, elements/portals outside root, native top-layer dialogs and operating
system surfaces are outside its scope. Background app requests continue.
If the browser reloads, the curtain is not persisted. No privacy-state sync to
other tabs is implied. Use the actual OS lock when access protection is needed.

The HTML remains usable if the script is unavailable: control initially
disabled and content visible. Its CSS forces display:none on its owned root
marker, including print layout, not a translucent overlay. RTL/i18n expansion
of this German shell control is separate work, not silently counted complete.

19 Node tests exercise controller transitions, pre-existing hidden states,
focus, cleanup, duplicate setup, unchanged content and markup/source contracts.
Synthetic DOM tests are not browser-rendering or screen-reader evidence.
Primary reference: https://html.spec.whatwg.org/multipage/interaction.html

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

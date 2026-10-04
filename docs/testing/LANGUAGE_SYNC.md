# STM-UX-001: synchronize language preference across tabs

The existing I18nProvider subscribes to changes of its existing stm.language
localStorage key. A valid supported choice in another tab updates React state
without reloading the page, writing back to storage, opening a window or
mutating tournament data. Existing translation fallback and lang/dir effects
are unchanged; selecting Arabic still flows through the existing RTL effect.

Each relevant event re-reads the current stored preference rather than trusting
its potentially stale newValue. The event must belong to this window's local
storage, not sessionStorage or an unrelated key. Missing/removed/cleared or
unsupported values retain the current session language. There is no automatic
fallback rewrite and no event feedback loop. Initial subscription and pageshow
reconcile a changed preference after mount or page-cache restoration.

The subscription is cleaned up on unmount and is safe for React StrictMode's
setup-cleanup-setup cycle. Storage getter/read denial is optional and does not
prevent later reconciliation. Errors from consumer code are not reclassified
as storage failures. Partial listener setup is cleaned up before rethrow.

This synchronizes only tabs using the same browser storage area and origin.
It does not synchronize devices, accounts or separate localhost/IP origins,
transfer private data, or create a new persistence key. This intentionally
makes the existing persisted language a shared preference, not per-tab state.

## Evidence and integration

44/44 Node tests PASS on Node 22.16.0, 0 failures/skips, with synthetic storage
and event sources and a source-wiring check. A cleanup defect in our initial
listener setup was reproduced (43 PASS / 1 FAIL), corrected and retested.
The new TypeScript module passed strict typechecking with available TypeScript
5.8.3; this is NOT the full app check with pinned TypeScript 6.0.3. The actual
npm command test:i18n:sync was run. Native type stripping needs Node >=22.6.
The normal build runs this command before the unchanged tsc/Vite build.

Real browser cross-tab delivery, React rendering, RTL visuals, full pinned
app/Windows/.NET/PowerShell tests and independent Codex review are NOT_RUN here.
No claim is made that source-level checks prove browser event delivery.

Basis: development cc47f1101983d3f3272a893dbf54bd66fa2355b4. Original index.tsx
and package.json were byte-verified against their Git blobs. Only an import
and an effect are added to the provider. On integration preserve ALL of #69's
language-detection/translation fixes and all existing build/test commands;
never overwrite them with this branch's older complete base file. This is a
subset of STM-UX-001 and does not complete missing UI translations. Canonical
BACKLOG/CHANGELOG synchronization remains required before merge.

No dependencies, lockfiles, product versions, protected workflows, existing PR
branches or user worktrees changed. No provider calls, releases or merges.

Primary specification consulted 2026-10-04:
https://html.spec.whatwg.org/multipage/webstorage.html

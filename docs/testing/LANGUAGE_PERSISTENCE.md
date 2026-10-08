# STM-UX-001: visible feedback when language storage fails

The existing I18nProvider now applies only supported selections and reports a
failed localStorage write through React state. The selected language remains
active in this tab even if storage is denied or full. A successful later choice
clears the warning. Unsupported values do not touch either state or storage.
A state/render callback error propagates rather than being mislabeled as a
storage problem. No browser exception text or other storage contents is read.

LanguageSwitcher keeps a polite status region in the DOM and associates its
unique useId with the selector through aria-describedby when necessary.
The hint is outside the label, avoiding duplicate accessible naming. German,
English and Spanish provide the new message; other catalogs retain fallback.
No modal, additional window, permission request, reload or background retry.
The existing stm.language key and user-initiated write are unchanged.

A successful setItem is not a guarantee of durable browser storage. The notice
reports the last local save attempt, not a continuously monitored storage state.
It is not a diagnosis of cookies, account settings or another device. No new
storage probes, secret reads or automatic permission/configuration changes.

## Verification

42/42 Node tests PASS on Node 22.16.0, 0 FAIL/SKIP. The helper is actually
executed for valid/invalid selections, thrown storage values, callback failures,
recovery and nonmutation. Source wiring and message tests complement these;
they are not React rendering tests. npm run test:i18n:persistence passed.
The helper and changed catalogs typecheck strictly with local TypeScript 5.8.3;
the provider passes a TSX syntax/transpile check. Full pinned TypeScript 6.0.3,
React/Vite, real browsers, Windows/.NET/PowerShell and independent review are
NOT_RUN here. The 81-case new-package suite and a selected 195-case combined
suite passed; repeat runs are not extra tests.

## Integration

Based on development f6f9e342277385ee3807008d2dafabdbb84cba47.
Preserve #69 translation/detection fixes, #99 subscription and #101 catalogs.
A selected local combination with the published #99/#101/#102 sources was
executed, not the complete final integration branch. In particular, a cross-tab
update does not itself change the last local save-attempt outcome. A future
broader persistence monitor must not infer success from an unrelated event.

The new test command precedes the existing tsc/Vite build. Keep all prior build,
audit and focused commands when reconciling package.json; #102 can discover the
new test once integrated. Do not replace the integrated file with this older
base. Canonical BACKLOG/CHANGELOG synchronization remains an explicit merge
requirement; this partial i18n package does not mark STM-UX-001 Done.
No dependencies, lockfiles, product versions, protected workflows or model
settings changed. No workstation writes, merges, releases or deployments.

Primary contracts checked 2026-10-05:
https://html.spec.whatwg.org/multipage/webstorage.html
https://react.dev/reference/react/useId

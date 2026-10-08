# Build Week UX audit

Status: 2026-07-18
Scope: core desktop and companion demo path
Baseline SHA: `a6f68e8f8e31201f0b9ce2ea77a13c37a50b9518`

## Evidence boundary

The audit began before implementation with source, DOM, CSS, API and existing test-evidence
inspection. The configured in-app browser reported that no browser instance was available, so
new before-change screenshots could not be captured in this run. No screenshots were invented
and no unrelated browser automation was substituted. Visual acceptance at 320, 360, 390, 412,
768, 1024 and 1440 px therefore remains a manual-candidate check in
the manual candidate test guide.

Local diagnostic data was isolated below the private run root. No real tournament database was
opened. The API demo smoke used synthetic names only and removed its test tournament afterward.

## Baseline findings

| Area | Finding at baseline | Severity | Build Week response |
|---|---|---:|---|
| Information architecture | Seven equal-weight tabs plus global tools competed for attention. | High | Five primary areas: Overview, Participants, Round, Standings, More. |
| First start | Empty state only instructed the user to create/select a tournament in the sidebar. | High | Central Create and explicit synthetic Demo actions. |
| Tournament creation | Unlabelled name/format controls; no pairing-strategy choice. | High | Labelled short form, summary, advanced pairing details and relevant initial colour. |
| FIDE Dutch | Backend/API/persistence existed, but the UI did not expose it and help text called it future work. | High | Explicit opt-in, Optimal V2 remains default, no silent migration, help corrected. |
| Live operations | Round actions appeared outside the Round view. | Medium | Pairing actions are scoped to Round. |
| Result entry | A select change wrote immediately. | High | Review/confirm step plus one-step undo. |
| Participants | No local filter; table described itself as requiring horizontal scrolling. | Medium | Name/club/ID filter and honest compact mobile fallback. |
| Standings | Thirteen columns appeared with equal priority. | Medium | Core columns first; uncommon tie-breaks are opt-in. |
| Advanced tools | Assistant, exports, audit and administration dominated primary navigation. | High | Grouped below More without removing functions. |
| Privacy | `/api/health` and the UI exposed absolute database/log paths. | High | Public health response retains status only; path fields removed. |
| Language maturity | Eighteen languages were presented equally although most are partial. | Medium | German/English identified as complete demo languages; others labelled preview. |
| Theme | Existing presentation was dark-only. | Medium | Local dark/light toggle; no server persistence or tracking. |
| Focus/touch | Focus treatment and small controls were inconsistent. | Medium | Strong `:focus-visible`; core controls at least 44 px on small screens. |

## Three user perspectives

### First-time volunteer

The original page exposed implementation and operator detail before a user had a tournament.
The revised entry offers one primary create action, one safe demo action, labelled defaults and a
summary. Pairing jargon is under an Advanced disclosure.

### Tournament director during a round

Current round, open results and next action remain visible, but printing, backup and audit no
longer compete with the round action. A result change is now explicit and reversible. Detailed
pairing diagnostics remain available because auditability is a product requirement.

### Helper on a phone

The five primary areas become a fixed bottom navigation below 720 px. Touch controls are enlarged,
the standings default is narrower, participant filtering is available and result writes require a
confirmation. PR #49's actual Android shell remains outside this branch and must still pass its
own device test.

## Breakpoint and state matrix

| Width | Source/CSS review | Automated build | Manual visual check |
|---:|---|---|---|
| 320 | No intentional sub-320 support; fixed five-item navigation and 44 px controls apply. | Pass | Pending |
| 360 | Single-column shell and bottom navigation apply. | Pass | Pending |
| 390 | Single-column shell and bottom navigation apply. | Pass | Pending |
| 412 | Single-column shell and bottom navigation apply. | Pass | Pending |
| 768 | Tablet layout; bottom navigation no longer applies. | Pass | Pending |
| 1024 | Existing 1050 px layout collapse applies. | Pass | Pending |
| 1440 | Two-column tournament shell. | Pass | Pending |

Dark and light themes compile. Portrait/landscape, keyboard sequence, screen-reader names,
contrast and real touch behaviour remain part of the manual matrix; source inspection alone is
not counted as visual evidence.

## Verification completed

- TypeScript and Vite production build: pass.
- Isolated public health response: no database or log directory field.
- Synthetic demo API path: 8 players, 1 completed round, 8 standings rows.
- FIDE Dutch strategy and initial colour persisted.
- TRF16 export: non-empty.
- Demo smoke tournament cleanup: pass.

## Remaining UX risks

- The WebApp is still a large monolithic React component; this run avoids a risky pre-submission
  refactor.
- Advanced administration and audit screens remain primarily German. The complete judge/demo path
  is prioritised in German and English; preview languages fall back to English/German.
- Tables retain horizontal overflow where dense expert data cannot safely be removed.
- Visual evidence and Galaxy S25 behaviour require the Owner's manual test before video capture.

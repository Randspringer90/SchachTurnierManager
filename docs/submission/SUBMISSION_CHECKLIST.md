# OpenAI Build Week submission checklist

This checklist is intentionally fail-closed. `Pending`, `Manual`, and `Owner decision` are not
equivalent to complete.

## Eligibility and scope

- [x] Target category selected: Work & Productivity.
- [x] Pre-existing project status disclosed.
- [x] Submission-period boundary identified: `ecfb473..final-candidate`.
- [ ] Final candidate SHA and exact commit range recorded.
- [ ] Final change log contains only demonstrated, landed functionality.

## Product and design

- [ ] Windows Setup installs per-user by double-click without development tools.
- [x] Clear first run offers tournament creation and an explicit synthetic demo in the source candidate.
- [x] Main navigation focuses on Overview, Participants, Round, Standings, and More.
- [x] Tournament creation uses progressive disclosure and safe defaults.
- [x] FIDE-Dutch is opt-in, keeps Optimal V2 default, and does not silently change existing tournaments.
- [x] Result changes use an explicit confirmation and one-step undo through the audited API path.
- [x] Standings show core columns before opt-in advanced tie-breaks.
- [ ] German and English five-minute demo paths are complete.
- [ ] Required viewport/light/dark/keyboard/accessibility evidence is captured.

## Compatibility and mobile

- [x] Synthetic TRF16 export demonstrated in the isolated API smoke.
- [ ] Synthetic Swiss-Manager CSV import/export demonstrated within documented scope.
- [ ] PR #49 gate issue resolved without a general binary bypass.
- [ ] Android candidate rebuilt from the final SHA.
- [ ] Android manifest, permissions, network policy, trackers, secrets, fixed hosts, and signature verified.
- [ ] Galaxy S25 install/connect/result/rotation/restart/upgrade/uninstall test completed by the Owner.

## Repository and documentation

- [x] README starts with an English product/judge path and accurately describes current candidate status.
- [x] Judge quickstart is written as a five-minute synthetic-data path; final timed manual run pending.
- [x] Build Week prior/new work boundary documented.
- [x] Codex/GPT-5.6/Claude/Marcel/Owner attribution documented honestly.
- [x] Working limitations documented without certification/release/offline overclaims.
- [ ] Final third-party notice/license/vulnerability inventory generated.
- [ ] Repository license or official private-access path decided by Owner.
- [x] README and submission local links pass checks.

## Builds and quality

- [ ] Final SHA frozen; no features after freeze.
- [x] Required PowerShell/security/collaboration/routing source gates green on the UX branch.
- [x] `dotnet restore`, build, and all 519 tests green on the UX branch.
- [x] `npm ci` (0 advisories), TypeScript, and Vite build green.
- [x] Portable packaging and ReleaseGate green; exact-candidate fresh runs remain pending.
- [ ] Final Setup built, smoked, hashed, and manifest-bound.
- [ ] Android debug/release/lint builds green.
- [ ] Final test APK signature and certificate fingerprint verified.
- [ ] Public-safe handoff ZIP excludes secrets, IDs, private paths/logs, real data, and binaries not intended for the handoff.

## Submission materials

- [x] English Devpost draft complete; final SHA/artifact placeholders remain.
- [x] English voice-over and video shot list target 2:50–2:55.
- [ ] Public YouTube URL added by Owner; no unlicensed music/images/trademarks.
- [ ] Repository URL and testing instructions added.
- [ ] Actual `/feedback` Session ID captured locally from this same primary thread.
- [ ] Only the Session ID SHA-256 and safe metadata committed.
- [ ] Devpost form submitted by Owner before 2026-07-21 17:00 PT.

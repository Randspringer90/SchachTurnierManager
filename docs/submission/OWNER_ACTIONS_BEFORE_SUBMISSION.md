# Owner Actions Before Submission

Complete these actions in order. None is represented as already complete.

## 0. State after the run of 2026-07-19 (read first)

That run had **no network access at all**: `github.com:443` and
`registry.npmjs.org:443` were both unreachable and the stored `gh` token is
invalid. Consequently **nothing was pushed, no pull request was opened, updated
or merged, and no CI ran.** Everything it produced exists only in the local
clone.

| Item | State |
|---|---|
| Candidate branch | `integration/final-candidate` at `eee20dd50e7403d4728367ce69ef6eb80d985d99`, **local only** |
| Base | `development` at `995d1a1f50fc883e8533d69eddcc8f894555cf84` |
| PR #51 scope (Build Week UX, demo) | integrated into the candidate branch locally |
| STM-FE-013/014 frontend modularization | integrated; `main.tsx` is now a 23-line bootstrap |
| Firefox reset/delete fix | implemented and unit/guard tested; **manual browser pass still owed** |
| PR #49 (Android companion) | **not merged**, see below |
| Windows Setup | built from the candidate: `SchachTurnierManager_Setup_0.54.1.exe`, SHA-256 `A4E44D6D997248FC40C0943054A2CB9B5A218B333C87854A6D0438C6EB181707`, unsigned |
| Android APK | **not produced** |

**First action:** restore network/auth and push, otherwise none of the above
reaches `origin/development`.

```powershell
gh auth refresh -h github.com
git fetch origin --prune
git log --oneline origin/development..integration/final-candidate
git push -u origin integration/final-candidate
```

### Why PR #49 was deliberately not merged

Merging it would have invalidated the gate built to make it safe.
`config/pull-request-artifact-attestations.json` pins 30 binary artifacts to
head `5aecee91…` **and** base `a6f68e8`. `development` has since moved to
`995d1a1`, so that attestation no longer covers a merge onto the current
candidate, and the approval is explicitly `OWNER_REVIEW_REQUIRED`. Committing
binaries into a public repository stays an owner decision. Either re-verify and
re-issue the attestation against the new base, or rebuild the companion from a
fresh branch off the merged candidate and replace #49.

Until that is resolved there is no APK for this candidate, and section B of
`OWNER_MANUAL_TEST.md` cannot be run. Do not present an older APK as this
candidate.

## Repository and merge control

1. Resolve the public-repository licence decision in `LICENSE_DECISION.md`.
2. Review and, only if satisfied, merge PR #50 through the protected workflow.
3. Update PR #49 from current `development` without force-push; regenerate its exact artifact
   attestation and repeat static review/CI before any merge decision.
4. Update PR #51 from the post-Android base without force-push; resolve overlap and repeat protected
   prompt-tool/security review before any merge decision.
5. Follow `FINAL_MERGE_ORDER.md`; do not carry an approval across a changed base or head SHA.

## Exact candidate and artifacts

1. Record the final `development` SHA and version source.
2. Run the complete release-candidate readiness and preserve its public-safe summary.
3. Rebuild the Windows setup, desktop package and signed Android test APK from that exact SHA.
4. Keep signing material and passwords under the local secret boundary; never copy them into the
   run ZIP, repository, PR, issue, video or submission form.
5. Record artifact file names, sizes, SHA-256 values, signing certificate fingerprint and signature
   verification in the local artifact manifest.
6. If any input changes, invalidate the artifacts and rebuild.

## Manual acceptance

1. Follow the committed manual-test guide for the Windows fresh-install, persistence, export,
   uninstall and data-retention checks using synthetic data only.
2. Run the Galaxy S25 install, same-WLAN connection, pairing read, confirmed synthetic result,
   standings update, rotation, restart, same-signature upgrade and uninstall checks.
3. Classify findings as P0, P1, P2 or P3. Fix only P0, reproducible P1, documentation, evidence or
   packaging issues after freeze.
4. Do not record a manual step as passed without evidence from the exact candidate.

## Video and submission

1. Record the English voice-over from `VIDEO_SHOTLIST.md` and `DEMO_SCRIPT_EN.md` using only the
   exact accepted candidate and synthetic players.
2. Keep the public YouTube video under three minutes and include an audible, accurate explanation
   of both Codex and GPT-5.6 use.
3. Replace all placeholders in `DEVPOST_DRAFT.md`; do not claim that the pre-existing project was
   created entirely during Build Week.
4. Confirm the repository/test-access route required by the final licence decision.
5. Upload and submit only after the final checklist is complete; this Codex run performs neither.

## Primary-thread feedback

After the core run is complete, execute `/feedback` in this exact primary Codex thread. Store the
real Session ID only in the run's private local file. Add only its SHA-256, capture time, Codex
version, model, prompt/report paths and Build Week commit range to public metadata. Enter the real
ID manually in Devpost.

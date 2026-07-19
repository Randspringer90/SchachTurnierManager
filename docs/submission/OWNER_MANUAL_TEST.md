# Owner's final manual candidate test

Run only against filenames and hashes from the final `artifact-manifest.json`. Record the exact
candidate SHA, version, Windows build, Galaxy model/Android version, timestamps and tester. Use a
fresh synthetic profile; do not modify a real tournament database.

## Candidate under test (run of 2026-07-19)

| Item | Value |
|---|---|
| Candidate commit | `9fe244363e43b32feb2b5cd2f49cf1236a36a97e` |
| Branch | `integration/final-candidate` — **local only, not yet pushed** |
| App version | 0.54.1 |
| Setup | `SchachTurnierManager_Setup_0.54.1.exe` |
| SHA-256 | `D5D9E1DFE3A20209609F0DE9AC6E9B5468FF8E7F19D8DC253534961DA2D8CAE0` |
| Size | 38,556,523 bytes (36.77 MB) |
| Signature | **unsigned** — SmartScreen will warn ("unknown publisher"). No production code-signing certificate exists for this project. |
| Android APK | **not produced by this run** — see section B. |

Verify the hash before running the setup:

```powershell
Get-FileHash .\SchachTurnierManager_Setup_0.54.1.exe -Algorithm SHA256
```

## Result classes

- **P0 Submission blocker:** installation, launch, core data integrity, pairing/result path,
  security/privacy, signature or candidate-SHA mismatch.
- **P1 Fix before video:** reproducible failure/confusion in the recorded judge path, responsive
  layout or connection workflow.
- **P2 Document:** non-core limitation with a safe workaround that does not undermine the claims.
- **P3 After competition:** polish or roadmap item outside the frozen submission path.

Mark every step Pass, Fail or Not applicable and attach a public-safe screenshot/log reference.

## A. Windows

1. Detect any old test installation and record its version/path; do not remove real user data.
2. Verify the setup filename, SHA-256, version and candidate SHA against the manifest.
3. Start the setup EXE by double-click and confirm it does not require administrator rights.
4. Record the installation directory and created shortcuts.
5. Launch the app and confirm the final version is visible.
6. Choose English, then **Open demo tournament**.
7. Verify exactly eight synthetic participants and no real names/IDs.
8. Open Round; preview and generate the next round.
9. Select one synthetic result, confirm the write and test Undo.
10. Verify the standings change and the extra tie-break toggle works.
11. Close the app, restart it and confirm tournament/round/result persistence.
12. Export TRF16, Swiss-Manager CSV and JSON backup; verify non-empty output and safe filenames.
13. Review application logs for errors, secrets, query strings, private paths shown in UI or PII.
14. Uninstall through Windows.
15. Confirm binaries/shortcuts are removed and document whether local tournament data was retained.

## A2. Reset and delete — the Firefox regression (run in Firefox first, then Chromium)

This is the defect this candidate fixes, and it is on the recorded judge path.
Previously the flow used `window.confirm` and then `window.prompt`; Firefox
suppresses repeated modal dialogs from the same script turn ("prevent this page
from creating additional dialogs"), which silently aborted the delete and left a
stale selection behind. Both actions now use an in-app dialog.

Open *More → Admin → Dangerous actions*.

**Reset**

1. Press **Turnier zurücksetzen**.
   - An in-app dialog opens. **No** native browser dialog appears at any point.
   - The dialog names the tournament and lists the exact consequences:
     participants and settings kept; rounds, results and Chess960 starting
     positions removed.
2. Press `Esc` — the dialog closes and nothing changed.
3. Click outside the dialog — it closes and nothing changed.
4. Reopen and use the keyboard only: `Tab` and `Shift+Tab` cycle inside the
   dialog and never move focus behind it.
5. Cancel — focus returns to the *Turnier zurücksetzen* button.
6. Confirm — participants and settings remain, rounds and results are gone.

**Delete**

7. Press **Turnier löschen**.
   - An in-app dialog opens. **No** native `confirm` and **no** native `prompt`
     appears at any point.
8. The delete button stays disabled until the tournament name is typed exactly.
   Verify that wrong case, a leading/trailing space and a partial name all keep
   it disabled, and that the exact name enables it.
9. Confirm — the tournament is deleted, the list refreshes and another
   tournament is selected automatically.
10. Double-click the confirm button on a second tournament: the button shows a
    loading state and disables itself; exactly one delete request is sent.
11. Delete the last remaining tournament: a clean empty state appears with no
    error banner and no request against the deleted id.
12. Repeat steps 1–11 in Chromium/Edge.

Anything failing here is **P0** for the demo video.

## B. Samsung Galaxy S25

> **Not deliverable from this run.** No APK was produced. The Android companion
> (PR #49) is not merged: its 30 binary artifacts are pinned to an
> `OWNER_REVIEW_REQUIRED` attestation bound to base `a6f68e8`, which
> `development` (`995d1a1`) has since superseded, and this run had no network
> access to update, re-verify or merge the pull request. See
> `docs/submission/OWNER_ACTIONS_BEFORE_SUBMISSION.md`.
>
> Do not install an older APK from a previous run and present it as this
> candidate — it would not match the candidate commit. Run the steps below only
> once a companion APK has been built from the merged candidate SHA.

1. Verify APK filename and SHA-256 against the final manifest.
2. Deliberately enable installation from the chosen trusted file source; do not weaken unrelated
   device security settings.
3. Install the APK and record Android's version/signing information.
4. Launch and verify the companion explanation and no cloud/offline overclaim.
5. Put PC and phone on the same trusted Wi-Fi/hotspot.
6. Enter the PC's private IPv4 or `.local` address; do not record the address in public evidence.
7. Connect and verify the service identity check succeeds.
8. Open `Build Week Demo Open` and read one pairing.
9. Enter one synthetic result and review the confirmation.
10. Verify the PC reflects the result and standings update.
11. Rotate portrait/landscape and check for clipped actions or unusable horizontal scrolling.
12. Restart the companion and reconnect.
13. Install the same-signed newer candidate over the first APK if an upgrade fixture is available;
    confirm Android accepts the signature lineage.
14. Uninstall and verify app removal.
15. Return “install unknown apps” to the user's preferred prior setting if it was changed only for
    this test.

## C. UX questions for each primary step

- Was the next action clear without explanation?
- Was there more than one competing primary action?
- Was specialist language unnecessary or unexplained?
- Was the next action visible at the tested viewport?
- Was the mobile view usable without chaotic horizontal scrolling?
- Were error messages specific and actionable?
- Was it clear which action changed data?
- Could keyboard focus be seen and followed?
- Did colour communicate anything without text/icon support?

Test widths 320, 360, 390, 412, 768, 1024 and 1440 px in both light and dark mode. Use portrait for
phone widths and test landscape where it changes the workflow. Cover empty, loading, error, success
and a larger participant/round state. Record browser/version and zoom.

## Stop rules

Stop and classify P0 if a hash/signature/SHA differs, the app touches real data, a secret/private
path appears in public output, result/pairing integrity is uncertain or an installation step
requires an undocumented security relaxation. Do not record the video from a failed candidate.

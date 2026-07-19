# Owner's final manual candidate test

Run only against filenames and hashes from the final `artifact-manifest.json`. Record the exact
candidate SHA, version, Windows build, Galaxy model/Android version, timestamps and tester. Use a
fresh synthetic profile; do not modify a real tournament database.

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

## B. Samsung Galaxy S25

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

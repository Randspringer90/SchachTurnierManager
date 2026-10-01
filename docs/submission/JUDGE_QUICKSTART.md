# Judge quickstart

Target time: under five minutes
Candidate version: 0.54.1 (replace with the final manifest if the version changes)
Data: synthetic only

## Packaged Windows path

1. Download the owner-provided submission-candidate package and verify its SHA-256 against the
   adjacent artifact manifest.
2. Run the Windows setup. It is a per-user installation and should not request administrator
   rights.
3. Start **SchachTurnierManager** from the desktop or Start menu shortcut.
4. Choose **English** in the header if needed.
5. Select **Open demo tournament**. Wait for the success message.
6. Open **Participants**: eight `Demo Player NN` records are present.
7. Open **Round**: round one is complete. Choose **Pairing preview**, review the audit summary,
   then generate the next round.
8. Select a result. Review the confirmation and choose **Save result**. The Undo action remains
   visible.
9. Open **Standings** and confirm that the table updates. Use **More tie-breaks** only if desired.
10. Open **More → Print, export & backup** and generate the TRF16 or Swiss-Manager export.

The core path is local. No account, cloud service, advertisement or analytics consent is required.

## Source fallback

If the owner has not supplied the final setup, follow the source instructions in the repository
README. A source run is a fallback, not evidence that the installer candidate passed.

## Optional Android companion demonstration

This step is available only after PR #49, the artifact gate and the final manifest are accepted.

1. Verify the APK SHA-256 against the final artifact manifest.
2. Install the owner-provided APK on the test phone.
3. Put the phone and tournament PC on the same trusted Wi-Fi or hotspot.
4. In the companion, enter the PC's private IPv4 or `.local` address.
5. Connect, open the synthetic demo, select a board and submit one result.
6. Confirm the write on the phone and verify the changed standings on the PC.

The companion is not a standalone offline tournament manager and does not use a cloud relay.

## What to verify

- The next action is obvious in each primary area.
- FIDE Dutch is visible as an opt-in choice; Optimal V2 remains the normal default.
- A result is never written merely by changing a select control.
- Advanced exports and audit details do not crowd the main navigation.
- German and English are presented as complete demo languages; other languages say Preview.
- No real player names or identifiers appear.

## Known test boundary

Final setup/APK paths and hashes are intentionally not hard-coded here. The owner must use the
exact filenames from `artifact-manifest.json`. Galaxy S25 and final visual breakpoint evidence must
be recorded before the video or submission claims those checks as passed.

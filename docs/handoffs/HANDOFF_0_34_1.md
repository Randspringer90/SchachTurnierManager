# Handoff 0.34.1 - Audit Journal Round Review Fix

## Ziel

0.34.1 ist ein Fix-Forward für 0.34.0. Der Domain-/Application-Build war grün, aber der neue Auditjournal-Regressionstest `AuditJournal_TracksManualCorrectionsAndRoundReview` scheiterte, weil Sperren/Entsperren/Prüfen einer Runde zwar im bestehenden Rundenaudit landeten, aber nicht im neuen persistenten `TournamentState.AuditJournal`.

## Änderung

- `SetRoundLock(...)` schreibt jetzt `RoundLocked` bzw. `RoundUnlocked` in das persistente Auditjournal.
- `SetRoundVerified(...)` schreibt jetzt `RoundVerified` bzw. `RoundUnverified` in das persistente Auditjournal.
- Keine Änderung an Auslosungslogik, Wertungsberechnung, Speicherformat über das bereits in 0.34.0 eingeführte Auditjournal hinaus oder UI.

## Erwartung

- `dotnet test`: 81/81 grün.
- `npm run build`: grün.
- `Pack-Portable`: `SchachTurnierManager_Portable_0.34.1.zip`.
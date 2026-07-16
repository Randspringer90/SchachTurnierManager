# Nightly-Resume bleibt plan-only und SHA-gebunden

- source: STM-AI-004 Owner-Auftrag und lokale Sicherheitsanalyse
- date: 2026-07-16
- trust: T0 Auftrag; Checkpoints und Testausgaben bleiben T3-Daten
- review: Owner-PR, Security-Review und Remote-CI vor Integration vorgesehen

## Kontext

Unterbrochene Läufe benötigen einen reproduzierbaren Zwischenstand. Freitext aus
vorherigen Läufen, Logs oder externen Quellen darf dabei nicht zur Instruktion oder
automatisch ausgeführten Aktion werden.

## Entscheidung

Ein Nightly-Checkpoint speichert nur redigierte Metadaten, bindet sie an Projekt,
Branch und Head und schreibt atomar in den ignorierten Output. Resume validiert die
Bindung sowie den aktuellen Git-Zustand und liefert ausschließlich einen Plan. Die
Registrierung bleibt bis zu einer getrennten Owner-Aktivierung
`READY_FOR_ACTIVATION`; alle externen Mutationsrechte sind `false`.

## Folgen

Saubere, grüne Zwischenstände sind wiederaufnehmbar. Manipulation, Git-Drift,
Attempt-Überschreitung, Secrets, PII, absolute Pfade und Reparse-Points blockieren
fail-closed. Das Projekt bleibt unabhängig von fremden Maschinen und Orchestratoren.

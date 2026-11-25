# ADR-0005: Immer aktuelle Abhängigkeiten aus geprüften öffentlichen Paketquellen

- Status: angenommen (Owner-Entscheidung 2026-11-24)

## Kontext
Es gibt nur die jeweils neueste STM-Version. Veraltete Pakete hatten bekannte Schwachstellen
(npm audit vor dem Update: 4 hoch). Auf Entwicklerrechnern können Benutzerprofile auf fremde,
z. B. betriebliche Paket-Registries zeigen.

## Entscheidung
- Neueste stabile Versionen: .NET SDK 11 / `net11.0`, EF Core 11, Node.js 26 LTS, Vite 8.3, React 19.3,
  aktuelle GitHub-Action-Releases (per Commit-SHA mit Versionskommentar gepinnt).
- Ein Major-Wechsel nur, wenn alles grün ist. TypeScript bleibt auf 6.0.3, weil Tests die JavaScript-
  Compiler-API nutzen, die TypeScript 7 nicht mehr bereitstellt (Folgeauftrag: Testhilfen migrieren).
- .NET 11 ist ein STS-Release (Support kürzer als .NET 10 LTS); bei dieser Aktualitätsregel wird regulär
  auf das nächste Release gewechselt.
- NuGet: nur nuget.org, Signaturpflicht, Paketinhaber-Allowlist in `NuGet.Config`, Lockfiles, Audit als Fehler.
- npm: nur über `scripts/Invoke-NpmSafe.ps1` (isolierte Konfiguration, `--ignore-scripts`); Lockfile
  verweist ausschließlich auf `registry.npmjs.org`.

## Folgen
- Regelmäßige Update-Läufe mit vollständigen Tests; Ergebnisse in `CHANGELOG.md`.
- Entwickler benötigen Node 26 (`.node-version`) und .NET SDK 11.

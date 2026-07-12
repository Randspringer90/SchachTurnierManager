# V0.41-Reconciliation (STM-INT-001)

> Technische Bestandsaufnahme und Migrationsentscheidung für die Konsolidierung des beim
> development-Bootstrap integrierten v0.41-Stands. Ziel: **ein** kanonischer, getesteter Stand
> ohne unnötige Doppelungen, tote Pfade oder widersprüchliche APIs. **Keine** neue Fachfunktion,
> **keine** Änderung an Pairing/Tie-Breaks.

## Vorhandene Implementierungen (Ist)

| Bereich | Fundstelle | Status |
|---------|-----------|--------|
| Lokale KI-Hilfe (Backend) | `src/SchachTurnierManager.Application/Ai/` (`IAiHelpProvider`, `DisabledAiHelpProvider`, `LocalDocsAiHelpProvider`, `LocalAiHelpKnowledgeBase`, `AiHelpModels`) | **tot** – nirgends in `src/` referenziert, **nicht** in der WebApi verdrahtet, kein API-Endpunkt, nur durch den isolierten Test `AiHelpProviderTests.cs` benutzt |
| Lokale KI-Hilfe / Wissensbasis (Frontend) | `src/SchachTurnierManager.WebApp/src/knowledge/localKnowledgeBase.json` + Assistent-/Hilfe-UI in `src/…/main.tsx` | **kanonisch, live** – providerlos/offline, Felder `providerMode`, `topics`, `quickQuestions`, `privacyNotice` |
| Export | `src/SchachTurnierManager.Domain/Services/TournamentExportFormatter.cs` | **kanonisch, live** – referenziert von `TournamentService` und Tests |
| Audit-/Forensik-Export | `src/SchachTurnierManager.Domain/Services/AuditForensicExportBuilder.cs`, `ExportDocument.cs` | live, eigenständige Funktion (keine Doppelung mit TournamentExportFormatter) |
| Operator-/Health-Dashboard | WebApi (`/api/health`, Dashboard-Einbettung in `Program.cs`) + `main.tsx` | kanonisch, live |

## Überschneidungen

- **Nur eine echte Doppelung:** Das Backend-Modul `Application/Ai/` bildet dieselbe Idee
  (lokale, providerlose Hilfe aus einer Themen-/Wissensbasis) ab wie die **kanonische**
  Frontend-Wissensbasis (`localKnowledgeBase.json`). Das Backend-Modul wurde jedoch nie in
  die WebApi eingebunden (kein DI, kein Endpunkt) und ist damit ein **totes Parallel-API**.
- **Keine** Doppelung bei Export (TournamentExportFormatter ist die einzige referenzierte
  Turnierexport-Formatierung; AuditForensicExportBuilder ist eine getrennte Funktion).
- **Keine** doppelten Dashboard-/Health-Endpunkte gefunden.

## Kanonische Zielkomponenten

| Bereich | Kanonisch |
|---------|-----------|
| Lokale KI-Hilfe/Wissensbasis | **Frontend** `localKnowledgeBase.json` + Assistent-UI (offline, providerlos) |
| Turnierexport | `TournamentExportFormatter` (Domain) |
| Dashboard/Health | bestehende WebApi-/WebApp-Funktionen |

## Zu erhaltende Funktionen
- Lokale, offline nutzbare Hilfe ohne externen Provider (bleibt über die Frontend-Wissensbasis
  vollständig erhalten – inklusive der Themen wie „qr-handy", die das tote Backend-Modul nur
  dupliziert hatte).
- Deterministischer Turnierexport.

## Zu entfernende Doppelungen
- Das komplette tote Modul `src/SchachTurnierManager.Application/Ai/` (5 Dateien) und der dazu
  isolierte Test `tests/SchachTurnierManager.Application.Tests/AiHelpProviderTests.cs`.

## Migrationsentscheidung
- **Entfernen statt migrieren:** Das Backend-Modul ist unreferenziert und dupliziert die
  bereits kanonische Frontend-Hilfe funktional vollständig. Es gibt keine einzigartige,
  produktiv genutzte Funktion, die migriert werden müsste (kein Endpunkt, keine UI, keine DI).
- **BYOK-Ausblick:** Ein späterer echter Provider (BYOK, Backlog **STM-UX-004**) wird bei Bedarf
  **frisch in Infrastructure** entworfen (konkreter Provider = Infrastructure, providerneutrale
  Schnittstelle = Application), nicht aus diesem toten Modul wiederbelebt. So bleiben die
  Schichtregeln aus `AGENTS.md`/`AI_AGENT_ARCHITECTURE.md` sauber.

## Risiken
- **Gering.** Da das Modul unreferenziert ist, kann seine Entfernung keinen Produktionspfad
  brechen; Build/Tests beweisen das. Einziger betroffener Test ist der isolierte Modul-Test,
  der mit entfernt wird.
- Kein Einfluss auf Pairing/Tie-Breaks/Export (unverändert).

## Teststrategie
- Vollständiger `dotnet build` + `dotnet test` nach der Entfernung (beweist: nichts referenzierte
  das Modul).
- Neuer kanonischer Test `KnowledgeBaseCanonicalTests`: die Frontend-Wissensbasis ist gültiges
  JSON, nicht leer, hat `providerMode`/`topics` und enthält **keine** Secrets oder Owner-Pfade
  (deterministische, offline nutzbare kanonische Hilfe).
- Frontend-Typecheck + Build (unverändert lauffähig).

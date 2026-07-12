# KI-Hilfe / interner Assistent

Status: erste sichere Integration ab 0.44.0. Default bleibt aus.

## Ziel

Der In-App-Reiter **Hilfe / Assistent** gibt Turnierleitern lokale Hilfe:

- Runbook-Fragen beantworten: Start, Backup, Restore, Import, Export, QR/Chess960.
- Operator-Checklisten zusammenfassen.
- Fehlermeldungen aus App/Skripten erklaeren.
- Keine Paarungen automatisch aendern und keine Turnierdaten ohne bewusste Freigabe senden.

## Nicht-Ziele

- Keine Cloud-Aufrufe in Tests.
- Keine API-Keys, Tokens oder Provider-Secrets im Git.
- Kein automatisches Senden echter Teilnehmerlisten, lokaler JSONs, Datenbanken oder Logs.
- Kein Ersatz fuer Pairing-Engine, Audit-Journal oder manuelle Turnierleiterentscheidung.

## Provider-Abstraktion

Implementierter Application-Vertrag:

```csharp
public interface IAiHelpProvider
{
    AiHelpStatus GetStatus();
    Task<AiHelpResponse> AskAsync(AiHelpRequest request, CancellationToken cancellationToken);
}

public sealed record AiHelpRequest(string Question);

public sealed record AiHelpResponse(
    bool IsConfigured,
    AiHelpMode Mode,
    string Provider,
    string Answer,
    IReadOnlyList<string> Citations,
    IReadOnlyList<string> Warnings,
    IReadOnlyList<AiHelpTopic> Topics);

public enum AiHelpMode
{
    Disabled = 0,
    LocalDocsOnly = 1,
    OpenAi = 2,
    Anthropic = 3,
    CustomHttp = 4
}
```

Implementiert sind:

- `DisabledAiHelpProvider`: Default, liefert klar `KI-Hilfe nicht konfiguriert`.
- `LocalDocsAiHelpProvider`: lokale Docs-only-Antworten aus kuratierten Runbook-Themen.

Nicht implementiert sind echte OpenAI-/Claude-/Custom-HTTP-Adapter. Sie bleiben bewusst nur
Config-Shape, bis BYO-Key, Kostenkontrolle, Datenschutz und Tests explizit freigegeben sind.

## Lokale Config-Shape

Siehe `.env.example`. Erwartete Regeln:

- `STM_AI_HELP_ENABLED=false` als Default.
- `STM_AI_PROVIDER=disabled` als Default.
- Optional lokal: `STM_AI_PROVIDER=local-docs` mit `STM_AI_HELP_ENABLED=true`.
- Provider-Keys nur lokal in `.env`, User Secrets oder Prozessumgebung.
- `.env` bleibt gitignored; `.env.example` enthaelt nur leere Beispielwerte.
- Tests duerfen keine echten Provider ansprechen.

## Wissensquellen

Zulaessige erste Quellen:

- `README.md`
- `docs/BERGFEST_MVP_RUNBOOK.md`
- `docs/FRIDAY_BERGFEST_CHECKLIST.md`
- `docs/FRIDAY_BERGFEST_OPERATOR_CARD.md`
- `docs/TOURNAMENT_PRESET_IMPORT.md`
- `docs/AUDIT_JOURNAL.md`
- `docs/SWISS_PAIRING_ENGINE.md`

Private Quellen wie `local-input/**`, `output/**`, Datenbanken, Logs und Backups sind
ausgeschlossen. Die 0.44.0-Implementierung nutzt kuratierte Themen und indexiert keine
privaten Rohdaten.

## UI-Verhalten

- Der Reiter **Hilfe / Assistent** zeigt Provider-Status, Fragefeld, Antwortbox und lokale
  Hilfethemen-Suche.
- Bei fehlender Konfiguration bleibt die UI bedienbar und zeigt `KI-Hilfe nicht konfiguriert`.
- Lokale Hilfethemen bleiben auch bei Backend-/Providerfehlern als Fallback sichtbar.
- Providerfehler duerfen die App nicht blockieren; die API gibt eine weiche Antwort mit Warnung.

## Secret-Gates

Vor jeder KI-Provider-Implementierung:

- `.npmrc` auf Tokens/Registry-Secrets pruefen.
- `.env` nicht committen.
- `scripts\Test-RepositoryOpenSourceSafety.ps1` und `git diff --check` ausfuehren.
- Unit-/Contract-Tests mit Mock-Provider, nicht mit echten Keys.

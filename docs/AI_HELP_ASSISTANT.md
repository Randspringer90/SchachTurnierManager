# KI-Hilfe / interner Assistent

Status: Architekturvorbereitung, noch keine produktive Integration. Default bleibt aus.

## Ziel

Ein spaeterer In-App-Assistent soll Turnierleitern lokale Hilfe geben:

- Runbook-Fragen beantworten: Start, Backup, Restore, Import, Export, QR/Chess960.
- Operator-Checklisten zusammenfassen.
- Fehlermeldungen aus App/Skripten erklaeren.
- Keine Paarungen automatisch aendern und keine Turnierdaten ohne bewusste Freigabe senden.

## Nicht-Ziele fuer die erste Umsetzung

- Keine Cloud-Aufrufe in Tests.
- Keine API-Keys, Tokens oder Provider-Secrets im Git.
- Kein automatisches Senden echter Teilnehmerlisten, lokaler JSONs, Datenbanken oder Logs.
- Kein Ersatz fuer Pairing-Engine, Audit-Journal oder manuelle Turnierleiterentscheidung.

## Provider-Abstraktion

Geplanter Application-Vertrag:

```csharp
public interface IAiHelpProvider
{
    Task<AiHelpResponse> AskAsync(AiHelpRequest request, CancellationToken cancellationToken);
}

public sealed record AiHelpRequest(
    string Question,
    IReadOnlyList<AiHelpDocument> LocalContext,
    AiHelpMode Mode);

public sealed record AiHelpResponse(
    string Answer,
    IReadOnlyList<string> Citations,
    IReadOnlyList<string> Warnings);

public enum AiHelpMode
{
    Mock = 0,
    LocalDocsOnly = 1,
    OpenAi = 2,
    Anthropic = 3,
    CustomHttp = 4
}
```

Erste Implementierung soll mit `Mock`/`LocalDocsOnly` starten. Provider wie OpenAI oder Claude
werden erst danach als optionale Adapter verdrahtet.

## Lokale Config-Shape

Siehe `.env.example`. Erwartete Regeln:

- `STM_AI_HELP_ENABLED=false` als Default.
- `STM_AI_PROVIDER=mock` als Default.
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

Private Quellen wie `local-input/**`, `output/**`, Datenbanken, Logs und Backups sind standardmaessig
ausgeschlossen.

## Secret-Gates

Vor jeder KI-Provider-Implementierung:

- `.npmrc` auf Tokens/Registry-Secrets pruefen.
- `.env` nicht committen.
- `scripts\Test-RepositoryOpenSourceSafety.ps1` und `git diff --check` ausfuehren.
- Unit-/Contract-Tests mit Mock-Provider, nicht mit echten Keys.

using System.Globalization;

namespace SchachTurnierManager.Application.Ai;

public static class LocalAiHelpKnowledgeBase
{
    private static readonly AiHelpTopic[] AllTopics =
    [
        new(
            "start-health",
            "Start, Healthcheck und Neustart",
            "docs/BERGFEST_MVP_RUNBOOK.md#1-backend-starten",
            "Backend auf Port 5088 starten, Healthcheck prüfen, Frontend auf Port 5173 starten und bei Hängern gezielt den jeweiligen Port neu starten.",
            "Backend: dotnet run --project .\\src\\SchachTurnierManager.WebApi\\SchachTurnierManager.WebApi.csproj. Healthcheck: http://localhost:5088/api/health. Frontend: npm run dev im WebApp-Verzeichnis. Wenn ein Fenster hängt, nur den betroffenen Port 5088 oder 5173 stoppen und danach neu starten.",
            ["start", "health", "backend", "frontend", "restart", "runbook"]),
        new(
            "backup-restore",
            "Backup, Restore und kritische Aktionen",
            "docs/BERGFEST_MVP_RUNBOOK.md#6-backup--restore--audit-nach-jeder-runde",
            "Vor Runde 1, nach jeder Runde und vor Reset/Löschen ein JSON-Backup ziehen; Restore nur bewusst und nicht hektisch während einer laufenden Runde.",
            "SQLite speichert automatisch, ersetzt aber kein separates JSON-Backup. Vor Reset, Löschen, Import und nach jeder Runde Backup JSON exportieren. Restore erst nach Sicherung des aktuellen Papier-/App-Stands und mit bewusst gewähltem Snapshot ausführen.",
            ["backup", "restore", "reset", "delete", "kritisch", "json"]),
        new(
            "audit",
            "Audit-Bundle nach jeder Runde",
            "docs/BERGFEST_MVP_RUNBOOK.md#6-backup--restore--audit-nach-jeder-runde",
            "Nach jeder Runde und am Turnierende ein Audit-Bundle exportieren, damit Paarungen, Korrekturen und Warnungen nachvollziehbar bleiben.",
            "Audit-Bundle JSONL oder JSON enthält Manifest, Turnier-Snapshot, Pairing-Forensik und Audit-Journal. Es ist lokale Forensik und kein Cloud-Upload. Nach jeder Runde sichern, besonders nach manuellen Korrekturen.",
            ["audit", "forensik", "bundle", "runde", "korrektur"]),
        new(
            "preset-import",
            "Preset-Import und Warnungen",
            "docs/TOURNAMENT_PRESET_IMPORT.md",
            "Lokale Presets zuerst per Dry-run prüfen; echte local-input-Dateien und Reports bleiben lokal und werden nicht committet.",
            "Dry-run erzeugt CSV und JSON-Report unter output\\reports\\. Echter Import nutzt die API-Vorschau. Warnungen stoppen den Import, bis -AllowWarnings nach Reportprüfung bewusst gesetzt wird.",
            ["import", "preset", "dry-run", "warnungen", "local-input"]),
        new(
            "qr-handy",
            "QR, Handy und lokaler Hotspot",
            "docs/BERGFEST_MVP_RUNBOOK.md#9-qrhandy-vorabtest-vor-dem-ersten-würfeln",
            "QR/Handy funktioniert nur im gleichen WLAN oder Hotspot; localhost funktioniert am Handy nicht.",
            "Laptop-IPv4 eintragen, Handy ins gleiche WLAN/Hotspot bringen und QR vor dem ersten Würfeln testen. Wenn Firewall oder Netz blockiert, am Laptop würfeln; der Turniertag darf nicht am Handy hängen.",
            ["qr", "handy", "hotspot", "wlan", "localhost", "chess960"]),
        new(
            "beamer-zuschauer",
            "Zuschauer- und Beamer-Anzeige",
            "docs/BERGFEST_MVP_RUNBOOK.md#7-export--druck-paarungen--tabelle",
            "Für Zuschauer nur read-only Anzeige oder Ausdrucke nutzen; Operator-Bedienelemente gehören nicht auf den Beamer.",
            "Beamer-Ansicht zeigt aktuelle Paarungen und Tabelle ohne Eingabe-Controls. Für echte Publikumsgeräte nur lokale LAN-Links verwenden, kein Tunnel und kein Cloud-Dienst.",
            ["beamer", "zuschauer", "anzeige", "read-only", "tabelle", "paarungen"]),
        new(
            "export-print",
            "Export, Druck und Turnierpaket",
            "docs/BERGFEST_MVP_RUNBOOK.md#7-export--druck-paarungen--tabelle",
            "Turnierpaket HTML/JSON bündelt Teilnehmerliste, Tabelle, aktuelle Runde, Ergebnisbogen sowie Backup- und Audit-Hinweise.",
            "HTML/CSV/JSON sind bevorzugt. PDF wird ohne neue Abhängigkeit über Browser-Druck erzeugt. Paket ersetzt kein Backup JSON.",
            ["export", "druck", "turnierpaket", "csv", "html", "json", "pdf"]),
        new(
            "result-correction",
            "Ergebnis-Korrektur und offene Bretter",
            "docs/FRIDAY_BERGFEST_OPERATOR_CARD.md",
            "Offene Ergebnisse vor der nächsten Runde klären; Korrekturen am gleichen Brett eintragen und danach Tabelle, Backup und Audit prüfen.",
            "Ergebnisänderungen aktualisieren die Tabelle. Gesperrte/geprüfte Runden schützen vor versehentlichen Änderungen. Bei Papierkorrekturen erst UI anpassen, dann Backup und Audit-Bundle sichern.",
            ["ergebnis", "korrektur", "offen", "runde", "tabelle"]),
        new(
            "collaboration",
            "Zusammenarbeit ohne Rechte-Risiko",
            "docs/COLLABORATION.md",
            "Bekannte arbeiten in kleinen lokalen Branches mit Issues/Review-Vorschlag; Push, PR und Admin-Aktionen bleiben freigabepflichtig.",
            "Rollen trennen: Turnierleiter entscheidet fachlich, Operator bedient vor Ort, Entwickler baut kleine Scheiben, Reviewer prüft Diff/Tests. Keine echten lokalen Daten committen.",
            ["kollaboration", "branch", "issue", "review", "rollen"]),
        new(
            "ai-config",
            "KI-Hilfe konfigurieren",
            "docs/AI_HELP_ASSISTANT.md",
            "KI-Hilfe ist standardmäßig deaktiviert. Lokale Hilfethemen bleiben verfügbar; Provider brauchen BYO-Key in lokaler Umgebung.",
            "Default: STM_AI_HELP_ENABLED=false. OpenAI/Claude/Custom-Provider sind nur als Config-Shape vorbereitet. Tests dürfen keine echten Provider oder Kosten auslösen.",
            ["ki", "ai", "provider", "openai", "claude", "config", "env"])
    ];

    public static IReadOnlyList<AiHelpTopic> Topics => AllTopics;

    public static IReadOnlyList<AiHelpTopic> Search(string question, int maxResults = 4)
    {
        var normalized = Normalize(question);
        if (string.IsNullOrWhiteSpace(normalized))
        {
            return AllTopics.Take(maxResults).ToArray();
        }

        var terms = normalized.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        return AllTopics
            .Select(topic => new { Topic = topic, Score = Score(topic, terms) })
            .Where(item => item.Score > 0)
            .OrderByDescending(item => item.Score)
            .ThenBy(item => item.Topic.Title, StringComparer.OrdinalIgnoreCase)
            .Take(maxResults)
            .Select(item => item.Topic)
            .ToArray();
    }

    private static int Score(AiHelpTopic topic, IReadOnlyList<string> terms)
    {
        var title = Normalize(topic.Title);
        var body = Normalize($"{topic.Summary} {topic.Body}");
        var tags = topic.Tags.Select(Normalize).ToArray();
        var score = 0;
        foreach (var term in terms)
        {
            if (title.Contains(term, StringComparison.Ordinal))
            {
                score += 5;
            }
            if (tags.Any(tag => tag.Contains(term, StringComparison.Ordinal)))
            {
                score += 4;
            }
            if (body.Contains(term, StringComparison.Ordinal))
            {
                score += 1;
            }
        }

        return score;
    }

    private static string Normalize(string value)
    {
        return value.Trim().ToLower(CultureInfo.GetCultureInfo("de-DE"));
    }
}

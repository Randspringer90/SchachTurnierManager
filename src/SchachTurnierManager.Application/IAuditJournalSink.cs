using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Application;

/// <summary>
/// Spiegelt Audit-Journal-Ereignisse zusätzlich zur Turnier-Datenbank in einen
/// unabhängigen, append-only Speicher (z. B. eine JSONL-Datei pro Turnier). Damit bleibt
/// der forensische Verlauf erhalten, selbst wenn die Turnierdatenbank verloren geht oder
/// zurückgesetzt wird. Implementierungen dürfen bei Schreibfehlern werfen – der Aufrufer
/// fängt das ab, damit der eigentliche Turnierschritt nie an einem Spiegelfehler scheitert.
/// </summary>
public interface IAuditJournalSink
{
    void Append(Guid tournamentId, string tournamentName, AuditJournalEntry entry);
}

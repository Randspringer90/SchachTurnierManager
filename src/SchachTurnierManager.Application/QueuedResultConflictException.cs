namespace SchachTurnierManager.Application;

public sealed class QueuedResultConflictException() : InvalidOperationException(
    "Das vorgemerkte Ergebnis passt nicht mehr zum Serverstand. Bitte aktuellen Stand prüfen; es wurde nichts überschrieben.");

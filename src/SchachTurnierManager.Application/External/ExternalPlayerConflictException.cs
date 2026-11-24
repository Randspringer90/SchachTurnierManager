namespace SchachTurnierManager.Application.External;

public sealed class ExternalPlayerConflictException() : InvalidOperationException("Der Zielspieler wurde seit der Vorschau geaendert. Aktuelle Werte laden und Feldauswahl erneut bestaetigen.");

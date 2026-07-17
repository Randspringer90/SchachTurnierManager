using SchachTurnierManager.Domain.Models;

namespace SchachTurnierManager.Domain.Services;

/// <summary>
/// Ein austauschbares Auslosungsverfahren fuer das Schweizer System (STM-FACH-002).
/// </summary>
/// <remarks>
/// Hintergrund der Architektur: Die bestehende <see cref="SwissPairingEngine"/> minimiert global
/// eine Gesamtstrafe ueber alle Bretter. FIDE-Dutch dagegen arbeitet eine fest vorgeschriebene
/// Reihenfolge ab (Bracket fuer Bracket, S1 gegen S2, definierte Transpositionen). Beides sind
/// grundverschiedene Verfahren, die sich nicht ineinander ueberfuehren lassen — deshalb stehen sie
/// hinter diesem Interface nebeneinander statt uebereinander. So bleibt die V2-Engine unveraendert
/// lauffaehig und beide Verfahren bleiben vergleichbar (vgl. docs/SWISS_PAIRING_ENGINE.md).
///
/// Jede Implementierung MUSS deterministisch sein: identische Eingabe ergibt identische Auslosung.
/// FIDE C.04.2 Art. 1.4 verlangt ausdruecklich, dass verschiedene Schiedsrichter und verschiedene
/// zugelassene Programme zu identischen Paarungen kommen. Zufall ist damit ausgeschlossen — auch
/// die ausgeloste Anfangsfarbe ist Eingabe (<see cref="TournamentSettings.SwissInitialColour"/>)
/// und wird nicht selbst gewuerfelt.
/// </remarks>
public interface ISwissPairingStrategy
{
    /// <summary>Welches Verfahren diese Implementierung umsetzt.</summary>
    SwissPairingStrategyKind Kind { get; }

    /// <summary>
    /// Erzeugt die naechste Runde. Die Entscheidungen muessen im
    /// <see cref="TournamentRound.Audit"/> nachvollziehbar dokumentiert sein — eine Auslosung, die
    /// der Turnierleiter nicht erklaeren kann, ist nach C.04.1 Art. 9 nicht zulaessig.
    /// </summary>
    TournamentRound GenerateNextRound(TournamentState tournament);
}

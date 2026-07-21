// Standalone, slim dice page for phones (opened via QR / LAN URL
// ?dice=...&round=...&board=...). Loads only that one tournament, shows only
// that board and uses the same backend endpoint.
// Extracted from main.tsx (STM-FE-014).
import React from 'react';
import { describeApiError, requestJson } from '../../api/client';
import { BoardDiceRoller } from '../../components/chess960/BoardDiceRoller';
import type { BoardDiceParams } from '../../lib/chess960';
import type { Tournament } from '../../api/contracts';
export function MobileDicePage({ params }: { params: BoardDiceParams }): React.ReactElement {
  const [tournament, setTournament] = React.useState<Tournament | null>(null);
  const [error, setError] = React.useState<string | null>(null);
  const [loading, setLoading] = React.useState(true);

  const load = React.useCallback(async () => {
    try {
      const data = await requestJson<Tournament>(`/api/tournaments/${params.tournamentId}`);
      setTournament(data);
      setError(null);
    } catch (ex) {
      setError(describeApiError(ex));
    } finally {
      setLoading(false);
    }
  }, [params.tournamentId]);

  React.useEffect(() => {
    void load();
  }, [load]);

  const round = tournament?.rounds.find(item => item.roundNumber === params.roundNumber) ?? null;
  const pairing = round?.pairings.find(item => item.boardNumber === params.boardNumber) ?? null;
  const playerName = (id?: string | null): string => tournament?.players.find(player => player.id === id)?.name ?? '—';

  return (
    <div className="mobile-dice">
      <header className="mobile-dice-header">
        <p className="eyebrow">Schachwürfel · Chess960</p>
        <h1>{tournament?.name ?? 'Turnier wird geladen …'}</h1>
        <p className="muted">Runde {params.roundNumber} · Brett {params.boardNumber}</p>
      </header>

      {loading && <p className="muted">Lädt …</p>}
      {error && <p className="board-dice-error">⚠ {error}</p>}

      {!loading && !error && (!round || !pairing) && (
        <p className="board-dice-error">Dieses Brett wurde nicht gefunden. Bitte am Laptop prüfen, ob Runde und Brett existieren.</p>
      )}

      {pairing && round && (
        <>
          <p className="mobile-dice-pairing">
            <strong>{playerName(pairing.whitePlayerId)}</strong> – {pairing.isBye ? 'spielfrei' : <strong>{playerName(pairing.blackPlayerId)}</strong>}
          </p>
          {pairing.isBye ? (
            <p className="board-dice-error">Spielfreies Brett – keine Startstellung nötig.</p>
          ) : round.isLocked || round.isVerified ? (
            <p className="board-dice-error">Runde ist gesperrt/geprüft. Startstellung kann nicht mehr geändert werden.</p>
          ) : (
            <BoardDiceRoller
              tournamentId={params.tournamentId}
              roundNumber={params.roundNumber}
              boardNumber={params.boardNumber}
              currentPosition={pairing.chess960StartPosition ?? null}
              disabled={false}
              onSaved={() => void load()}
            />
          )}
        </>
      )}
      <p className="mobile-dice-foot muted">Funktioniert nur im gleichen WLAN/Hotspot wie der Laptop.</p>
    </div>
  );
}



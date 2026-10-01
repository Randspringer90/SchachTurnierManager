// Step-by-step dice roller for exactly one board. Used both inside the desktop
// modal and on the mobile QR page. The animation is visualisation only; the
// stored position number is derived by the backend domain service.
// Extracted from main.tsx (STM-FE-014).
import React from 'react';
import { requestJson } from '../../api/client';
import { ChessDie } from './ChessDie';
import { chess960BackRankFromNumber, chess960PieceFace, diceFaceGlyphs, diceFaceNames } from '../../lib/chess960';
import type { Chess960StartPosition, Tournament, TournamentRound } from '../../api/contracts';
// Schritt-für-Schritt-Würfel für genau ein Brett. Wird im Modal (Reiter „Browser würfeln")
// und auf der mobilen QR-Seite verwendet. Die Animation ist Visualisierung; gespeichert wird
// die exakt vorgewürfelte Positionsnummer, die das Backend über den Domain-Service ableitet.
export function BoardDiceRoller({
  tournamentId,
  roundNumber,
  boardNumber,
  currentPosition,
  disabled,
  onSaved
}: {
  tournamentId: string;
  roundNumber: number;
  boardNumber: number;
  currentPosition: Chess960StartPosition | null;
  disabled: boolean;
  onSaved: (round: TournamentRound) => void;
}): React.ReactElement {
  const [phase, setPhase] = React.useState<'idle' | 'rolling' | 'revealed'>('idle');
  const [previewNumber, setPreviewNumber] = React.useState<number | null>(null);
  const [previewBackRank, setPreviewBackRank] = React.useState<string>('');
  const [revealStep, setRevealStep] = React.useState(0);
  const [rolling, setRolling] = React.useState(false);
  const [quick, setQuick] = React.useState(false);
  const [face, setFace] = React.useState(0);
  const [spin, setSpin] = React.useState(0);
  const [saving, setSaving] = React.useState(false);
  const [localError, setLocalError] = React.useState<string | null>(null);
  const [localStatus, setLocalStatus] = React.useState<string | null>(null);
  const timers = React.useRef<number[]>([]);

  React.useEffect(() => () => {
    timers.current.forEach(id => window.clearTimeout(id));
  }, []);

  const schedule = (callback: () => void, delay: number): void => {
    const id = window.setTimeout(callback, delay);
    timers.current.push(id);
  };

  function revealNext(rank: string, step: number): void {
    if (step >= 8) {
      setRolling(false);
      setPhase('revealed');
      return;
    }
    setFace(chess960PieceFace(rank[step]));
    setQuick(true);
    setRolling(true);
    setSpin(previous => previous + 1);
    schedule(() => {
      setRolling(false);
      setRevealStep(step + 1);
      schedule(() => revealNext(rank, step + 1), 170);
    }, 300);
  }

  function startRoll(): void {
    if (rolling || saving || disabled) {
      return;
    }
    setLocalError(null);
    setLocalStatus(null);
    const number = Math.floor(Math.random() * 960);
    const rank = chess960BackRankFromNumber(number);
    setPreviewNumber(number);
    setPreviewBackRank(rank);
    setRevealStep(0);
    setPhase('rolling');
    setQuick(false);
    setRolling(true);
    setSpin(previous => previous + 1);
    schedule(() => {
      setRolling(false);
      revealNext(rank, 0);
    }, 1100);
  }

  async function save(): Promise<void> {
    if (previewNumber === null || saving) {
      return;
    }
    if (currentPosition) {
      const confirmed = window.confirm(`Brett ${boardNumber}: vorhandene Startstellung (SP ${currentPosition.positionNumber}) überschreiben?`);
      if (!confirmed) {
        return;
      }
    }
    setSaving(true);
    setLocalError(null);
    try {
      const updated = await requestJson<TournamentRound>(
        `/api/tournaments/${tournamentId}/rounds/${roundNumber}/chess960/start-positions/${boardNumber}`,
        {
          method: 'POST',
          body: JSON.stringify({ overwriteExisting: Boolean(currentPosition), positionNumber: previewNumber })
        }
      );
      setLocalStatus(`Gespeichert: SP ${previewNumber} für Brett ${boardNumber}.`);
      setPhase('idle');
      setPreviewNumber(null);
      setPreviewBackRank('');
      setRevealStep(0);
      onSaved(updated);
    } catch (ex) {
      setLocalError(ex instanceof Error ? ex.message : String(ex));
    } finally {
      setSaving(false);
    }
  }

  const revealedRank = previewBackRank
    .split('')
    .map((piece, index) => (index < revealStep ? piece : ''));

  return (
    <div className="board-dice-roller">
      <ChessDie rolling={rolling} spin={spin} face={face} quick={quick} compact />
      <div className="board-dice-squares" aria-label="Chess960-Grundreihe Feld für Feld">
        {revealedRank.map((piece, index) => (
          <div
            key={index}
            className={`board-dice-square${index < revealStep ? ' filled' : ''}${index === revealStep && phase === 'rolling' ? ' active' : ''}`}
          >
            {piece ? diceFaceGlyphs[chess960PieceFace(piece)] : index + 1}
          </div>
        ))}
      </div>
      <p className="dice-result-line">
        {phase === 'rolling'
          ? 'Der Würfel arbeitet sich Feld für Feld nach rechts …'
          : phase === 'revealed' && previewNumber !== null
            ? `Ergebnis: ${previewBackRank} · SP ${previewNumber}`
            : currentPosition
              ? `Aktuell gespeichert: ${currentPosition.whiteBackRank} · SP ${currentPosition.positionNumber}`
              : 'Bereit zum Würfeln für dieses Brett.'}
      </p>
      {phase === 'revealed' && previewNumber !== null && (
        <p className="board-dice-black muted">Schwarz spiegelbildlich: {previewBackRank.toLowerCase()}</p>
      )}
      <div className="dice-modal-actions">
        {phase !== 'revealed' && (
          <button type="button" onClick={startRoll} disabled={rolling || saving || disabled}>
            {rolling ? 'Würfelt …' : currentPosition ? '🎲 Neu würfeln' : '🎲 Würfeln'}
          </button>
        )}
        {phase === 'revealed' && (
          <>
            <button type="button" onClick={() => void save()} disabled={saving || disabled}>
              {saving ? 'Speichert …' : '💾 Für Brett speichern'}
            </button>
            <button type="button" className="secondary" onClick={startRoll} disabled={saving}>🎲 Nochmal würfeln</button>
            <button type="button" className="secondary" onClick={() => { setPhase('idle'); setPreviewNumber(null); setRevealStep(0); }} disabled={saving}>Abbrechen</button>
          </>
        )}
      </div>
      {localStatus && <p className="board-dice-ok">{localStatus}</p>}
      {localError && <p className="board-dice-error">⚠ {localError}</p>}
    </div>
  );
}



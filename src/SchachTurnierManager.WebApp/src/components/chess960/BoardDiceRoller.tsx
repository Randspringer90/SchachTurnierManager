// Step-by-step dice roller for exactly one board. Used both inside the desktop
// modal and on the mobile QR page. The animation is visualisation only; the
// stored position number is derived by the backend domain service.
// Extracted from main.tsx (STM-FE-014).
import React from 'react';
import { describeApiError, requestJson } from '../../api/client';
import { ConfirmDialog } from '../dialogs/ConfirmDialog';
import { ChessDie } from './ChessDie';
import { chess960BackRankFromNumber, chess960PieceFace, diceFaceGlyphs } from '../../lib/chess960';
import { useI18n } from '../../i18n';
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
  const { t } = useI18n();
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
  const [overwriteConfirmOpen, setOverwriteConfirmOpen] = React.useState(false);
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

  function requestSave(): void {
    if (previewNumber === null || saving) {
      return;
    }
    // Kein window.confirm: Firefox unterdrueckt wiederholte native Dialoge aus
    // demselben Skriptdurchlauf, dann wuerde "Speichern" still nichts tun.
    if (currentPosition) {
      setOverwriteConfirmOpen(true);
      return;
    }
    void save();
  }

  async function save(): Promise<void> {
    if (previewNumber === null || saving) {
      return;
    }
    setOverwriteConfirmOpen(false);
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
      setLocalStatus(t('dice.saved', { position: previewNumber, board: boardNumber }));
      setPhase('idle');
      setPreviewNumber(null);
      setPreviewBackRank('');
      setRevealStep(0);
      onSaved(updated);
    } catch (ex) {
      setLocalError(describeApiError(ex));
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
      <div className="board-dice-squares" aria-label={t('dice.rankLabel')}>
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
          ? t('dice.revealing')
          : phase === 'revealed' && previewNumber !== null
            ? t('dice.result', { rank: previewBackRank, position: previewNumber })
            : currentPosition
              ? t('dice.current', { rank: currentPosition.whiteBackRank, position: currentPosition.positionNumber })
              : t('dice.ready')}
      </p>
      {phase === 'revealed' && previewNumber !== null && (
        <p className="board-dice-black muted">{t('dice.blackRank', { rank: previewBackRank.toLowerCase() })}</p>
      )}
      <div className="dice-modal-actions">
        {phase !== 'revealed' && (
          <button type="button" onClick={startRoll} disabled={rolling || saving || disabled}>
            {rolling ? t('dice.rolling') : currentPosition ? t('dice.rollAgain') : t('dice.roll')}
          </button>
        )}
        {phase === 'revealed' && (
          <>
            <button type="button" onClick={requestSave} disabled={saving || disabled}>
              {saving ? t('dice.saving') : t('dice.saveBoard')}
            </button>
            <button type="button" className="secondary" onClick={startRoll} disabled={saving}>{t('dice.rollAgain')}</button>
            <button type="button" className="secondary" onClick={() => { setPhase('idle'); setPreviewNumber(null); setRevealStep(0); }} disabled={saving}>{t('dice.cancel')}</button>
          </>
        )}
      </div>
      {localStatus && <p className="board-dice-ok">{localStatus}</p>}
      {localError && <p className="board-dice-error">⚠ {localError}</p>}
      <ConfirmDialog
        open={overwriteConfirmOpen && currentPosition !== null}
        title={t('dice.overwriteTitle', { board: boardNumber })}
        description={t('dice.overwriteDescription', { position: currentPosition?.positionNumber ?? '—' })}
        consequences={[
          t('dice.previous', { rank: currentPosition?.whiteBackRank ?? '—', position: currentPosition?.positionNumber ?? '—' }),
          t('dice.next', { rank: previewBackRank || '—', position: previewNumber ?? '—' })
        ]}
        confirmLabel={t('dice.overwrite')}
        cancelLabel={t('dice.cancel')}
        destructive
        busy={saving}
        busyLabel={t('dice.saving')}
        onConfirm={() => void save()}
        onCancel={() => setOverwriteConfirmOpen(false)}
      />
    </div>
  );
}

import React from 'react';
import { requestJson, isApiTransportError } from '../api/client';
import type { Tournament } from '../api/contracts';
import { createResultQueue, type QueuedResultEntry, type ResultQueueStore } from '../lib/offlineResultQueue';
import { resultOptions } from '../lib/tournamentOptions';
import { ConfirmDialog } from './dialogs/ConfirmDialog';

export function OfflineResultQueuePanel({ store, tournaments, lang, onRefresh }: {
  store: ResultQueueStore; tournaments: Tournament[]; lang: string; onRefresh: () => Promise<unknown>;
}) {
  const [entries, setEntries] = React.useState<QueuedResultEntry[]>([]);
  const [error, setError] = React.useState(false);
  const [busy, setBusy] = React.useState(false);
  const running = React.useRef(false);
  const [discard, setDiscard] = React.useState<QueuedResultEntry | null>(null);
  const english = lang === 'en';
  const reload = React.useCallback(async () => {
    try { setEntries(await store.list()); setError(false); } catch { setError(true); }
  }, [store]);
  React.useEffect(() => {
    let disposed = false;
    const update = () => { if (!disposed) void reload(); };
    update();
    window.addEventListener('stm-result-queue-changed', update);
    const timer = setInterval(update, 3000);
    return () => { disposed = true; clearInterval(timer); window.removeEventListener('stm-result-queue-changed', update); };
  }, [reload]);
  const queue = React.useMemo(() => createResultQueue(store,
    item => requestJson(`/api/tournaments/${item.tournamentId}/queued-results`, { method: 'POST', body: JSON.stringify(item.mutation) }),
    isApiTransportError, () => { window.dispatchEvent(new Event('stm-result-queue-changed')); }), [store]);
  async function synchronize() {
    if (running.current) return;
    running.current = true; setBusy(true);
    try { await queue.replay(); await onRefresh(); await reload(); }
    catch { setError(true); }
    finally { running.current = false; setBusy(false); }
  }
  async function discardEntry() {
    if (!discard || running.current) return;
    running.current = true; setBusy(true);
    try { await store.remove(discard.id); setDiscard(null); await reload(); window.dispatchEvent(new Event('stm-result-queue-changed')); }
    catch { setError(true); }
    finally { running.current = false; setBusy(false); }
  }
  if (!entries.length && !error) return null;
  const label = (kind: number) => { const option = resultOptions.find(item => item.value === kind); return option ? (english ? option.labelEn : option.label) : '?'; };
  return <section className="card offline-result-queue" aria-label={english ? 'Locally queued results' : 'Lokal vorgemerkte Ergebnisse'}>
    <h3>{english ? 'Locally queued results' : 'Lokal vorgemerkte Ergebnisse'}</h3>
    <p>{english ? 'These results are stored in this browser and have not yet been acknowledged. Keep this browser data. Tournament backups do not include this queue.'
      : 'Diese Ergebnisse liegen in diesem Browser und sind noch nicht bestätigt. Browserdaten aufbewahren. Turnierbackups enthalten diese Warteschlange nicht.'}</p>
    {error && <p role="alert">{english ? 'The local queue could not be read or synchronized. Keep the browser data and check the server connection.'
      : 'Die lokale Warteschlange konnte nicht gelesen oder synchronisiert werden. Browserdaten aufbewahren und Serververbindung prüfen.'}</p>}
    <button type="button" disabled={busy || !entries.some(item => item.state === 'pending')} onClick={() => void synchronize()}>
      {english ? 'Synchronize results' : 'Ergebnisse synchronisieren'}</button>
    <button type="button" className="secondary" disabled={busy} onClick={() => void onRefresh().catch(() => setError(true))}>
      {english ? 'Load current server state' : 'Aktuellen Serverstand laden'}</button>
    <ul>{entries.map(item => {
      const tournament = tournaments.find(t => t.id === item.tournamentId);
      const current = tournament?.rounds.find(r => r.roundNumber === item.mutation.roundNumber)?.pairings.find(p => p.boardNumber === item.mutation.boardNumber);
      return <li key={item.id}>
        {tournament?.name ?? item.tournamentId} · {english ? 'Round' : 'Runde'} {item.mutation.roundNumber}, {english ? 'board' : 'Brett'} {item.mutation.boardNumber}:
        {' '}{label(item.mutation.result)} · {item.state === 'conflict' ? (english ? 'Conflict: review and enter again' : 'Konflikt: prüfen und neu erfassen') : (english ? 'Pending' : 'Ausstehend')}
        {current && <span> · {english ? 'Server result' : 'Serverergebnis'}: {label(current.result.kind)}</span>}
        <button type="button" className="secondary" disabled={busy} onClick={() => setDiscard(item)}>{english ? 'Discard local entry' : 'Lokalen Eintrag verwerfen'}</button>
      </li>;
    })}</ul>
    {discard && <ConfirmDialog open destructive busy={busy}
      title={english ? 'Discard the local entry?' : 'Lokalen Eintrag verwerfen?'}
      description={english ? 'The local copy will be removed. This does not undo any request already sent to the server. Check the current server result first.'
        : 'Die lokale Kopie wird entfernt. Bereits gesendete Anfragen werden dadurch nicht zurückgerufen. Zuerst das aktuelle Serverergebnis prüfen.'}
      confirmLabel={english ? 'Discard entry' : 'Eintrag verwerfen'} cancelLabel={english ? 'Cancel' : 'Abbrechen'}
      onConfirm={() => void discardEntry()} onCancel={() => { if (!running.current) setDiscard(null); }} />}
  </section>;
}

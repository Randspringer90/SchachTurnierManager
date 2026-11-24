import React from 'react';
import type { ExternalPlayerLookupResult, ExternalPlayerProfile, Player, Tournament } from '../api/contracts';
import { describeApiError, requestJson } from '../api/client';
import { ConfirmDialog } from './dialogs/ConfirmDialog';

type CatalogInfo = { available: boolean; importedAt: string | null; bytes: number; stale: boolean };
type Field = 'name' | 'fideId' | 'elo' | 'federation' | 'title';
const fields: Field[] = ['name', 'fideId', 'elo', 'federation', 'title'];
const label = (field: Field, english: boolean) => ({ name: english ? 'Name' : 'Name', fideId: 'FIDE-ID', elo: english ? 'Standard rating' : 'Standard-Elo', federation: english ? 'Federation' : 'Föderation', title: english ? 'Title' : 'Titel' })[field];
const localValue = (player: Player | null, field: Field) => !player ? null : field === 'elo' ? player.rating.elo : player[field];

export function FideLookupPanel({ tournament, lang, onApplied }: { tournament?: Tournament; lang: string; onApplied: () => Promise<unknown> }) {
  const english = lang === 'en';
  const [file, setFile] = React.useState<File | null>(null);
  const [info, setInfo] = React.useState<CatalogInfo | null>(null);
  const [query, setQuery] = React.useState('');
  const [federation, setFederation] = React.useState('');
  const [result, setResult] = React.useState<ExternalPlayerLookupResult | null>(null);
  const [review, setReview] = React.useState<{ profile: ExternalPlayerProfile; target: Player | null } | null>(null);
  const [selected, setSelected] = React.useState<Field[]>([]);
  const [confirm, setConfirm] = React.useState(false);
  const [busy, setBusy] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [status, setStatus] = React.useState('');
  const generation = React.useRef(0);
  const running = React.useRef(false);
  const current = React.useRef(tournament); current.current = tournament;
  const controller = React.useRef<AbortController | null>(null);
  const invalidate = () => { generation.current++; controller.current?.abort(); controller.current = null; running.current = false; setBusy(false); setReview(null); setSelected([]); setConfirm(false); setResult(null); setError(null); };
  React.useEffect(() => {
    invalidate();
    const read = new AbortController();
    void requestJson<CatalogInfo>('/api/external-players/fide/catalog', { signal: read.signal }).then(setInfo).catch(() => {});
    return () => { generation.current++; controller.current?.abort(); read.abort(); };
  }, [tournament?.id]);

  async function execute(action: (signal: AbortSignal, isCurrent: () => boolean) => Promise<void>) {
    if (running.current) return;
    running.current = true; setBusy(true); setError(null);
    const token = ++generation.current, owner = tournament?.id;
    const request = new AbortController(); controller.current = request;
    const isCurrent = () => generation.current === token && current.current?.id === owner;
    try { await action(request.signal, isCurrent); }
    catch (failure) { if (isCurrent()) setError(describeApiError(failure, lang)); }
    finally { if (isCurrent()) { running.current = false; setBusy(false); controller.current = null; } }
  }
  async function importList() {
    if (!file || file.size <= 0 || file.size > 256 * 1024 * 1024) { setError(english ? 'Choose an unpacked standard TXT list up to 256 MiB.' : 'Eine entpackte Standard-TXT-Liste bis 256 MiB auswählen.'); return; }
    setResult(null); setReview(null);
    try { await execute(async (signal, isCurrent) => {
      const imported = await requestJson<{ players: number }>('/api/external-players/fide/catalog', { method: 'POST', body: file, headers: { 'Content-Type': 'text/plain;charset=utf-8' }, signal, timeoutMs: 120000 });
      const updated = await requestJson<CatalogInfo>('/api/external-players/fide/catalog', { signal });
      if (isCurrent()) { setInfo(updated); setStatus(english ? `${imported.players} entries cached locally. No tournament data changed.` : `${imported.players} Einträge lokal gespeichert. Keine Turnierdaten geändert.`); }
    }); } catch (failure) { if (current.current?.id === tournament?.id) setError(describeApiError(failure, lang)); }
  }
  async function search(event: React.FormEvent) {
    event.preventDefault(); setReview(null); setConfirm(false); setSelected([]); setResult(null);
    try { await execute(async (signal, isCurrent) => {
      const found = await requestJson<ExternalPlayerLookupResult>(`/api/external-players/fide/local-search?query=${encodeURIComponent(query)}&federation=${encodeURIComponent(federation)}`, { signal });
      if (isCurrent()) setResult(found);
    }); } catch (failure) { if (current.current?.id === tournament?.id) setError(describeApiError(failure, lang)); }
  }
  function choose(profile: ExternalPlayerProfile) {
    if (busy) return;
    const matches = tournament?.players.filter(player => player.fideId === profile.fideId) ?? [];
    setReview({ profile, target: matches.length === 1 ? matches[0] : null }); setSelected([]); setConfirm(false); setError(null);
  }
  async function apply() {
    const captured = review, owner = tournament?.id;
    if (!captured || !owner || !selected.length || (!captured.target && !selected.includes('name'))) return;
    try { await execute(async (signal, isCurrent) => {
      await requestJson(`/api/tournaments/${owner}/external-players/apply`, { method: 'POST', signal, body: JSON.stringify({
        profile: captured.profile, targetPlayerId: captured.target?.id ?? null, createIfNoTarget: !captured.target,
        overwriteExistingValues: true, selectedFields: selected, expectedPlayer: captured.target
      }) });
      if (!isCurrent()) return;
      setConfirm(false); setReview(null); setSelected([]);
      setStatus(english ? 'Confirmed fields saved and recorded in the local audit.' : 'Bestätigte Felder gespeichert und im lokalen Audit protokolliert.');
      try { await onApplied(); }
      catch { if (isCurrent()) setError(english ? 'Fields were saved. Reload the tournament to refresh its views.' : 'Felder wurden gespeichert. Turnier neu laden, um die Ansichten zu aktualisieren.'); }
    }); } catch (failure) { if (current.current?.id === tournament?.id) setError(describeApiError(failure, lang)); }
  }
  return <article className="card fide-lookup-panel">
    <h3>{english ? 'FIDE name search · local list' : 'FIDE-Namenssuche · lokale Liste'}</h3>
    <p>{english ? 'Select an official unpacked standard TXT list. Names, files and tournament data stay on this computer. No background download or online name query.' : 'Eine offizielle entpackte Standard-TXT-Liste auswählen. Namen, Dateien und Turnierdaten bleiben auf diesem Computer. Kein Hintergrunddownload und keine Online-Namensabfrage.'}</p>
    <p><a href="https://ratings.fide.com/download_lists.phtml" target="_blank" rel="noopener noreferrer">{english ? 'Official FIDE downloads' : 'Offizielle FIDE-Downloads'}</a></p>
    <label>{english ? 'Unpacked standard TXT list (up to 256 MiB)' : 'Entpackte Standard-TXT-Liste (bis 256 MiB)'}<input className="fide-catalog-file" type="file" accept=".txt,text/plain" disabled={busy} onChange={event => { invalidate(); setFile(event.target.files?.[0] ?? null); }} /></label>
    <button type="button" className="fide-catalog-import secondary" onClick={() => void importList()} disabled={!file || busy}>{english ? 'Cache list locally' : 'Liste lokal speichern'}</button>
    <p className="fide-catalog-status">{info?.available
      ? `${english ? 'List imported' : 'Liste importiert'}: ${info.importedAt ? new Date(info.importedAt).toLocaleString() : '—'}. ${info.stale ? (english ? 'Older than 24 hours; verify the list date before applying values.' : 'Älter als 24 Stunden; Listenstand vor Übernahme prüfen.') : ''}`
      : (english ? 'Offline: import a list before searching.' : 'Offline: vor der Suche eine Liste laden.')}</p>
    <form className="fide-name-search" onSubmit={event => void search(event)}>
      <label>{english ? 'Name or FIDE ID' : 'Name oder FIDE-ID'}<input className="fide-name-query" value={query} maxLength={100} disabled={busy} onChange={event => { invalidate(); setQuery(event.target.value); }} /></label>
      <label>{english ? 'Federation (optional)' : 'Föderation (optional)'}<input className="fide-federation-query" value={federation} maxLength={3} disabled={busy} onChange={event => { invalidate(); setFederation(event.target.value); }} /></label>
      <button type="submit" disabled={busy || query.trim().length < 2}>{busy ? (english ? 'Working…' : 'Wird bearbeitet…') : (english ? 'Search locally' : 'Lokal suchen')}</button>
    </form>
    {status && <p role="status" className="fide-action-status">{status}</p>}
    {error && <p role="alert" className="fide-error">{error}</p>}
    {result && <div className="fide-results"><p>{result.status === 3
      ? (english ? 'Offline: the local list is unavailable. Load a valid standard TXT list.' : 'Offline: Die lokale Liste ist nicht verfügbar. Eine gültige Standard-TXT-Liste laden.')
      : result.status === 4 ? (english ? 'Enter a name or ID with 2–100 characters and an optional three-letter federation.' : 'Name oder ID mit 2–100 Zeichen und optional eine Föderation mit drei Buchstaben eingeben.')
      : `${result.players.length} ${english ? 'local matches (maximum 50). Check the list date before applying values.' : 'lokale Treffer (höchstens 50). Listenstand vor der Übernahme prüfen.'}`}</p>{result.players.map(profile => <div key={profile.externalId} className="fide-result">
      <strong>{profile.name}</strong><span> · {profile.fideId} · {profile.elo ?? '—'} · {profile.federation} · {profile.title ?? '—'}</span>
      <button type="button" onClick={() => choose(profile)} disabled={busy || !tournament}>{english ? 'Review fields' : 'Felder prüfen'}</button>
    </div>)}</div>}
    {review && <section className="fide-field-review">
      <h4>{review.profile.name}</h4>
      <p>{english ? 'Choose each field explicitly. Unchecked fields keep their local values. An outdated target requires a new review.' : 'Jedes Feld ausdrücklich auswählen. Nicht gewählte Felder behalten ihren lokalen Wert. Bei geändertem Zielspieler ist eine neue Vorschau nötig.'}</p>
      <label>{english ? 'Target participant' : 'Zielteilnehmer'}<select className="fide-target" disabled={busy} value={review.target?.id ?? ''} onChange={event => { setReview({ ...review, target: tournament?.players.find(player => player.id === event.target.value) ?? null }); setSelected([]); setConfirm(false); setError(null); }}>
        <option value="">{english ? 'New participant' : 'Neuer Teilnehmer'}</option>{tournament?.players.map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
      </select></label>
      <table><thead><tr><th>{english ? 'Apply' : 'Übernehmen'}</th><th>{english ? 'Field' : 'Feld'}</th><th>{english ? 'Local value' : 'Lokaler Wert'}</th><th>{english ? 'FIDE value' : 'FIDE-Wert'}</th></tr></thead><tbody>{fields.map(field => <tr key={field}>
        <td><input type="checkbox" aria-label={label(field, english)} data-fide-field={field} checked={selected.includes(field)} disabled={busy || review.profile[field] == null || review.profile[field] === ''} onChange={event => setSelected(event.target.checked ? [...selected, field] : selected.filter(value => value !== field))} /></td>
        <th>{label(field, english)}</th><td>{localValue(review.target, field) ?? '—'}</td><td>{review.profile[field] ?? '—'}</td>
      </tr>)}</tbody></table>
      <p>{english ? 'Source/list import' : 'Quelle/Listenimport'}: FIDE · {new Date(review.profile.retrievedAt).toLocaleString()}</p>
      <button type="button" className="fide-apply-selected" disabled={busy || !selected.length || (!review.target && !selected.includes('name'))} onClick={() => setConfirm(true)}>{english ? 'Apply selected fields…' : 'Ausgewählte Felder übernehmen…'}</button>
      <button type="button" className="secondary" disabled={busy} onClick={() => { setReview(null); setConfirm(false); setSelected([]); }}>{english ? 'Close review' : 'Vorschau schließen'}</button>
    </section>}
    {confirm && review && <ConfirmDialog open title={english ? 'Apply these FIDE fields?' : 'Diese FIDE-Felder übernehmen?'}
      description={(review.target ? (english ? 'Update ' : 'Aktualisieren: ') + review.target.name : (english ? 'Create ' : 'Neu anlegen: ') + review.profile.name)}
      consequences={selected.map(field => `${label(field, english)}: ${localValue(review.target, field) ?? '—'} → ${review.profile[field] ?? '—'}`)}
      confirmLabel={english ? 'Confirm selected fields' : 'Ausgewählte Felder bestätigen'} cancelLabel={english ? 'Cancel' : 'Abbrechen'}
      destructive={!!review.target} busy={busy} errorMessage={error} onCancel={() => { if (!busy) setConfirm(false); }} onConfirm={() => void apply()} />}
  </article>;
}

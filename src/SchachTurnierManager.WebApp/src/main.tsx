import React from 'react';
import ReactDOM from 'react-dom/client';
import './styles.css';

type Health = {
  status: string;
  app: string;
  version: string;
  time: string;
  database?: string;
};

type RatingProfile = {
  manualTwz?: number | null;
  elo?: number | null;
  rapidElo?: number | null;
  blitzElo?: number | null;
  dwz?: number | null;
  dwzIndex?: number | null;
};

type Player = {
  id: string;
  name: string;
  club?: string | null;
  federation?: string | null;
  country?: string | null;
  birthYear?: number | null;
  gender: number;
  fideId?: string | null;
  nationalId?: string | null;
  title?: string | null;
  startingRank: number;
  rating: RatingProfile;
  status: number;
  notes?: string | null;
};

type GameResult = {
  kind: number;
  isPlayed: boolean;
  isBye: boolean;
};

type Pairing = {
  boardNumber: number;
  whitePlayerId?: string | null;
  blackPlayerId?: string | null;
  result: GameResult;
  notes?: string | null;
  isBye: boolean;
  isManualOverride: boolean;
  lastChangedAt?: string | null;
};

type PairingAudit = {
  algorithm: string;
  rulesetVersion: string;
  createdAt: string;
  messages: string[];
  scoreGroups: string[];
  floaters: string[];
  colorNotes: string[];
};

type TournamentRound = {
  roundNumber: number;
  pairings: Pairing[];
  audit: PairingAudit;
  isLocked: boolean;
  isVerified: boolean;
  resultStatus: number;
  lockedAt?: string | null;
  verifiedAt?: string | null;
  notes?: string | null;
};

type StandingRow = {
  rank: number;
  playerId: string;
  name: string;
  startingRank: number;
  twz: number;
  points: number;
  wins: number;
  buchholz: number;
  buchholzCutOne: number;
  sonnebornBerger: number;
  averageOpponentRating: number;
  tournamentPerformance?: number | null;
  heroScore: number;
  categories: Record<string, boolean>;
};

type Tournament = {
  id: string;
  name: string;
  createdOn: string;
  settings: {
    format: number;
    scoringSystem: number;
    twzSource: number;
    plannedRounds: number;
    seniorBirthYearOrEarlier?: number | null;
    heroCupMinimumRatedGames: number;
    forfeitTiebreakPolicy: number;
    countByeAsWin: boolean;
  };
  players: Player[];
  rounds: TournamentRound[];
};

type CategoryStandingTable = {
  category: string;
  rows: StandingRow[];
};

type CrossTable = {
  players: CrossTablePlayer[];
  rows: CrossTableRow[];
};

type CrossTablePlayer = {
  playerId: string;
  name: string;
  rank: number;
  startingRank: number;
  points: number;
};

type CrossTableRow = {
  playerId: string;
  name: string;
  rank: number;
  points: number;
  cells: CrossTableCell[];
};

type CrossTableCell = {
  playerId: string;
  opponentId: string;
  isSelf: boolean;
  roundNumber?: number | null;
  boardNumber?: number | null;
  color: number;
  resultLabel: string;
  points?: number | null;
  isBye: boolean;
  notes?: string | null;
};

type HeroCupRow = {
  rank: number;
  playerId: string;
  name: string;
  twz: number;
  ratedGames: number;
  actualScore: number;
  expectedScore: number;
  overPerformance: number;
  averageOpponentRating: number;
  tournamentPerformance?: number | null;
  reason: string;
};

type BoardDiagnostic = {
  boardNumber: number;
  white: string;
  black: string;
  result: number;
  resultLabel: string;
  isOpen: boolean;
  isForfeit: boolean;
  countsForBuchholz: boolean;
  countsForDirectAndSonneborn: boolean;
  countsForPerformance: boolean;
  note: string;
};

type RoundDiagnostics = {
  roundNumber: number;
  resultStatus: number;
  isComplete: boolean;
  isLocked: boolean;
  isVerified: boolean;
  openBoards: number;
  forfeitBoards: number;
  byeBoards: number;
  warnings: string[];
  boards: BoardDiagnostic[];
};

type PairingEdit = { whitePlayerId: string; blackPlayerId: string; notes: string; };

type PlayerForm = {
  name: string;
  club: string;
  birthYear: string;
  gender: number;
  dwz: string;
  elo: string;
  manualTwz: string;
  fideId: string;
  nationalId: string;
  title: string;
  status: number;
  notes: string;
};

const resultOptions = [
  { value: 0, label: 'offen' },
  { value: 1, label: '1-0' },
  { value: 2, label: '½-½' },
  { value: 3, label: '0-1' },
  { value: 4, label: '+/- kampflos Weiß' },
  { value: 5, label: '-/+ kampflos Schwarz' },
  { value: 6, label: '-/- kampflos beide' },
  { value: 7, label: 'Bye' },
  { value: 8, label: 'Armageddon Weiß' },
  { value: 9, label: 'Armageddon Schwarz' }
];

const formatOptions = [
  { value: 1, label: 'Schweizer System' },
  { value: 0, label: 'Jeder gegen Jeden' }
];

const genderOptions = [
  { value: 0, label: 'unbekannt' },
  { value: 1, label: 'offen' },
  { value: 2, label: 'weiblich' },
  { value: 3, label: 'männlich' },
  { value: 4, label: 'divers' }
];

const playerStatusOptions = [
  { value: 0, label: 'aktiv' },
  { value: 1, label: 'pausiert' },
  { value: 2, label: 'zurückgezogen' }
];

const emptyPlayerForm: PlayerForm = {
  name: '',
  club: '',
  birthYear: '',
  gender: 0,
  dwz: '',
  elo: '',
  manualTwz: '',
  fideId: '',
  nationalId: '',
  title: '',
  status: 0,
  notes: ''
};

async function requestJson<T>(url: string, init?: RequestInit): Promise<T> {
  const response = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(init?.headers ?? {}) },
    ...init
  });
  if (!response.ok) {
    let message = `HTTP ${response.status}`;
    try {
      const body = await response.json() as { error?: string };
      message = body.error ?? message;
    } catch {
      // ignore non-json error body
    }
    throw new Error(message);
  }
  return await response.json() as T;
}

async function requestText(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return await response.text();
}

function resultLabel(kind: number): string {
  return resultOptions.find(option => option.value === kind)?.label ?? String(kind);
}

function genderLabel(kind: number): string {
  return genderOptions.find(option => option.value === kind)?.label ?? String(kind);
}

function statusLabel(kind: number): string {
  return playerStatusOptions.find(option => option.value === kind)?.label ?? String(kind);
}

function roundStatusLabel(kind: number): string {
  switch (kind) {
    case 1: return 'vollständig';
    case 2: return 'geprüft';
    case 3: return 'gesperrt';
    default: return 'offen';
  }
}

function twzOf(player: Player): number {
  return player.rating.manualTwz ?? player.rating.dwz ?? player.rating.elo ?? 0;
}

function numberOrNull(value: string): number | null {
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : Number(trimmed);
}

function playerToForm(player: Player): PlayerForm {
  return {
    name: player.name,
    club: player.club ?? '',
    birthYear: player.birthYear?.toString() ?? '',
    gender: player.gender,
    dwz: player.rating.dwz?.toString() ?? '',
    elo: player.rating.elo?.toString() ?? '',
    manualTwz: player.rating.manualTwz?.toString() ?? '',
    fideId: player.fideId ?? '',
    nationalId: player.nationalId ?? '',
    title: player.title ?? '',
    status: player.status,
    notes: player.notes ?? ''
  };
}

function formToRequest(form: PlayerForm, startingRank?: number): unknown {
  return {
    name: form.name,
    club: form.club || null,
    federation: null,
    country: null,
    birthYear: numberOrNull(form.birthYear),
    gender: form.gender,
    elo: numberOrNull(form.elo),
    rapidElo: null,
    blitzElo: null,
    dwz: numberOrNull(form.dwz),
    dwzIndex: null,
    manualTwz: numberOrNull(form.manualTwz),
    fideId: form.fideId || null,
    nationalId: form.nationalId || null,
    title: form.title || null,
    status: form.status,
    notes: form.notes || null,
    startingRank: startingRank ?? null
  };
}

function downloadText(filename: string, content: string, type: string): void {
  const blob = new Blob([content], { type });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  URL.revokeObjectURL(url);
}

function App() {
  const [health, setHealth] = React.useState<Health | null>(null);
  const [tournaments, setTournaments] = React.useState<Tournament[]>([]);
  const [selectedId, setSelectedId] = React.useState<string>('');
  const [standings, setStandings] = React.useState<StandingRow[]>([]);
  const [categories, setCategories] = React.useState<CategoryStandingTable[]>([]);
  const [crossTable, setCrossTable] = React.useState<CrossTable | null>(null);
  const [heroCup, setHeroCup] = React.useState<HeroCupRow[]>([]);
  const [roundDiagnostics, setRoundDiagnostics] = React.useState<RoundDiagnostics[]>([]);
  const [newTournamentName, setNewTournamentName] = React.useState('Vereinsturnier');
  const [format, setFormat] = React.useState(1);
  const [playerForm, setPlayerForm] = React.useState<PlayerForm>(emptyPlayerForm);
  const [editingPlayerId, setEditingPlayerId] = React.useState<string | null>(null);
  const [csvContent, setCsvContent] = React.useState('Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen\n');
  const [replacePlayers, setReplacePlayers] = React.useState(false);
  const [backupJson, setBackupJson] = React.useState('');
  const [pairingEdits, setPairingEdits] = React.useState<Record<string, PairingEdit>>({});
  const [status, setStatus] = React.useState('Bereit.');
  const [error, setError] = React.useState<string | null>(null);
  const selectedTournament = tournaments.find(tournament => tournament.id === selectedId) ?? tournaments[0];

  const loadTournaments = React.useCallback(async (): Promise<Tournament[]> => {
    const data = await requestJson<Tournament[]>('/api/tournaments');
    setTournaments(data);
    if (!selectedId && data.length > 0) {
      setSelectedId(data[0].id);
    }
    return data;
  }, [selectedId]);

  const loadDerived = React.useCallback(async (id: string) => {
    if (!id) {
      setStandings([]);
      setCategories([]);
      setCrossTable(null);
      setHeroCup([]);
      setRoundDiagnostics([]);
      return;
    }

    const [standingData, categoryData, crossTableData, heroCupData, diagnosticsData] = await Promise.all([
      requestJson<StandingRow[]>(`/api/tournaments/${id}/standings`),
      requestJson<CategoryStandingTable[]>(`/api/tournaments/${id}/categories`),
      requestJson<CrossTable>(`/api/tournaments/${id}/cross-table`),
      requestJson<HeroCupRow[]>(`/api/tournaments/${id}/hero-cup`),
      requestJson<RoundDiagnostics[]>(`/api/tournaments/${id}/round-diagnostics`)
    ]);
    setStandings(standingData);
    setCategories(categoryData);
    setCrossTable(crossTableData);
    setHeroCup(heroCupData);
    setRoundDiagnostics(diagnosticsData);
  }, []);

  const refresh = React.useCallback(async (preferredId?: string) => {
    const data = await loadTournaments();
    const id = preferredId ?? selectedTournament?.id ?? selectedId ?? data[0]?.id ?? '';
    if (id) {
      await loadDerived(id);
    }
  }, [loadDerived, loadTournaments, selectedId, selectedTournament?.id]);

  React.useEffect(() => {
    requestJson<Health>('/api/health')
      .then(setHealth)
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
    loadTournaments().catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, [loadTournaments]);

  React.useEffect(() => {
    if (selectedTournament?.id) {
      loadDerived(selectedTournament.id).catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
    }
  }, [loadDerived, selectedTournament?.id]);

  async function createTournament(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    const created = await requestJson<Tournament>('/api/tournaments', {
      method: 'POST',
      body: JSON.stringify({
        name: newTournamentName,
        settings: {
          format,
          scoringSystem: 0,
          twzSource: 0,
          plannedRounds: 5,
          allowManualPairingOverrides: true,
          forfeitTiebreakPolicy: 0,
          countByeAsWin: false,
          heroCupMinimumRatedGames: 1
        }
      })
    });
    setSelectedId(created.id);
    setStatus(`Turnier angelegt: ${created.name}`);
    await refresh(created.id);
  }

  async function savePlayer(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedTournament) {
      return;
    }

    setError(null);
    const existing = editingPlayerId ? selectedTournament.players.find(player => player.id === editingPlayerId) : undefined;
    const body = JSON.stringify(formToRequest(playerForm, existing?.startingRank));
    if (editingPlayerId) {
      await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players/${editingPlayerId}`, { method: 'PUT', body });
      setStatus('Teilnehmer aktualisiert.');
    } else {
      await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players`, { method: 'POST', body });
      setStatus('Teilnehmer gespeichert.');
    }

    setPlayerForm(emptyPlayerForm);
    setEditingPlayerId(null);
    await refresh(selectedTournament.id);
  }

  async function deleteOrWithdrawPlayer(player: Player) {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players/${player.id}`, { method: 'DELETE' });
    setStatus('Teilnehmer gelöscht oder zurückgezogen.');
    if (editingPlayerId === player.id) {
      setEditingPlayerId(null);
      setPlayerForm(emptyPlayerForm);
    }
    await refresh(selectedTournament.id);
  }

  async function setPlayerStatus(player: Player, newStatus: number) {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players/${player.id}/status`, {
      method: 'PATCH',
      body: JSON.stringify({ status: newStatus })
    });
    setStatus(`Status für ${player.name} geändert.`);
    await refresh(selectedTournament.id);
  }

  async function generateRound() {
    if (!selectedTournament) {
      return;
    }
    setError(null);
    await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/pairings/next-round`, { method: 'POST' });
    setStatus('Neue Runde ausgelost.');
    await refresh(selectedTournament.id);
  }

  async function recordResult(roundNumber: number, boardNumber: number, result: number) {
    if (!selectedTournament) {
      return;
    }
    setError(null);
    await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/results`, {
      method: 'POST',
      body: JSON.stringify({ roundNumber, boardNumber, result })
    });
    setStatus(`Ergebnis Runde ${roundNumber}, Brett ${boardNumber} gespeichert.`);
    await refresh(selectedTournament.id);
  }

  function editKey(roundNumber: number, boardNumber: number): string {
    return `${roundNumber}-${boardNumber}`;
  }

  function pairingEdit(round: TournamentRound, pairing: Pairing): PairingEdit {
    const key = editKey(round.roundNumber, pairing.boardNumber);
    return pairingEdits[key] ?? {
      whitePlayerId: pairing.whitePlayerId ?? '',
      blackPlayerId: pairing.blackPlayerId ?? '',
      notes: pairing.notes ?? ''
    };
  }

  function updatePairingEdit(roundNumber: number, boardNumber: number, patch: Partial<PairingEdit>): void {
    const key = editKey(roundNumber, boardNumber);
    setPairingEdits(previous => ({
      ...previous,
      [key]: { ...(previous[key] ?? { whitePlayerId: '', blackPlayerId: '', notes: '' }), ...patch }
    }));
  }

  async function saveManualPairing(round: TournamentRound, pairing: Pairing) {
    if (!selectedTournament) {
      return;
    }
    const edit = pairingEdit(round, pairing);
    setError(null);
    await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/boards/${pairing.boardNumber}/pairing`, {
      method: 'PUT',
      body: JSON.stringify({
        whitePlayerId: edit.whitePlayerId || null,
        blackPlayerId: edit.blackPlayerId || null,
        notes: edit.notes || null
      })
    });
    setStatus(`Paarung Runde ${round.roundNumber}, Brett ${pairing.boardNumber} manuell gespeichert.`);
    setPairingEdits(previous => {
      const copy = { ...previous };
      delete copy[editKey(round.roundNumber, pairing.boardNumber)];
      return copy;
    });
    await refresh(selectedTournament.id);
  }

  async function setRoundLock(round: TournamentRound, isLocked: boolean) {
    if (!selectedTournament) {
      return;
    }
    setError(null);
    await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/lock`, {
      method: 'PATCH',
      body: JSON.stringify({ isLocked })
    });
    setStatus(isLocked ? `Runde ${round.roundNumber} gesperrt.` : `Runde ${round.roundNumber} entsperrt.`);
    await refresh(selectedTournament.id);
  }

  async function setRoundVerified(round: TournamentRound, isVerified: boolean) {
    if (!selectedTournament) {
      return;
    }
    setError(null);
    await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/verify`, {
      method: 'PATCH',
      body: JSON.stringify({ isVerified })
    });
    setStatus(isVerified ? `Runde ${round.roundNumber} geprüft.` : `Runde ${round.roundNumber} wieder geöffnet.`);
    await refresh(selectedTournament.id);
  }

  async function importPlayers() {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    const imported = await requestJson<Player[]>(`/api/tournaments/${selectedTournament.id}/players/import.csv`, {
      method: 'POST',
      body: JSON.stringify({ content: csvContent, replaceExisting: replacePlayers })
    });
    setStatus(`${imported.length} Teilnehmer importiert.`);
    await refresh(selectedTournament.id);
  }

  async function exportPlayers() {
    if (!selectedTournament) {
      return;
    }

    const csv = await requestText(`/api/tournaments/${selectedTournament.id}/players/export.csv`);
    downloadText(`${selectedTournament.name}-teilnehmer.csv`, csv, 'text/csv;charset=utf-8');
  }

  function openTournamentExport(path: string) {
    if (!selectedTournament) {
      return;
    }

    window.open(`/api/tournaments/${selectedTournament.id}/${path}`, '_blank', 'noopener,noreferrer');
  }

  function openRoundPrint(roundNumber: number) {
    if (!selectedTournament) {
      return;
    }

    window.open(`/api/tournaments/${selectedTournament.id}/rounds/${roundNumber}/print/html`, '_blank', 'noopener,noreferrer');
  }

  async function exportTournamentJson() {
    if (!selectedTournament) {
      return;
    }

    const text = await requestText(`/api/tournaments/${selectedTournament.id}/export/json`);
    setBackupJson(JSON.stringify(JSON.parse(text), null, 2));
    downloadText(`${selectedTournament.name}-backup.json`, JSON.stringify(JSON.parse(text), null, 2), 'application/json;charset=utf-8');
  }

  async function importTournamentJson() {
    const parsed = JSON.parse(backupJson) as Tournament;
    const imported = await requestJson<Tournament>('/api/tournaments/import', {
      method: 'POST',
      body: JSON.stringify({ tournament: parsed, overwriteExisting: true })
    });
    setSelectedId(imported.id);
    setStatus(`Turnier importiert: ${imported.name}`);
    await refresh(imported.id);
  }

  function playerNameById(id?: string | null): string {
    if (!id || !selectedTournament) {
      return '—';
    }
    return selectedTournament.players.find(player => player.id === id)?.name ?? id.slice(0, 8);
  }

  function editPlayer(player: Player): void {
    setEditingPlayerId(player.id);
    setPlayerForm(playerToForm(player));
  }

  function diagnosticsFor(roundNumber: number): RoundDiagnostics | undefined {
    return roundDiagnostics.find(item => item.roundNumber === roundNumber);
  }

  return (
    <main className="shell">
      <header className="hero">
        <div>
          <p className="eyebrow">Lokaler Turnierleiter · v0.7.0</p>
          <h1>SchachTurnierManager</h1>
          <p>Persistenter Turnierleiter mit SQLite, Schweizer-System-Audit, manuellen Paarungskorrekturen, Rundensperren, kampflose Ergebnisse, Kategorien, Kreuztabelle und Im-/Export.</p>
        </div>
        <div className="status-card">
          <strong>Backend</strong>
          {health && <span className="ok">{health.app} {health.version}: {health.status}</span>}
          {!health && !error && <span>Prüfe API…</span>}
          {health?.database && <small>{health.database}</small>}
        </div>
      </header>

      <section className="status-line">
        <span>{status}</span>
        {error && <strong className="error">{error}</strong>}
      </section>

      <section className="layout">
        <aside className="panel">
          <h2>Turniere</h2>
          <form onSubmit={(event) => void createTournament(event)} className="stack">
            <input value={newTournamentName} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setNewTournamentName(event.target.value)} placeholder="Turniername" />
            <select value={format} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setFormat(Number(event.target.value))}>
              {formatOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
            </select>
            <button type="submit">Turnier anlegen</button>
          </form>
          <div className="list">
            {tournaments.map(tournament => (
              <button
                type="button"
                key={tournament.id}
                className={tournament.id === selectedTournament?.id ? 'selected' : ''}
                onClick={() => setSelectedId(tournament.id)}
              >
                {tournament.name}<small>{tournament.players.length} Teilnehmer · {tournament.rounds.length} Runden</small>
              </button>
            ))}
          </div>
        </aside>

        <section className="panel main-panel">
          <div className="panel-header">
            <div>
              <h2>{selectedTournament?.name ?? 'Noch kein Turnier'}</h2>
              <p>{selectedTournament ? `${selectedTournament.players.length} Teilnehmer · ${selectedTournament.rounds.length} Runden` : 'Lege zuerst ein Turnier an.'}</p>
            </div>
            <button type="button" onClick={() => void generateRound()} disabled={!selectedTournament || selectedTournament.players.filter(player => player.status === 0).length < 2}>Nächste Runde auslosen</button>
          </div>

          <div className="grid two">
            <article className="card">
              <h3>{editingPlayerId ? 'Teilnehmer bearbeiten' : 'Teilnehmer erfassen'}</h3>
              <form onSubmit={(event) => void savePlayer(event)} className="player-form wide">
                <input value={playerForm.name} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, name: event.target.value })} placeholder="Name *" />
                <input value={playerForm.club} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, club: event.target.value })} placeholder="Verein" />
                <input value={playerForm.birthYear} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, birthYear: event.target.value })} placeholder="Geburtsjahr" type="number" min="1900" max="2100" />
                <select value={playerForm.gender} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setPlayerForm({ ...playerForm, gender: Number(event.target.value) })}>
                  {genderOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                </select>
                <input value={playerForm.dwz} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, dwz: event.target.value })} placeholder="DWZ" type="number" min="0" />
                <input value={playerForm.elo} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, elo: event.target.value })} placeholder="Elo" type="number" min="0" />
                <input value={playerForm.manualTwz} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, manualTwz: event.target.value })} placeholder="TWZ manuell" type="number" min="0" />
                <input value={playerForm.fideId} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, fideId: event.target.value })} placeholder="FIDE-ID" />
                <input value={playerForm.nationalId} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, nationalId: event.target.value })} placeholder="DSB-ID" />
                <input value={playerForm.title} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, title: event.target.value })} placeholder="Titel" />
                <select value={playerForm.status} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setPlayerForm({ ...playerForm, status: Number(event.target.value) })}>
                  {playerStatusOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                </select>
                <input value={playerForm.notes} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setPlayerForm({ ...playerForm, notes: event.target.value })} placeholder="Notizen" />
                <button type="submit" disabled={!selectedTournament}>{editingPlayerId ? 'Aktualisieren' : 'Speichern'}</button>
                {editingPlayerId && <button type="button" className="secondary" onClick={() => { setEditingPlayerId(null); setPlayerForm(emptyPlayerForm); }}>Abbrechen</button>}
              </form>
            </article>

            <article className="card">
              <h3>Teilnehmerliste</h3>
              <div className="table-scroll">
                <table>
                  <thead><tr><th>#</th><th>Name</th><th>Verein</th><th>TWZ</th><th>Kat.</th><th>Status</th><th>Aktion</th></tr></thead>
                  <tbody>
                    {selectedTournament?.players.map(player => (
                      <tr key={player.id} className={player.status === 2 ? 'muted-row' : ''}>
                        <td>{player.startingRank}</td>
                        <td>{player.name}</td>
                        <td>{player.club ?? '—'}</td>
                        <td>{twzOf(player)}</td>
                        <td>{genderLabel(player.gender)} {player.birthYear ? `· ${player.birthYear}` : ''}</td>
                        <td>{statusLabel(player.status)}</td>
                        <td className="actions">
                          <button type="button" className="small" onClick={() => editPlayer(player)}>Bearbeiten</button>
                          {player.status === 0
                            ? <button type="button" className="small" onClick={() => void setPlayerStatus(player, 2)}>Zurückziehen</button>
                            : <button type="button" className="small" onClick={() => void setPlayerStatus(player, 0)}>Aktivieren</button>}
                          <button type="button" className="small danger" onClick={() => void deleteOrWithdrawPlayer(player)}>Löschen</button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </article>
          </div>

          <div className="grid two">
            <article className="card">
              <h3>Live-Tabelle</h3>
              <div className="table-scroll">
                <table>
                  <thead><tr><th>Rang</th><th>Name</th><th>Punkte</th><th>Siege</th><th>BH</th><th>SB</th><th>TPR</th></tr></thead>
                  <tbody>
                    {standings.map(row => (
                      <tr key={row.playerId}>
                        <td>{row.rank}</td>
                        <td>{row.name}</td>
                        <td>{row.points}</td>
                        <td>{row.wins}</td>
                        <td>{row.buchholz}</td>
                        <td>{row.sonnebornBerger}</td>
                        <td>{row.tournamentPerformance ?? '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </article>

            <article className="card">
              <h3>Heldenpokal</h3>
              <div className="table-scroll">
                <table>
                  <thead><tr><th>Rang</th><th>Name</th><th>Über Erwartung</th><th>Ist</th><th>Erwartet</th><th>Ø Gegner</th></tr></thead>
                  <tbody>
                    {heroCup.map(row => (
                      <tr key={row.playerId}>
                        <td>{row.rank}</td>
                        <td title={row.reason}>{row.name}</td>
                        <td>{row.overPerformance}</td>
                        <td>{row.actualScore}/{row.ratedGames}</td>
                        <td>{row.expectedScore}</td>
                        <td>{row.averageOpponentRating}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </article>
          </div>

          <article className="card">
            <h3>Kategorieauswertungen</h3>
            {categories.length === 0 && <p>Noch keine Kategorie mit passenden Spielern.</p>}
            <div className="category-grid">
              {categories.map(category => (
                <section key={category.category} className="mini-table">
                  <h4>{category.category}</h4>
                  <table>
                    <tbody>
                      {category.rows.map(row => <tr key={row.playerId}><td>{row.rank}</td><td>{row.name}</td><td>{row.points}</td></tr>)}
                    </tbody>
                  </table>
                </section>
              ))}
            </div>
          </article>

          <article className="card">
            <h3>Kreuztabelle</h3>
            <div className="table-scroll">
              <table className="cross-table">
                <thead>
                  <tr><th>Spieler</th>{crossTable?.players.map(player => <th key={player.playerId}>{player.rank}</th>)}<th>Pkt.</th></tr>
                </thead>
                <tbody>
                  {crossTable?.rows.map(row => (
                    <tr key={row.playerId}>
                      <th>{row.rank}. {row.name}</th>
                      {row.cells.map(cell => <td key={cell.opponentId} title={cell.roundNumber ? `R${cell.roundNumber}, Brett ${cell.boardNumber}` : undefined}>{cell.resultLabel}</td>)}
                      <td>{row.points}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </article>

          <article className="card">
            <h3>Runden und Ergebnisse</h3>
            {selectedTournament?.rounds.length === 0 && <p>Noch keine Runde ausgelost.</p>}
            {selectedTournament?.rounds.map(round => (
              <section key={round.roundNumber} className="round-box">
                <div className="round-header">
                  <div>
                    <h4>Runde {round.roundNumber}</h4>
                    <p className="muted">Status: {roundStatusLabel(round.resultStatus)}{round.isLocked ? ' · gesperrt' : ''}{round.isVerified ? ' · geprüft' : ''}</p>
                  </div>
                  <div className="actions">
                    <button type="button" className="small" onClick={() => void setRoundLock(round, !round.isLocked)} disabled={round.isVerified}>{round.isLocked ? 'Entsperren' : 'Sperren'}</button>
                    <button type="button" className="small secondary" onClick={() => void setRoundVerified(round, !round.isVerified)}>{round.isVerified ? 'Prüfung zurücknehmen' : 'Als geprüft markieren'}</button>
                  </div>
                </div>
                {round.audit && (
                  <details className="audit-box">
                    <summary>{round.audit.algorithm} · {round.audit.rulesetVersion}</summary>
                    <div className="audit-grid">
                      <section>
                        <strong>Hinweise</strong>
                        <ul>{round.audit.messages.map((message, index) => <li key={`m-${index}`}>{message}</li>)}</ul>
                      </section>
                      <section>
                        <strong>Scoregruppen</strong>
                        <ul>{round.audit.scoreGroups.map((message, index) => <li key={`s-${index}`}>{message}</li>)}</ul>
                      </section>
                      <section>
                        <strong>Floater</strong>
                        <ul>{round.audit.floaters.length === 0 ? <li>keine</li> : round.audit.floaters.map((message, index) => <li key={`f-${index}`}>{message}</li>)}</ul>
                      </section>
                      <section>
                        <strong>Farben</strong>
                        <ul>{round.audit.colorNotes.map((message, index) => <li key={`c-${index}`}>{message}</li>)}</ul>
                      </section>
                    </div>
                  </details>
                )}
                {diagnosticsFor(round.roundNumber) && (
                  <details className="diagnostics-box" open={diagnosticsFor(round.roundNumber)?.warnings.length !== 0}>
                    <summary>Rundenprüfung · {diagnosticsFor(round.roundNumber)?.openBoards ?? 0} offen · {diagnosticsFor(round.roundNumber)?.forfeitBoards ?? 0} kampflos · {diagnosticsFor(round.roundNumber)?.byeBoards ?? 0} Bye</summary>
                    {(diagnosticsFor(round.roundNumber)?.warnings.length ?? 0) === 0 && <p className="ok">Keine Warnungen.</p>}
                    <ul>{diagnosticsFor(round.roundNumber)?.warnings.map((warning, index) => <li key={`w-${round.roundNumber}-${index}`}>{warning}</li>)}</ul>
                    <div className="table-scroll compact">
                      <table>
                        <thead><tr><th>Brett</th><th>Ergebnis</th><th>BH</th><th>SB/Direkt</th><th>TPR</th><th>Hinweis</th></tr></thead>
                        <tbody>
                          {diagnosticsFor(round.roundNumber)?.boards.map(board => (
                            <tr key={`d-${round.roundNumber}-${board.boardNumber}`} className={board.isForfeit ? 'manual-row' : board.isOpen ? 'warning-row' : ''}>
                              <td>{board.boardNumber}</td>
                              <td>{board.resultLabel}</td>
                              <td>{board.countsForBuchholz ? 'ja' : 'nein'}</td>
                              <td>{board.countsForDirectAndSonneborn ? 'ja' : 'nein'}</td>
                              <td>{board.countsForPerformance ? 'ja' : 'nein'}</td>
                              <td>{board.note}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </details>
                )}
                <div className="table-scroll">
                  <table>
                    <thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Ergebnis</th><th>Manuelle Paarung</th></tr></thead>
                    <tbody>
                      {round.pairings.map(pairing => {
                        const edit = pairingEdit(round, pairing);
                        const roundClosed = round.isLocked || round.isVerified;
                        return (
                          <tr key={`${round.roundNumber}-${pairing.boardNumber}`} className={pairing.isManualOverride ? 'manual-row' : ''}>
                            <td>{pairing.boardNumber}{pairing.isManualOverride ? <small>manuell</small> : null}</td>
                            <td>{playerNameById(pairing.whitePlayerId)}</td>
                            <td>{pairing.isBye ? 'spielfrei' : playerNameById(pairing.blackPlayerId)}</td>
                            <td>
                              <select
                                value={pairing.result.kind}
                                onChange={(event: React.ChangeEvent<HTMLSelectElement>) => void recordResult(round.roundNumber, pairing.boardNumber, Number(event.target.value))}
                                disabled={pairing.isBye || roundClosed}
                              >
                                {resultOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                              </select>
                              <small>{resultLabel(pairing.result.kind)}</small>
                            </td>
                            <td>
                              <div className="manual-pairing">
                                <select value={edit.whitePlayerId} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updatePairingEdit(round.roundNumber, pairing.boardNumber, { whitePlayerId: event.target.value })} disabled={roundClosed}>
                                  <option value="">Weiß wählen</option>
                                  {selectedTournament.players.filter(player => player.status === 0).map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
                                </select>
                                <select value={edit.blackPlayerId} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updatePairingEdit(round.roundNumber, pairing.boardNumber, { blackPlayerId: event.target.value })} disabled={roundClosed}>
                                  <option value="">Schwarz/Bye leer</option>
                                  {selectedTournament.players.filter(player => player.status === 0).map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
                                </select>
                                <input value={edit.notes} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePairingEdit(round.roundNumber, pairing.boardNumber, { notes: event.target.value })} placeholder="Notiz" disabled={roundClosed} />
                                <button type="button" className="small" onClick={() => void saveManualPairing(round, pairing)} disabled={roundClosed || !edit.whitePlayerId}>Paarung speichern</button>
                              </div>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </section>
            ))}
          </article>

          <article className="card">
            <h3>Import / Export</h3>
            <div className="grid two">
              <section>
                <h4>Teilnehmer-CSV</h4>
                <textarea value={csvContent} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => setCsvContent(event.target.value)} rows={7} />
                <label className="checkbox"><input type="checkbox" checked={replacePlayers} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setReplacePlayers(event.target.checked)} /> vorhandene Teilnehmer ersetzen</label>
                <div className="actions">
                  <button type="button" onClick={() => void importPlayers()} disabled={!selectedTournament}>CSV importieren</button>
                  <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>CSV exportieren</button>
                </div>
              </section>
              <section>
                <h4>JSON-Backup</h4>
                <textarea value={backupJson} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => setBackupJson(event.target.value)} rows={7} placeholder="Backup-JSON hier einfügen oder exportieren" />
                <div className="actions">
                  <button type="button" onClick={() => void exportTournamentJson()} disabled={!selectedTournament}>Backup exportieren</button>
                  <button type="button" className="secondary" onClick={() => void importTournamentJson()} disabled={!backupJson.trim()}>Backup importieren</button>
                </div>
              </section>
              <section>
                <h4>Druck / Aushang</h4>
                <p className="muted">Erzeugt lokale CSV-/HTML-Dateien für Tabelle, Paarungen, Rundenblatt und kompletten Turnierbericht.</p>
                <div className="actions vertical-actions">
                  <button type="button" onClick={() => openTournamentExport('standings/export.csv')} disabled={!selectedTournament}>Tabelle als CSV</button>
                  <button type="button" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>Alle Paarungen als CSV</button>
                  <button type="button" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>Turnier-Druckansicht</button>
                </div>
                <div className="round-print-list">
                  {selectedTournament?.rounds.map(round => (
                    <button key={`print-${round.roundNumber}`} type="button" className="small secondary" onClick={() => openRoundPrint(round.roundNumber)}>Runde {round.roundNumber} drucken</button>
                  ))}
                </div>
              </section>
            </div>
          </article>
        </section>
      </section>
    </main>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(<App />);

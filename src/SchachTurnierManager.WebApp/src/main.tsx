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
  birthYear?: number | null;
  gender: number;
  startingRank: number;
  rating: RatingProfile;
  status: number;
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
};

type TournamentRound = {
  roundNumber: number;
  pairings: Pairing[];
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
  tournamentPerformance?: number | null;
  heroScore: number;
};

type Tournament = {
  id: string;
  name: string;
  createdOn: string;
  players: Player[];
  rounds: TournamentRound[];
};

const resultOptions = [
  { value: 0, label: 'offen' },
  { value: 1, label: '1-0' },
  { value: 2, label: '½-½' },
  { value: 3, label: '0-1' },
  { value: 4, label: '+/-' },
  { value: 5, label: '-/+' },
  { value: 6, label: '-/-' },
  { value: 7, label: 'Bye' },
  { value: 8, label: 'Armageddon Weiß' },
  { value: 9, label: 'Armageddon Schwarz' }
];

const formatOptions = [
  { value: 1, label: 'Schweizer System' },
  { value: 0, label: 'Jeder gegen Jeden' }
];

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

function resultLabel(kind: number): string {
  return resultOptions.find(option => option.value === kind)?.label ?? String(kind);
}

function App() {
  const [health, setHealth] = React.useState<Health | null>(null);
  const [tournaments, setTournaments] = React.useState<Tournament[]>([]);
  const [selectedId, setSelectedId] = React.useState<string>('');
  const [standings, setStandings] = React.useState<StandingRow[]>([]);
  const [newTournamentName, setNewTournamentName] = React.useState('Vereinsturnier');
  const [format, setFormat] = React.useState(1);
  const [playerName, setPlayerName] = React.useState('');
  const [club, setClub] = React.useState('');
  const [twz, setTwz] = React.useState('');
  const [birthYear, setBirthYear] = React.useState('');
  const [status, setStatus] = React.useState('Bereit.');
  const [error, setError] = React.useState<string | null>(null);
  const selectedTournament = tournaments.find(tournament => tournament.id === selectedId) ?? tournaments[0];

  const loadTournaments = React.useCallback(async () => {
    const data = await requestJson<Tournament[]>('/api/tournaments');
    setTournaments(data);
    if (!selectedId && data.length > 0) {
      setSelectedId(data[0].id);
    }
  }, [selectedId]);

  const loadStandings = React.useCallback(async (id: string) => {
    if (!id) {
      setStandings([]);
      return;
    }
    setStandings(await requestJson<StandingRow[]>(`/api/tournaments/${id}/standings`));
  }, []);

  const refresh = React.useCallback(async (id?: string) => {
    await loadTournaments();
    await loadStandings(id ?? selectedTournament?.id ?? selectedId);
  }, [loadStandings, loadTournaments, selectedId, selectedTournament?.id]);

  React.useEffect(() => {
    requestJson<Health>('/api/health')
      .then(setHealth)
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
    loadTournaments().catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, [loadTournaments]);

  React.useEffect(() => {
    if (selectedTournament?.id) {
      loadStandings(selectedTournament.id).catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
    }
  }, [loadStandings, selectedTournament?.id]);

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
          allowManualPairingOverrides: true
        }
      })
    });
    setSelectedId(created.id);
    setStatus(`Turnier angelegt: ${created.name}`);
    await refresh(created.id);
  }

  async function addPlayer(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedTournament) {
      return;
    }
    setError(null);
    await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players`, {
      method: 'POST',
      body: JSON.stringify({
        name: playerName,
        club: club || null,
        federation: null,
        country: null,
        birthYear: birthYear ? Number(birthYear) : null,
        gender: 0,
        elo: null,
        rapidElo: null,
        blitzElo: null,
        dwz: null,
        dwzIndex: null,
        manualTwz: twz ? Number(twz) : null,
        fideId: null,
        nationalId: null,
        title: null,
        status: 0,
        notes: null,
        startingRank: null
      })
    });
    setPlayerName('');
    setClub('');
    setTwz('');
    setBirthYear('');
    setStatus('Teilnehmer gespeichert.');
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

  function playerNameById(id?: string | null): string {
    if (!id || !selectedTournament) {
      return '—';
    }
    return selectedTournament.players.find(player => player.id === id)?.name ?? id.slice(0, 8);
  }

  return (
    <main className="shell">
      <header className="hero">
        <div>
          <p className="eyebrow">Lokaler Turnierleiter · v0.2.0</p>
          <h1>SchachTurnierManager</h1>
          <p>Persistentes MVP mit SQLite, API, Teilnehmererfassung, Auslosung, Ergebnissen und Live-Tabelle.</p>
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
            <input value={newTournamentName} onChange={event => setNewTournamentName(event.target.value)} placeholder="Turniername" />
            <select value={format} onChange={event => setFormat(Number(event.target.value))}>
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
            <button type="button" onClick={() => void generateRound()} disabled={!selectedTournament || selectedTournament.players.length < 2}>Nächste Runde auslosen</button>
          </div>

          <div className="grid two">
            <article className="card">
              <h3>Teilnehmer erfassen</h3>
              <form onSubmit={(event) => void addPlayer(event)} className="player-form">
                <input value={playerName} onChange={event => setPlayerName(event.target.value)} placeholder="Name *" />
                <input value={club} onChange={event => setClub(event.target.value)} placeholder="Verein" />
                <input value={twz} onChange={event => setTwz(event.target.value)} placeholder="TWZ" type="number" min="0" />
                <input value={birthYear} onChange={event => setBirthYear(event.target.value)} placeholder="Geburtsjahr" type="number" min="1900" max="2100" />
                <button type="submit" disabled={!selectedTournament}>Speichern</button>
              </form>
              <table>
                <thead><tr><th>#</th><th>Name</th><th>Verein</th><th>TWZ</th></tr></thead>
                <tbody>
                  {selectedTournament?.players.map(player => (
                    <tr key={player.id}>
                      <td>{player.startingRank}</td>
                      <td>{player.name}</td>
                      <td>{player.club ?? '—'}</td>
                      <td>{player.rating.manualTwz ?? player.rating.dwz ?? player.rating.elo ?? 0}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </article>

            <article className="card">
              <h3>Live-Tabelle</h3>
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
            </article>
          </div>

          <article className="card">
            <h3>Runden und Ergebnisse</h3>
            {selectedTournament?.rounds.length === 0 && <p>Noch keine Runde ausgelost.</p>}
            {selectedTournament?.rounds.map(round => (
              <section key={round.roundNumber} className="round-box">
                <h4>Runde {round.roundNumber}</h4>
                <table>
                  <thead><tr><th>Brett</th><th>Weiß</th><th>Schwarz</th><th>Ergebnis</th><th>Speichern</th></tr></thead>
                  <tbody>
                    {round.pairings.map(pairing => (
                      <tr key={`${round.roundNumber}-${pairing.boardNumber}`}>
                        <td>{pairing.boardNumber}</td>
                        <td>{playerNameById(pairing.whitePlayerId)}</td>
                        <td>{pairing.isBye ? 'spielfrei' : playerNameById(pairing.blackPlayerId)}</td>
                        <td>{resultLabel(pairing.result.kind)}</td>
                        <td>
                          <select
                            value={pairing.result.kind}
                            onChange={event => void recordResult(round.roundNumber, pairing.boardNumber, Number(event.target.value))}
                            disabled={pairing.isBye}
                          >
                            {resultOptions.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
                          </select>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </section>
            ))}
          </article>
        </section>
      </section>
    </main>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(<App />);

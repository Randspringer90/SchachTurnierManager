import React from 'react';
import ReactDOM from 'react-dom/client';
import './styles.css';

type Health = {
  status: string;
  app: string;
  version: string;
  time: string;
};

function App() {
  const [health, setHealth] = React.useState<Health | null>(null);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    fetch('/api/health')
      .then((response) => response.ok ? response.json() : Promise.reject(new Error(`HTTP ${response.status}`)))
      .then(setHealth)
      .catch((err: unknown) => setError(err instanceof Error ? err.message : String(err)));
  }, []);

  return (
    <main className="shell">
      <section className="hero">
        <p className="eyebrow">Lokaler Turnierleiter</p>
        <h1>SchachTurnierManager</h1>
        <p>
          Dashboard-Grundlage für Teilnehmer, Auslosung, Ergebnisse, Tabellen,
          Wertungen, Armageddon und spätere Swiss-/Chess-Results-Adapter.
        </p>
      </section>

      <section className="grid">
        <article className="card">
          <h2>Backend</h2>
          {health && <p className="ok">{health.app} {health.version}: {health.status}</p>}
          {error && <p className="error">Backend nicht erreichbar: {error}</p>}
          {!health && !error && <p>Prüfe API-Verbindung…</p>}
        </article>
        <article className="card">
          <h2>MVP-Funktionen</h2>
          <ul>
            <li>Rundenturnier-Paarungen</li>
            <li>Basis-Schweizer-System</li>
            <li>Buchholz, SB, Siege, Performance</li>
            <li>Armageddon-Zeitgebot-Grundlage</li>
          </ul>
        </article>
        <article className="card">
          <h2>Nächste UI-Schritte</h2>
          <ul>
            <li>Teilnehmerformular</li>
            <li>Rundentabelle</li>
            <li>Ergebniseingabe</li>
            <li>Kreuztabelle</li>
          </ul>
        </article>
      </section>
    </main>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(<App />);

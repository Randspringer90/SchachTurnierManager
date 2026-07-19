// Planning recommendation for the tournament assistant.
// Extracted from main.tsx (STM-FE-014). Pure function over the assistant form.
import { assistantNumber, recommendedSwissRounds, assistantScenarioRoundMinutes } from './assistant';
import { formatOptions, scoringOptions } from './tournamentOptions';
import type {
  TournamentAssistantForm,
  TournamentAssistantRecommendation,
  TournamentAssistantScenario,
} from '../api/contracts';
export const assistantScenarioOptions: Array<{ value: TournamentAssistantScenario; label: string; description: string }> = [
  { value: 'club-night', label: 'Vereinsabend / Schnellturnier', description: 'Robuste Standardempfehlung für 8–30 Spieler und begrenzte Zeit.' },
  { value: 'youth', label: 'Jugendturnier', description: 'Kürzere Runden, klare Checklisten, viele Ausdrucke.' },
  { value: 'open', label: 'Open / großes Feld', description: 'Schweizer System, Audit, Backup und Veröffentlichung im Vordergrund.' },
  { value: 'blitz', label: 'Blitz / Schnellschach', description: 'Viele kurze Runden und einfache Wertung.' },
  { value: 'chess960', label: 'Chess960 / Freestyle', description: 'QR-/Handy-Würfeln und Startstellungs-Audit einplanen.' },
  { value: 'team', label: 'Mannschaft / Teamturnier', description: 'Noch nicht vollständig implementiert; aktuell als Planungshinweis.' }
];

export const defaultTournamentAssistantForm: TournamentAssistantForm = {
  playerCount: '12',
  availableMinutes: '180',
  boardCount: '6',
  scenario: 'club-night',
  rated: false,
  chess960: false,
  needsQr: true
};

export function buildTournamentAssistantRecommendation(form: TournamentAssistantForm): TournamentAssistantRecommendation {
  const playerCount = assistantNumber(form.playerCount, 12, 2, 512);
  const availableMinutes = assistantNumber(form.availableMinutes, 180, 30, 1440);
  const boardCount = assistantNumber(form.boardCount, Math.max(1, Math.ceil(playerCount / 2)), 1, 256);
  const activeChess960 = form.chess960 || form.scenario === 'chess960';
  const canRoundRobin = playerCount <= 8 && form.scenario !== 'open' && form.scenario !== 'team';
  const formatValue = canRoundRobin && availableMinutes >= Math.max(3, playerCount - 1) * assistantScenarioRoundMinutes(form) ? 0 : 1;
  const plannedRounds = formatValue === 0 ? Math.max(1, playerCount - 1) : recommendedSwissRounds(playerCount);
  const scoringSystem = form.scenario === 'blitz' ? 0 : 0;
  const estimatedRoundMinutes = assistantScenarioRoundMinutes(form);
  const estimatedTotalMinutes = plannedRounds * estimatedRoundMinutes + 20;
  const estimatedBoards = Math.ceil(playerCount / 2);
  const timeFit: TournamentAssistantRecommendation['timeFit'] = estimatedTotalMinutes <= availableMinutes
    ? 'ok'
    : estimatedTotalMinutes <= availableMinutes + 30
      ? 'tight'
      : 'blocked';
  const timeFitLabel = timeFit === 'ok'
    ? 'Zeitfenster passt'
    : timeFit === 'tight'
      ? 'Zeitfenster knapp – Rundenlänge oder Rundenzahl prüfen'
      : 'Zeitfenster reicht voraussichtlich nicht';
  const formatLabel = formatOptions.find(option => option.value === formatValue)?.label ?? 'Schweizer System';
  const scoringLabel = scoringOptions.find(option => option.value === scoringSystem)?.label ?? scoringOptions[0].label;
  const setupSteps = [
    `${formatLabel} mit ${plannedRounds} Runde(n) vorbereiten`,
    `Teilnehmerliste importieren oder erfassen; erwartete Bretter: ${estimatedBoards}`,
    'Vor Runde 1 Backup ziehen und Datenbankpfad prüfen',
    'Auslosungsvorschau öffnen, Pairing-Qualität prüfen und erst dann auslosen',
    'Nach jeder Runde Ergebnisse vollständig erfassen, Runde prüfen und Backup exportieren'
  ];

  if (activeChess960) {
    setupSteps.splice(3, 0, 'Chess960/QR-Würfeln vor Rundenstart testen und WLAN-/Hotspot-Link prüfen');
  }

  const warnings: string[] = [];
  if (boardCount < estimatedBoards) {
    warnings.push(`Nur ${boardCount} Brett(er) angegeben, aber ${estimatedBoards} Brett(er) benötigt. BYE/Schichtbetrieb oder weniger Teilnehmer einplanen.`);
  }
  if (timeFit !== 'ok') {
    warnings.push(timeFitLabel);
  }
  if (playerCount > 20) {
    warnings.push('Großes Schweizer Feld: Paarungsstrategie bewusst wählen und Pairing-Audit besonders prüfen. FIDE Dutch ist integriert, aber nicht als FIDE-zertifizierte Turniersoftware ausgewiesen.');
  }
  if (form.rated) {
    warnings.push('Gewertetes Turnier: Ausschreibung, Bedenkzeit, Bye-/Kampflos-Regeln und Exportformat vorab mit Verband/Turnierordnung abgleichen.');
  }
  if (form.scenario === 'team') {
    warnings.push('Team-/Mannschaftsturniere sind aktuell noch Planungsszenario; vollständige Mehrbrett-Teamlogik folgt in RUN-16.');
  }

  const operatorChecklist = [
    'Laptop am Netzteil betreiben und Energiesparen/Bildschirmsperre deaktivieren',
    'Startdatei/Backend-Fenster offen lassen und Browser nicht schließen',
    'Drucker oder PDF-Export vor Runde 1 testen',
    'Ergebniszettel/QR-Aushang vorbereiten',
    'Nach jeder Runde Audit/Backup sichern'
  ];

  const exportPlan = [
    'Teilnehmerliste vor Turnierstart exportieren',
    'Rundenblatt je Runde drucken oder als PDF ablegen',
    'Tabelle nach jeder Runde veröffentlichen',
    'Abschluss-Backup und finale Tabelle exportieren'
  ];

  const handoffPrompt = `Plane ein ${assistantScenarioOptions.find(option => option.value === form.scenario)?.label ?? 'Turnier'} mit ${playerCount} Teilnehmern, ${availableMinutes} Minuten Zeit, ${boardCount} Brettern, Format ${formatLabel}, ${plannedRounds} Runden${activeChess960 ? ', Chess960/Freestyle mit QR-Würfeln' : ''}. Prüfe Pairing, Wertung, Backup, Druck und Veröffentlichung Schritt für Schritt.`;

  return {
    title: `${formatLabel} · ${plannedRounds} Runde(n) · ca. ${estimatedTotalMinutes} Min.`,
    format: formatValue,
    formatLabel,
    plannedRounds,
    scoringSystem,
    scoringLabel,
    estimatedRoundMinutes,
    estimatedTotalMinutes,
    estimatedBoards,
    timeFit,
    timeFitLabel,
    setupSteps,
    warnings,
    operatorChecklist,
    exportPlan,
    handoffPrompt
  };
}


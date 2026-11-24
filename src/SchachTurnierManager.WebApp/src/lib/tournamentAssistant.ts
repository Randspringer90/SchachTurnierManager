// Planning recommendation for the tournament assistant.
// Extracted from main.tsx (STM-FE-014). Pure function over the assistant form.
import { assistantNumber, recommendedSwissRounds, assistantScenarioRoundMinutes } from './assistant';
import { optionLabel, formatOptions, scoringOptions } from './tournamentOptions';
import type {
  TournamentAssistantForm,
  TournamentAssistantRecommendation,
  TournamentAssistantScenario,
} from '../api/contracts';
export const assistantScenarioOptions: Array<{ value: TournamentAssistantScenario; label: string; labelEn: string; description: string; descriptionEn: string }> = [
  { value: 'club-night', label: 'Vereinsabend / Schnellturnier', labelEn: "Club night / rapid tournament", description: 'Robuste Standardempfehlung für 8–30 Spieler und begrenzte Zeit.', descriptionEn: "Robust default for 8–30 players and limited time." },
  { value: 'youth', label: 'Jugendturnier', labelEn: "Youth tournament", description: 'Kürzere Runden, klare Checklisten, viele Ausdrucke.', descriptionEn: "Shorter rounds, clear checklists and printed sheets." },
  { value: 'open', label: 'Open / großes Feld', labelEn: "Open / large field", description: 'Schweizer System, Audit, Backup und Veröffentlichung im Vordergrund.', descriptionEn: "Focus on the Swiss system, audit, backup and publication." },
  { value: 'blitz', label: 'Blitz / Schnellschach', labelEn: "Blitz / rapid chess", description: 'Viele kurze Runden und einfache Wertung.', descriptionEn: "Many short rounds and simple scoring." },
  { value: 'chess960', label: 'Chess960 / Freestyle', labelEn: "Chess960 / Freestyle", description: 'QR-/Handy-Würfeln und Startstellungs-Audit einplanen.', descriptionEn: "Plan for QR/mobile rolls and a starting-position audit." },
  { value: 'team', label: 'Mannschaft / Teamturnier', labelEn: "Team tournament", description: 'Noch nicht vollständig implementiert; aktuell als Planungshinweis.', descriptionEn: "Not fully implemented yet; currently for planning only." }
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

export function buildTournamentAssistantRecommendation(form: TournamentAssistantForm, english = false): TournamentAssistantRecommendation {
  const copy = (german: string, translated: string) => english ? translated : german;
  const playerCount = assistantNumber(form.playerCount, 12, 2, 512);
  const availableMinutes = assistantNumber(form.availableMinutes, 180, 30, 1440);
  const boardCount = assistantNumber(form.boardCount, Math.max(1, Math.floor(playerCount / 2)), 1, 256);
  const activeChess960 = form.chess960 || form.scenario === 'chess960';
  const canRoundRobin = playerCount <= 8 && form.scenario !== 'open' && form.scenario !== 'team';
  const roundRobinRounds = playerCount % 2 === 0 ? playerCount - 1 : playerCount;
  const formatValue = canRoundRobin && availableMinutes >= Math.max(3, roundRobinRounds) * assistantScenarioRoundMinutes(form) ? 0 : 1;
  const plannedRounds = formatValue === 0 ? roundRobinRounds : recommendedSwissRounds(playerCount);
  const scoringSystem = form.scenario === 'blitz' ? 0 : 0;
  const estimatedRoundMinutes = assistantScenarioRoundMinutes(form);
  const estimatedTotalMinutes = plannedRounds * estimatedRoundMinutes + 20;
  const estimatedBoards = Math.floor(playerCount / 2);
  const timeFit: TournamentAssistantRecommendation['timeFit'] = estimatedTotalMinutes <= availableMinutes
    ? 'ok'
    : estimatedTotalMinutes <= availableMinutes + 30
      ? 'tight'
      : 'blocked';
  const timeFitLabel = timeFit === 'ok'
    ? copy('Zeitfenster passt', "Time available is sufficient")
    : timeFit === 'tight'
      ? copy('Zeitfenster knapp – Rundenlänge oder Rundenzahl prüfen', "Time is tight. Review round duration or round count")
      : copy('Zeitfenster reicht voraussichtlich nicht', "Time available is probably insufficient");
  const formatLabel = optionLabel(formatOptions.find(option => option.value === formatValue), english);
  const scoringLabel = optionLabel(scoringOptions.find(option => option.value === scoringSystem), english);
  const setupSteps = [
    copy(`${formatLabel} mit ${plannedRounds} Runde(n) vorbereiten`, `Prepare ${formatLabel} with ${plannedRounds} round(s)`),
    copy(`Teilnehmerliste importieren oder erfassen; erwartete Bretter: ${estimatedBoards}`, `Import or enter participants; expected boards: ${estimatedBoards}`),
    copy('Vor Runde 1 Backup ziehen und Datenbankpfad prüfen', "Export a backup and check the database path before round 1"),
    copy('Auslosungsvorschau öffnen, Pairing-Qualität prüfen und erst dann auslosen', "Open the preview and check pairing quality before pairing"),
    copy('Nach jeder Runde Ergebnisse vollständig erfassen, Runde prüfen und Backup exportieren', "Enter all results, review the round and export a backup after each round")
  ];

  if (activeChess960) {
    setupSteps.splice(3, 0, copy('Chess960/QR-Würfeln vor Rundenstart testen und WLAN-/Hotspot-Link prüfen', "Test Chess960/QR rolls and the secure LAN connection before the round"));
  }

  const warnings: string[] = [];
  if (boardCount < estimatedBoards) {
    warnings.push(copy(`Nur ${boardCount} Brett(er) angegeben, aber ${estimatedBoards} Brett(er) benötigt. BYE/Schichtbetrieb oder weniger Teilnehmer einplanen.`, `Only ${boardCount} board(s) available; ${estimatedBoards} needed. Plan byes, multiple sessions or fewer participants.`));
  }
  if (timeFit !== 'ok') {
    warnings.push(timeFitLabel);
  }
  if (playerCount > 20) {
    warnings.push(copy('Großes Schweizer Feld: Paarungsstrategie bewusst wählen und Pairing-Audit besonders prüfen. FIDE Dutch ist integriert, aber nicht als FIDE-zertifizierte Turniersoftware ausgewiesen.', "Large Swiss field: select the pairing strategy deliberately and review the pairing audit closely. FIDE Dutch is integrated without claiming FIDE certification."));
  }
  if (form.rated) {
    warnings.push(copy('Gewertetes Turnier: Ausschreibung, Bedenkzeit, Bye-/Kampflos-Regeln und Exportformat vorab mit Verband/Turnierordnung abgleichen.', "Rated tournament: check the announcement, time control, bye/forfeit rules and export format against federation and tournament regulations in advance."));
  }
  if (form.scenario === 'team') {
    warnings.push(copy('Team-/Mannschaftsturniere sind aktuell noch Planungsszenario; vollständige Mehrbrett-Teamlogik folgt in RUN-16.', "Team tournaments are currently a planning scenario. Full multi-board team logic is pending in RUN-16."));
  }

  const operatorChecklist = [
    copy('Laptop am Netzteil betreiben und Energiesparen/Bildschirmsperre deaktivieren', "Use mains power and prevent sleep or screen lock"),
    copy('Startdatei/Backend-Fenster offen lassen und Browser nicht schließen', "Keep the launcher/backend window and browser open"),
    copy('Drucker oder PDF-Export vor Runde 1 testen', "Test printing or PDF export before round 1"),
    copy('Ergebniszettel/QR-Aushang vorbereiten', "Prepare result slips and QR postings"),
    copy('Nach jeder Runde Audit/Backup sichern', "Save audit evidence and a backup after each round")
  ];

  const exportPlan = [
    copy('Teilnehmerliste vor Turnierstart exportieren', "Export participants before the tournament starts"),
    copy('Rundenblatt je Runde drucken oder als PDF ablegen', "Print or save a PDF round sheet for each round"),
    copy('Tabelle nach jeder Runde veröffentlichen', "Publish standings after each round"),
    copy('Abschluss-Backup und finale Tabelle exportieren', "Export a final backup and final standings")
  ];

  const scenario = assistantScenarioOptions.find(option => option.value === form.scenario);
  const handoffPrompt = english
    ? `Plan a ${scenario?.labelEn ?? 'tournament'} with ${playerCount} participants, ${availableMinutes} minutes, ${boardCount} boards, ${formatLabel}, ${plannedRounds} rounds${activeChess960 ? ', Chess960/Freestyle with QR rolls' : ''}. Review pairing, scoring, backup, printing and publication step by step.`
    : `Plane ein ${assistantScenarioOptions.find(option => option.value === form.scenario)?.label ?? 'Turnier'} mit ${playerCount} Teilnehmern, ${availableMinutes} Minuten Zeit, ${boardCount} Brettern, Format ${formatLabel}, ${plannedRounds} Runden${activeChess960 ? ', Chess960/Freestyle mit QR-Würfeln' : ''}. Prüfe Pairing, Wertung, Backup, Druck und Veröffentlichung Schritt für Schritt.`;

  return {
    title: copy(`${formatLabel} · ${plannedRounds} Runde(n) · ca. ${estimatedTotalMinutes} Min.`, `${formatLabel} · ${plannedRounds} round(s) · approx. ${estimatedTotalMinutes} min`),
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

// Main application shell.
//
// This component still owns most of the operator workflow. It was extracted
// out of main.tsx (STM-FE-014) as the first step of the modularization: pure
// helpers, contracts, the API client, dialogs, the Chess960 components and the
// mobile companion page now live in dedicated modules, and main.tsx is a
// bootstrap only. Remaining feature-area extractions are tracked in the
// backlog (STM-FE-015..018).
import React from 'react';
import { buildAuditJournalCsv } from '../lib/auditCsv';
import { createTournamentProjectionLoader, type TournamentProjection } from '../lib/tournamentProjection';
import { createPlayerImportPreviewGuard } from '../lib/playerImportPreview';
import { createTournamentEditorGuard, type TournamentEditorToken } from '../lib/tournamentEditorGuard';
import { backupImportSummary, createBackupImportGuard, type BackupImportRequest } from '../lib/backupImportGuard';
import { describeJsonParseFailure } from '../lib/jsonParseError';
import { captureResultEntry, createIndexedDbResultQueueStore, type QueuedResultEntry } from '../lib/offlineResultQueue';
import { OfflineResultQueuePanel } from '../components/OfflineResultQueuePanel';
import { FideLookupPanel } from '../components/FideLookupPanel';
import { LanguageSwitcher, useI18n } from '../i18n';
import { describeApiError, healthProbeTimeoutMs, isApiTransportError, pairingRequestTimeoutMs, requestJson, requestText } from '../api/client';
import {
  canOperate,
  describeReadiness,
  nextProbeDelayMs,
  readinessAfterProbe,
  steadyProbeIntervalMs,
  type BackendReadiness,
} from '../lib/backendReadiness';
import { ConfirmDialog } from '../components/dialogs/ConfirmDialog';
import { QrPanel } from '../components/QrPanel';
import { ChessDie } from '../components/chess960/ChessDie';
import { BoardDiceRoller } from '../components/chess960/BoardDiceRoller';
import { canDispatchDestructiveAction, selectNextTournamentId } from '../lib/destructiveActions';
import { assistantNumber, recommendedSwissRounds, assistantScenarioRoundMinutes } from '../lib/assistant';
import { buildLocalKnowledgeAnswer, getLocalKnowledgeBase } from '../lib/knowledge';
import { assistantScenarioOptions, defaultTournamentAssistantForm, buildTournamentAssistantRecommendation } from '../lib/tournamentAssistant';
import { chess960BackRankFromNumber, chess960PieceFace, defaultLanHost, diceFaceGlyphs } from '../lib/chess960';
import { mainTabs, isMainTab } from './navigation';
import type { MainTab } from './navigation';
import {
  buildWeekDemoMarker,
  buildWeekDemoName,
  defaultTiebreaks,
  emptyPlayerForm,
  emptySettingsForm,
  externalSourceOptions,
  forfeitPolicyOptions,
  formatOptions,
  optionLabel,
  genderOptions,
  isBuildWeekDemoTournament,
  pairingStrategyOptions,
  playerStatusOptions,
  resultOptions,
  sampleCsvTemplate,
  scoringOptions,
  swissInitialColourOptions,
  tiebreakOptions,
  twzSourceOptions,
  unplayedRoundBuchholzOptions,
} from '../lib/tournamentOptions';
import {
  backupTimestampSlug,
  downloadText,
  isStandaloneDisplayMode,
  readLocalStorage,
  safeFileNamepart,
  writeLocalStorage,
} from '../lib/browser';
import {
  approximateAgeLabel,
  auditActionLabel,
  auditDateLabel,
  auditSeverityClass,
  auditSeverityKey,
  auditSeverityLabel,
  backupTimeLabel,
  duplicateKindLabel,
  externalSourceLabel,
  genderLabel,
  importPreviewStatusClass,
  importPreviewStatusLabel,
  pairingQualitySeverityClass,
  pairingQualitySeverityLabel,
  pwaStatusLabel,
  resultLabel,
  roundStatusLabel,
  statusLabel,
  tiebreakLabel,
} from '../lib/labels';
import {
  applyExternalProfileToForm,
  externalProfileKey,
  formToRequest,
  formToSettings,
  importPreviewMessages,
  moveTiebreak,
  numberOrNull,
  playerToForm,
  settingsToForm,
  twzOf,
} from '../lib/playerForms';
import type { PlayerForm } from '../lib/tournamentOptions';
import type { DestructiveAction, DestructiveDialogState } from '../lib/destructiveActions';
import type {
  Health,
  BeforeInstallPromptEvent,
  PwaStatus,
  RatingProfile,
  Player,
  GameResult,
  Chess960StartPosition,
  Pairing,
  PairingAudit,
  TournamentRound,
  StandingRow,
  Tournament,
  AuditJournalEntry,
  CategoryStandingTable,
  CrossTable,
  CrossTablePlayer,
  CrossTableRow,
  CrossTableCell,
  HeroCupRow,
  BoardDiagnostic,
  RoundDiagnostics,
  PairingQualityBoard,
  PairingQualityReport,
  NextRoundPreview,
  ExternalPlayerProviderInfo,
  ExternalPlayerProfile,
  ExternalPlayerLookupResult,
  ExternalPlayerAggregateSourceResult,
  ExternalPlayerAggregateResult,
  ExternalPlayerDuplicateMatch,
  ExternalPlayerDuplicateCheck,
  ExternalPlayerApplyResult,
  PlayerImportPreview,
  PlayerImportPreviewRow,
  PairingEdit,
  SettingsForm,
  TournamentAssistantScenario,
  TournamentAssistantForm,
  TournamentAssistantRecommendation,
  KnowledgeChatRole,
  KnowledgeChatMessage,
  KnowledgeTopic,
  KnowledgeBase,
} from '../api/contracts';

/** Nicht zerstoerende Rueckfrage vor einer Bedienaktion, als In-App-Dialog. */
type ActionConfirmState = {
  title: string;
  description: string;
  consequences?: string[];
  confirmLabel: string;
  cancelLabel: string;
  destructive?: boolean;
  run: () => Promise<void>;
  onCancel?: () => void;
};

type DerivedTournamentData = {
  standings: StandingRow[]; categories: CategoryStandingTable[]; crossTable: CrossTable;
  heroCup: HeroCupRow[]; diagnostics: RoundDiagnostics[]; auditJournal: AuditJournalEntry[];
};

type BackupImportConfirmation = {
  request: BackupImportRequest;
  tournamentName: string;
  existingRoundCount: number;
  backupRoundCount: number;
};

/** STM-SEC-006: CSV exports prefix formula-like text with an apostrophe; a CSV re-import keeps it. */
function csvReimportNote(lang: string): string {
  return lang === 'en'
    ? 'Note: CSV exports prefix text starting with =, +, -, @ (or a control character) with an apostrophe to block spreadsheet formulas. Re-importing such a CSV keeps that apostrophe as part of the value. Use the JSON backup for a lossless transfer.'
    : 'Hinweis: CSV-Exporte stellen Texten, die mit =, +, -, @ (oder einem Steuerzeichen) beginnen, ein Apostroph voran, damit Tabellenprogramme keine Formeln ausführen. Ein erneuter CSV-Import übernimmt dieses Apostroph als Teil des Werts. Für eine verlustfreie Übernahme die JSON-Sicherung verwenden.';
}

export function App() {
  const { t, lang } = useI18n();
  const localKnowledgeBase = getLocalKnowledgeBase(lang);
  const knowledgeQuickQuestions = localKnowledgeBase.quickQuestions;
  const [health, setHealth] = React.useState<Health | null>(null);
  const [backendReadiness, setBackendReadiness] = React.useState<BackendReadiness>('starting');
  // Zaehlt nur die Neustarts der Bereitschaftspruefung ("Erneut versuchen"),
  // damit der Effekt wieder anlaeuft, ohne den Zustand selbst zu beobachten.
  const [readinessProbeGeneration, setReadinessProbeGeneration] = React.useState(0);
  const [pwaStatus, setPwaStatus] = React.useState<PwaStatus>(() => isStandaloneDisplayMode() ? 'installed' : 'checking');
  const [pwaInstallPrompt, setPwaInstallPrompt] = React.useState<BeforeInstallPromptEvent | null>(null);
  const [tournaments, setTournaments] = React.useState<Tournament[]>([]);
  const [selectedId, setSelectedIdState] = React.useState<string>('');
  const selectedTournament = tournaments.find(tournament => tournament.id === selectedId);
  const [projection, setProjection] = React.useState<TournamentProjection<DerivedTournamentData>>({id:'',phase:'idle',data:null});
  const [projectionLoader] = React.useState(() => createTournamentProjectionLoader<DerivedTournamentData>(setProjection));
  const currentProjection = projection.id === selectedTournament?.id && projection.phase === 'ready' ? projection.data : null;
  const standings = currentProjection?.standings ?? [];
  const categories = currentProjection?.categories ?? [];
  const crossTable = currentProjection?.crossTable ?? null;
  const heroCup = currentProjection?.heroCup ?? [];
  const roundDiagnostics = currentProjection?.diagnostics ?? [];
  const auditJournal = currentProjection?.auditJournal ?? [];
  const [pairingQualityReports, setPairingQualityReports] = React.useState<Record<number, PairingQualityReport>>({});
  const [nextRoundPreview, setNextRoundPreview] = React.useState<NextRoundPreview | null>(null);
  const [isNextRoundPreviewDialogOpen, setIsNextRoundPreviewDialogOpen] = React.useState(false);
  const [chess960DialogRound, setChess960DialogRound] = React.useState<TournamentRound | null>(null);
  const [chess960DialogToken, setChess960DialogToken] = React.useState<TournamentEditorToken | null>(null);
  const [chess960Guard] = React.useState(() => createTournamentEditorGuard(selectedId));
  const chess960EditorToken = chess960Guard.capture(selectedId);
  const [chess960Rolling, setChess960Rolling] = React.useState(false);
  const [chess960HasRolled, setChess960HasRolled] = React.useState(false);
  const [diceSpin, setDiceSpin] = React.useState(0);
  const [diceFace, setDiceFace] = React.useState(0);
  const [boardDiceModal, setBoardDiceModal] = React.useState<{ roundNumber: number; boardNumber: number } | null>(null);
  const [destructiveDialog, setDestructiveDialog] = React.useState<DestructiveDialogState | null>(null);
  // Rueckfragen, die frueher window.confirm waren (Auslosung trotz kritischer
  // Hinweise, Chess960 ueberschreiben). Firefox darf native Dialoge desselben
  // Skriptdurchlaufs unterdruecken - dann bliebe die Aktion wirkungslos.
  const [actionConfirm, setActionConfirm] = React.useState<ActionConfirmState | null>(null);
  const [actionConfirmBusy, setActionConfirmBusy] = React.useState(false);
  const actionConfirmInFlight = React.useRef<ActionConfirmState | null>(null);
  const [boardDiceTab, setBoardDiceTab] = React.useState<'browser' | 'qr'>('browser');
  const [laptopIp, setLaptopIp] = React.useState<string>(() => readLocalStorage('stm.laptopIp') ?? defaultLanHost());
  const [diceUrlCopied, setDiceUrlCopied] = React.useState(false);
  const [newTournamentName, setNewTournamentName] = React.useState('Vereinsturnier');
  const [format, setFormat] = React.useState(1);
  const [pairingStrategy, setPairingStrategy] = React.useState(0);
  const [swissInitialColour, setSwissInitialColour] = React.useState(1);
  const [isCreateTournamentOpen, setIsCreateTournamentOpen] = React.useState(false);
  // Blockiert das zweite Absenden. Ohne das erzeugte ein Doppelklick auf
  // "Jetzt anlegen" zwei identische Turniere - im Firefox-Smoke reproduziert.
  const [creatingTournament, setCreatingTournament] = React.useState(false);
  const [demoBusy, setDemoBusy] = React.useState(false);
  const [participantSearch, setParticipantSearch] = React.useState('');
  const [showAdvancedStandings, setShowAdvancedStandings] = React.useState(false);
  const [assistantForm, setAssistantForm] = React.useState<TournamentAssistantForm>(defaultTournamentAssistantForm);
  const assistantRecommendation = React.useMemo(() => buildTournamentAssistantRecommendation(assistantForm, lang === 'en'), [assistantForm, lang]);
  const [knowledgeChatInput, setKnowledgeChatInput] = React.useState('');
  const [knowledgeChatMessages, setKnowledgeChatMessages] = React.useState<KnowledgeChatMessage[]>([]);
  const [settingsForm, setSettingsForm] = React.useState<SettingsForm>(emptySettingsForm);
  const [newTournamentSettingsForm, setNewTournamentSettingsForm] = React.useState<SettingsForm>(emptySettingsForm);
  const settingsSource = React.useRef({ id: '', form: emptySettingsForm });
  const [settingsEditorGuard] = React.useState(() => createTournamentEditorGuard(selectedId));
  const settingsEditorToken = settingsEditorGuard.capture(selectedId);
  const [playerForm, setPlayerForm] = React.useState<PlayerForm>(emptyPlayerForm);
  const [externalQuery, setExternalQuery] = React.useState('');
  const [externalLookup, setExternalLookup] = React.useState<ExternalPlayerAggregateResult | null>(null);
  const [externalSearching, setExternalSearching] = React.useState(false);
  const [externalDuplicateChecks, setExternalDuplicateChecks] = React.useState<Record<string, ExternalPlayerDuplicateCheck>>({});
  const [editingPlayerId, setEditingPlayerId] = React.useState<string | null>(null);
  const [csvContent, setCsvContent] = React.useState('Name;Verein;Geburtsjahr;Geschlecht;DWZ;DWZIndex;Elo;TWZ;FIDE-ID;DSB-ID;Titel;Status;Notizen\n');
  const [replacePlayers, setReplacePlayers] = React.useState(false);
  const [importPreview, setImportPreview] = React.useState<PlayerImportPreview | null>(null);
  const [importPreviewGuard] = React.useState(() => createPlayerImportPreviewGuard<PlayerImportPreview>({
    tournamentId: selectedId, content: csvContent, replaceExisting: replacePlayers,
  }));
  const [formatImportResult, setFormatImportResult] = React.useState<{ added: number; errors: string[] } | null>(null);
  const [confirmWarningImport, setConfirmWarningImport] = React.useState(false);
  const [backupJson, setBackupJson] = React.useState('');
  const [backupImportGuard] = React.useState(createBackupImportGuard);
  const [backupImportPending, setBackupImportPending] = React.useState<BackupImportConfirmation | null>(null);
  const [backupImportBusy, setBackupImportBusy] = React.useState(false);
  const [pairingEdits, setPairingEdits] = React.useState<Record<string, PairingEdit>>({});
  const [playerEditorGuard] = React.useState(() => createTournamentEditorGuard(selectedId));
  const [pairingEditorGuard] = React.useState(() => createTournamentEditorGuard(selectedId));
  const playerEditorToken = playerEditorGuard.capture(selectedId);
  const pairingEditorToken = pairingEditorGuard.capture(selectedId);
  const [pendingResultChange, setPendingResultChange] = React.useState<{ tournamentId: string; roundNumber: number; boardNumber: number; result: number; previousResult: number; queueEntry?: QueuedResultEntry } | null>(null);
  // STM-FACH-007: optional operator reason for a correction. Free text never enters the browser result queue.
  const [correctionReason, setCorrectionReason] = React.useState('');
  const [resultQueueStore] = React.useState(createIndexedDbResultQueueStore);
  const [localQueueEnabled, setLocalQueueEnabled] = React.useState(false);
  const [lastResultChange, setLastResultChange] = React.useState<{ tournamentId: string; roundNumber: number; boardNumber: number; result: number; previousResult: number } | null>(null);
  const createTournamentInFlight = React.useRef(false);
  const resultConfirmButtonRef = React.useRef<HTMLButtonElement | null>(null);
  // Single-flight guard: a double click must not send the same result twice.
  const resultSavingRef = React.useRef(false);
  const [resultSaving, setResultSaving] = React.useState(false);
  const resultReturnFocusRef = React.useRef<HTMLElement | null>(null);
  const [status, setStatus] = React.useState('Bereit.');
  const [error, setError] = React.useState<string | null>(null);
  const [outdoorMode, setOutdoorMode] = React.useState<boolean>(() => readLocalStorage('stm.outdoorMode') === '1');
  const [theme, setTheme] = React.useState<'dark' | 'light'>(() => readLocalStorage('stm.theme') === 'light' ? 'light' : 'dark');
  const [lastBackupAt, setLastBackupAt] = React.useState<string | null>(null);
  const [backupRecommended, setBackupRecommended] = React.useState<boolean>(false);
  const [activeMainTab, setActiveMainTab] = React.useState<MainTab>(() => {
    const stored = readLocalStorage('stm.activeMainTab');
    return isMainTab(stored) ? stored : 'overview';
  });
  const [activeRoundNumber, setActiveRoundNumber] = React.useState<number | null>(null);
  const auditJournalRecentEntries = auditJournal.slice(0, 15);
  const auditJournalWarningCount = auditJournal.filter(entry => auditSeverityKey(entry.severity) === 'warning').length;
  const auditJournalCriticalCount = auditJournal.filter(entry => auditSeverityKey(entry.severity) === 'critical').length;
  const auditJournalInfoCount = auditJournal.length - auditJournalWarningCount - auditJournalCriticalCount;
  const auditJournalRoundEntryCount = auditJournal.filter(entry => entry.roundNumber !== null && entry.roundNumber !== undefined).length;
  const auditJournalPlayerEntryCount = auditJournal.filter(entry => Boolean(entry.playerId || entry.playerName)).length;
  const visiblePlayers = (selectedTournament?.players ?? []).filter(player => {
    const query = participantSearch.trim().toLocaleLowerCase();
    if (!query) {
      return true;
    }
    return [player.name, player.club, player.fideId, player.nationalId]
      .some(value => value?.toLocaleLowerCase().includes(query));
  });

  const setSelectedId = React.useCallback((id: string) => {
    if (projectionLoader.disposed) return;
    if (projectionLoader.select(id)) {
      playerEditorGuard.select(id); pairingEditorGuard.select(id);
      settingsEditorGuard.select(id); chess960Guard.select(id);
      cancelBackupImport();
      setEditingPlayerId(null); setPlayerForm(emptyPlayerForm); setPairingEdits({});
      setExternalDuplicateChecks({});
      importPreviewGuard.update({ ...importPreviewGuard.inputs, tournamentId: id });
      setImportPreview(null); setConfirmWarningImport(false);
      setPairingQualityReports({}); setNextRoundPreview(null); setIsNextRoundPreviewDialogOpen(false);
      closeChess960Dialog(); setPendingResultChange(null); setLastResultChange(null); setBoardDiceModal(null);
      setActionConfirm(null); setError(null);
    }
    setSelectedIdState(id);
  }, [projectionLoader, importPreviewGuard, playerEditorGuard, pairingEditorGuard, settingsEditorGuard, chess960Guard, backupImportGuard]);

  const [tournamentListLoader] = React.useState(() => {
    const loader = createTournamentProjectionLoader<Tournament[]>(state => {
      if (state.phase !== 'ready' || !state.data) return;
      setTournaments(state.data);
      if (!state.data.some(item => item.id === projectionLoader.selectedId)) {
        setSelectedId(state.data[0]?.id ?? '');
      }
    });
    loader.select('tournaments');
    return loader;
  });

  React.useEffect(() => {
    projectionLoader.resume(); tournamentListLoader.resume();
    return () => { projectionLoader.dispose(); tournamentListLoader.dispose(); importPreviewGuard.invalidate(); playerEditorGuard.invalidate(); pairingEditorGuard.invalidate(); settingsEditorGuard.invalidate(); chess960Guard.invalidate(); backupImportGuard.invalidate(); };
  }, [projectionLoader, tournamentListLoader, importPreviewGuard]);

  const loadTournaments = React.useCallback(async (): Promise<Tournament[] | null> => {
    let data: Tournament[] | null = null;
    const accepted = await tournamentListLoader.load('tournaments', async signal => {
      data = await requestJson<Tournament[]>('/api/tournaments', {signal});
      return data;
    });
    return accepted ? data : null;
  }, [tournamentListLoader]);

  const loadDerived = React.useCallback(async (id: string) => {
    await projectionLoader.load(id, async signal => {
      setPairingQualityReports({}); setNextRoundPreview(null); setIsNextRoundPreviewDialogOpen(false);
      const [standingData, categoryData, crossTableData, heroCupData, diagnosticsData, auditJournalData] = await Promise.all([
        requestJson<StandingRow[]>(`/api/tournaments/${id}/standings`, { signal }),
        requestJson<CategoryStandingTable[]>(`/api/tournaments/${id}/categories`, { signal }),
        requestJson<CrossTable>(`/api/tournaments/${id}/cross-table`, { signal }),
        requestJson<HeroCupRow[]>(`/api/tournaments/${id}/hero-cup`, { signal }),
        requestJson<RoundDiagnostics[]>(`/api/tournaments/${id}/round-diagnostics`, { signal }),
        requestJson<AuditJournalEntry[]>(`/api/tournaments/${id}/audit-journal`, { signal })
      ]);
      return {standings:standingData,categories:categoryData,crossTable:crossTableData,heroCup:heroCupData,diagnostics:diagnosticsData,auditJournal:auditJournalData};
    });
  }, [projectionLoader]);

  const refresh = React.useCallback(async (preferredId?: string) => {
    // A new selection has its own effect below. Starting a second derived read
    // here would cancel that first read as soon as the new list is published.
    const selectionAtStart = projectionLoader.selectedId;
    const selectionWillLoad = projectionLoader.phase === 'idle';
    const data = await loadTournaments();
    if (!data) return;
    const id = preferredId ?? projectionLoader.selectedId ?? data[0]?.id ?? '';
    if (id && !(selectionWillLoad && id === selectionAtStart)) {
      await loadDerived(id);
    }
  }, [loadDerived, loadTournaments, projectionLoader]);

  // Startbereitschaft: begrenzter Retry mit wachsender Wartezeit, danach ein
  // ruhiger Takt. Kein Dauerpolling und keine Endlosschleife - die Wartezeiten
  // kommen aus `backendReadiness`, damit die Abfolge ohne Browser testbar ist.
  React.useEffect(() => {
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let failedAttempts = 0;

    async function probe(): Promise<void> {
      let succeeded = false;
      try {
        const current = await requestJson<Health>('/api/health', { timeoutMs: healthProbeTimeoutMs });
        if (cancelled) {
          return;
        }
        succeeded = true;
        setHealth(current);
      } catch (ex) {
        if (cancelled) {
          return;
        }
        // Technische Ursache bleibt in der Konsole, die Oberflaeche bekommt den
        // Bereitschaftshinweis - dort steht kein Host und kein Port.
        console.warn('Bereitschaftspruefung des lokalen Backends fehlgeschlagen.', ex);
        setHealth(null);
      }

      failedAttempts = succeeded ? 0 : failedAttempts + 1;
      const readiness = readinessAfterProbe(succeeded, failedAttempts);
      setBackendReadiness(readiness);

      if (succeeded) {
        try {
          await loadTournaments();
          // Retry only a failed read, using this existing healthy-poll cadence.
          // Ready/loading projections and all editor drafts stay untouched.
          if (!cancelled && projectionLoader.phase === 'error' && projectionLoader.selectedId) {
            await loadDerived(projectionLoader.selectedId).catch(() => {
              // The atomic loader publishes its own visible error/retry state.
            });
          }
        } catch (ex) {
          if (!cancelled) {
            setError(describeApiError(ex, lang));
          }
        }
      }

      if (!cancelled) {
        timer = setTimeout(() => { void probe(); }, succeeded ? steadyProbeIntervalMs : nextProbeDelayMs(failedAttempts));
      }
    }

    void probe();
    return () => {
      cancelled = true;
      if (timer) {
        clearTimeout(timer);
      }
    };
  }, [loadTournaments, loadDerived, projectionLoader, lang, readinessProbeGeneration]);

  async function retryDerivedProjection(): Promise<void> {
    const id = selectedTournament?.id;
    if (!id || projectionLoader.selectedId !== id || projectionLoader.phase !== 'error') return;
    // load() marks itself loading synchronously, before another click can run.
    await loadDerived(id).catch(() => {
      // Keep projection failures separate from unrelated action errors.
      // Its localized status and retry control remain visible on failure.
    });
  }
  /** "Erneut versuchen" - neuer Startversuch ohne Browserneustart. */
  function retryBackendReadiness(): void {
    setBackendReadiness('starting');
    setError(null);
    setReadinessProbeGeneration(previous => previous + 1);
  }

  /**
   * Einheitlicher Fehlerausgang fuer jede Bedienaktion.
   *
   * Jede scheiternde Aktion muss sichtbar werden. Vorher endeten mehrere
   * `async`-Handler ohne `catch`: der Fehler wurde zu einer unbehandelten
   * Promise-Ablehnung, die Oberflaeche blieb unveraendert und die Schaltflaeche
   * wirkte tot. Bei einem Transportfehler wird zusaetzlich der Backend-Chip
   * ehrlich gemacht, statt weiter "online" zu behaupten.
   */
  async function confirmActionDialog(): Promise<void> {
    if (!actionConfirm || actionConfirmBusy || actionConfirmInFlight.current) {
      return;
    }

    const pending = actionConfirm;
    actionConfirmInFlight.current = pending;
    setActionConfirmBusy(true);
    try {
      await pending.run();
    } finally {
      if (actionConfirmInFlight.current === pending) {
        actionConfirmInFlight.current = null;
        setActionConfirmBusy(false);
      }
      setActionConfirm(current => current === pending ? null : current);
    }
  }

  function reportActionFailure(label: string, ex: unknown): void {
    setError(`${label}: ${describeApiError(ex, lang)}`);
    if (isApiTransportError(ex)) {
      setHealth(null);
      setBackendReadiness('unreachable');
    }
  }

  React.useEffect(() => {
    if (!('serviceWorker' in navigator)) {
      setPwaStatus('unsupported');
      return undefined;
    }

    let isCancelled = false;
    const beforeInstallPrompt = (event: Event) => {
      event.preventDefault();
      setPwaInstallPrompt(event as BeforeInstallPromptEvent);
      setPwaStatus('installable');
    };
    const appInstalled = () => {
      setPwaInstallPrompt(null);
      setPwaStatus('installed');
    };

    window.addEventListener('beforeinstallprompt', beforeInstallPrompt);
    window.addEventListener('appinstalled', appInstalled);

    navigator.serviceWorker.register('/service-worker.js')
      .then(registration => {
        if (isCancelled) {
          return;
        }

        if (registration.waiting) {
          setPwaStatus('update-available');
        } else {
          setPwaStatus(isStandaloneDisplayMode() ? 'installed' : 'ready');
        }

        registration.addEventListener('updatefound', () => {
          const installing = registration.installing;
          installing?.addEventListener('statechange', () => {
            if (installing.state === 'installed' && navigator.serviceWorker.controller) {
              setPwaStatus('update-available');
            }
          });
        });
      })
      .catch((err: unknown) => {
        console.warn(t('workflow.couldNotRegisterThePWAServiceWorker'), err);
        if (!isCancelled) {
          setPwaStatus('error');
        }
      });

    return () => {
      isCancelled = true;
      window.removeEventListener('beforeinstallprompt', beforeInstallPrompt);
      window.removeEventListener('appinstalled', appInstalled);
    };
  }, []);

  React.useEffect(() => {
    if (selectedTournament?.id) {
      loadDerived(selectedTournament.id).catch(() => {
        // Projection errors have their own localized status and retry control.
      });
    }
  }, [loadDerived, selectedTournament?.id, JSON.stringify(selectedTournament)]);

  React.useEffect(() => {
    const next = settingsToForm(selectedTournament);
    const previous = settingsSource.current;
    const id = selectedTournament?.id ?? '';
    setSettingsForm(current => previous.id !== id || JSON.stringify(current) === JSON.stringify(previous.form) ? next : current);
    settingsSource.current = { id, form: next };
  }, [selectedTournament?.id, JSON.stringify(selectedTournament?.settings)]);

  React.useEffect(() => {
    // A new or closed confirmation never inherits the reason typed for another board.
    setCorrectionReason('');
    if (!pendingResultChange) {
      return;
    }
    window.requestAnimationFrame(() => {
      resultConfirmButtonRef.current?.scrollIntoView({ block: 'center', behavior: 'smooth' });
      resultConfirmButtonRef.current?.focus();
    });
  }, [pendingResultChange]);

  React.useEffect(() => {
    writeLocalStorage('stm.outdoorMode', outdoorMode ? '1' : '0');
  }, [outdoorMode]);

  React.useEffect(() => {
    writeLocalStorage('stm.theme', theme);
  }, [theme]);

  React.useEffect(() => {
    writeLocalStorage('stm.activeMainTab', activeMainTab);
  }, [activeMainTab]);

  // Hält den aktiven Runden-Unterreiter immer auf eine real existierende Runde.
  // Greift nach Reset/Delete (keine Runden → null) und beim Turnierwechsel.
  React.useEffect(() => {
    const rounds = selectedTournament?.rounds ?? [];
    if (rounds.length === 0) {
      if (activeRoundNumber !== null) {
        setActiveRoundNumber(null);
      }
      return;
    }

    const exists = rounds.some(round => round.roundNumber === activeRoundNumber);
    if (!exists) {
      setActiveRoundNumber(rounds[rounds.length - 1].roundNumber);
    }
  }, [selectedTournament?.id, selectedTournament?.rounds.length, activeRoundNumber]);

  React.useEffect(() => {
    if (!selectedTournament?.id) {
      setLastBackupAt(null);
      setBackupRecommended(false);
      return;
    }
    setLastBackupAt(readLocalStorage(`stm.lastBackup.${selectedTournament.id}`));
    setBackupRecommended(false);
  }, [selectedTournament?.id]);

  React.useEffect(() => {
    setPairingQualityReports({});
    setNextRoundPreview(null);
    setIsNextRoundPreviewDialogOpen(false);
    closeChess960Dialog();
    setPendingResultChange(null);
    setLastResultChange(null);
  }, [selectedTournament?.id]);

  React.useEffect(() => {
    writeLocalStorage('stm.laptopIp', laptopIp);
  }, [laptopIp]);

  React.useEffect(() => {
    if (!isNextRoundPreviewDialogOpen && !chess960DialogRound && !boardDiceModal) {
      return undefined;
    }

    function closeOnEscape(event: KeyboardEvent): void {
      if (event.key === 'Escape') {
        setIsNextRoundPreviewDialogOpen(false);
        closeChess960Dialog();
        setBoardDiceModal(null);
      }
    }

    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [isNextRoundPreviewDialogOpen, chess960DialogRound, boardDiceModal]);

  async function installPwa(): Promise<void> {
    if (!pwaInstallPrompt) {
      setStatus(t('workflow.theBrowserDoesNotCurrentlyOfferAn'));
      return;
    }

    try {
      await pwaInstallPrompt.prompt();
      const choice = await pwaInstallPrompt.userChoice;
      setPwaInstallPrompt(null);
      setPwaStatus(choice.outcome === 'accepted' ? 'installed' : 'ready');
      setStatus(choice.outcome === 'accepted' ? 'PWA-Installation gestartet.' : 'PWA-Installation abgebrochen.');
    } catch (ex) {
      setError(describeApiError(ex, lang));
      setPwaStatus('error');
    }
  }

  async function createTournament(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    // Der Zustandswert alleine reicht nicht: React verarbeitet zwei Submits aus
    // demselben Ereigniszyklus, bevor das Re-Render die Schaltflaeche sperrt.
    if (creatingTournament || createTournamentInFlight.current) {
      return;
    }
    createTournamentInFlight.current = true;
    setCreatingTournament(true);
    setError(null);
    try {
      const created = await requestJson<Tournament>('/api/tournaments', {
        method: 'POST',
        body: JSON.stringify({
          name: newTournamentName.trim(),
          settings: {
            ...formToSettings(newTournamentSettingsForm),
            format,
            pairingStrategy: format === 1 ? pairingStrategy : 0,
            swissInitialColour: format === 1 && pairingStrategy === 1 ? swissInitialColour : 1
          }
        })
      });
      setSelectedId(created.id);
      setIsCreateTournamentOpen(false);
      setActiveMainTab('overview');
      setStatus(lang === 'en' ? `Tournament created: ${created.name}` : t('workflow.tournamentCreated', { p0: created.name }));
      await refresh(created.id);
    } catch (ex) {
      reportActionFailure(lang === 'en' ? 'Tournament could not be created' : t('workflow.couldNotCreateTournament'), ex);
    } finally {
      createTournamentInFlight.current = false;
      setCreatingTournament(false);
    }
  }

  async function createDemoTournament(): Promise<void> {
    const existing = tournaments.find(isBuildWeekDemoTournament);
    if (existing) {
      // Never delete silently: rounds and results entered into the demo stay intact.
      // Resetting is the separate, confirmed delete action followed by a new demo.
      setError(null);
      setSelectedId(existing.id);
      setIsCreateTournamentOpen(false);
      setActiveMainTab('overview');
      setStatus(lang === 'en'
        ? 'The existing synthetic demo was opened unchanged. To start over, delete it (with confirmation) and create the demo again.'
        : t('workflow.openedTheExistingSyntheticDemoWithoutChanges'));
      return;
    }

    setDemoBusy(true);
    setError(null);
    setStatus(lang === 'en' ? 'Creating the synthetic demo locally …' : t('workflow.creatingASyntheticDemoLocally'));
    let createdDemoId: string | null = null;
    try {
      const created = await requestJson<Tournament>('/api/tournaments', {
        method: 'POST',
        body: JSON.stringify({
          name: buildWeekDemoName,
          settings: {
            ...formToSettings(emptySettingsForm),
            format: 1,
            plannedRounds: 3,
            pairingStrategy: 1,
            swissInitialColour: 1
          }
        })
      });
      createdDemoId = created.id;

      const ratings = [2010, 1930, 1850, 1770, 1690, 1610, 1530, 1450];
      for (const [index, rating] of ratings.entries()) {
        await requestJson<Player>(`/api/tournaments/${created.id}/players`, {
          method: 'POST',
          body: JSON.stringify({
          name: `Demo Player ${String(index + 1).padStart(2, '0')}`,
          club: index % 2 === 0 ? 'Example Knights' : 'Sample Rooks',
          federation: 'SYN',
          country: 'XX',
          birthYear: 1988 + index,
          gender: 0,
          elo: rating,
          rapidElo: null,
          blitzElo: null,
          dwz: null,
          dwzIndex: null,
          manualTwz: null,
          fideId: null,
          nationalId: null,
          title: null,
          status: 0,
          notes: buildWeekDemoMarker,
          startingRank: null
          })
        });
      }

      const firstRound = await requestJson<TournamentRound>(`/api/tournaments/${created.id}/pairings/next-round`, { method: 'POST', timeoutMs: pairingRequestTimeoutMs });
      const demoResults = [1, 2, 3, 1];
      for (const [index, pairing] of firstRound.pairings.filter(pairing => !pairing.isBye).entries()) {
        await requestJson<TournamentRound>(`/api/tournaments/${created.id}/results`, {
          method: 'POST',
          body: JSON.stringify({
            roundNumber: firstRound.roundNumber,
            boardNumber: pairing.boardNumber,
            result: demoResults[index % demoResults.length]
          })
        });
      }

      setSelectedId(created.id);
      setIsCreateTournamentOpen(false);
      setActiveMainTab('overview');
      await refresh(created.id);
      setStatus(lang === 'en'
        ? 'Demo ready: eight synthetic players, one completed round and FIDE Dutch. The next round is ready to pair.'
        : t('workflow.demoReadyEightSyntheticPlayersOneCompleted'));
    } catch (ex) {
      if (createdDemoId) {
        try {
          await requestJson<{ deleted: boolean }>(`/api/tournaments/${createdDemoId}`, { method: 'DELETE' });
        } catch {
          // Keep the original failure visible. A partial demo can still be removed in Administration.
        }
      }
      setError(`${lang === 'en' ? 'The demo could not be created completely' : t('workflow.couldNotFinishCreatingTheDemoTournament')}: ${describeApiError(ex, lang)}`);
    } finally {
      setDemoBusy(false);
    }
  }

  async function saveSettings(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedTournament) {
      return;
    }

    const operation = settingsEditorGuard.advance(settingsEditorToken);
    if (!operation || operation.tournamentId !== selectedTournament.id) return;
    setSettingsForm(current => ({ ...current }));
    setError(null);
    try {
      const updated = await requestJson<Tournament>(`/api/tournaments/${selectedTournament.id}/settings`, {
        method: 'PUT',
        body: JSON.stringify({ settings: formToSettings(settingsForm) })
      });
      if (!settingsEditorGuard.isCurrent(operation)) return;
      setSettingsForm(settingsToForm(updated));
      setStatus(lang === 'en' ? 'Tournament settings saved. Standings and tie-breaks recalculated.' : 'Turniereinstellungen gespeichert. Tabelle und Wertungen wurden neu berechnet.');
      await refresh(updated.id);
    } catch (ex) {
      if (settingsEditorGuard.isCurrent(operation)) reportActionFailure(t('workflow.couldNotSaveTournamentSettings'), ex);
    }
  }

  function updateSettingsForm(form: SettingsForm): void {
    if (settingsEditorGuard.advance(settingsEditorToken)) setSettingsForm(form);
  }

  function openDestructiveDialog(action: DestructiveAction): void {
    if (!selectedTournament) {
      return;
    }

    setDestructiveDialog({
      action,
      tournamentId: selectedTournament.id,
      tournamentName: selectedTournament.name,
      busy: false,
      error: null
    });
  }

  function closeDestructiveDialog(): void {
    setDestructiveDialog(current => (current && current.busy ? current : null));
  }

  async function confirmDestructiveDialog(): Promise<void> {
    if (!canDispatchDestructiveAction(destructiveDialog)) {
      return;
    }

    const pending = destructiveDialog!;
    setDestructiveDialog({ ...pending, busy: true, error: null });
    setError(null);

    try {
      if (pending.action === 'reset') {
        const updated = await requestJson<Tournament>(`/api/tournaments/${pending.tournamentId}/reset`, { method: 'POST' });
        setNextRoundPreview(null);
        setIsNextRoundPreviewDialogOpen(false);
        closeChess960Dialog();
        setPairingQualityReports({});
        setDestructiveDialog(null);
        setStatus(t('workflow.tournamentResetParticipantsAndSettingsWereKept', { p0: updated.name }));
        await refresh(updated.id);
        return;
      }

      await requestJson<{ deleted: boolean; id: string }>(`/api/tournaments/${pending.tournamentId}`, { method: 'DELETE' });
      setNextRoundPreview(null);
      setIsNextRoundPreviewDialogOpen(false);
      closeChess960Dialog();
      setPairingQualityReports({});
      setDestructiveDialog(null);
      setStatus(t('workflow.tournamentDeleted', { p0: pending.tournamentName }));

      const data = await loadTournaments();
      if (!data) return;
      const nextId = selectNextTournamentId(data, pending.tournamentId, projectionLoader.selectedId);
      setSelectedId(nextId);
      await loadDerived(nextId);
    } catch (ex) {
      const message = describeApiError(ex, lang);
      const prefix = pending.action === 'reset' ? t('workflow.resetFailed') : t('workflow.deleteFailed');
      // Keep the dialog open so the operator sees the backend error in context
      // instead of losing it behind a closed modal.
      setDestructiveDialog({ ...pending, busy: false, error: `${prefix}: ${message}` });
    }
  }

  function toggleTiebreak(value: number, enabled: boolean): void {
    if (!settingsEditorGuard.advance(settingsEditorToken)) return;
    setSettingsForm(previous => {
      const without = previous.tiebreaks.filter(item => item !== value);
      const next = enabled ? [...without, value] : without;
      return { ...previous, tiebreaks: next.length === 0 ? [99] : next };
    });
  }

  async function savePlayer(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!selectedTournament) {
      return;
    }

    const operation = playerEditorGuard.advance(playerEditorToken);
    if (!operation || operation.tournamentId !== selectedTournament.id) return;
    // Refresh rendered tokens even when clearing an already-null error bails out.
    setPlayerForm(current => ({ ...current }));
    setError(null);
    const existing = editingPlayerId ? selectedTournament.players.find(player => player.id === editingPlayerId) : undefined;
    const body = JSON.stringify(formToRequest(playerForm, existing?.startingRank));
    try {
      if (editingPlayerId) {
        await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players/${editingPlayerId}`, { method: 'PUT', body });
        if (!playerEditorGuard.isCurrent(operation)) return;
        setStatus(lang === 'en' ? 'Participant updated.' : 'Teilnehmer aktualisiert.');
      } else {
        await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players`, { method: 'POST', body });
        if (!playerEditorGuard.isCurrent(operation)) return;
        setStatus(lang === 'en' ? 'Participant saved.' : 'Teilnehmer gespeichert.');
      }

      playerEditorGuard.invalidate();
      setPlayerForm(emptyPlayerForm);
      setEditingPlayerId(null);
      await refresh(selectedTournament.id);
    } catch (ex) {
      if (playerEditorGuard.isCurrent(operation)) setError(describeApiError(ex, lang));
    }
  }

  async function deleteOrWithdrawPlayer(player: Player) {
    if (!selectedTournament) {
      return;
    }

    const captured = projectionLoader.capture(selectedTournament.id);
    const editor = playerEditorToken;
    if (!captured) return;
    setError(null);
    try {
      await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players/${player.id}`, { method: 'DELETE' });
      if (!projectionLoader.isCurrent(captured)) return;
      setStatus(t('workflow.participantDeletedOrWithdrawn'));
      if (editingPlayerId === player.id && playerEditorGuard.isCurrent(editor)) {
        playerEditorGuard.invalidate();
        setEditingPlayerId(null);
        setPlayerForm(emptyPlayerForm);
      }
      await refresh(selectedTournament.id);
    } catch (ex) {
      if (projectionLoader.isCurrent(captured)) reportActionFailure(t('workflow.couldNotRemoveParticipant', { p0: player.name }), ex);
    }
  }

  async function setPlayerStatus(player: Player, newStatus: number) {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    try {
      await requestJson<Player>(`/api/tournaments/${selectedTournament.id}/players/${player.id}/status`, {
        method: 'PATCH',
        body: JSON.stringify({ status: newStatus })
      });
      setStatus(t('workflow.statusChangedFor', { p0: player.name }));
      await refresh(selectedTournament.id);
    } catch (ex) {
      reportActionFailure(t('workflow.couldNotChangeStatusFor', { p0: player.name }), ex);
    }
  }

  async function previewNextRound() {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    const captured = projectionLoader.capture(selectedTournament.id);
    if (!captured) return;
    try {
      const preview = await requestJson<NextRoundPreview>(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round`, { timeoutMs: pairingRequestTimeoutMs, signal: captured.signal });
      if (!projectionLoader.isCurrent(captured)) return;
      setNextRoundPreview(preview);
      setIsNextRoundPreviewDialogOpen(true);
      setStatus(lang === 'en'
        ? `Pairing preview for round ${preview.roundNumber}: ${preview.pairingQuality.qualityScore}/100 · ${pairingQualitySeverityLabel(preview.pairingQuality.severity, true)}.`
        : t('workflow.roundPairingPreview100', { p0: preview.roundNumber, p1: preview.pairingQuality.qualityScore, p2: pairingQualitySeverityLabel(preview.pairingQuality.severity) }));
    } catch (ex) {
      if (!projectionLoader.isCurrent(captured)) return;
      reportActionFailure(lang === 'en' ? 'Pairing preview failed' : 'Auslosungsvorschau fehlgeschlagen', ex);
    }
  }
  function generateRound(): void {
    if (!selectedTournament) {
      return;
    }

    // Kein window.confirm: Firefox darf wiederholte native Dialoge desselben
    // Skriptdurchlaufs unterdruecken - dann loest "Runde auslosen" still nichts
    // aus. Die Rueckfrage laeuft darum ueber den In-App-Dialog.
    if (nextRoundPreview?.pairingQuality.hasCriticalIssues) {
      setActionConfirm({
        title: lang === 'en' ? 'Pair the round despite critical findings?' : t('workflow.pairTheRoundDespiteCriticalNotices'),
        description: lang === 'en'
          ? 'The preview contains critical findings. In small tournaments, rematches or score-group deviations may be unavoidable.'
          : t('workflow.thePreviewContainsCriticalNoticesRematchesOr'),
        consequences: nextRoundPreview.pairingQuality.findings.slice(0, 5),
        confirmLabel: t('safety.pairAnyway'),
        cancelLabel: t('common.cancel'),
        run: pairNextRound
      });
      return;
    }

    void pairNextRound();
  }

  async function pairNextRound(): Promise<void> {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    try {
      const created = await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/pairings/next-round`, { method: 'POST', timeoutMs: pairingRequestTimeoutMs });
      setStatus(lang === 'en' ? 'New round paired. Tip: create a local backup now.' : t('workflow.newRoundPairedExportALocalBackup'));
      setBackupRecommended(true);
      setNextRoundPreview(null);
      setIsNextRoundPreviewDialogOpen(false);
      setActiveRoundNumber(created.roundNumber);
      setActiveMainTab('rounds');
      await refresh(selectedTournament.id);
    } catch (ex) {
      setError(describeApiError(ex, lang));
    }
  }

  function openBoardDice(roundNumber: number, boardNumber: number) {
    setBoardDiceModal({ roundNumber, boardNumber });
    setBoardDiceTab('browser');
    setDiceUrlCopied(false);
  }

  function openChess960Dice(round: TournamentRound) {
    if (!selectedTournament) return;
    const token = chess960Guard.advance(chess960EditorToken);
    if (!token) return;
    // Aktuellsten Rundenstand aus dem geladenen Turnier nehmen (zeigt vorhandene Stellungen).
    const freshRound = selectedTournament?.rounds.find(item => item.roundNumber === round.roundNumber) ?? round;
    setChess960DialogToken(token);
    setChess960DialogRound(freshRound);
    setChess960Rolling(false);
    setChess960HasRolled(false);
  }

  function closeChess960Dialog(): void {
    chess960Guard.invalidate();
    setChess960DialogToken(null);
    setChess960DialogRound(null);
    setChess960Rolling(false);
    setActionConfirm(null);
  }

  function performChess960Roll(round: TournamentRound): void {
    const token = chess960DialogToken;
    if (!selectedTournament || chess960Rolling || !chess960Guard.isCurrent(token)
        || token.tournamentId !== selectedTournament.id) {
      return;
    }

    const existingCount = round.pairings.filter(pairing => pairing.chess960StartPosition).length;
    if (existingCount > 0) {
      setActionConfirm({
        title: t('workflow.replaceExistingStartingPositions'),
        description: t('workflow.roundAlreadyHasSavedStartingPositionS', { p0: round.roundNumber, p1: existingCount }),
        consequences: [t('workflow.allExistingChess960StartingPositionsForThis')],
        confirmLabel: t('workflow.replace'),
        cancelLabel: 'Abbrechen',
        destructive: true,
        onCancel: () => {
          const next = chess960Guard.advance(token);
          if (next) setChess960DialogToken(next);
        },
        run: () => rollChess960(round, true, token)
      });
      return;
    }

    void rollChess960(round, false, token);
  }

  async function rollChess960(round: TournamentRound, hasExistingPositions: boolean, token = chess960DialogToken): Promise<void> {
    if (!selectedTournament || chess960Rolling) {
      return;
    }
    const operation = chess960Guard.advance(token);
    if (!operation || operation.tournamentId !== selectedTournament.id) return;

    setError(null);
    setChess960DialogToken(operation);
    setChess960Rolling(true);
    setDiceSpin(previous => previous + 1);

    // Sichtbare Wurfanimation; die gültige Stellung kommt anschließend vom validierten Backend-Service.
    const animation = new Promise<void>(resolve => setTimeout(resolve, 1250));
    try {
      const rollRequest = requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/chess960/start-positions`, {
        method: 'POST',
        body: JSON.stringify({ overwriteExisting: hasExistingPositions })
      });
      const [updated] = await Promise.all([rollRequest, animation]);
      if (!chess960Guard.isCurrent(operation)) return;
      setDiceFace(Math.floor(Math.random() * diceFaceGlyphs.length));
      setChess960DialogRound(updated);
      setChess960HasRolled(true);
      setBackupRecommended(true);
      setStatus(t('workflow.chess960StartingPositionsRolledForRoundExport', { p0: updated.roundNumber }));
      await refresh(selectedTournament.id);
    } catch (ex) {
      if (chess960Guard.isCurrent(operation)) setError(describeApiError(ex, lang));
    } finally {
      if (chess960Guard.isCurrent(operation)) setChess960Rolling(false);
    }
  }

  async function recordResult(tournamentId: string, roundNumber: number, boardNumber: number, result: number, expectedPreviousResult: number,
    captured?: QueuedResultEntry): Promise<'saved' | 'queued' | false> {
    if (!selectedTournament || selectedTournament.id !== tournamentId) {
      setError(lang === 'en'
        ? 'The selected tournament changed. Reload the board and confirm the result again.'
        : t('workflow.theSelectedTournamentHasChangedReloadThe'));
      return false;
    }
    setError(null);
    setStatus(lang === 'en'
      ? `Saving result for round ${roundNumber}, board ${boardNumber} …`
      : t('workflow.savingResultForRoundBoard', { p0: roundNumber, p1: boardNumber }));
    let persisted = false;
    let sent = false;
    try {
      const pairing = selectedTournament.rounds.find(round => round.roundNumber === roundNumber)?.pairings.find(pair => pair.boardNumber === boardNumber);
      if (!pairing) throw new Error(lang === 'en' ? 'Board no longer exists.' : t('workflow.theBoardNoLongerExists'));
      const entry = captured ?? captureResultEntry(tournamentId, selectedTournament.resultQueueEpoch, roundNumber, pairing, result, expectedPreviousResult);
      if (localQueueEnabled) {
        await resultQueueStore.add(entry);
        persisted = true;
        window.dispatchEvent(new Event('stm-result-queue-changed'));
      }
      await requestJson<TournamentRound>(`/api/tournaments/${tournamentId}/queued-results`, {
        method: 'POST',
        body: JSON.stringify(entry.mutation)
      });
      sent = true;
      if (persisted) { await resultQueueStore.remove(entry.id); window.dispatchEvent(new Event('stm-result-queue-changed')); }
      await refresh(tournamentId);
      setStatus(lang === 'en'
        ? `✓ Result saved: round ${roundNumber}, board ${boardNumber}.`
        : t('workflow.resultSavedRoundBoard', { p0: roundNumber, p1: boardNumber }));
      return 'saved';
    } catch (ex) {
      if (persisted && !sent && isApiTransportError(ex)) {
        setStatus(lang === 'en' ? 'Result queued in this browser. Synchronize it when the server is available; it is not yet confirmed.'
          : t('workflow.resultKeptInThisBrowserSyncWhen'));
        return 'queued';
      }
      if (sent) setStatus(lang === 'en' ? 'Server acknowledged the result. Reload before entering it again.' : t('workflow.theServerConfirmedTheResultReloadBefore'));
      setError(`${lang === 'en' ? `Result for round ${roundNumber}, board ${boardNumber} could not be saved` : t('workflow.couldNOTSaveResultForRoundBoard', { p0: roundNumber, p1: boardNumber })}: ${describeApiError(ex, lang)}`);
      return false;
    }
  }

  // Corrections with a reason are sent online only (direct endpoint, guarded by the expected previous
  // result) so that the free-text reason is never persisted in browser storage.
  async function recordCorrection(tournamentId: string, roundNumber: number, boardNumber: number, result: number,
    expectedPreviousResult: number, reason: string, expectedLastChangedAt: string | null): Promise<'saved' | false> {
    if (!selectedTournament || selectedTournament.id !== tournamentId) {
      setError(lang === 'en'
        ? 'The selected tournament changed. Reload the board and confirm the result again.'
        : t('workflow.theSelectedTournamentHasChangedReloadThe'));
      return false;
    }
    setError(null);
    try {
      await requestJson<TournamentRound>(`/api/tournaments/${tournamentId}/rounds/${roundNumber}/boards/${boardNumber}/result`, {
        method: 'POST',
        // expectedLastChangedAt also detects a change that was reverted in between (A -> B -> A).
        body: JSON.stringify({ result, expectedPreviousResult, correctionReason: Array.from(reason).slice(0, 500).join(''),
          ...(expectedLastChangedAt ? { expectedLastChangedAt } : {}) })
      });
      await refresh(tournamentId);
      setStatus(t('result.correctedRoundBoard', { p0: roundNumber, p1: boardNumber }));
      return 'saved';
    } catch (ex) {
      setError(`${lang === 'en' ? `Result for round ${roundNumber}, board ${boardNumber} could not be saved` : t('workflow.couldNOTSaveResultForRoundBoard', { p0: roundNumber, p1: boardNumber })}: ${describeApiError(ex, lang)}`);
      return false;
    }
  }

  function requestResultChange(roundNumber: number, boardNumber: number, result: number, previousResult: number, source?: HTMLElement): void {
    if (!selectedTournament || result === previousResult) {
      return;
    }
    const pairing = selectedTournament.rounds.find(round => round.roundNumber === roundNumber)?.pairings
      .find(board => board.boardNumber === boardNumber);
    if (!pairing || pairing.isBye || result === 7) return;
    resultReturnFocusRef.current = source ?? null;
    try {
      setPendingResultChange({ tournamentId: selectedTournament.id, roundNumber, boardNumber, result, previousResult,
        queueEntry: captureResultEntry(selectedTournament.id, selectedTournament.resultQueueEpoch, roundNumber, pairing, result, previousResult) });
    } catch {
      setError(lang === 'en' ? 'The result could not be prepared safely. Update this browser and try again.'
        : t('workflow.couldNotSafelyPrepareTheResultReload'));
    }
  }

  function closeResultConfirmation(): void {
    setPendingResultChange(null);
    window.requestAnimationFrame(() => resultReturnFocusRef.current?.focus());
  }

  async function confirmResultChange(): Promise<void> {
    if (!pendingResultChange) {
      return;
    }
    if (resultSavingRef.current) {
      return;
    }
    resultSavingRef.current = true;
    setResultSaving(true);
    try {
      const change = pendingResultChange;
      const reason = correctionReason.trim();
      const saved = change.previousResult !== 0 && reason
        ? await recordCorrection(change.tournamentId, change.roundNumber, change.boardNumber, change.result, change.previousResult, reason,
            change.queueEntry?.mutation.expectedLastChangedAt ?? null)
        : await recordResult(change.tournamentId, change.roundNumber, change.boardNumber, change.result, change.previousResult, change.queueEntry);
      if (saved) {
        setLastResultChange(saved === 'queued' ? null : change);
        closeResultConfirmation();
      }
    } finally {
      resultSavingRef.current = false;
      setResultSaving(false);
    }
  }

  async function undoLastResultChange(): Promise<void> {
    if (!lastResultChange) {
      return;
    }
    const undo = lastResultChange;
    const saved = await recordResult(undo.tournamentId, undo.roundNumber, undo.boardNumber, undo.previousResult, undo.result);
    if (saved) {
      setLastResultChange(null);
      if (saved === 'saved') setStatus(lang === 'en'
        ? `Result correction undone: round ${undo.roundNumber}, board ${undo.boardNumber}.`
        : t('workflow.resultCorrectionUndoneRoundBoard', { p0: undo.roundNumber, p1: undo.boardNumber }));
    }
  }

  function editKey(roundNumber: number, boardNumber: number): string {
    return `${roundNumber}-${boardNumber}`;
  }

  function pairingEdit(round: TournamentRound, pairing: Pairing): PairingEdit {
    const key = editKey(round.roundNumber, pairing.boardNumber);
    return (pairingEditorGuard.isCurrent(pairingEditorToken) ? pairingEdits[key] : undefined) ?? {
      whitePlayerId: pairing.whitePlayerId ?? '',
      blackPlayerId: pairing.blackPlayerId ?? '',
      notes: pairing.notes ?? ''
    };
  }

  function updatePairingEdit(roundNumber: number, boardNumber: number, patch: Partial<PairingEdit>): void {
    if (!selectedTournament?.settings.allowManualPairingOverrides) return;
    const round = selectedTournament?.rounds.find(item => item.roundNumber === roundNumber);
    const pairing = round?.pairings.find(item => item.boardNumber === boardNumber);
    if (!round || !pairing) return;
    const edit = pairingEdit(round, pairing);
    if (!pairingEditorGuard.advance(pairingEditorToken)) return;
    const key = editKey(roundNumber, boardNumber);
    setPairingEdits(previous => ({
      ...previous,
      [key]: { ...edit, ...patch }
    }));
  }

  async function saveManualPairing(round: TournamentRound, pairing: Pairing) {
    if (!selectedTournament?.settings.allowManualPairingOverrides) {
      return;
    }
    const edit = pairingEdit(round, pairing);
    const operation = pairingEditorGuard.advance(pairingEditorToken);
    if (!operation || operation.tournamentId !== selectedTournament.id) return;
    setPairingEdits(current => ({ ...current }));
    setError(null);
    try {
      await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/boards/${pairing.boardNumber}/pairing`, {
        method: 'PUT',
        body: JSON.stringify({
          whitePlayerId: edit.whitePlayerId || null,
          blackPlayerId: edit.blackPlayerId || null,
          notes: edit.notes || null
        })
      });
      if (!pairingEditorGuard.isCurrent(operation)) return;
      setStatus(t('workflow.manualPairingSavedForRoundBoard', { p0: round.roundNumber, p1: pairing.boardNumber }));
      pairingEditorGuard.invalidate();
      setPairingEdits(previous => {
        const copy = { ...previous };
        delete copy[editKey(round.roundNumber, pairing.boardNumber)];
        return copy;
      });
      await refresh(selectedTournament.id);
    } catch (ex) {
      if (pairingEditorGuard.isCurrent(operation)) reportActionFailure(t('workflow.couldNotSavePairingForRoundBoard', { p0: round.roundNumber, p1: pairing.boardNumber }), ex);
    }
  }

  async function setRoundLock(round: TournamentRound, isLocked: boolean) {
    if (!selectedTournament) {
      return;
    }
    setError(null);
    try {
      await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/lock`, {
        method: 'PATCH',
        body: JSON.stringify({ isLocked })
      });
      setStatus(isLocked ? t('workflow.roundLocked', { p0: round.roundNumber }) : t('workflow.roundUnlocked', { p0: round.roundNumber }));
      await refresh(selectedTournament.id);
    } catch (ex) {
      reportActionFailure(t('workflow.couldNotChangeTheLockStateOf', { p0: round.roundNumber }), ex);
    }
  }

  async function setRoundVerified(round: TournamentRound, isVerified: boolean) {
    if (!selectedTournament) {
      return;
    }
    setError(null);
    try {
      await requestJson<TournamentRound>(`/api/tournaments/${selectedTournament.id}/rounds/${round.roundNumber}/verify`, {
        method: 'PATCH',
        body: JSON.stringify({ isVerified })
      });
      setStatus(isVerified ? t('workflow.roundReviewed', { p0: round.roundNumber }) : t('workflow.roundReopened', { p0: round.roundNumber }));
      await refresh(selectedTournament.id);
    } catch (ex) {
      reportActionFailure(t('workflow.couldNotChangeReviewStatusForRound', { p0: round.roundNumber }), ex);
    }
  }

  async function searchExternalPlayers(event?: React.FormEvent<HTMLFormElement>) {
    event?.preventDefault();
    setError(null);
    const query = externalQuery.trim();
    if (!query) {
      setError(t('workflow.enterANameOrAFIDEID'));
      return;
    }

    setExternalSearching(true);
    try {
      const result = await requestJson<ExternalPlayerAggregateResult>(`/api/external-players/search-all?query=${encodeURIComponent(query)}`);
      setExternalLookup(result);
      setExternalDuplicateChecks({});
      setStatus(lang === 'en' ? `${result.players.length} player(s) found. Source availability is shown below.` : result.message);
    } catch (ex) {
      setError(`${lang === 'en' ? 'Player search failed' : 'Spielersuche fehlgeschlagen'}: ${describeApiError(ex, lang)}`);
    } finally {
      setExternalSearching(false);
    }
  }

  function applyExternalPlayer(profile: ExternalPlayerProfile): void {
    if (!playerEditorGuard.advance(playerEditorToken)) return;
    setPlayerForm(applyExternalProfileToForm(profile));
    setEditingPlayerId(null);
    setStatus(t('workflow.appliedFromToTheParticipantForm', { p0: profile.name, p1: externalSourceLabel(profile.source) }));
  }

  // Findet einen bereits im aktuellen Turnier vorhandenen Teilnehmer mit gleicher FIDE-/DSB-ID.
  // Grundlage für "Bereits Teilnehmer" und das Deaktivieren von "Als neuen Teilnehmer speichern".
  function existingParticipantForProfile(profile: ExternalPlayerProfile): Player | undefined {
    if (!selectedTournament) {
      return undefined;
    }
    const normId = (value?: string | null): string => (value ? value.replace(/[^a-z0-9]/gi, '').toUpperCase() : '');
    const fide = normId(profile.fideId);
    const national = normId(profile.nationalId);
    if (!fide && !national) {
      return undefined;
    }
    return selectedTournament.players.find(player =>
      (fide && normId(player.fideId) === fide) || (national && normId(player.nationalId) === national));
  }

  function editExistingFromProfile(player: Player): void {
    if (!playerEditorGuard.advance(playerEditorToken)) return;
    setEditingPlayerId(player.id);
    setPlayerForm(playerToForm(player));
    setStatus(lang === 'en' ? `Existing participant ${player.name} loaded for editing.` : `Vorhandenen Teilnehmer ${player.name} zum Bearbeiten geladen.`);
  }

  async function checkExternalDuplicates(profile: ExternalPlayerProfile): Promise<ExternalPlayerDuplicateCheck | null> {
    if (!selectedTournament) {
      setError(t('workflow.selectATournamentFirst'));
      return null;
    }

    const captured = projectionLoader.capture(selectedTournament.id);
    if (!captured) return null;
    setError(null);
    try {
      const duplicateCheck = await requestJson<ExternalPlayerDuplicateCheck>(`/api/tournaments/${selectedTournament.id}/external-players/check-duplicates`, {
        method: 'POST',
        body: JSON.stringify({ profile })
      });
      if (!projectionLoader.isCurrent(captured)) return null;
      setExternalDuplicateChecks(previous => ({ ...previous, [externalProfileKey(profile)]: duplicateCheck }));
      setStatus(duplicateCheck.hasLikelyDuplicate
        ? t('workflow.foundPossibleDuplicateSFor', { p0: duplicateCheck.matches.length, p1: profile.name })
        : t('workflow.noReliableDuplicateFoundFor', { p0: profile.name }));
      return duplicateCheck;
    } catch (ex) {
      if (projectionLoader.isCurrent(captured)) reportActionFailure(t('workflow.duplicateCheckFailedFor', { p0: profile.name }), ex);
      return null;
    }
  }

  async function applyExternalProfile(profile: ExternalPlayerProfile, targetPlayerId?: string, overwriteExistingValues = false): Promise<void> {
    if (!selectedTournament) {
      setError(t('workflow.selectATournamentFirst'));
      return;
    }

    const operation = playerEditorGuard.advance(playerEditorToken);
    if (!operation || operation.tournamentId !== selectedTournament.id) return;
    setPlayerForm(current => ({ ...current }));
    setError(null);
    try {
      const result = await requestJson<ExternalPlayerApplyResult>(`/api/tournaments/${selectedTournament.id}/external-players/apply`, {
        method: 'POST',
        body: JSON.stringify({
          profile,
          targetPlayerId: targetPlayerId || null,
          createIfNoTarget: !targetPlayerId,
          overwriteExistingValues
        })
      });
      if (!playerEditorGuard.isCurrent(operation)) return;
      setExternalDuplicateChecks(previous => ({ ...previous, [externalProfileKey(profile)]: result.duplicateCheck }));
      playerEditorGuard.invalidate();
      setEditingPlayerId(result.player.id);
      setPlayerForm(playerToForm(result.player));
      setStatus(t('workflow.changedFields', { p0: lang === 'en' ? (result.created ? 'Participant created.' : result.updated ? 'Participant updated.' : 'Participant unchanged.') : result.message, p1: result.changedFields.length ? result.changedFields.join(', ') : t('workflow.none') }));
      await refresh(selectedTournament.id);
    } catch (ex) {
      if (playerEditorGuard.isCurrent(operation)) setError(describeApiError(ex, lang));
    }
  }

  function useSampleCsvTemplate(): void {
    updateCsvContent(sampleCsvTemplate);
    updateReplacePlayers(false);
    setImportPreview(null);
    setConfirmWarningImport(false);
    setStatus(t('workflow.cSVTemplateInsertedAdjustTheDataThen'));
  }

  function updateCsvContent(content: string): void {
    importPreviewGuard.update({ ...importPreviewGuard.inputs, content });
    setCsvContent(content); setImportPreview(null); setConfirmWarningImport(false);
  }

  function updateReplacePlayers(replaceExisting: boolean): void {
    importPreviewGuard.update({ ...importPreviewGuard.inputs, replaceExisting });
    setReplacePlayers(replaceExisting); setImportPreview(null); setConfirmWarningImport(false);
  }

  async function previewPlayersImport() {
    if (!selectedTournament) {
      setError(t('workflow.selectATournamentFirst'));
      return;
    }

    const request = importPreviewGuard.begin({ tournamentId: selectedTournament.id, content: csvContent, replaceExisting: replacePlayers });
    if (!request) return;
    setImportPreview(null); setConfirmWarningImport(false); setError(null);
    try {
      const preview = await requestJson<PlayerImportPreview>(`/api/tournaments/${request.tournamentId}/players/preview-import.csv`, {
        method: 'POST',
        body: JSON.stringify({ content: request.content, replaceExisting: request.replaceExisting }),
        signal: request.signal,
      });
      if (!importPreviewGuard.accept(request, preview)) return;
      setImportPreview(preview);
      setConfirmWarningImport(false);
      const blockerText = preview.hasBlockingIssues ? ' ' + t('workflow.blockingIssuesMustBeResolvedBeforeImport') : '';
      setStatus(t('workflow.cSVCheckedRowsImportableWarningSBlocked', { p0: preview.totalRows, p1: preview.importableRows, p2: preview.warningRows, p3: preview.blockingRows, p4: blockerText }));
    } catch (ex) {
      if (!importPreviewGuard.isCurrent(request)) return;
      reportActionFailure(t('workflow.couldNotCheckCSV'), ex);
    }
  }

  function pairingQualityFor(roundNumber: number): PairingQualityReport | undefined {
    return pairingQualityReports[roundNumber];
  }

  async function loadPairingQuality(roundNumber: number) {
    if (!selectedTournament) {
      setError(t('workflow.selectATournamentFirst'));
      return;
    }

    setError(null);
    const captured = projectionLoader.capture(selectedTournament.id);
    if (!captured) return;
    try {
      const report = await requestJson<PairingQualityReport>(`/api/tournaments/${selectedTournament.id}/rounds/${roundNumber}/pairing-quality`, { signal: captured.signal });
      if (!projectionLoader.isCurrent(captured)) return;
      setPairingQualityReports(previous => ({ ...previous, [roundNumber]: report }));
      setStatus(lang === 'en'
        ? `Pairing quality for round ${roundNumber}: ${report.qualityScore}/100 · ${pairingQualitySeverityLabel(report.severity, true)}.`
        : t('workflow.pairingQualityForRound100', { p0: roundNumber, p1: report.qualityScore, p2: pairingQualitySeverityLabel(report.severity) }));
    } catch (ex) {
      if (!projectionLoader.isCurrent(captured)) return;
      reportActionFailure(t('workflow.couldNotLoadPairingQualityForRound', { p0: roundNumber }), ex);
    }
  }
  async function importPlayers() {
    if (!selectedTournament) {
      return;
    }

    const identity = { tournamentId: selectedTournament.id, content: csvContent, replaceExisting: replacePlayers };
    if (!importPreview || !importPreviewGuard.matches(identity, importPreview)) {
      setError(t('workflow.checkTheCSVFirst'));
      return;
    }

    if (importPreview.replaceExisting !== replacePlayers) {
      setError(t('workflow.theImportOptionHasChangedSinceThe'));
      return;
    }

    if (importPreview.hasBlockingIssues) {
      setError(t('workflow.theCSVContainsBlockingIssuesCorrectThem'));
      return;
    }

    if (importPreview.warningRows > 0 && !confirmWarningImport) {
      setError(t('workflow.theCSVContainsWarningsOrPossibleDuplicates'));
      return;
    }

    setError(null);
    // Consume before dispatch: double clicks and older preview replies cannot
    // authorize a second import. The payload below is the validated snapshot.
    importPreviewGuard.invalidate();
    setImportPreview(null); setConfirmWarningImport(false);
    const selection = projectionLoader.capture(identity.tournamentId);
    try {
      const imported = await requestJson<Player[]>(`/api/tournaments/${identity.tournamentId}/players/import.csv`, {
        method: 'POST',
        body: JSON.stringify({ content: identity.content, replaceExisting: identity.replaceExisting })
      });
      if (!selection || !projectionLoader.isCurrent(selection)) return;
      setStatus(lang === 'en' ? `${imported.length} participant(s) imported.` : `${imported.length} Teilnehmer importiert.`);
      await refresh(identity.tournamentId);
    } catch (ex) {
      if (!selection || !projectionLoader.isCurrent(selection)) return;
      reportActionFailure(lang === 'en' ? 'Participant import failed' : 'Teilnehmerimport fehlgeschlagen', ex);
    }
  }

  async function exportPlayers() {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    try {
      const csv = await requestText(`/api/tournaments/${selectedTournament.id}/players/export.csv`);
      downloadText(`${selectedTournament.name}-teilnehmer.csv`, csv, 'text/csv;charset=utf-8');
      setStatus(lang === 'en' ? 'Participant list exported as CSV.' : 'Teilnehmerliste als CSV exportiert.');
    } catch (ex) {
      reportActionFailure(lang === 'en' ? 'Participant export failed' : 'Teilnehmerexport fehlgeschlagen', ex);
    }
  }

  // STM-IE-002: Datei als Bytes lesen (nicht als Text), damit der Server echte
  // UTF-8-/Windows-1252-Erkennung durchfuehren kann statt einer vom Browser geratenen Dekodierung.
  async function importPlayerFile(file: File, endpoint: string) {
    if (!selectedTournament) {
      return;
    }

    setError(null);
    try {
      const buffer = await file.arrayBuffer();
      const bytes = new Uint8Array(buffer);
      let binary = '';
      for (let i = 0; i < bytes.length; i++) {
        binary += String.fromCharCode(bytes[i]);
      }
      const base64 = btoa(binary);

      const outcome = await requestJson<{ added: Player[]; formatErrors: string[] }>(
        `/api/tournaments/${selectedTournament.id}/${endpoint}`,
        { method: 'POST', body: JSON.stringify({ fileBytes: base64, replaceExisting: replacePlayers }) }
      );
      setFormatImportResult({ added: outcome.added.length, errors: outcome.formatErrors });
      setStatus(lang === 'en'
        ? `${outcome.added.length} participant(s) imported${outcome.formatErrors.length > 0 ? ` · ${outcome.formatErrors.length} notice(s)` : ''}.`
        : `${outcome.added.length} Teilnehmer importiert${outcome.formatErrors.length > 0 ? ` · ${outcome.formatErrors.length} Hinweis(e)` : ''}.`);
      await refresh(selectedTournament.id);
    } catch (ex) {
      reportActionFailure(t('workflow.couldNotImportFile', { p0: file.name }), ex);
    }
  }

  function openNextRoundPreviewCsv() {
    if (!selectedTournament) {
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round/export.csv`, '_blank', 'noopener,noreferrer');
  }

  function openNextRoundPreviewPrint() {
    if (!selectedTournament) {
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/preview-next-round/print/html`, '_blank', 'noopener,noreferrer');
  }

  function openTournamentExport(path: string) {
    if (!selectedTournament) {
      return;
    }

    window.open(`/api/tournaments/${selectedTournament.id}/${path}`, '_blank', 'noopener,noreferrer');
  }

  function openExportManifest(): void {
    openTournamentExport('exports/manifest.json');
  }

  function latestRoundNumber(): number | null {
    if (!selectedTournament || selectedTournament.rounds.length === 0) {
      return null;
    }
    return selectedTournament.rounds.reduce((max, round) => Math.max(max, round.roundNumber), 0);
  }

  function activePlayerCount(): number {
    return selectedTournament?.players.filter(player => player.status === 0).length ?? 0;
  }

  function inactivePlayerCount(): number {
    return selectedTournament?.players.filter(player => player.status !== 0).length ?? 0;
  }

  function totalOpenBoardCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.openBoards, 0);
  }

  function totalForfeitBoardCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.forfeitBoards, 0);
  }

  function openLatestRoundPrint() {
    const roundNumber = latestRoundNumber();
    if (roundNumber === null) {
      setError(t('workflow.noRoundIsAvailableToPrintYet'));
      return;
    }
    openRoundPrint(roundNumber);
  }

  function openLatestPairingsCsv() {
    const roundNumber = latestRoundNumber();
    if (!selectedTournament || roundNumber === null) {
      setError(t('workflow.noRoundIsAvailableForPairingExport'));
      return;
    }
    window.open(`/api/tournaments/${selectedTournament.id}/pairings/export.csv?roundNumber=${roundNumber}`, '_blank', 'noopener,noreferrer');
  }

  function exportAuditJournalCsv(): void {
    if (!selectedTournament) {
      return;
    }

    const csv = buildAuditJournalCsv(auditJournal, { date: auditDateLabel, severity: auditSeverityLabel, action: auditActionLabel });
    downloadText(`${selectedTournament.name}-auditjournal.csv`, csv, 'text/csv;charset=utf-8');
  }

  function exportAuditJournalJson(): void {
    if (!selectedTournament) {
      return;
    }

    downloadText(`${selectedTournament.name}-auditjournal.json`, JSON.stringify(auditJournal, null, 2), 'application/json;charset=utf-8');
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

    const selection = projectionLoader.capture(selectedTournament.id);
    if (!selection) return;
    setError(null);
    try {
      const text = await requestText(`/api/tournaments/${selectedTournament.id}/export/json`);
      if (!projectionLoader.isCurrent(selection)) return;
      const pretty = JSON.stringify(JSON.parse(text), null, 2);
      updateBackupJson(pretty);
      const now = new Date();
      const roundLabel = latestRoundNumber() === null ? 'start' : `r${latestRoundNumber()}`;
      const fileName = `${safeFileNamepart(selectedTournament.name)}_${roundLabel}_${backupTimestampSlug(now)}.json`;
      downloadText(fileName, pretty, 'application/json;charset=utf-8');
      const iso = now.toISOString();
      setLastBackupAt(iso);
      setBackupRecommended(false);
      writeLocalStorage(`stm.lastBackup.${selectedTournament.id}`, iso);
      setStatus(lang === 'en' ? `✓ Local backup saved: ${fileName}` : `✓ Lokales Backup gespeichert: ${fileName}`);
    } catch (ex) {
      if (projectionLoader.isCurrent(selection)) setError(t('workflow.couldNOTCreateBackup', { p0: describeApiError(ex, lang) }));
    }
  }

  function cancelBackupImport(): void {
    backupImportGuard.invalidate();
    setBackupImportPending(null);
    setBackupImportBusy(false);
  }

  function updateBackupJson(value: string): void {
    cancelBackupImport();
    setBackupJson(value);
  }

  async function confirmBackupImport(): Promise<void> {
    if (backupImportPending) await commitBackupImport(backupImportPending.request, true);
  }

  async function commitBackupImport(request: BackupImportRequest, overwriteExisting: boolean): Promise<void> {
    if (!backupImportGuard.dispatch(request)) return;
    setBackupImportBusy(true);
    setError(null);
    try {
      const imported = await requestJson<Tournament>('/api/tournaments/import', {
        method: 'POST',
        body: JSON.stringify({ tournament: JSON.parse(request.payload), overwriteExisting })
      });
      if (!backupImportGuard.isCurrent(request)) return;
      setBackupImportPending(null);
      setSelectedId(imported.id);
      setStatus(t('workflow.tournamentImported', { p0: imported.name }));
      await refresh(imported.id);
    } catch (ex) {
      if (backupImportGuard.isCurrent(request)) {
        setBackupImportPending(null);
        reportActionFailure(t('workflow.couldNotImportTournament'), ex);
      }
    } finally {
      if (backupImportGuard.finish(request)) setBackupImportBusy(false);
    }
  }

  async function importTournamentJson() {
    setError(null);
    let parsed: Tournament;
    try {
      parsed = JSON.parse(backupJson) as Tournament;
    } catch (ex) {
      // Ein defektes Backup ist kein Backendfehler - der Bediener soll die
      // Datei pruefen, nicht den Server.
      setError(t('workflow.couldNotReadBackup', { p0: describeJsonParseFailure(ex, lang) }));
      return;
    }

    const summary = backupImportSummary(parsed);
    if (!summary) {
      setError(lang === 'en' ? 'The backup needs an unambiguous tournament ID and a rounds list.' : t('workflow.theBackupNeedsAnUnambiguousTournamentID'));
      return;
    }
    const request = backupImportGuard.begin(JSON.stringify(parsed));
    if (!request) return;
    setBackupImportPending(null);
    setBackupImportBusy(true);
    try {
      // Read current targets without changing selection or the user's draft.
      // If a matching ID is created later, overwrite=false makes the server reject it.
      const current = await requestJson<Tournament[]>('/api/tournaments');
      if (!backupImportGuard.isCurrent(request)) return;
      const existing = current.find(item => item.id.toLowerCase() === summary.id);
      if (existing) {
        setBackupImportPending({ request, tournamentName: existing.name,
          existingRoundCount: existing.rounds.length, backupRoundCount: summary.roundCount });
        setBackupImportBusy(false);
      } else {
        await commitBackupImport(request, false);
      }
    } catch (ex) {
      if (backupImportGuard.finish(request)) {
        setBackupImportBusy(false);
        reportActionFailure(t('workflow.couldNotImportTournament'), ex);
      }
    }
  }

  function playerNameById(id?: string | null): string {
    if (!id || !selectedTournament) {
      return '—';
    }
    return selectedTournament.players.find(player => player.id === id)?.name ?? id.slice(0, 8);
  }

  function chess960Display(pairing: Pairing): string {
    if (!pairing.chess960StartPosition) {
      return pairing.isBye ? 'spielfrei' : t('workflow.notRolledYet');
    }

    return `${pairing.chess960StartPosition.whiteBackRank} · SP ${pairing.chess960StartPosition.positionNumber}`;
  }

  function chess960SeedDisplay(pairing: Pairing): string {
    return pairing.chess960StartPosition?.seed === null || pairing.chess960StartPosition?.seed === undefined
      ? ''
      : `Seed ${pairing.chess960StartPosition.seed}`;
  }

  function chess960PositionCount(round: TournamentRound): number {
    return round.pairings.filter(pairing => pairing.chess960StartPosition).length;
  }

  function chess960GameBoardCount(round: TournamentRound): number {
    return round.pairings.filter(pairing => !pairing.isBye).length;
  }

  function editPlayer(player: Player): void {
    if (!playerEditorGuard.advance(playerEditorToken)) return;
    setEditingPlayerId(player.id);
    setPlayerForm(playerToForm(player));
  }

  function updatePlayerForm(form: PlayerForm): void {
    if (playerEditorGuard.advance(playerEditorToken)) setPlayerForm(form);
  }

  function cancelPlayerEdit(): void {
    if (!playerEditorGuard.advance(playerEditorToken)) return;
    setEditingPlayerId(null); setPlayerForm(emptyPlayerForm);
  }

  function diagnosticsFor(roundNumber: number): RoundDiagnostics | undefined {
    return roundDiagnostics.find(item => item.roundNumber === roundNumber);
  }

  function completedRoundCount(): number {
    return roundDiagnostics.filter(item => item.isComplete).length;
  }

  function unverifiedCompleteRoundCount(): number {
    return roundDiagnostics.filter(item => item.isComplete && !item.isVerified).length;
  }

  function lockedRoundCount(): number {
    return selectedTournament?.rounds.filter(round => round.isLocked).length ?? 0;
  }

  function diagnosticWarningCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.warnings.length, 0);
  }

  function resultReviewRows() {
    return roundDiagnostics
      .flatMap(round => round.boards
        .filter(board => board.isOpen || board.isForfeit || board.note.trim().length > 0)
        .map(board => ({
          roundNumber: round.roundNumber,
          boardNumber: board.boardNumber,
          white: board.white,
          black: board.black,
          resultLabel: board.resultLabel,
          note: board.note,
          kind: board.isOpen ? 'offen' : board.isForfeit ? t('workflow.forfeit') : t('workflow.notice')
        })))
      .slice(0, 12);
  }

  function resultReviewStatusLabel(): string {
    if (!selectedTournament || selectedTournament.rounds.length === 0) {
      return t('workflow.noRoundYet');
    }
    if (totalOpenBoardCount() > 0) {
      return 'offene Ergebnisse';
    }
    if (unverifiedCompleteRoundCount() > 0) {
      return t('workflow.reviewPending');
    }
    if (diagnosticWarningCount() > 0) {
      return t('workflow.reviewNotices');
    }
    return 'bereit';
  }

  function resultReviewStatusDisplayLabel(): string {
    const label = resultReviewStatusLabel();
    if (lang !== 'en') {
      return label;
    }
    switch (label) {
      case t('workflow.noRoundYet'): return 'no round yet';
      case 'offene Ergebnisse': return 'open results';
      case t('workflow.reviewPending'): return 'review pending';
      case t('workflow.reviewNotices'): return 'review notices';
      case 'bereit': return 'ready';
      default: return label;
    }
  }

  function resultReviewStatusClass(): string {
    const label = resultReviewStatusLabel();
    if (label === 'bereit') {
      return 'result-review-status ok';
    }
    if (label === 'offene Ergebnisse') {
      return 'result-review-status danger';
    }
    return 'result-review-status warn';
  }
  function totalByeBoardCount(): number {
    return roundDiagnostics.reduce((sum, item) => sum + item.byeBoards, 0);
  }

  function byeForfeitAffectedRoundCount(): number {
    return new Set(roundDiagnostics
      .filter(item => item.byeBoards > 0 || item.forfeitBoards > 0)
      .map(item => item.roundNumber)).size;
  }

  function byeForfeitRows() {
    return roundDiagnostics
      .flatMap(round => round.boards
        .filter(board => board.isForfeit
          || board.note.toLowerCase().includes('bye')
          || board.note.toLowerCase().includes('spielfrei')
          || board.black.toLowerCase().includes('spielfrei'))
        .map(board => ({
          roundNumber: round.roundNumber,
          boardNumber: board.boardNumber,
          white: board.white,
          black: board.black,
          resultLabel: board.resultLabel,
          note: board.note,
          isForfeit: board.isForfeit,
          countsForBuchholz: board.countsForBuchholz,
          countsForDirectAndSonneborn: board.countsForDirectAndSonneborn,
          countsForPerformance: board.countsForPerformance,
          kind: board.note.toLowerCase().includes('bye') || board.note.toLowerCase().includes('spielfrei') || board.black.toLowerCase().includes('spielfrei') ? t('workflow.byeNoGame') : t('workflow.forfeit')
        })))
      .slice(0, 20);
  }

  function byeForfeitAuditStatusLabel(): string {
    if (!selectedTournament || selectedTournament.rounds.length === 0) {
      return t('workflow.noRoundYet');
    }
    if (totalForfeitBoardCount() > 0) {
      return t('workflow.reviewForfeits2');
    }
    if (totalByeBoardCount() > 0) {
      return 'Bye sichtbar';
    }
    return t('workflow.noCases');
  }

  function byeForfeitAuditStatusDisplayLabel(): string {
    const label = byeForfeitAuditStatusLabel();
    if (lang !== 'en') {
      return label;
    }
    switch (label) {
      case t('workflow.noRoundYet'): return 'no round yet';
      case t('workflow.reviewForfeits2'): return 'review forfeits';
      case 'Bye sichtbar': return 'bye visible';
      case t('workflow.noCases'): return 'no cases';
      default: return label;
    }
  }

  function byeForfeitAuditStatusClass(): string {
    const label = byeForfeitAuditStatusLabel();
    if (label === t('workflow.noCases')) {
      return 'bye-forfeit-status ok';
    }
    if (label === t('workflow.reviewForfeits2')) {
      return 'bye-forfeit-status warn';
    }
    return 'bye-forfeit-status info';
  }
  function pairingReadinessOpenResultCount(): number {
    return totalOpenBoardCount();
  }

  function pairingReadinessUnverifiedRoundCount(): number {
    if (!selectedTournament) {
      return 0;
    }

    return selectedTournament.rounds.filter(round => {
      const diagnostics = diagnosticsFor(round.roundNumber);
      return diagnostics !== undefined && diagnostics.openBoards === 0 && !round.isVerified;
    }).length;
  }

  function pairingReadinessIssues(): string[] {
    const issues = pairingReadinessBlockingIssues();

    if (!selectedTournament) {
      return issues;
    }

    const unverifiedRounds = pairingReadinessUnverifiedRoundCount();
    if (unverifiedRounds > 0) {
      issues.push(lang === 'en'
        ? `${unverifiedRounds} completed round(s) are not marked as reviewed.`
        : t('workflow.completeRoundSHaveNotBeenMarked', { p0: unverifiedRounds }));
    }

    if (nextRoundPreview?.pairingQuality.hasCriticalIssues) {
      issues.push(lang === 'en'
        ? 'The current pairing preview contains critical notes. This can be unavoidable in small events; pair the round only after a deliberate review.'
        : t('workflow.thePairingPreviewContainsCriticalNoticesThis'));
    }

    return issues;
  }

  function pairingReadinessBlockingIssues(): string[] {
    const issues: string[] = [];

    if (!selectedTournament) {
      issues.push(lang === 'en' ? 'No tournament selected.' : t('workflow.noTournamentSelected'));
      return issues;
    }

    if (!currentProjection) {
      issues.push(lang === 'en' ? 'Current tournament data must finish loading before pairing.' : t('workflow.theCurrentTournamentDataMustBeFully'));
    }

    const activePlayers = activePlayerCount();
    if (activePlayers < 2) {
      issues.push(lang === 'en' ? 'At least two active players are required to create pairings.' : t('workflow.atLeastTwoActivePlayersAreNeeded'));
    }

    const openResults = pairingReadinessOpenResultCount();
    if (openResults > 0) {
      issues.push(lang === 'en' ? `${openResults} open result(s) must be resolved before pairing the next round.` : t('workflow.resolvePendingResultSBeforeTheNext', { p0: openResults }));
    }

    if (selectedTournament.rounds.length >= selectedTournament.settings.plannedRounds) {
      issues.push(lang === 'en' ? `The planned number of rounds (${selectedTournament.settings.plannedRounds}) has already been reached.` : `Die geplante Rundenzahl (${selectedTournament.settings.plannedRounds}) ist bereits erreicht.`);
    }

    return issues;
  }

  function pairingReadinessStatusLabel(): string {
    if (!selectedTournament) {
      return lang === 'en' ? 'no tournament' : t('workflow.noTournament');
    }

    if (pairingReadinessBlockingIssues().length > 0) {
      return lang === 'en' ? 'blocked' : 'blockiert';
    }

    if (pairingReadinessUnverifiedRoundCount() > 0 || nextRoundPreview?.pairingQuality.hasCriticalIssues) {
      return lang === 'en' ? 'review' : t('workflow.review2');
    }

    return lang === 'en' ? 'ready' : 'bereit';
  }

  function pairingReadinessStatusClass(): string {
    if (!selectedTournament) {
      return 'pairing-readiness-status neutral';
    }
    if (pairingReadinessBlockingIssues().length > 0) {
      return 'pairing-readiness-status danger';
    }
    if (pairingReadinessUnverifiedRoundCount() > 0 || nextRoundPreview?.pairingQuality.hasCriticalIssues) {
      return 'pairing-readiness-status warn';
    }
    {
      return 'pairing-readiness-status ok';
    }
  }

  function pairingReadinessCanCreatePreview(): boolean {
    return pairingReadinessBlockingIssues().length === 0;
  }

  function pairingReadinessCanGenerateRound(): boolean {
    // Kleine Turniere können unvermeidbare Rematches, Scoregruppen-Abweichungen
    // und ungeprüfte Warnhinweise haben. Diese Punkte sollen warnen, aber die
    // Auslosung nach bewusster Turnierleiter-Entscheidung nicht hart blockieren.
    return pairingReadinessCanCreatePreview();
  }

  function operatorRoundLabel(): string {
    const planned = selectedTournament?.settings.plannedRounds ?? 0;
    const current = selectedTournament?.rounds.length ?? 0;
    if (!selectedTournament) {
      return '–';
    }
    if (current === 0) {
      return lang === 'en' ? `none yet · ${planned} planned` : `noch keine · geplant ${planned}`;
    }
    return lang === 'en' ? `Round ${current} of ${planned}` : t('workflow.roundOf', { p0: current, p1: planned });
  }

  type OperatorStep = {
    tone: 'ok' | 'warn' | 'danger' | 'neutral';
    title: string;
    detail: string;
    actionLabel?: string;
    action?: () => void;
  };

  function nextOperatorStep(): OperatorStep {
    if (!selectedTournament) {
      return {
        tone: 'neutral',
        title: lang === 'en' ? 'Create or select a tournament' : t('workflow.createOrSelectATournament'),
        detail: lang === 'en' ? 'Create a tournament or choose one from the list.' : t('workflow.createATournamentOnTheLeftOr')
      };
    }

    if (!currentProjection) {
      return {tone:'neutral', title:lang === 'en' ? 'Tournament data is loading' : t('workflow.loadingTournamentData'),
        detail:lang === 'en' ? 'Pairing readiness is shown once the current data is available.' : t('workflow.pairingReadinessAppearsAfterTheCurrentData')};
    }

    if (activePlayerCount() < 2) {
      return {
        tone: 'warn',
        title: lang === 'en' ? 'Add participants' : 'Teilnehmer erfassen',
        detail: lang === 'en' ? `At least two active players are required (${activePlayerCount()} now).` : t('workflow.atLeastTwoActivePlayersAreNeeded2', { p0: activePlayerCount() })
      };
    }

    const rounds = selectedTournament.rounds.length;
    const planned = selectedTournament.settings.plannedRounds;

    if (rounds === 0) {
      return {
        tone: 'ok',
        title: t('rounds.firstTitle'),
        detail: lang === 'en' ? 'Review the preview, then create the pairings.' : t('workflow.viewAndReviewThePreviewThenPair'),
        actionLabel: t('rounds.preview'),
        action: () => void previewNextRound()
      };
    }

    const openResults = totalOpenBoardCount();
    if (openResults > 0) {
      return {
        tone: 'danger',
        title: lang === 'en' ? `Enter results (${openResults} open)` : `Ergebnisse eintragen (${openResults} offen)`,
        detail: lang === 'en' ? `Round ${latestRoundNumber()} is active. Complete every board before pairing the next round.` : t('workflow.roundIsInProgressEveryBoardNeeds', { p0: latestRoundNumber() ?? '—' }),
        actionLabel: lang === 'en' ? 'Print round sheet' : t('workflow.printRoundSheet'),
        action: () => openLatestRoundPrint()
      };
    }

    if (rounds >= planned) {
      return {
        tone: 'ok',
        title: lang === 'en' ? 'Review final standings' : t('workflow.finishReviewStandings'),
        detail: lang === 'en' ? `All ${planned} planned rounds are complete. Review, print and back up the final standings.` : t('workflow.allPlannedRoundsHaveBeenPlayedReview', { p0: planned }),
        actionLabel: lang === 'en' ? 'Tournament print view' : t('workflow.tournamentPrintView'),
        action: () => openTournamentExport('print/html')
      };
    }

    const unverified = pairingReadinessUnverifiedRoundCount();
    const detail = unverified > 0
      ? (lang === 'en' ? `All results are entered. ${unverified} complete round(s) are not marked reviewed.` : t('workflow.allResultsEnteredCompleteRoundSHave', { p0: unverified }))
      : (lang === 'en' ? 'All results are entered. Review the preview, then pair the next round.' : t('workflow.allResultsEnteredReviewThePreviewThen'));
    return {
      tone: unverified > 0 ? 'warn' : 'ok',
      title: lang === 'en' ? `Preview / pair round ${rounds + 1}` : t('workflow.createPreviewPairRound', { p0: rounds + 1 }),
      detail,
      actionLabel: t('rounds.preview'),
      action: () => void previewNextRound()
    };
  }
  function applyAssistantRecommendation(): void {
    setFormat(assistantRecommendation.format);
    setNewTournamentSettingsForm({
      ...newTournamentSettingsForm,
      format: assistantRecommendation.format,
      scoringSystem: assistantRecommendation.scoringSystem,
      plannedRounds: assistantRecommendation.plannedRounds.toString(),
      tiebreaks: assistantRecommendation.format === 0 ? [4, 0, 1, 99] : defaultTiebreaks
    });
    setNewTournamentName(`${optionLabel(assistantScenarioOptions.find(option => option.value === assistantForm.scenario), lang === 'en')} ${new Date().getFullYear()}`);
    setStatus(t('workflow.assistantRecommendationAppliedToTheNewTournament'));
    setActiveMainTab('admin');
    setIsCreateTournamentOpen(true);
  }


  function askKnowledgeChat(questionOverride?: string): void {
    const question = (questionOverride ?? knowledgeChatInput).trim();
    if (!question) {
      setError(t('workflow.enterAQuestionForLocalTournamentHelp'));
      return;
    }

    const userMessage: KnowledgeChatMessage = {
      id: `user-${Date.now()}-${Math.random().toString(36).slice(2)}`,
      role: 'user',
      text: question,
      sources: []
    };
    const answer = buildLocalKnowledgeAnswer(question, selectedTournament, assistantRecommendation, lang);
    setKnowledgeChatMessages(previous => [...previous, userMessage, answer]);
    setKnowledgeChatInput('');
    setStatus(t('workflow.localTournamentHelpHasAnsweredNoExternal'));
  }

  function correctionJournalItems() {
    if (!selectedTournament) {
      return [];
    }

    const items: Array<{
      key: string;
      scope: string;
      severity: 'info' | 'warning' | 'critical';
      title: string;
      detail: string;
      action: string;
    }> = [];

    for (const player of selectedTournament.players.filter(player => player.status !== 0)) {
      items.push({
        key: `player-status-${player.id}`,
        scope: t('nav.participants'),
        severity: 'warning',
        title: lang === 'en'
          ? `${player.name} is ${statusLabel(player.status, true).toLowerCase()}`
          : `${player.name} ist ${statusLabel(player.status).toLowerCase()}`,
        detail: `${player.name}${player.club ? ` · ${player.club}` : ''}${player.notes ? ` · ${player.notes}` : ''}`,
        action: t('workflow.reviewParticipantStatusBeforeTheNextPairing')
      });
    }

    for (const round of selectedTournament.rounds) {
      const diagnostics = diagnosticsFor(round.roundNumber);
      const openBoards = diagnostics?.openBoards ?? 0;
      const roundStatus = roundStatusLabel(round.resultStatus);

      if (round.isLocked) {
        items.push({
          key: `round-locked-${round.roundNumber}`,
          scope: t('operator.round'),
          severity: 'info',
          title: t('workflow.roundIsLocked', { p0: round.roundNumber }),
          detail: `${roundStatus} · ${round.pairings.length} Brett(er)`,
          action: t('workflow.unlockARoundOnlyForDeliberateTournament')
        });
      }

      if (round.isVerified) {
        items.push({
          key: `round-verified-${round.roundNumber}`,
          scope: t('operator.round'),
          severity: 'info',
          title: t('workflow.roundIsReviewed', { p0: round.roundNumber }),
          detail: `${roundStatus} · ${round.pairings.length} Brett(er)`,
          action: t('workflow.reopenAReviewedRoundOnlyAfterConsultation')
        });
      } else if (round.pairings.length > 0 && openBoards === 0) {
        items.push({
          key: `round-unverified-${round.roundNumber}`,
          scope: t('operator.round'),
          severity: 'warning',
          title: t('workflow.roundIsCompleteButNotReviewed', { p0: round.roundNumber }),
          detail: `${roundStatus} · keine offenen Bretter laut Diagnose`,
          action: t('workflow.checkResultSheetsAndMarkTheRound')
        });
      }

      for (const pairing of round.pairings) {
        const resultText = resultLabel(pairing.result.kind);
        const lowerResult = resultText.toLowerCase();
        const whiteName = playerNameById(pairing.whitePlayerId);
        const blackName = pairing.isBye ? 'spielfrei' : playerNameById(pairing.blackPlayerId);
        const hasSpecialResult = pairing.isBye || lowerResult.includes(t('workflow.forfeit')) || lowerResult.includes('bye') || lowerResult.includes('spielfrei');

        if (pairing.isManualOverride) {
          items.push({
            key: `manual-pairing-${round.roundNumber}-${pairing.boardNumber}`,
            scope: t('workflow.pairing'),
            severity: 'critical',
            title: t('workflow.manualPairingRB', { p0: round.roundNumber, p1: pairing.boardNumber }),
            detail: `${whiteName} – ${blackName}${pairing.notes ? ` · ${pairing.notes}` : ''}`,
            action: t('workflow.checkManualPairingsAgainstTheTournamentDirector')
          });
        }

        if (hasSpecialResult) {
          items.push({
            key: `special-result-${round.roundNumber}-${pairing.boardNumber}`,
            scope: t('rounds.result'),
            severity: pairing.isBye ? 'info' : 'warning',
            title: `${pairing.isBye ? t('workflow.byeNoGame') : 'Sonderergebnis'} R${round.roundNumber}/B${pairing.boardNumber}`,
            detail: `${whiteName} – ${blackName} · ${resultText}`,
            action: 'Wertungsauswirkung in Bye-/Kampflos-Audit und Tabelle kontrollieren.'
          });
        }
      }
    }

    return items.slice(0, 60);
  }

  const correctionJournal = correctionJournalItems();
  const correctionJournalCriticalCount = correctionJournal.filter(item => item.severity === 'critical').length;
  const correctionJournalWarningCount = correctionJournal.filter(item => item.severity === 'warning').length;
  const correctionJournalInfoCount = correctionJournal.filter(item => item.severity === 'info').length;
  const correctionJournalStatusClass = !selectedTournament
    ? 'blocked'
    : correctionJournalCriticalCount > 0
      ? 'blocked'
      : correctionJournalWarningCount > 0
        ? 'warning'
        : 'ready';
  const correctionJournalStatusLabel = !selectedTournament
    ? t('workflow.noTournament')
    : correctionJournalCriticalCount > 0
      ? t('workflow.critical')
      : correctionJournalWarningCount > 0
        ? t('workflow.review2')
        : t('workflow.noIssues');

  const readinessNotice = describeReadiness(backendReadiness, lang);
  // Waehrend der Startphase bleiben schreibende Aktionen gesperrt: ein Klick in
  // diesem Fenster landet garantiert in einem halb geladenen Zustand.
  const backendReady = canOperate(backendReadiness);

  return (
    <main className={`shell theme-${theme}${outdoorMode ? ' outdoor' : ''}`}>
      <header className="hero">
        <div>
          <p className="eyebrow">{t('hero.eyebrow')}{health?.version ? ` · v${health.version}` : ''}</p>
          <h1>{t('app.title')}</h1>
          <p>{t('hero.subtitle')}</p>
        </div>
        <div className="status-card">
          <strong>{t('backend.title')}</strong>
          {health && <span className="ok">{health.app} {health.version}: {health.status}</span>}
          {!health && backendReadiness === 'starting' && <span>{t('backend.checking')}</span>}
          {!health && backendReadiness === 'unreachable' && <span className="error">{t('backend.offline')}</span>}
          {health?.database && <small>{t('workflow.localDatabase')} {health.database}</small>}
          <LanguageSwitcher />
          <button type="button" className="small secondary theme-toggle" onClick={() => setTheme(previous => previous === 'dark' ? 'light' : 'dark')} aria-pressed={theme === 'light'}>
            {theme === 'dark' ? t('theme.light') : t('theme.dark')}
          </button>
          <div className={`pwa-status ${pwaStatus}`}>
            <span>{pwaStatusLabel(pwaStatus, lang === 'en')}</span>
            {pwaInstallPrompt && <button type="button" className="small secondary" onClick={() => void installPwa()}>{t('workflow.install')}</button>}
          </div>
        </div>
      </header>

      {readinessNotice && (
        <section className={`readiness-banner tone-${readinessNotice.tone}`} role="status" aria-live="polite" data-readiness={backendReadiness}>
          <div>
            <strong>{readinessNotice.title}</strong>
            <p>{readinessNotice.detail}</p>
          </div>
          {readinessNotice.retryLabel && (
            <button type="button" onClick={retryBackendReadiness}>{readinessNotice.retryLabel}</button>
          )}
        </section>
      )}

      <section className="status-line" role="status" aria-live="polite" aria-atomic="true">
        <span>{status}</span>
        {selectedTournament && !currentProjection && <span aria-busy={projection.phase === 'loading'}>{projection.phase === 'error'
          ? (lang === 'en' ? 'Tournament data could not be loaded.' : t('workflow.couldNotLoadTournamentData'))
          : (lang === 'en' ? 'Loading current tournament data…' : t('workflow.loadingCurrentTournamentData'))}</span>}
        {selectedTournament && projection.id === selectedTournament.id && projection.phase === 'error' && (
          <button type="button" className="small secondary derived-retry" onClick={() => void retryDerivedProjection()}>{t('workflow.retryTournamentData')}</button>
        )}
        {error && <strong className="error" role="alert">{error}</strong>}
      </section>

      <OfflineResultQueuePanel store={resultQueueStore} tournaments={tournaments} lang={lang} onRefresh={() => refresh()} />

      {selectedTournament && (() => {
        const step = nextOperatorStep();
        return (
          <section className="operator-bar" aria-label="Operator-Status">
            <div className="operator-chips">
              <div className="operator-chip">
                <span className="operator-chip-label">{t('operator.round')}</span>
                <strong>{operatorRoundLabel()}</strong>
              </div>
              <div className={`operator-chip ${totalOpenBoardCount() > 0 ? 'danger' : 'ok'}`}>
                <span className="operator-chip-label">{t('operator.openResults')}</span>
                <strong>{totalOpenBoardCount()}</strong>
                {selectedTournament && <small>{activePlayerCount()} {t('operator.active')} · {inactivePlayerCount()} {t('operator.inactive')}</small>}
              </div>
              <div className={`operator-chip ${backupRecommended ? 'danger' : lastBackupAt ? 'ok' : ''}`}>
                <span className="operator-chip-label">{t('operator.lastBackup')}</span>
                <strong>{backupRecommended ? t('operator.backupRecommended') : lastBackupAt ? t('operator.backupCurrent') : t('operator.backupNone')}</strong>
                <small>{backupTimeLabel(lastBackupAt, lang === 'en')}</small>
              </div>
            </div>
            <div className={`operator-next tone-${step.tone}`}>
              <div>
                <span className="operator-next-eyebrow">{t('operator.nextStep')}</span>
                <strong>{step.title}</strong>
                <p>{step.detail}</p>
              </div>
              {step.action && step.actionLabel && (
                <button type="button" onClick={step.action}>{step.actionLabel}</button>
              )}
            </div>
            <div className="operator-tools">
              <button
                type="button"
                className={outdoorMode ? '' : 'secondary'}
                aria-pressed={outdoorMode}
                onClick={() => setOutdoorMode(previous => !previous)}
                title={lang === 'en' ? 'Larger text and controls with stronger contrast for outdoor use. Stored locally.' : t('workflow.largerTextAndButtonsWithHigherContrast')}
              >
                {outdoorMode ? (lang === 'en' ? '☀ Tournament mode ON' : '☀ Turniertag-Modus AN') : (lang === 'en' ? '☀ Tournament mode OFF' : '☀ Turniertag-Modus AUS')}
              </button>
              <button
                type="button"
                className={backupRecommended ? '' : 'secondary'}
                onClick={() => void exportTournamentJson()}
                disabled={!selectedTournament}
                title={lang === 'en' ? 'Downloads a local JSON snapshot with tournament name, round and timestamp. No cloud.' : t('workflow.downloadsALocalJSONSnapshotWithTournament')}
              >
                {lang === 'en' ? '💾 Create backup now' : '💾 Jetzt Backup erstellen'}
              </button>
            </div>
          </section>
        );
      })()}

      {destructiveDialog?.action === 'reset' && (
        <ConfirmDialog
          open
          title={lang === 'en' ? 'Reset tournament?' : t('workflow.resetTournament2')}
          description={
            lang === 'en'
              ? `Reset "${destructiveDialog.tournamentName}" back to its starting state?`
              : t('workflow.resetTournamentToItsStartingState', { p0: destructiveDialog.tournamentName })
          }
          consequences={[
            t('safety.keepParticipantsSettings'),
            t('workflow.allRoundsResultsAndChess960StartingPositions'),
            t('safety.backupBeforeAction')
          ]}
          confirmLabel={lang === 'en' ? 'Reset tournament' : t('workflow.resetTournament')}
          cancelLabel={t('common.cancel')}
          busy={destructiveDialog.busy}
          busyLabel={lang === 'en' ? 'Resetting…' : t('workflow.resetting')}
          errorMessage={destructiveDialog.error}
          onConfirm={() => void confirmDestructiveDialog()}
          onCancel={closeDestructiveDialog}
        />
      )}

      {destructiveDialog?.action === 'delete' && (
        <ConfirmDialog
          open
          destructive
          title={lang === 'en' ? 'Delete tournament permanently?' : t('workflow.permanentlyDeleteTournament')}
          description={
            lang === 'en'
              ? `"${destructiveDialog.tournamentName}" including all participants, rounds and results will be removed from the local database. This cannot be undone and is not the same as resetting.`
              : t('workflow.andAllItsParticipantsRoundsAndResults', { p0: destructiveDialog.tournamentName })
          }
          consequences={[t('safety.backupBeforeAction')]}
          requireTypedConfirmation={destructiveDialog.tournamentName}
          typedConfirmationLabel={t('safety.typeExactTournamentName')}
          confirmLabel={lang === 'en' ? 'Delete tournament' : t('workflow.deleteTournament')}
          cancelLabel={t('common.cancel')}
          busy={destructiveDialog.busy}
          busyLabel={lang === 'en' ? 'Deleting…' : t('workflow.deleting')}
          errorMessage={destructiveDialog.error}
          onConfirm={() => void confirmDestructiveDialog()}
          onCancel={closeDestructiveDialog}
        />
      )}

      {backupImportPending && (
        <ConfirmDialog
          key={backupImportPending.request.generation}
          open
          destructive
          title={lang === 'en' ? 'Replace the existing tournament?' : t('workflow.replaceExistingTournament')}
          description={lang === 'en'
            ? `The backup belongs to "${backupImportPending.tournamentName}". This tournament already exists and will be replaced completely.`
            : t('workflow.thisBackupBelongsToTheExistingTournament', { p0: backupImportPending.tournamentName })}
          consequences={lang === 'en'
            ? [`Existing tournament: ${backupImportPending.existingRoundCount} round(s). Backup: ${backupImportPending.backupRoundCount} round(s).`,
              'All current participants, settings, rounds, results and audit entries will be replaced by the backup. Changes made since the backup will be lost.',
              'Create a separate backup of the current tournament before replacing it if you need to keep those changes.']
            : [t('workflow.existingTournamentRoundSBackupRoundS', { p0: backupImportPending.existingRoundCount, p1: backupImportPending.backupRoundCount }),
              t('workflow.theBackupReplacesCurrentParticipantsSettingsRounds'),
              t('workflow.exportTheCurrentTournamentSeparatelyBeforeReplacement')]}
          requireTypedConfirmation={backupImportPending.tournamentName}
          typedConfirmationLabel={t('safety.typeExactTournamentName')}
          confirmLabel={t('safety.replaceWithBackup')}
          cancelLabel={t('common.cancel')}
          busy={backupImportBusy}
          busyLabel={t('safety.importing')}
          onConfirm={() => void confirmBackupImport()}
          onCancel={cancelBackupImport}
        />
      )}

      {actionConfirm && (
        <ConfirmDialog
          open
          destructive={actionConfirm.destructive}
          title={actionConfirm.title}
          description={actionConfirm.description}
          consequences={actionConfirm.consequences}
          confirmLabel={actionConfirm.confirmLabel}
          cancelLabel={actionConfirm.cancelLabel}
          busy={actionConfirmBusy}
          busyLabel={lang === 'en' ? 'Working…' : t('workflow.working')}
          onConfirm={() => void confirmActionDialog()}
          onCancel={() => {
            if (!actionConfirmBusy && !actionConfirmInFlight.current) {
              actionConfirm.onCancel?.();
              setActionConfirm(current => current === actionConfirm ? null : current);
            }
          }}
        />
      )}

      {nextRoundPreview && isNextRoundPreviewDialogOpen && (
        <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label={lang === 'en' ? `Pairing preview for round ${nextRoundPreview.roundNumber}` : t('workflow.roundPairingPreview', { p0: nextRoundPreview.roundNumber })}>
          <article className={`card preview-card preview-modal ${pairingQualitySeverityClass(nextRoundPreview.pairingQuality.severity)}`}>
            <div className="preview-card-header">
              <div>
                <p className="eyebrow">{lang === 'en' ? 'Preview · not saved yet' : t('workflow.popupPreviewNotSavedYet')}</p>
                <h3>{lang === 'en' ? `Pairing preview for round ${nextRoundPreview.roundNumber}` : t('workflow.roundPairingPreview', { p0: nextRoundPreview.roundNumber })}</h3>
                <p className="muted">{nextRoundPreview.summary}</p>
              </div>
              <div className="preview-score">
                <strong>{nextRoundPreview.pairingQuality.qualityScore}/100</strong>
                <span>{pairingQualitySeverityLabel(nextRoundPreview.pairingQuality.severity, lang === 'en')}</span>
              </div>
            </div>
            <div className="preview-metrics">
              <span>{nextRoundPreview.boardCount} {lang === 'en' ? 'boards' : t('workflow.boards2')}</span>
              <span>{nextRoundPreview.pairingQuality.rematchCount} Rematches</span>
              <span>{nextRoundPreview.pairingQuality.crossScoreGroupPairingCount} {lang === 'en' ? 'score-group findings' : 'Scoregruppen-Hinweise'}</span>
              <span>{nextRoundPreview.pairingQuality.thirdSameColorRiskCount} {lang === 'en' ? 'colour-sequence risks' : 'Farbfolge-Risiken'}</span>
              <span>{nextRoundPreview.pairingQuality.byeCount} Bye</span>
            </div>
            {nextRoundPreview.pairingQuality.hasCriticalIssues && (
              <div className="preview-warning critical">
                <strong>{lang === 'en' ? 'Review findings without automatically blocking:' : t('workflow.reviewNoticesWithoutAutomaticallyBlockingPairing')}</strong> {lang === 'en' ? 'In small tournaments, rematches and score-group deviations can be unavoidable.' : t('workflow.rematchesAndScoreGroupDeviationsAreOften')}
              </div>
            )}
            {nextRoundPreview.messages.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.messages.map((message, index) => <li key={`preview-modal-message-${index}`}>{message}</li>)}</ul>}
            {nextRoundPreview.pairingQuality.findings.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.pairingQuality.findings.map((finding, index) => <li key={`preview-modal-quality-${index}`}>{finding}</li>)}</ul>}
            <div className="table-scroll compact preview-pairings preview-modal-table">
              <table>
                <thead><tr><th>{lang === 'en' ? 'Board' : t('rounds.board')}</th><th>{lang === 'en' ? 'White' : t('rounds.white')}</th><th>{lang === 'en' ? 'Black' : t('rounds.black')}</th><th>{lang === 'en' ? 'Score before round' : t('workflow.scoreBeforeRound')}</th><th>{lang === 'en' ? 'Findings' : t('workflow.notices')}</th></tr></thead>
                <tbody>
                  {nextRoundPreview.pairingQuality.boards.map(board => (
                    <tr key={`preview-modal-board-${board.boardNumber}`} className={board.isRematch ? 'quality-board-critical' : board.wouldGiveWhiteThirdSameColor || board.wouldGiveBlackThirdSameColor ? 'quality-board-warning' : board.isCrossScoreGroupPairing || board.isBye ? 'quality-board-notice' : ''}>
                      <td>{board.boardNumber}</td>
                      <td>{board.whiteName}</td>
                      <td>{board.isBye ? (lang === 'en' ? 'bye' : 'spielfrei') : board.blackName}</td>
                      <td>{board.isBye ? 'Bye' : `${board.whiteScoreBeforeRound} : ${board.blackScoreBeforeRound}`}</td>
                      <td>{board.findings.length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{board.findings.map((finding, index) => <li key={`preview-modal-board-${board.boardNumber}-${index}`}>{finding}</li>)}</ul>}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="actions preview-actions">
              <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>{lang === 'en' ? 'Pair this round now' : t('workflow.pairThisRoundNow')}</button>
              <button type="button" className="secondary" onClick={openNextRoundPreviewPrint}>{lang === 'en' ? 'Open print view' : t('workflow.openPrintView')}</button>
              <button type="button" className="secondary" onClick={openNextRoundPreviewCsv}>{lang === 'en' ? 'Export CSV' : t('workflow.exportCSV')}</button>
              <button type="button" className="secondary" onClick={() => setIsNextRoundPreviewDialogOpen(false)}>{lang === 'en' ? 'Close' : t('common.close')}</button>
            </div>
          </article>
        </div>
      )}

      {chess960DialogRound && chess960Guard.isCurrent(chess960DialogToken) && chess960DialogToken.tournamentId === selectedId && (
        <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label={t('workflow.chessDiceRound2', { p0: chess960DialogRound.roundNumber })}>
          <article className="card chess960-modal">
            <div className="preview-card-header">
              <div>
                <p className="eyebrow">{t('workflow.chessDiceChess960')}</p>
                <h3>{t('workflow.chessDiceRound')} {chess960DialogRound.roundNumber}</h3>
                <p className="muted">{t('workflow.eachRegularBoardReceivesALegalRandom')}</p>
              </div>
              <div className="preview-score">
                <strong>{chess960PositionCount(chess960DialogRound)}</strong>
                <span>{t('workflow.of')} {chess960GameBoardCount(chess960DialogRound)} {t('workflow.boards')}</span>
              </div>
            </div>

            <ChessDie rolling={chess960Rolling} spin={diceSpin} face={diceFace} />
            <p className="dice-result-line">
              {chess960Rolling
                ? t('workflow.rollingTheDice')
                : chess960HasRolled
                  ? t('workflow.rolledLegalStartingPositionSSaved', { p0: [t('dice.king'), t('dice.queen'), t('dice.rook'), t('dice.bishop'), t('dice.knight'), t('dice.pawn')][diceFace], p1: diceFaceGlyphs[diceFace], p2: chess960PositionCount(chess960DialogRound) })
                  : t('workflow.readyToRollACompleteChess960Starting')}
            </p>
            <div className="dice-modal-actions">
              <button type="button" onClick={() => void performChess960Roll(chess960DialogRound)} disabled={chess960Rolling || chess960DialogRound.isLocked || chess960DialogRound.isVerified || chess960GameBoardCount(chess960DialogRound) === 0}>
                {chess960Rolling ? t('workflow.rolling') : chess960PositionCount(chess960DialogRound) > 0 ? t('workflow.rollAgain') : t('workflow.roll')}
              </button>
            </div>

            {chess960PositionCount(chess960DialogRound) > 0 && (
              <div className="table-scroll compact chess960-modal-table">
                <table>
                  <thead><tr><th>{t('rounds.board')}</th><th>{t('workflow.pairing')}</th><th>{t('workflow.whiteStartingPosition')}</th><th>{t('workflow.blackStartingPosition')}</th><th>ID / Seed</th></tr></thead>
                  <tbody>
                    {chess960DialogRound.pairings.map(pairing => (
                      <tr key={`chess960-modal-${chess960DialogRound.roundNumber}-${pairing.boardNumber}`}>
                        <td>{pairing.boardNumber}</td>
                        <td>{playerNameById(pairing.whitePlayerId)} – {pairing.isBye ? 'spielfrei' : playerNameById(pairing.blackPlayerId)}</td>
                        <td><strong>{pairing.chess960StartPosition?.whiteBackRank ?? '—'}</strong></td>
                        <td>{pairing.chess960StartPosition?.blackBackRank ?? '—'}</td>
                        <td>{pairing.chess960StartPosition ? `SP ${pairing.chess960StartPosition.positionNumber}${chess960SeedDisplay(pairing) ? ` · ${chess960SeedDisplay(pairing)}` : ''}` : '—'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="actions preview-actions">
              <button type="button" className="secondary" onClick={() => openRoundPrint(chess960DialogRound.roundNumber)} disabled={chess960PositionCount(chess960DialogRound) === 0}>{t('workflow.printRoundSheet')}</button>
              <button type="button" onClick={closeChess960Dialog} disabled={chess960Rolling}>{t('common.close')}</button>
            </div>
          </article>
        </div>
      )}

      {boardDiceModal && selectedTournament && (() => {
        const round = selectedTournament.rounds.find(item => item.roundNumber === boardDiceModal.roundNumber);
        const pairing = round?.pairings.find(item => item.boardNumber === boardDiceModal.boardNumber);
        if (!round || !pairing) {
          return null;
        }
        const roundClosed = round.isLocked || round.isVerified;
        const port = window.location.port ? `:${window.location.port}` : '';
        const host = laptopIp.trim() || window.location.hostname;
        const diceUrl = `http://${host}${port}/?dice=${selectedTournament.id}&round=${round.roundNumber}&board=${pairing.boardNumber}`;
        const hostIsLocal = host === 'localhost' || host === '127.0.0.1' || host === '::1';
        return (
          <div className="modal-backdrop" role="dialog" aria-modal="true" aria-label={t('workflow.rollBoard', { p0: pairing.boardNumber })} onClick={() => setBoardDiceModal(null)}>
            <article className="card chess960-modal board-dice-modal" onClick={(event: React.MouseEvent) => event.stopPropagation()}>
              <div className="preview-card-header">
                <div>
                  <p className="eyebrow">{t('workflow.chessDiceChess960SingleBoard')}</p>
                  <h3>{selectedTournament.name}</h3>
                  <p className="muted">{t('operator.round')} {round.roundNumber} {t('workflow.board')} {pairing.boardNumber}</p>
                  <p className="board-dice-pairing"><strong>{playerNameById(pairing.whitePlayerId)}</strong> – {pairing.isBye ? t('dice.bye') : <strong>{playerNameById(pairing.blackPlayerId)}</strong>}</p>
                </div>
                <button type="button" className="secondary" onClick={() => setBoardDiceModal(null)}>{t('common.close')}</button>
              </div>

              {pairing.chess960StartPosition
                ? <p className="board-dice-warning">{t('workflow.alreadySaved')} {pairing.chess960StartPosition.whiteBackRank} · SP {pairing.chess960StartPosition.positionNumber}{t('workflow.rollingAgainReplacesThisPositionAfterConfirmation')}</p>
                : <p className="muted">{t('workflow.noStartingPositionHasBeenSavedFor')}</p>}

              <div className="tab-bar board-dice-tabs">
                <button type="button" className={`tab-button${boardDiceTab === 'browser' ? ' active' : ''}`} onClick={() => setBoardDiceTab('browser')}>{t('workflow.rollInBrowser')}</button>
                <button type="button" className={`tab-button${boardDiceTab === 'qr' ? ' active' : ''}`} onClick={() => setBoardDiceTab('qr')}>{t('workflow.qRMobile')}</button>
              </div>

              {boardDiceTab === 'browser' && (
                roundClosed
                  ? <p className="board-dice-error">{t('workflow.theRoundIsLockedOrReviewedIts')}</p>
                  : <BoardDiceRoller
                      tournamentId={selectedTournament.id}
                      roundNumber={round.roundNumber}
                      boardNumber={pairing.boardNumber}
                      currentPosition={pairing.chess960StartPosition ?? null}
                      disabled={roundClosed}
                      onSaved={() => { setBackupRecommended(true); void refresh(selectedTournament.id); }}
                    />
              )}

              {boardDiceTab === 'qr' && (
                <div className="qr-tab">
                  <p className="muted">{t('workflow.playersOrArbitersCanRollThisBoard')}</p>
                  <div className="qr-tab-grid">
                    <div className="qr-tab-code"><QrPanel url={diceUrl} /></div>
                    <div className="qr-tab-info">
                      <label className="qr-ip-label">{t('workflow.laptopIPOnTheLocalNetwork')} <input
                          type="text"
                          value={laptopIp}
                          placeholder={t('dice.ipExample')}
                          onChange={(event: React.ChangeEvent<HTMLInputElement>) => { setLaptopIp(event.target.value); setDiceUrlCopied(false); }}
                        />
                      </label>
                      {hostIsLocal && <p className="board-dice-warning">{t('workflow.theURLCurrentlyPointsTo')}{host}{t('workflow.onAPhone')} <code>localhost</code> {t('workflow.pointsToThePhoneItselfEnterThe')} <code>ipconfig</code> {t('workflow.iPv4Address')}</p>}
                      <div className="qr-url-row">
                        <code className="qr-url">{diceUrl}</code>
                        <button
                          type="button"
                          className="small"
                          onClick={() => {
                            void navigator.clipboard?.writeText(diceUrl).then(() => setDiceUrlCopied(true)).catch(() => setDiceUrlCopied(false));
                          }}
                        >{diceUrlCopied ? t('dice.copied') : t('dice.copyUrl')}</button>
                      </div>
                      <ul className="qr-hints muted">
                        <li>{t('dice.networkNotice')}</li>
                        <li>{t('workflow.phoneAndLaptopMustUseTheSame')}</li>
                        <li>{t('workflow.aWindowsFirewallMayBlockAccessTo')} {window.location.port || '5173'} {t('workflow.inThatCaseRollOnTheLaptop')}</li>
                        <li>{t('workflow.concurrentRollsLaptopAndPhoneRequireConfirmation')}</li>
                      </ul>
                    </div>
                  </div>
                </div>
              )}
            </article>
          </div>
        );
      })()}

      <section className="layout">
        <aside className="panel">
          <h2>{t('tournaments.title')}</h2>
          <div className="tournament-start-actions">
            <button type="button" onClick={() => setIsCreateTournamentOpen(previous => !previous)} aria-expanded={isCreateTournamentOpen}>
              {isCreateTournamentOpen ? t('tournaments.closeCreate') : t('tournaments.create')}
            </button>
            <button type="button" className="secondary" onClick={() => void createDemoTournament()} disabled={demoBusy || !backendReady}>
              {demoBusy ? t('tournaments.demoPreparing') : t('tournaments.openDemo')}
            </button>
          </div>
          {isCreateTournamentOpen && (
            <form onSubmit={(event) => void createTournament(event)} className="stack create-tournament-form">
              <label>{t('tournaments.name')}
                <input value={newTournamentName} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setNewTournamentName(event.target.value)} placeholder={t('tournaments.namePlaceholder')} required />
              </label>
              <label>{t('tournaments.format')}
                <select value={format} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setFormat(Number(event.target.value))}>
                  {formatOptions.map(option => <option key={option.value} value={option.value}>{lang === 'en' ? (option.value === 1 ? 'Swiss system' : 'Round robin') : option.label}</option>)}
                </select>
              </label>
              {format === 1 && (
                <details className="advanced-settings">
                  <summary>{t('tournaments.advancedPairing')}</summary>
                  <label>{t('tournaments.pairing')}
                    <select value={pairingStrategy} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setPairingStrategy(Number(event.target.value))}>
                      {pairingStrategyOptions.map(option => <option key={option.value} value={option.value}>{lang === 'en' && option.value === 0 ? 'Optimal V2 (recommended)' : option.label}</option>)}
                    </select>
                  </label>
                  <p className="muted">{lang === 'en'
                    ? 'Optimal V2 remains the proven default. FIDE Dutch uses the implemented Dutch criteria and creates a detailed audit note; this is not FIDE certification.'
                    : t('workflow.optimalV2RemainsTheDefaultFIDEDutch')}</p>
                  {pairingStrategy === 1 && (
                    <label>{t('tournaments.initialColour')}
                      <select value={swissInitialColour} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setSwissInitialColour(Number(event.target.value))}>
                        {swissInitialColourOptions.map(option => <option key={option.value} value={option.value}>{lang === 'en' ? (option.value === 1 ? 'White' : 'Black') : option.label}</option>)}
                      </select>
                    </label>
                  )}
                </details>
              )}
              <div className="create-summary" aria-live="polite">
                <strong>{t('tournaments.summary')}</strong>
                <span>{newTournamentName.trim() || (lang === 'en' ? 'Untitled' : 'Unbenannt')} · {lang === 'en' ? (format === 1 ? 'Swiss system' : 'Round robin') : formatOptions.find(option => option.value === format)?.label}</span>
                {format === 1 && <span>{lang === 'en' && pairingStrategy === 0 ? 'Optimal V2 (recommended)' : pairingStrategyOptions.find(option => option.value === pairingStrategy)?.label}</span>}
              </div>
              <button type="submit" disabled={!newTournamentName.trim() || creatingTournament || !backendReady}>
                {creatingTournament
                  ? (lang === 'en' ? 'Creating …' : 'Wird angelegt …')
                  : t('tournaments.createNow')}
              </button>
            </form>
          )}
          <div className="list">
            {tournaments.length === 0 && <p className="muted">{t('tournaments.none')}</p>}
            {tournaments.map(tournament => (
              <button
                type="button"
                key={tournament.id}
                className={tournament.id === selectedTournament?.id ? 'selected' : ''}
                onClick={() => setSelectedId(tournament.id)}
              >
                {tournament.name}<small>{tournament.players.length} {lang === 'en' ? 'players' : t('nav.participants')} · {tournament.rounds.length} {lang === 'en' ? 'rounds' : t('workflow.rounds')}</small>
              </button>
            ))}
          </div>
        </aside>

        <section className="panel main-panel">
          <div className="panel-header">
            <div>
              <h2>{selectedTournament?.name ?? t('tournaments.noSelection')}</h2>
              <p>{selectedTournament ? `${selectedTournament.players.length} ${lang === 'en' ? 'players' : t('nav.participants')} · ${selectedTournament.rounds.length} ${lang === 'en' ? 'rounds' : t('workflow.rounds')}` : (lang === 'en' ? 'Create a tournament first.' : t('workflow.createATournamentFirst'))}</p>
            </div>
            {activeMainTab === 'rounds' && <div className="actions">
              <button type="button" className="secondary" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>{t('rounds.preview')}</button>
              <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>{t('rounds.pairNext')}</button>
            </div>}
          </div>

          <nav className="tab-bar" role="tablist" aria-label={lang === 'en' ? 'Tournament areas' : 'Turnierbereiche'}>
            {mainTabs.filter(tab => !tab.secondary).map(tab => (
              <button
                key={tab.id}
                type="button"
                role="tab"
                aria-selected={activeMainTab === tab.id || (tab.id === 'more' && ['assistant', 'print', 'admin'].includes(activeMainTab))}
                className={`tab-button${activeMainTab === tab.id || (tab.id === 'more' && ['assistant', 'print', 'admin'].includes(activeMainTab)) ? ' active' : ''}`}
                onClick={() => setActiveMainTab(tab.id)}
              >
                {t(tab.labelKey)}
              </button>
            ))}
          </nav>

          {activeMainTab === 'overview' && (
            <article className="card overview-card">
              <h3>{t('overview.title')}</h3>
              {!selectedTournament && (
                <div className="empty-state">
                  <p className="eyebrow">{t('overview.readyEyebrow')}</p>
                  <h4>{t('overview.readyTitle')}</h4>
                  <p>{t('overview.readyText')}</p>
                  <div className="actions">
                    <button type="button" onClick={() => setIsCreateTournamentOpen(true)}>{t('tournaments.create')}</button>
                    <button type="button" className="secondary" onClick={() => void createDemoTournament()} disabled={demoBusy || !backendReady}>{demoBusy ? t('tournaments.demoPreparing') : t('tournaments.openDemo')}</button>
                  </div>
                  <small>{t('overview.demoPrivacy')}</small>
                </div>
              )}
              {selectedTournament && (
                <>
                  <div className="overview-grid">
                    <div><span>{t('operator.tournament')}</span><strong>{selectedTournament.name}</strong></div>
                    <div><span>{t('tournaments.format')}</span><strong>{lang === 'en' ? (selectedTournament.settings.format === 1 ? 'Swiss system' : 'Round robin') : formatOptions.find(option => option.value === selectedTournament.settings.format)?.label ?? '–'}</strong></div>
                    {selectedTournament.settings.format === 1 && <div><span>{t('tournaments.pairing')}</span><strong>{lang === 'en' && (selectedTournament.settings.pairingStrategy ?? 0) === 0 ? 'Optimal V2 (recommended)' : pairingStrategyOptions.find(option => option.value === (selectedTournament.settings.pairingStrategy ?? 0))?.label ?? 'Optimal V2'}</strong></div>}
                    <div><span>{t('operator.round')}</span><strong>{operatorRoundLabel()}</strong></div>
                    <div><span>{t('rounds.status')}</span><strong>{resultReviewStatusDisplayLabel()}</strong></div>
                    <div><span>{t('operator.openResults')}</span><strong>{totalOpenBoardCount()}</strong></div>
                    <div><span>{t('nav.participants')}</span><strong>{activePlayerCount()} {t('operator.active')} · {inactivePlayerCount()} {t('operator.inactive')}</strong></div>
                    <div><span>{t('backend.title')}</span><strong>{health ? `${t('backend.online')} · ${health.version}` : t('backend.offline')}</strong></div>
                    <div><span>{t('operator.lastBackup')}</span><strong>{backupRecommended ? t('operator.backupRecommended') : lastBackupAt ? t('operator.backupCurrent') : t('operator.backupNone')}</strong><small>{backupTimeLabel(lastBackupAt, lang === 'en')}</small></div>
                  </div>
                  {(() => {
                    const step = nextOperatorStep();
                    return (
                      <div className={`overview-next tone-${step.tone}`}>
                        <div>
                          <span className="operator-next-eyebrow">{t('operator.nextStep')}</span>
                          <strong>{step.title}</strong>
                          <p>{step.detail}</p>
                        </div>
                        {step.action && step.actionLabel && (
                          <button type="button" onClick={step.action}>{step.actionLabel}</button>
                        )}
                      </div>
                    );
                  })()}
                  <details className="operator-checklist">
                    <summary>{t('workflow.venueChecklistLaptopAdvice')}</summary>
                    <div className="operator-checklist-body">
                      <ul>
                        <li>{t('workflow.backendReadyTheBackendIndicatorAboveMust')} <strong>{t('backend.online')}</strong> sein)</li>
                        <li>{t('workflow.exportABackupBeforePairingRound1')}</li>
                        <li>{t('workflow.checkParticipantsCountNamesFIDEIDs')}</li>
                        <li>{t('workflow.provideWaterShadeAndSunProtection')}</li>
                        <li>{t('workflow.printTheCurrentRoundSheet')}</li>
                        <li>{t('workflow.rollChess960PositionsForAChess960Tournament')}</li>
                        <li>{t('workflow.enterResultsAfterEachRoundAndWait')}</li>
                        <li>{t('workflow.exportABackupAfterEachRound')}</li>
                      </ul>
                      <p className="operator-power-note">
                        <strong>{t('workflow.power')}</strong> {t('workflow.connectTheLaptopToMainsPowerPrevent')} </p>
                    </div>
                  </details>
                </>
              )}
            </article>
          )}

          {activeMainTab === 'more' && (
            <article className="card more-card">
              <p className="eyebrow">{t('more.eyebrow')}</p>
              <h3>{t('more.title')}</h3>
              <p className="muted">{t('more.intro')}</p>
              <div className="more-grid">
                <button type="button" className="more-link" onClick={() => setActiveMainTab('assistant')}>
                  <strong>{t('more.assistant')}</strong><span>{t('more.assistantDetail')}</span>
                </button>
                <button type="button" className="more-link" onClick={() => setActiveMainTab('print')}>
                  <strong>{t('more.exports')}</strong><span>{t('more.exportsDetail')}</span>
                </button>
                <button type="button" className="more-link" onClick={() => setActiveMainTab('admin')}>
                  <strong>{t('more.admin')}</strong><span>{t('more.adminDetail')}</span>
                </button>
              </div>
              <div className="privacy-note">{t('more.privacy')}</div>
            </article>
          )}

          {activeMainTab === 'assistant' && (
            <article className="card assistant-card">
              <div className="assistant-header">
                <div>
                  <p className="eyebrow">{t('workflow.tournamentAssistantLocalWithoutAnAIAPI')}</p>
                  <h3>{t('workflow.whichFormatFits')}</h3>
                  <p className="muted">{t('workflow.theAssistantRecommendsTournamentSettingsBasedOn')}</p>
                </div>
                <div className={`assistant-fit ${assistantRecommendation.timeFit}`}>
                  <strong>{assistantRecommendation.timeFitLabel}</strong>
                  <span>{assistantRecommendation.estimatedTotalMinutes} {t('workflow.estimatedMinutes')}</span>
                </div>
              </div>
              <div className="assistant-grid">
                <section className="assistant-form">
                  <label>{t('workflow.scenario')} <select value={assistantForm.scenario} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => setAssistantForm({ ...assistantForm, scenario: event.target.value as TournamentAssistantScenario })}>
                      {assistantScenarioOptions.map(option => <option key={option.value} value={option.value}>{optionLabel(option, lang === 'en')}</option>)}
                    </select>
                  </label>
                  <p className="muted">{((option) => lang === 'en' ? option?.descriptionEn : option?.description)(assistantScenarioOptions.find(option => option.value === assistantForm.scenario))}</p>
                  <div className="settings-grid compact">
                    <label>{t('nav.participants')} <input type="number" min="2" max="512" value={assistantForm.playerCount} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, playerCount: event.target.value })} />
                    </label>
                    <label>{t('workflow.timeInMinutes')} <input type="number" min="30" max="1440" value={assistantForm.availableMinutes} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, availableMinutes: event.target.value })} />
                    </label>
                    <label>{t('workflow.boards2')} <input type="number" min="1" max="256" value={assistantForm.boardCount} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, boardCount: event.target.value })} />
                    </label>
                  </div>
                  <div className="checkbox-row">
                    <label className="checkbox"><input type="checkbox" checked={assistantForm.rated} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, rated: event.target.checked })} /> {t('workflow.ratedTournamentPlanned')}</label>
                    <label className="checkbox"><input type="checkbox" checked={assistantForm.chess960} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, chess960: event.target.checked })} /> Chess960/Freestyle</label>
                    <label className="checkbox"><input type="checkbox" checked={assistantForm.needsQr} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setAssistantForm({ ...assistantForm, needsQr: event.target.checked })} /> {t('workflow.useQRMobileAtTheBoard')}</label>
                  </div>
                  <div className="actions">
                    <button type="button" onClick={applyAssistantRecommendation}>{t('workflow.applyRecommendation')}</button>
                    <button type="button" className="secondary" onClick={() => downloadText(`turnierassistent-${backupTimestampSlug(new Date())}.txt`, assistantRecommendation.handoffPrompt, 'text/plain;charset=utf-8')}>{t('workflow.exportPromptPlan')}</button>
                  </div>
                </section>
                <section className="assistant-result">
                  <h4>{assistantRecommendation.title}</h4>
                  <div className="overview-grid assistant-metrics">
                    <div><span>{t('tournaments.format')}</span><strong>{assistantRecommendation.formatLabel}</strong></div>
                    <div><span>{t('workflow.rounds')}</span><strong>{assistantRecommendation.plannedRounds}</strong></div>
                    <div><span>{t('workflow.boards2')}</span><strong>{assistantRecommendation.estimatedBoards}</strong></div>
                    <div><span>{t('standings.points')}</span><strong>{assistantRecommendation.scoringLabel}</strong></div>
                  </div>
                  {assistantRecommendation.warnings.length > 0 && (
                    <div className="assistant-warning">
                      <strong>{t('workflow.review')}</strong>
                      <ul>{assistantRecommendation.warnings.map((warning, index) => <li key={`assistant-warning-${index}`}>{warning}</li>)}</ul>
                    </div>
                  )}
                  <div className="assistant-columns">
                    <section>
                      <strong>{t('workflow.setupSteps')}</strong>
                      <ol>{assistantRecommendation.setupSteps.map((step, index) => <li key={`assistant-step-${index}`}>{step}</li>)}</ol>
                    </section>
                    <section>
                      <strong>{t('workflow.tournamentDayChecklist')}</strong>
                      <ul>{assistantRecommendation.operatorChecklist.map((item, index) => <li key={`assistant-check-${index}`}>{item}</li>)}</ul>
                    </section>
                    <section>
                      <strong>{t('workflow.exportPublication')}</strong>
                      <ul>{assistantRecommendation.exportPlan.map((item, index) => <li key={`assistant-export-${index}`}>{item}</li>)}</ul>
                    </section>
                  </div>
                  <details className="audit-box assistant-handoff">
                    <summary>{t('workflow.showHandoffPrompt')}</summary>
                    <p>{assistantRecommendation.handoffPrompt}</p>
                  </details>
                </section>
              </div>
              <section className="knowledge-chat-card">
                <div className="assistant-header compact-header">
                  <div>
                    <p className="eyebrow">{t('workflow.localHelpChatRUN1011Foundation')}</p>
                    <h4>{t('workflow.askTournamentHelp')}</h4>
                    <p className="muted">{t('workflow.ruleBasedKnowledgeBaseForOperationPairing')}</p>
                    <small className="knowledge-source-meta">{t('workflow.knowledgeBase')} {localKnowledgeBase.sourceVersion} {t('workflow.updated')} {localKnowledgeBase.sourceUpdated}</small>
                  </div>
                  <span className="knowledge-privacy-pill" title={localKnowledgeBase.privacyNotice}>{t('workflow.offlineLocal')}</span>
                </div>
                <div className="knowledge-quick-actions">
                  {knowledgeQuickQuestions.map(question => (
                    <button key={question} type="button" className="small secondary" onClick={() => askKnowledgeChat(question)}>{question}</button>
                  ))}
                </div>
                <div className="knowledge-chat-log" aria-live="polite">
                  {knowledgeChatMessages.length === 0 && <p className="knowledge-welcome">{t('knowledge.welcome')}</p>}
                  {knowledgeChatMessages.map(message => (
                    <article key={message.id} className={`knowledge-message ${message.role}`}>
                      <strong>{message.role === 'user' ? t('knowledge.you') : t('knowledge.help')}</strong>
                      {message.text.split('\n').map((line, index) => line ? <p key={`${message.id}-${index}`}>{line}</p> : <br key={`${message.id}-${index}`} />)}
                      {message.sources.length > 0 && <small>{t('workflow.sources')} {message.sources.join(' · ')}</small>}
                    </article>
                  ))}
                </div>
                <div className="knowledge-chat-input">
                  <input
                    type="text"
                    value={knowledgeChatInput}
                    onChange={(event: React.ChangeEvent<HTMLInputElement>) => setKnowledgeChatInput(event.target.value)}
                    onKeyDown={(event: React.KeyboardEvent<HTMLInputElement>) => {
                      if (event.key === 'Enter') {
                        event.preventDefault();
                        askKnowledgeChat();
                      }
                    }}
                    placeholder={t('workflow.askAQuestionEGWhatShould')}
                  />
                  <button type="button" onClick={() => askKnowledgeChat()} disabled={!knowledgeChatInput.trim()}>{t('workflow.answer')}</button>
                  <button type="button" className="secondary" disabled={knowledgeChatMessages.length === 0} onClick={() => downloadText(`lokale-turnierhilfe-${backupTimestampSlug(new Date())}.txt`, knowledgeChatMessages.map(message => `${message.role === 'user' ? t('knowledge.you') : t('knowledge.help')}:\n${message.text}`).join('\n\n---\n\n'), 'text/plain;charset=utf-8')}>{t('workflow.exportChat')}</button>
                </div>
              </section>
            </article>
          )}

          {activeMainTab === 'rounds' && pendingResultChange && (
            <article className="card result-confirm" role="alertdialog" aria-modal="true" aria-labelledby="result-confirm-title">
              <div>
                <p className="eyebrow">{t('result.confirmEyebrow')}</p>
                <h3 id="result-confirm-title">{t('result.confirmTitle')}</h3>
                <p>{t('rounds.round')} {pendingResultChange.roundNumber}, {t('rounds.board')} {pendingResultChange.boardNumber}: <strong>{resultLabel(pendingResultChange.previousResult, lang === 'en')}</strong> → <strong>{resultLabel(pendingResultChange.result, lang === 'en')}</strong></p>
                {pendingResultChange.previousResult !== 0 && (
                  <label className="correction-reason">{t('result.correctionReasonLabel')}
                    <textarea value={correctionReason} maxLength={500} rows={2}
                      onChange={event => setCorrectionReason(event.target.value)} aria-describedby="correction-reason-hint" />
                    <small id="correction-reason-hint">{t('result.correctionReasonHint')}</small>
                  </label>
                )}
                <label><input type="checkbox" checked={localQueueEnabled} onChange={event => setLocalQueueEnabled(event.target.checked)} />
                  {lang === 'en' ? 'Keep this result in this browser until the server acknowledges it (up to 200 entries).'
                    : t('workflow.keepTheResultInThisBrowserUntil')}</label>
              </div>
              <div className="actions">
                <button type="button" className="secondary" onClick={closeResultConfirmation}>{t('common.cancel')}</button>
                <button ref={resultConfirmButtonRef} type="button" disabled={resultSaving} aria-busy={resultSaving} onClick={() => void confirmResultChange()}>{t('result.save')}</button>
              </div>
            </article>
          )}
          {activeMainTab === 'rounds' && !pendingResultChange && lastResultChange && (
            <div className="undo-bar" role="status">
              <span>{lang === 'en' ? `Result saved: round ${lastResultChange.roundNumber}, board ${lastResultChange.boardNumber}.` : t('workflow.resultSavedRoundBoard2', { p0: lastResultChange.roundNumber, p1: lastResultChange.boardNumber })}</span>
              <button type="button" className="small secondary" onClick={() => void undoLastResultChange()}>{t('result.undo')}</button>
            </div>
          )}

          {activeMainTab === 'rounds' && nextRoundPreview && (
            <article className={`card preview-card ${pairingQualitySeverityClass(nextRoundPreview.pairingQuality.severity)}`}>
              <div className="preview-card-header">
                <div>
                  <p className="eyebrow">{lang === 'en' ? 'Preview · not saved yet' : t('workflow.previewNotSavedYet')}</p>
                  <h3>{lang === 'en' ? `Pairing preview for round ${nextRoundPreview.roundNumber}` : t('workflow.roundPairingPreview', { p0: nextRoundPreview.roundNumber })}</h3>
                  <p className="muted">{lang === 'en' ? 'Review the proposed boards and quality score before creating the round.' : nextRoundPreview.summary}</p>
                </div>
                <div className="preview-score">
                  <strong>{nextRoundPreview.pairingQuality.qualityScore}/100</strong>
                  <span>{pairingQualitySeverityLabel(nextRoundPreview.pairingQuality.severity, lang === 'en')}</span>
                </div>
              </div>
              <div className="preview-metrics">
                <span>{nextRoundPreview.boardCount} {lang === 'en' ? 'boards' : t('workflow.boards2')}</span>
                <span>{nextRoundPreview.pairingQuality.rematchCount} Rematches</span>
                <span>{nextRoundPreview.pairingQuality.crossScoreGroupPairingCount} {lang === 'en' ? 'cross-score-group pairings' : 'Scoregruppen-Abweichungen'}</span>
                <span>{nextRoundPreview.pairingQuality.thirdSameColorRiskCount} {lang === 'en' ? 'colour-sequence risks' : 'Farbfolge-Risiken'}</span>
                <span>{nextRoundPreview.pairingQuality.byeCount} Bye</span>
              </div>
              {nextRoundPreview.pairingQuality.hasCriticalIssues && <div className="preview-warning critical"><strong>{lang === 'en' ? 'Critical preview:' : 'Kritische Vorschau:'}</strong> {lang === 'en' ? 'Review pairings, rematches and colour sequences. Some constraints can be unavoidable in small events.' : t('workflow.checkPairingsRematchesAndColourSequencesSome')}</div>}
              {!nextRoundPreview.isSavable && <div className="preview-warning critical"><strong>{lang === 'en' ? 'Cannot be saved:' : 'Nicht speicherbar:'}</strong> {lang === 'en' ? 'This preview cannot be accepted. Review the technical notes.' : t('workflow.thisPreviewCannotBeAppliedReviewThe')}</div>}
              {(nextRoundPreview.messages.length > 0 || nextRoundPreview.pairingQuality.findings.length > 0) && (
                <details className="preview-audit-notes">
                  <summary>{lang === 'en' ? 'Technical pairing notes' : 'Technische Paarungshinweise'}</summary>
                  {nextRoundPreview.messages.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.messages.map((message, index) => <li key={`preview-message-${index}`}>{message}</li>)}</ul>}
                  {nextRoundPreview.pairingQuality.findings.length > 0 && <ul className="message-list preview-message-list">{nextRoundPreview.pairingQuality.findings.map((finding, index) => <li key={`preview-quality-${index}`}>{finding}</li>)}</ul>}
                </details>
              )}
              <div className="table-scroll compact preview-pairings">
                <table>
                  <thead><tr><th>{t('rounds.board')}</th><th>{t('rounds.white')}</th><th>{t('rounds.black')}</th><th>{lang === 'en' ? 'Score before round' : t('workflow.scoreBeforeRound')}</th><th>{lang === 'en' ? 'Notes' : t('workflow.notices')}</th></tr></thead>
                  <tbody>
                    {nextRoundPreview.pairingQuality.boards.map(board => (
                      <tr key={`preview-board-${board.boardNumber}`} className={board.isRematch ? 'quality-board-critical' : board.wouldGiveWhiteThirdSameColor || board.wouldGiveBlackThirdSameColor ? 'quality-board-warning' : board.isCrossScoreGroupPairing || board.isBye ? 'quality-board-notice' : ''}>
                        <td>{board.boardNumber}</td>
                        <td>{board.whiteName}</td>
                        <td>{board.isBye ? t('rounds.bye') : board.blackName}</td>
                        <td>{board.isBye ? 'Bye' : `${board.whiteScoreBeforeRound} : ${board.blackScoreBeforeRound}`}</td>
                        <td>{board.findings.length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{board.findings.map((finding, index) => <li key={`preview-board-${board.boardNumber}-${index}`}>{finding}</li>)}</ul>}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
              <details className="audit-box preview-audit">
                <summary>{lang === 'en' ? 'Show preview audit' : 'Audit der Vorschau anzeigen'}</summary>
                <div className="audit-grid">
                  <section><strong>{lang === 'en' ? 'Notes' : t('workflow.notices')}</strong><ul>{nextRoundPreview.round.audit.messages.map((message, index) => <li key={`preview-audit-message-${index}`}>{message}</li>)}</ul></section>
                  <section><strong>{lang === 'en' ? 'Score groups' : t('workflow.scoreGroups')}</strong><ul>{nextRoundPreview.round.audit.scoreGroups.map((message, index) => <li key={`preview-audit-score-${index}`}>{message}</li>)}</ul></section>
                  <section><strong>{t('workflow.floater')}</strong><ul>{nextRoundPreview.round.audit.floaters.length === 0 ? <li>{t('workflow.none')}</li> : nextRoundPreview.round.audit.floaters.map((message, index) => <li key={`preview-audit-floater-${index}`}>{message}</li>)}</ul></section>
                  <section><strong>{lang === 'en' ? 'Colours' : t('workflow.colours')}</strong><ul>{nextRoundPreview.round.audit.colorNotes.map((message, index) => <li key={`preview-audit-color-${index}`}>{message}</li>)}</ul></section>
                </div>
              </details>
              <div className="actions preview-actions">
                <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>{lang === 'en' ? 'Create this round' : t('workflow.pairThisRoundNow')}</button>
                <button type="button" className="secondary" onClick={openNextRoundPreviewPrint}>{lang === 'en' ? 'Open print view' : t('workflow.openPrintView')}</button>
                <button type="button" className="secondary" onClick={openNextRoundPreviewCsv}>{lang === 'en' ? 'Export CSV' : t('workflow.exportCSV')}</button>
                <button type="button" className="secondary" onClick={() => setIsNextRoundPreviewDialogOpen(true)}>{lang === 'en' ? 'Open dialog' : t('workflow.openAsPopup')}</button>
                <button type="button" className="secondary" onClick={() => { setNextRoundPreview(null); setIsNextRoundPreviewDialogOpen(false); }}>{lang === 'en' ? 'Close preview' : t('workflow.closePreview')}</button>
              </div>
            </article>
          )}
          {activeMainTab === 'admin' && (
            <article className="card admin-danger-card">
              <h3>{t('workflow.dangerousActions')}</h3>
              <p className="muted">{t('workflow.resetKeepsParticipantsAndSettingsButRemoves')}</p>
              <div className="actions">
                <button type="button" className="secondary" onClick={() => openDestructiveDialog('reset')} disabled={!selectedTournament}>{t('workflow.resetTournament')}</button>
                <button type="button" className="danger" onClick={() => openDestructiveDialog('delete')} disabled={!selectedTournament}>{t('workflow.deleteTournament')}</button>
              </div>
            </article>
          )}
          {activeMainTab === 'admin' && (
          <article className="card settings-card">
            <h3>{t('workflow.tournamentSettings')}</h3>
            <form onSubmit={(event) => void saveSettings(event)} className="settings-form">
              <div className="settings-grid">
                <label>{t('tournaments.format')} <select value={settingsForm.format} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updateSettingsForm({ ...settingsForm, format: Number(event.target.value) })} disabled={(selectedTournament?.rounds.length ?? 0) > 0}>
                    {formatOptions.map(option => <option key={option.value} value={option.value}>{optionLabel(option, lang === 'en')}</option>)}
                  </select>
                </label>
                {settingsForm.format === 1 && <label>{t('tournaments.pairing')} <select value={settingsForm.pairingStrategy} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updateSettingsForm({ ...settingsForm, pairingStrategy: Number(event.target.value) })} disabled={(selectedTournament?.rounds.length ?? 0) > 0}>
                    {pairingStrategyOptions.map(option => <option key={option.value} value={option.value}>{optionLabel(option, lang === 'en')}</option>)}
                  </select>
                  <small className="field-help">{t('workflow.optimalV2RemainsTheDefaultTheSelection')}</small>
                </label>}
                {settingsForm.format === 1 && settingsForm.pairingStrategy === 1 && <label>{t('workflow.initialColour')} <select value={settingsForm.swissInitialColour} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updateSettingsForm({ ...settingsForm, swissInitialColour: Number(event.target.value) })} disabled={(selectedTournament?.rounds.length ?? 0) > 0}>
                    {swissInitialColourOptions.map(option => <option key={option.value} value={option.value}>{optionLabel(option, lang === 'en')}</option>)}
                  </select>
                  <small className="field-help">{t('workflow.usedOnlyForFIDEDutchWhenBoth')}</small>
                </label>}
                <label>{t('workflow.scoringSystem')} <select value={settingsForm.scoringSystem} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updateSettingsForm({ ...settingsForm, scoringSystem: Number(event.target.value) })}>
                    {scoringOptions.map(option => <option key={option.value} value={option.value}>{optionLabel(option, lang === 'en')}</option>)}
                  </select>
                </label>
                <label>{t('workflow.tournamentRatingSource')} <select value={settingsForm.twzSource} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updateSettingsForm({ ...settingsForm, twzSource: Number(event.target.value) })}>
                    {twzSourceOptions.map(option => <option key={option.value} value={option.value}>{optionLabel(option, lang === 'en')}</option>)}
                  </select>
                </label>
                <label>{t('workflow.plannedRounds')} <input type="number" min="1" max="99" value={settingsForm.plannedRounds} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updateSettingsForm({ ...settingsForm, plannedRounds: event.target.value })} />
                </label>
                <label>{t('workflow.forfeits')} <select value={settingsForm.forfeitTiebreakPolicy} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updateSettingsForm({ ...settingsForm, forfeitTiebreakPolicy: Number(event.target.value) })}>
                    {forfeitPolicyOptions.map(option => <option key={option.value} value={option.value}>{optionLabel(option, lang === 'en')}</option>)}
                  </select>
                </label>
                <label>{t('workflow.unplayedRoundsBuchholz')} <select value={settingsForm.unplayedRoundBuchholzMode} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updateSettingsForm({ ...settingsForm, unplayedRoundBuchholzMode: Number(event.target.value) })}>
                    {unplayedRoundBuchholzOptions.map(option => <option key={option.value} value={option.value}>{optionLabel(option, lang === 'en')}</option>)}
                  </select>
                </label>
                <label>{t('workflow.seniorsBirthYearOrEarlier')} <input type="number" min="1900" max="2100" value={settingsForm.seniorBirthYearOrEarlier} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updateSettingsForm({ ...settingsForm, seniorBirthYearOrEarlier: event.target.value })} placeholder="z. B. 1966" />
                </label>
                <label>{t('workflow.heroCupMinimumGames')} <input type="number" min="1" max="99" value={settingsForm.heroCupMinimumRatedGames} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updateSettingsForm({ ...settingsForm, heroCupMinimumRatedGames: event.target.value })} />
                </label>
              </div>
              <p className="muted">{t('workflow.inFIDEModeTheForfeitPolicyTakes')}</p>
              <div className="checkbox-row">
                <label className="checkbox"><input type="checkbox" checked={settingsForm.countByeAsWin} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updateSettingsForm({ ...settingsForm, countByeAsWin: event.target.checked })} /> {t('workflow.countAByeAsAWin')}</label>
                <label className="checkbox"><input type="checkbox" checked={settingsForm.allowManualPairingOverrides} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updateSettingsForm({ ...settingsForm, allowManualPairingOverrides: event.target.checked })} /> {t('workflow.allowManualPairings')}</label>
              </div>
              <div className="tiebreak-editor">
                <strong>{t('workflow.tieBreakOrder')}</strong>
                <p className="muted">{t('workflow.afterPointsTieBreaksAreAppliedIn')}</p>
                <div className="tiebreak-list">
                  {settingsForm.tiebreaks.map((value, index) => (
                    <div key={`${value}-${index}`} className="tiebreak-item">
                      <span>{index + 1}. {tiebreakLabel(value, lang === 'en')}</span>
                      <button type="button" className="small secondary" onClick={() => updateSettingsForm({ ...settingsForm, tiebreaks: moveTiebreak(settingsForm.tiebreaks, index, -1) })} disabled={index === 0}>↑</button>
                      <button type="button" className="small secondary" onClick={() => updateSettingsForm({ ...settingsForm, tiebreaks: moveTiebreak(settingsForm.tiebreaks, index, 1) })} disabled={index === settingsForm.tiebreaks.length - 1}>↓</button>
                      <button type="button" className="small danger" onClick={() => toggleTiebreak(value, false)} disabled={value === 99 && settingsForm.tiebreaks.length === 1}>{t('workflow.remove')}</button>
                    </div>
                  ))}
                </div>
                <div className="tiebreak-add">
                  {tiebreakOptions.filter(option => !settingsForm.tiebreaks.includes(option.value)).map(option => (
                    <button key={option.value} type="button" className="small" onClick={() => toggleTiebreak(option.value, true)}>+ {optionLabel(option, lang === 'en')}</button>
                  ))}
                </div>
              </div>
              <button type="submit" disabled={!selectedTournament}>{t('workflow.saveSettings')}</button>
            </form>
          </article>
          )}

          {activeMainTab === 'participants' && (
          <div className={showAdvancedStandings ? 'grid two' : 'grid'}>
            <article className="card external-lookup-card">
              <h3>{lang === 'en' ? 'Find a player' : t('workflow.findPlayer')}</h3>
              <p className="muted">{lang === 'en' ? 'Available sources are checked together. FIDE ID lookup is active; prepared but inactive sources are labelled clearly.' : t('workflow.oneSearchChecksAllAvailableSourcesAnd')}</p>
              <form onSubmit={(event) => void searchExternalPlayers(event)} className="external-lookup-form single">
                <input aria-label={lang === 'en' ? 'Player name or FIDE ID' : 'Spielername oder FIDE-ID'} value={externalQuery} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setExternalQuery(event.target.value)} placeholder={lang === 'en' ? 'Name or FIDE ID' : 'Name oder FIDE-ID (z. B. 99900123)'} />
                <button type="submit" disabled={externalSearching}>{externalSearching ? (lang === 'en' ? 'Searching …' : t('workflow.searching')) : (lang === 'en' ? 'Find player' : t('workflow.findPlayer'))}</button>
              </form>
              {externalLookup && (
                <div className="lookup-results">
                  <strong>{lang === 'en' ? `${externalLookup.players.length} player(s) found. Source availability is shown below.` : externalLookup.message}</strong>
                  {externalLookup.sources.length > 0 && (
                    <ul className="source-status-list">
                      {externalLookup.sources.map(source => (
                        <li key={source.source} className={source.isActive ? 'source-active' : 'source-prepared'}>
                          <span className="source-badge">{source.isActive ? (lang === 'en' ? 'active' : 'aktiv') : (lang === 'en' ? 'prepared' : 'vorbereitet')}</span>
                          <strong>{source.sourceName}</strong>
                          {source.isActive ? (source.status === 3 ? (lang === 'en' ? ' · temporarily unavailable' : ' · vorübergehend nicht verfügbar') : ` · ${source.count} ${lang === 'en' ? 'match(es)' : 'Treffer'}`) : ' ' + t('workflow.currentlyInactive')}
                        </li>
                      ))}
                    </ul>
                  )}
                  {externalLookup.players.length === 0 && <p className="muted">{t('workflow.noResultsAvailableToApply')} {externalLookup.mode === 'name' ? t('workflow.enterAFIDEIDForADirect') : ''}</p>}
                  {externalLookup.players.map(profile => {
                    const existingParticipant = existingParticipantForProfile(profile);
                    return (
                    <div key={`${profile.source}-${profile.externalId}`} className={`lookup-result${existingParticipant ? ' lookup-result-existing' : ''}`}>
                      <div>
                        <strong>{profile.name}{existingParticipant && <span className="participant-badge">{t('workflow.alreadyInTournament')}</span>}</strong>
                        <small>{profile.fideId ? `FIDE ${profile.fideId}` : profile.externalId} · {profile.federation ?? profile.country ?? (lang === 'en' ? 'no federation' : 'ohne Verband')} · Elo {profile.elo ?? '—'} · DWZ {profile.dwz ?? '—'} · {profile.birthYear ?? (lang === 'en' ? 'year ?' : 'Jahr ?')}</small>
                        {profile.profileUrl && <small><a href={profile.profileUrl} target="_blank" rel="noreferrer">{t('workflow.openProfile')}</a></small>}
                        {externalDuplicateChecks[externalProfileKey(profile)] && (
                          <div className="duplicate-box">
                            <strong>{externalDuplicateChecks[externalProfileKey(profile)].hasLikelyDuplicate ? t('workflow.possibleDuplicates') : t('workflow.noReliableDuplicate')}</strong>
                            {externalDuplicateChecks[externalProfileKey(profile)].matches.length === 0 && <small>{t('workflow.noExistingParticipantIsAReliableMatch')}</small>}
                            {externalDuplicateChecks[externalProfileKey(profile)].matches.map(match => (
                              <div key={`${profile.source}-${profile.externalId}-${match.playerId}`} className="duplicate-match">
                                <span>{match.playerName} · {duplicateKindLabel(match.kind, lang === 'en')} · Score {match.score}</span>
                                <small>{match.reason}</small>
                                <div className="actions">
                                  <button type="button" className="small" onClick={() => void applyExternalProfile(profile, match.playerId, false)}>{t('workflow.fillMissingParticipantData')}</button>
                                  <button type="button" className="small secondary" onClick={() => void applyExternalProfile(profile, match.playerId, true)}>{t('workflow.replaceWithExternalData')}</button>
                                </div>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                      <div className="lookup-actions">
                        <button type="button" className="small" onClick={() => applyExternalPlayer(profile)}>{t('workflow.useInForm')}</button>
                        <button type="button" className="small secondary" onClick={() => void checkExternalDuplicates(profile)} disabled={!selectedTournament}>{t('workflow.checkDuplicates')}</button>
                        {existingParticipant ? (
                          <button type="button" className="small secondary" onClick={() => editExistingFromProfile(existingParticipant)}>{t('workflow.openEditExistingParticipant')}</button>
                        ) : (
                          <button type="button" className="small" onClick={() => void applyExternalProfile(profile)} disabled={!selectedTournament}>{t('workflow.saveAsNewParticipant')}</button>
                        )}
                      </div>
                    </div>
                    );
                  })}
                </div>
              )}
            </article>

            <FideLookupPanel tournament={selectedTournament} lang={lang} onApplied={async () => { await refresh(selectedId); }} />
            <article className="card">
              <h3>{editingPlayerId ? (lang === 'en' ? 'Edit participant' : 'Teilnehmer bearbeiten') : (lang === 'en' ? 'Add participant' : 'Teilnehmer erfassen')}</h3>
              <form onSubmit={(event) => void savePlayer(event)} className="player-form wide">
                <input aria-label={lang === 'en' ? 'Name, required' : 'Name, erforderlich'} value={playerForm.name} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, name: event.target.value })} placeholder={lang === 'en' ? 'Name *' : 'Name *'} />
                <input aria-label={lang === 'en' ? 'Club' : 'Verein'} value={playerForm.club} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, club: event.target.value })} placeholder={lang === 'en' ? 'Club' : 'Verein'} />
                <input aria-label={lang === 'en' ? 'Federation' : 'Verband oder Federation'} value={playerForm.federation} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, federation: event.target.value })} placeholder={lang === 'en' ? 'Federation' : 'Verband/Federation'} />
                <input aria-label={lang === 'en' ? 'Country' : 'Land'} value={playerForm.country} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, country: event.target.value })} placeholder={lang === 'en' ? 'Country' : 'Land'} />
                <input aria-label={lang === 'en' ? 'Birth year' : 'Geburtsjahr'} value={playerForm.birthYear} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, birthYear: event.target.value })} placeholder={lang === 'en' ? 'Birth year' : 'Geburtsjahr'} type="number" min="1900" max="2100" />
                <select aria-label={lang === 'en' ? 'Gender category' : 'Geschlechtskategorie'} value={playerForm.gender} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updatePlayerForm({ ...playerForm, gender: Number(event.target.value) })}>
                  {genderOptions.map(option => <option key={option.value} value={option.value}>{lang === 'en' ? option.labelEn : option.label}</option>)}
                </select>
                <input aria-label="DWZ" value={playerForm.dwz} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, dwz: event.target.value })} placeholder="DWZ" type="number" min="0" />
                <input aria-label="DWZ-Index" value={playerForm.dwzIndex} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, dwzIndex: event.target.value })} placeholder="DWZ-Index" type="number" min="0" />
                <input aria-label="Elo Standard" value={playerForm.elo} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, elo: event.target.value })} placeholder="Elo Standard" type="number" min="0" />
                <input aria-label="Elo Rapid" value={playerForm.rapidElo} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, rapidElo: event.target.value })} placeholder="Elo Rapid" type="number" min="0" />
                <input aria-label="Elo Blitz" value={playerForm.blitzElo} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, blitzElo: event.target.value })} placeholder="Elo Blitz" type="number" min="0" />
                <input aria-label={lang === 'en' ? 'Manual tournament rating' : 'Manuelle Turnierwertungszahl'} value={playerForm.manualTwz} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, manualTwz: event.target.value })} placeholder={lang === 'en' ? 'Manual tournament rating' : 'TWZ manuell'} type="number" min="0" />
                <input aria-label="FIDE ID" value={playerForm.fideId} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, fideId: event.target.value })} placeholder="FIDE-ID" />
                <input aria-label="DSB ID" value={playerForm.nationalId} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, nationalId: event.target.value })} placeholder="DSB-ID" />
                <input aria-label={lang === 'en' ? 'Title' : 'Titel'} value={playerForm.title} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, title: event.target.value })} placeholder={lang === 'en' ? 'Title' : 'Titel'} />
                <select aria-label={lang === 'en' ? 'Participant status' : 'Teilnehmerstatus'} value={playerForm.status} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updatePlayerForm({ ...playerForm, status: Number(event.target.value) })}>
                  {playerStatusOptions.map(option => <option key={option.value} value={option.value}>{lang === 'en' ? option.labelEn : option.label}</option>)}
                </select>
                <input aria-label={lang === 'en' ? 'Notes' : 'Notizen'} value={playerForm.notes} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePlayerForm({ ...playerForm, notes: event.target.value })} placeholder={lang === 'en' ? 'Notes' : 'Notizen'} />
                <button type="submit" disabled={!selectedTournament}>{editingPlayerId ? (lang === 'en' ? 'Update' : 'Aktualisieren') : (lang === 'en' ? 'Save' : 'Speichern')}</button>
                {editingPlayerId && <button type="button" className="secondary" onClick={cancelPlayerEdit}>{t('common.cancel')}</button>}
              </form>
            </article>
          </div>
          )}

          {activeMainTab === 'participants' && (
          <article className="card participant-card">
            <div className="participant-heading">
              <div><h3>{t('participants.list')}</h3><small className="muted">{visiblePlayers.length} / {selectedTournament?.players.length ?? 0}</small></div>
              <label className="participant-search">{t('participants.filter')}
                <input type="search" value={participantSearch} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setParticipantSearch(event.target.value)} placeholder={t('participants.filterPlaceholder')} />
              </label>
            </div>
            <div className="table-scroll participant-scroll">
              <table className="participant-table">
                <thead><tr><th>#</th><th>{t('standings.name')}</th><th>{lang === 'en' ? 'Club' : 'Verein'}</th><th>FIDE</th><th>TWZ/DWZ</th><th>{lang === 'en' ? 'Year' : 'Jg.'}</th><th>{lang === 'en' ? 'Age' : 'Alter ca.'}</th><th>{lang === 'en' ? 'Category' : 'Kat.'}</th><th>{t('rounds.status')}</th><th>{lang === 'en' ? 'Actions' : t('workflow.action')}</th></tr></thead>
                <tbody>
                  {(selectedTournament?.players.length ?? 0) === 0 && (
                    <tr><td colSpan={10} className="muted">{lang === 'en' ? 'No participants yet.' : 'Noch keine Teilnehmer erfasst.'}</td></tr>
                  )}
                  {(selectedTournament?.players.length ?? 0) > 0 && visiblePlayers.length === 0 && (
                    <tr><td colSpan={10} className="muted">{lang === 'en' ? 'No participants match the filter.' : t('workflow.noParticipantsMatchTheFilter')}</td></tr>
                  )}
                  {visiblePlayers.map(player => (
                    <tr key={player.id} className={player.status === 2 ? 'muted-row' : ''}>
                      <td>{player.startingRank}</td>
                      <td className="col-name">{player.name}</td>
                      <td className="col-club">{player.club ?? '—'}</td>
                      <td>{player.fideId ?? '—'}</td>
                      <td>{twzOf(player, selectedTournament?.settings.twzSource)}</td>
                      <td>{player.birthYear ?? '—'}</td>
                      <td>{approximateAgeLabel(player.birthYear)}</td>
                      <td>{genderLabel(player.gender, lang === 'en')}</td>
                      <td>{statusLabel(player.status, lang === 'en')}</td>
                      <td className="actions col-actions">
                        <button type="button" className="small" onClick={() => editPlayer(player)}>{t('common.edit')}</button>
                        {player.status === 0
                          ? <button type="button" className="small" onClick={() => void setPlayerStatus(player, 2)}>{lang === 'en' ? 'Withdraw' : t('workflow.withdraw')}</button>
                          : <button type="button" className="small" onClick={() => void setPlayerStatus(player, 0)}>{lang === 'en' ? 'Activate' : 'Aktivieren'}</button>}
                        <button type="button" className="small danger" onClick={() => void deleteOrWithdrawPlayer(player)}>{t('common.delete')}</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </article>
          )}

          {activeMainTab === 'standings' && (
          <div className="grid two">
            <article className="card">
              <div className="standings-heading">
                <div><h3>{t('standings.live')}</h3><p className="muted">{t('standings.intro')}</p></div>
                <button type="button" className="secondary" aria-expanded={showAdvancedStandings} onClick={() => setShowAdvancedStandings(previous => !previous)}>{showAdvancedStandings ? t('standings.less') : t('standings.more')}</button>
              </div>
              <div className="table-scroll">
                <table>
                  <thead><tr><th>{t('standings.rank')}</th><th>{t('standings.name')}</th><th>{t('standings.points')}</th><th>{t('standings.wins')}</th><th>BH</th><th>SB</th>{showAdvancedStandings && <><th>{t('rounds.black')}</th><th>BH-1</th><th>BH-2</th><th>Median</th><th>Koya</th><th>Prog.</th><th>TPR</th></>}</tr></thead>
                  <tbody>
                    {standings.map(row => (
                      <tr key={row.playerId}>
                        <td>{row.rank}</td>
                        <td>{row.name}</td>
                        <td>{row.points}</td>
                        <td>{row.wins}</td>
                        <td>{row.buchholz}</td>
                        <td>{row.sonnebornBerger}</td>
                        {showAdvancedStandings && <><td>{row.blackWins}</td><td>{row.buchholzCutOne}</td><td>{row.buchholzCutTwo}</td><td>{row.medianBuchholz}</td><td>{row.koyaScore}</td><td>{row.progressiveScore}</td><td>{row.tournamentPerformance ?? '—'}</td></>}
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </article>

            {showAdvancedStandings && <article className="card">
              <h3>{lang === 'en' ? 'Hero Cup' : 'Heldenpokal'}</h3>
              <div className="table-scroll">
                <table>
                  <thead><tr><th>{lang === 'en' ? 'Rank' : 'Rang'}</th><th>{t('standings.name')}</th><th>{lang === 'en' ? 'Above expectation' : t('workflow.aboveExpectation')}</th><th>{lang === 'en' ? 'Actual' : 'Ist'}</th><th>{lang === 'en' ? 'Expected' : 'Erwartet'}</th><th>{lang === 'en' ? 'Avg. opponents' : 'Ø Gegner'}</th></tr></thead>
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
            </article>}
          </div>

          )}

          {activeMainTab === 'standings' && showAdvancedStandings && (
          <article className="card">
            <h3>{lang === 'en' ? 'Category standings' : 'Kategorieauswertungen'}</h3>
            {categories.length === 0 && <p>{lang === 'en' ? 'No category with matching players yet.' : 'Noch keine Kategorie mit passenden Spielern.'}</p>}
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

          )}

          {activeMainTab === 'standings' && showAdvancedStandings && (
          <article className="card">
            <h3>{lang === 'en' ? 'Cross table' : 'Kreuztabelle'}</h3>
            <div className="table-scroll">
              <table className="cross-table">
                <thead>
                  <tr><th>{lang === 'en' ? 'Player' : t('workflow.player')}</th>{crossTable?.players.map(player => <th key={player.playerId}>{player.rank}</th>)}<th>{lang === 'en' ? 'Pts.' : 'Pkt.'}</th></tr>
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

          )}

          {activeMainTab === 'rounds' && (
          <article className="card">
            <h3>{t('rounds.title')}</h3>
            {(!selectedTournament || selectedTournament.rounds.length === 0) ? (
              <div className="round-start">
                <h4>{t('rounds.firstTitle')}</h4>
                <p className="muted">{t('rounds.firstHelp')}</p>
                <div className="actions">
                  <button type="button" className="secondary" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>{t('rounds.preview')}</button>
                  <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>{t('rounds.pairFirst')}</button>
                </div>
                {pairingReadinessBlockingIssues().length > 0 && (
                  <ul className="message-list round-bottom-blockers">
                    {pairingReadinessBlockingIssues().map((issue, index) => <li key={`round-start-blocker-${index}`}>{issue}</li>)}
                  </ul>
                )}
              </div>
            ) : (
              <>
                <div className="round-tab-bar" role="tablist" aria-label={t('rounds.title')}>
                  {selectedTournament.rounds.map(round => (
                    <button
                      key={`round-tab-${round.roundNumber}`}
                      type="button"
                      role="tab"
                      aria-selected={round.roundNumber === activeRoundNumber}
                      className={`round-tab-button${round.roundNumber === activeRoundNumber ? ' active' : ''}`}
                      onClick={() => setActiveRoundNumber(round.roundNumber)}
                    >
                      {t('rounds.round')} {round.roundNumber}
                    </button>
                  ))}
                  {pairingReadinessCanCreatePreview() && (
                    <button type="button" className="round-tab-button round-tab-next" onClick={() => void previewNextRound()}>＋ {t('rounds.next')}</button>
                  )}
                </div>
                {selectedTournament.rounds.filter(round => round.roundNumber === activeRoundNumber).map(round => (
              <section key={round.roundNumber} className="round-box">
                <div className="round-header">
                  <div>
                    <h4>{t('rounds.round')} {round.roundNumber}</h4>
                    <p className="muted">{t('rounds.status')}: {roundStatusLabel(round.resultStatus, lang === 'en')}{round.isLocked ? ` · ${lang === 'en' ? 'locked' : 'gesperrt'}` : ''}{round.isVerified ? ` · ${lang === 'en' ? 'reviewed' : t('workflow.reviewed')}` : ''}</p>
                  </div>
                  <div className="actions">
                    <button type="button" className="small" onClick={() => void setRoundLock(round, !round.isLocked)} disabled={round.isVerified}>{round.isLocked ? t('rounds.unlock') : t('rounds.lock')}</button>
                    <button type="button" className="small secondary" onClick={() => void setRoundVerified(round, !round.isVerified)}>{round.isVerified ? t('rounds.unverify') : t('rounds.verify')}</button>
                  </div>
                </div>
                {round.audit && (
                  <details className="audit-box">
                    <summary>{round.audit.algorithm} · {round.audit.rulesetVersion}</summary>
                    <div className="audit-grid">
                      <section>
                        <strong>{t('workflow.notices')}</strong>
                        <ul>{round.audit.messages.map((message, index) => <li key={`m-${index}`}>{message}</li>)}</ul>
                      </section>
                      <section>
                        <strong>{t('workflow.scoreGroups')}</strong>
                        <ul>{round.audit.scoreGroups.map((message, index) => <li key={`s-${index}`}>{message}</li>)}</ul>
                      </section>
                      <section>
                        <strong>{t('workflow.floater')}</strong>
                        <ul>{round.audit.floaters.length === 0 ? <li>{t('workflow.none')}</li> : round.audit.floaters.map((message, index) => <li key={`f-${index}`}>{message}</li>)}</ul>
                      </section>
                      <section>
                        <strong>{t('workflow.colours')}</strong>
                        <ul>{round.audit.colorNotes.map((message, index) => <li key={`c-${index}`}>{message}</li>)}</ul>
                      </section>
                    </div>
                  </details>
                )}
                {diagnosticsFor(round.roundNumber) && (
                  <details className="diagnostics-box" open={diagnosticsFor(round.roundNumber)?.warnings.length !== 0}>
                    <summary>{t('workflow.roundReview')} {diagnosticsFor(round.roundNumber)?.openBoards ?? 0} {t('workflow.open')} {diagnosticsFor(round.roundNumber)?.forfeitBoards ?? 0} {t('workflow.forfeits2')} {diagnosticsFor(round.roundNumber)?.byeBoards ?? 0} Bye</summary>
                    {(diagnosticsFor(round.roundNumber)?.warnings.length ?? 0) === 0 && <p className="ok">{t('workflow.noWarnings')}</p>}
                    <ul>{diagnosticsFor(round.roundNumber)?.warnings.map((warning, index) => <li key={`w-${round.roundNumber}-${index}`}>{warning}</li>)}</ul>
                    <div className="table-scroll compact">
                      <table>
                        <thead><tr><th>{t('rounds.board')}</th><th>{t('rounds.result')}</th><th>BH</th><th>{t('workflow.sBDirectEncounter')}</th><th>TPR</th><th>{t('workflow.notice')}</th></tr></thead>
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
                <details className={`quality-box ${pairingQualityFor(round.roundNumber) ? pairingQualitySeverityClass(pairingQualityFor(round.roundNumber)!.severity) : 'quality-empty'}`}>
                  <summary>{lang === 'en' ? 'Advanced: pairing quality' : t('workflow.advancedPairingQuality')}</summary>
                  <div className="quality-header">
                    <div>
                      <strong>{lang === 'en' ? 'Pairing quality' : t('workflow.pairingQuality')}</strong>
                      {pairingQualityFor(round.roundNumber)
                        ? <span>{pairingQualityFor(round.roundNumber)!.qualityScore}/100 · {pairingQualitySeverityLabel(pairingQualityFor(round.roundNumber)!.severity, lang === 'en')}</span>
                        : <span>{lang === 'en' ? 'not calculated yet' : t('workflow.notCalculatedYet')}</span>}
                    </div>
                    <button type="button" className="small secondary" onClick={() => void loadPairingQuality(round.roundNumber)}>{lang === 'en' ? 'Check quality' : t('workflow.checkQuality')}</button>
                  </div>
                  {pairingQualityFor(round.roundNumber) && (
                    <details open={pairingQualityFor(round.roundNumber)!.severity >= 2}>
                      <summary>{pairingQualityFor(round.roundNumber)!.findingCount} {t('workflow.noticeS')} {pairingQualityFor(round.roundNumber)!.rematchCount} Rematch · {pairingQualityFor(round.roundNumber)!.crossScoreGroupPairingCount} {t('workflow.scoreGroupDeviationS')} {pairingQualityFor(round.roundNumber)!.thirdSameColorRiskCount} {t('workflow.colourSequenceRiskS')}</summary>
                      <ul className="message-list">
                        {pairingQualityFor(round.roundNumber)!.findings.map((finding, index) => <li key={`quality-finding-${round.roundNumber}-${index}`}>{finding}</li>)}
                      </ul>
                      <div className="table-scroll compact">
                        <table>
                          <thead><tr><th>{t('rounds.board')}</th><th>{t('workflow.pairing')}</th><th>{t('workflow.scoreBeforeRound')}</th><th>{t('workflow.notices')}</th></tr></thead>
                          <tbody>
                            {pairingQualityFor(round.roundNumber)!.boards.map(board => (
                              <tr key={`quality-board-${round.roundNumber}-${board.boardNumber}`} className={board.isRematch ? 'quality-board-critical' : board.wouldGiveWhiteThirdSameColor || board.wouldGiveBlackThirdSameColor ? 'quality-board-warning' : board.isCrossScoreGroupPairing || board.isBye ? 'quality-board-notice' : ''}>
                                <td>{board.boardNumber}</td>
                                <td>{board.whiteName} – {board.blackName}</td>
                                <td>{board.isBye ? 'Bye' : `${board.whiteScoreBeforeRound} : ${board.blackScoreBeforeRound}`}</td>
                                <td>{board.findings.length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{board.findings.map((finding, index) => <li key={`quality-board-finding-${round.roundNumber}-${board.boardNumber}-${index}`}>{finding}</li>)}</ul>}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </details>
                  )}
                </details>
                <details className="chess960-dice-panel">
                  <summary>{lang === 'en' ? 'Advanced: Chess960 starting positions' : t('workflow.advancedChessDiceChess960')}</summary>
                  <div className="chess960-dice-header">
                    <div>
                      <strong>{lang === 'en' ? 'Chess960 starting positions' : t('workflow.chessDiceChess9602')}</strong>
                      <span>{chess960PositionCount(round)} {lang === 'en' ? `of ${chess960GameBoardCount(round)} regular boards have a starting position.` : t('workflow.ofRegularBoardsHaveAStartingPosition', { p0: chess960GameBoardCount(round) })}</span>
                    </div>
                    <button type="button" className="secondary" onClick={() => openChess960Dice(round)} disabled={round.isLocked || round.isVerified || chess960GameBoardCount(round) === 0}>{lang === 'en' ? '🎲 Open Chess960 dice' : t('workflow.openChessDice')}</button>
                  </div>
                  {chess960PositionCount(round) > 0 && (
                    <div className="table-scroll compact chess960-table">
                      <table>
                        <thead><tr><th>{lang === 'en' ? 'Board' : t('rounds.board')}</th><th>{lang === 'en' ? 'Pairing' : t('workflow.pairing')}</th><th>{lang === 'en' ? 'Starting position' : 'Startstellung'}</th><th>ID / Seed</th><th>{lang === 'en' ? 'Action' : t('workflow.action')}</th></tr></thead>
                        <tbody>
                          {round.pairings.map(pairing => (
                            <tr key={`chess960-${round.roundNumber}-${pairing.boardNumber}`}>
                              <td>{pairing.boardNumber}</td>
                              <td>{playerNameById(pairing.whitePlayerId)} – {pairing.isBye ? t('dice.bye') : playerNameById(pairing.blackPlayerId)}</td>
                              <td><strong>{chess960Display(pairing)}</strong></td>
                              <td>{pairing.chess960StartPosition ? `SP ${pairing.chess960StartPosition.positionNumber}${chess960SeedDisplay(pairing) ? ` · ${chess960SeedDisplay(pairing)}` : ''}` : '—'}</td>
                              <td>{!pairing.isBye && <button type="button" className="small board-dice-button" title={lang === 'en' ? `Roll Chess960 for board ${pairing.boardNumber}` : t('workflow.rollChess960ForBoard', { p0: pairing.boardNumber })} onClick={() => openBoardDice(round.roundNumber, pairing.boardNumber)} disabled={round.isLocked || round.isVerified}>{lang === 'en' ? '🎲 Roll' : t('workflow.roll')}</button>}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  )}
                </details>
                <div className="table-scroll">
                  <table>
                    <thead><tr><th>{t('rounds.board')}</th><th>{t('rounds.white')}</th><th>{t('rounds.black')}</th><th>{t('rounds.result')}</th><th>{t('rounds.manual')}</th></tr></thead>
                    <tbody>
                      {round.pairings.map(pairing => {
                        const edit = pairingEdit(round, pairing);
                        const roundClosed = round.isLocked || round.isVerified;
                        const manualPairingDisabled = roundClosed || !selectedTournament.settings.allowManualPairingOverrides;
                        return (
                          <tr key={`${round.roundNumber}-${pairing.boardNumber}`} className={pairing.isManualOverride ? 'manual-row' : ''}>
                            <td>{pairing.boardNumber}{pairing.isManualOverride ? <small>{t('workflow.manual')}</small> : null}</td>
                            <td>{playerNameById(pairing.whitePlayerId)}</td>
                            <td>{pairing.isBye ? t('rounds.bye') : playerNameById(pairing.blackPlayerId)}</td>
                            <td>
                              <select
                                value={pairing.result.kind}
                                onChange={(event: React.ChangeEvent<HTMLSelectElement>) => requestResultChange(round.roundNumber, pairing.boardNumber, Number(event.target.value), pairing.result.kind, event.currentTarget)}
                                disabled={pairing.isBye || roundClosed}
                                aria-label={`${t('rounds.result')}: ${t('rounds.round')} ${round.roundNumber}, ${t('rounds.board')} ${pairing.boardNumber}`}
                              >
                                {resultOptions.filter(option => pairing.isBye || option.value !== 7).map(option => <option key={option.value} value={option.value}>{lang === 'en' ? option.labelEn : option.label}</option>)}
                              </select>
                              <small>{resultLabel(pairing.result.kind, lang === 'en')}</small>
                            </td>
                            <td>
                              <details className="manual-pairing-disclosure">
                                <summary>{lang === 'en' ? 'Advanced override' : 'Erweiterte Korrektur'}</summary>
                                <div className="manual-pairing">
                                <select aria-label={lang === 'en' ? 'Override white player' : t('workflow.selectWhiteManually')} value={edit.whitePlayerId} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updatePairingEdit(round.roundNumber, pairing.boardNumber, { whitePlayerId: event.target.value })} disabled={manualPairingDisabled}>
                                  <option value="">{lang === 'en' ? 'Select White' : t('workflow.selectWhite')}</option>
                                  {selectedTournament.players.filter(player => player.status === 0).map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
                                </select>
                                <select aria-label={lang === 'en' ? 'Override black player or bye' : t('workflow.selectBlackOrAByeManually')} value={edit.blackPlayerId} onChange={(event: React.ChangeEvent<HTMLSelectElement>) => updatePairingEdit(round.roundNumber, pairing.boardNumber, { blackPlayerId: event.target.value })} disabled={manualPairingDisabled}>
                                  <option value="">{lang === 'en' ? 'Black / leave empty for bye' : 'Schwarz/Bye leer'}</option>
                                  {selectedTournament.players.filter(player => player.status === 0).map(player => <option key={player.id} value={player.id}>{player.name}</option>)}
                                </select>
                                <input aria-label={lang === 'en' ? 'Override reason' : 'Grund der manuellen Korrektur'} value={edit.notes} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updatePairingEdit(round.roundNumber, pairing.boardNumber, { notes: event.target.value })} placeholder={lang === 'en' ? 'Reason' : 'Notiz'} disabled={manualPairingDisabled} />
                                <button type="button" className="small" onClick={() => void saveManualPairing(round, pairing)} disabled={manualPairingDisabled || !edit.whitePlayerId}>{lang === 'en' ? 'Save override' : t('workflow.savePairing')}</button>
                                </div>
                              </details>
                            </td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
                <div className="round-bottom-actions">
                  <div>
                    <strong>{t('rounds.continue')}</strong>
                    <span>{t('rounds.continueHelp')}</span>
                  </div>
                  <button type="button" className="secondary" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>{t('rounds.createPreview')}</button>
                  <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>{t('rounds.pairNext')}</button>
                  {pairingReadinessBlockingIssues().length > 0 && (
                    <ul className="message-list round-bottom-blockers">
                      {pairingReadinessBlockingIssues().map((issue, index) => <li key={`round-bottom-blocker-${index}`}>{issue}</li>)}
                    </ul>
                  )}
                </div>
              </section>
                ))}
              </>
            )}
          </article>
          )}

          {activeMainTab === 'rounds' && (
          <article className="card pairing-readiness-card">
              <div className="pairing-readiness-header">
                <div>
                  <h3>{lang === 'en' ? 'Pairing readiness' : 'Auslosungsfreigabe'}</h3>
                  <p className="muted">{lang === 'en' ? 'Check results, round review and preview quality before pairing the next round.' : t('workflow.checksResultsRoundReviewsAndPreviewQuality')}</p>
                </div>
                <span className={pairingReadinessStatusClass()}>{pairingReadinessStatusLabel()}</span>
              </div>

              <div className="pairing-readiness-metrics">
                <div><strong>{pairingReadinessOpenResultCount()}</strong><span>{lang === 'en' ? 'open results' : 'offene Ergebnisse'}</span></div>
                <div><strong>{pairingReadinessUnverifiedRoundCount()}</strong><span>{lang === 'en' ? 'unreviewed rounds' : t('workflow.unreviewedRounds')}</span></div>
                <div><strong>{selectedTournament?.players.filter(player => player.status === 0).length ?? 0}</strong><span>{lang === 'en' ? 'active players' : t('workflow.activePlayers')}</span></div>
                <div><strong>{nextRoundPreview ? nextRoundPreview.pairingQuality.qualityScore : '—'}</strong><span>{lang === 'en' ? 'preview quality' : t('workflow.previewQuality')}</span></div>
              </div>

              {pairingReadinessIssues().length === 0 ? (
                <div className="pairing-readiness-ok"><strong>{lang === 'en' ? 'Ready:' : 'Bereit:'}</strong> {lang === 'en' ? 'No blocking issues are visible for the next pairing.' : t('workflow.noBlockingIssuesAreVisibleForThe')}</div>
              ) : (
                <div className="pairing-readiness-warning">
                  <strong>{lang === 'en' ? 'Review before pairing the next round:' : t('workflow.reviewBeforeTheNextPairing')}</strong>
                  <ul>
                    {pairingReadinessIssues().map((issue, index) => <li key={index}>{issue}</li>)}
                  </ul>
                </div>
              )}

              <div className="pairing-readiness-actions">
                <button type="button" onClick={() => void previewNextRound()} disabled={!pairingReadinessCanCreatePreview()}>{lang === 'en' ? 'Create pairing preview' : 'Auslosungsvorschau erzeugen'}</button>
                <button type="button" onClick={() => void generateRound()} disabled={!pairingReadinessCanGenerateRound()}>{lang === 'en' ? 'Pair next round' : t('rounds.pairNext')}</button>
                <button type="button" className="secondary" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>{lang === 'en' ? 'Print current round' : t('workflow.printCurrentRound')}</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>{lang === 'en' ? 'Open tournament report' : t('workflow.openTournamentReport')}</button>
              </div>

              <p className="muted small">{lang === 'en' ? 'This panel is the tournament director’s deliberate check before the next round.' : t('workflow.thisSupplementsTheActionsInTheHeader')}</p>
            </article>
          )}

          {activeMainTab === 'standings' && showAdvancedStandings && (
          <article className="card bye-forfeit-card">
              <div className="bye-forfeit-header">
                <div>
                  <h3>{lang === 'en' ? 'Bye and forfeit audit' : 'Bye- und Kampflos-Audit'}</h3>
                  <p className="muted">{lang === 'en' ? 'Shows byes and forfeits with their tie-break impact before standings, exports or the next pairing.' : t('workflow.showsByesAndForfeitsWithTheirEffect')}</p>
                </div>
                <span className={byeForfeitAuditStatusClass()}>{byeForfeitAuditStatusDisplayLabel()}</span>
              </div>

              <div className="bye-forfeit-metrics">
                <div><strong>{totalByeBoardCount()}</strong><span>{t('workflow.byeNoGame')}</span></div>
                <div><strong>{totalForfeitBoardCount()}</strong><span>{t('workflow.forfeit')}</span></div>
                <div><strong>{byeForfeitAffectedRoundCount()}</strong><span>{t('workflow.affectedRounds')}</span></div>
                <div><strong>{byeForfeitRows().length}</strong><span>{t('workflow.visibleCases')}</span></div>
              </div>

              {!selectedTournament && <p className="muted">{t('workflow.selectATournamentFirst')}</p>}
              {selectedTournament && selectedTournament.rounds.length === 0 && <div className="bye-forfeit-empty">{t('workflow.noRoundYetByesAndForfeitsAppear')}</div>}
              {selectedTournament && selectedTournament.rounds.length > 0 && byeForfeitRows().length === 0 && <div className="bye-forfeit-ok">{t('workflow.noByesOrForfeitsFoundInThe')}</div>}
              {totalForfeitBoardCount() > 0 && <div className="bye-forfeit-warning"><strong>{t('workflow.reviewForfeits')}</strong> {t('workflow.beforePublicationCheckThatBuchholzSonnebornBerger')}</div>}
              {totalByeBoardCount() > 0 && <div className="bye-forfeit-warning info"><strong>{t('workflow.byesPresent')}</strong> {t('workflow.postedResultsAndExportsShouldClearlyIdentify')}</div>}

              {byeForfeitRows().length > 0 && (
                <div className="table-wrap bye-forfeit-table-wrap">
                  <table>
                    <thead>
                      <tr><th>{t('operator.round')}</th><th>{t('rounds.board')}</th><th>{t('rounds.white')}</th><th>{t('rounds.black')}</th><th>{t('workflow.type')}</th><th>{t('rounds.result')}</th><th>BH</th><th>{t('workflow.directSB')}</th><th>Perf.</th><th>{t('workflow.notice')}</th></tr>
                    </thead>
                    <tbody>
                      {byeForfeitRows().map(row => (
                        <tr key={`${row.roundNumber}-${row.boardNumber}-${row.kind}`}>
                          <td>{row.roundNumber}</td>
                          <td>{row.boardNumber}</td>
                          <td>{row.white}</td>
                          <td>{row.black}</td>
                          <td><span className={`bye-forfeit-chip ${row.isForfeit ? 'warn' : 'info'}`}>{row.kind}</span></td>
                          <td>{row.resultLabel}</td>
                          <td>{row.countsForBuchholz ? 'ja' : 'nein'}</td>
                          <td>{row.countsForDirectAndSonneborn ? 'ja' : 'nein'}</td>
                          <td>{row.countsForPerformance ? 'ja' : 'nein'}</td>
                          <td>{row.note || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              <div className="bye-forfeit-actions">
                <button type="button" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>{t('workflow.printCurrentRound')}</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>{t('workflow.pairingsCSV')}</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>{t('workflow.openTournamentReport')}</button>
              </div>
            </article>
          )}

          {activeMainTab === 'rounds' && (
          <article className="card result-review-card">
              <div className="result-review-header">
                <div>
                  <h3>{lang === 'en' ? 'Round completion checklist' : 'Rundenabschluss-Checkliste'}</h3>
                  <p className="muted">{lang === 'en' ? 'Checks open results, forfeits, unreviewed rounds and diagnostic findings before publishing or pairing again.' : t('workflow.checksPendingResultsForfeitsUnreviewedRoundsAnd')}</p>
                </div>
                <span className={resultReviewStatusClass()}>{resultReviewStatusDisplayLabel()}</span>
              </div>

              <div className="result-review-metrics">
                <div><strong>{selectedTournament?.rounds.length ?? 0}</strong><span>{lang === 'en' ? 'rounds' : t('workflow.rounds')}</span></div>
                <div><strong>{completedRoundCount()}</strong><span>{lang === 'en' ? 'complete' : t('workflow.complete')}</span></div>
                <div><strong>{totalOpenBoardCount()}</strong><span>{lang === 'en' ? 'open' : 'offen'}</span></div>
                <div><strong>{totalForfeitBoardCount()}</strong><span>{lang === 'en' ? 'forfeits' : t('workflow.forfeit')}</span></div>
                <div><strong>{unverifiedCompleteRoundCount()}</strong><span>{lang === 'en' ? 'unreviewed' : t('workflow.unreviewed')}</span></div>
                <div><strong>{lockedRoundCount()}</strong><span>{lang === 'en' ? 'locked' : 'gesperrt'}</span></div>
                <div><strong>{diagnosticWarningCount()}</strong><span>{lang === 'en' ? 'findings' : t('workflow.notices')}</span></div>
              </div>

              {!selectedTournament && <p className="muted">{lang === 'en' ? 'Select a tournament first.' : t('workflow.selectATournamentFirst')}</p>}
              {selectedTournament && selectedTournament.rounds.length === 0 && <div className="result-review-empty">{lang === 'en' ? 'No round has been paired yet. The checklist activates once pairings exist.' : t('workflow.noRoundPairedYetTheChecklistBecomes')}</div>}
              {selectedTournament && selectedTournament.rounds.length > 0 && totalOpenBoardCount() === 0 && unverifiedCompleteRoundCount() === 0 && diagnosticWarningCount() === 0 && <div className="result-review-ok">{lang === 'en' ? 'All known rounds are complete, reviewed or free of diagnostic warnings. The tournament report is ready.' : t('workflow.allKnownRoundsAreCompleteReviewedOr')}</div>}
              {totalOpenBoardCount() > 0 && <div className="result-review-warning danger"><strong>{lang === 'en' ? 'Open results:' : 'Offene Ergebnisse:'}</strong> {lang === 'en' ? 'Enter every open board before standings, publication or the next pairing.' : t('workflow.enterAllPendingBoardResultsBeforeStandings')}</div>}
              {unverifiedCompleteRoundCount() > 0 && totalOpenBoardCount() === 0 && <div className="result-review-warning"><strong>{lang === 'en' ? 'Review pending:' : t('workflow.reviewPending2')}</strong> {lang === 'en' ? 'At least one complete round has not been marked as reviewed.' : t('workflow.atLeastOneCompletedRoundHasNot')}</div>}

              {resultReviewRows().length > 0 && (
                <div className="table-wrap result-review-table-wrap">
                  <table>
                    <thead>
                      <tr><th>{lang === 'en' ? 'Round' : t('operator.round')}</th><th>{lang === 'en' ? 'Board' : t('rounds.board')}</th><th>{lang === 'en' ? 'White' : t('rounds.white')}</th><th>{lang === 'en' ? 'Black' : t('rounds.black')}</th><th>{t('rounds.status')}</th><th>{lang === 'en' ? 'Finding' : t('workflow.notice')}</th></tr>
                    </thead>
                    <tbody>
                      {resultReviewRows().map(row => (
                        <tr key={`${row.roundNumber}-${row.boardNumber}-${row.kind}`}>
                          <td>{row.roundNumber}</td>
                          <td>{row.boardNumber}</td>
                          <td>{row.white}</td>
                          <td>{row.black}</td>
                          <td><span className={`result-review-chip ${row.kind === 'offen' ? 'danger' : row.kind === t('workflow.forfeit') ? 'warn' : ''}`}>{row.kind}</span></td>
                          <td>{row.note || row.resultLabel}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              )}

              <div className="result-review-actions">
                <button type="button" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>{lang === 'en' ? 'Print current round' : t('workflow.printCurrentRound')}</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>{lang === 'en' ? 'Open tournament report' : t('workflow.openTournamentReport')}</button>
                <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.csv')} disabled={!selectedTournament}>{lang === 'en' ? 'Standings CSV' : 'Tabelle CSV'}</button>
              </div>
            </article>
          )}

          {activeMainTab === 'overview' && (
          <article className="card correction-journal-card">
            <div className="card-heading-row">
              <div>
                <h3>{t('workflow.correctionsAndInterventions')}</h3>
                <p className="muted">{t('workflow.tournamentDirectorChecklistOfManualPairingsLocked')}</p>
              </div>
              <span className={`status-pill ${correctionJournalStatusClass}`}>{correctionJournalStatusLabel}</span>
            </div>
            <div className="review-metrics correction-metrics">
              <div><strong>{correctionJournal.length}</strong><span>{t('workflow.entries')}</span></div>
              <div><strong>{correctionJournalCriticalCount}</strong><span>{t('workflow.critical')}</span></div>
              <div><strong>{correctionJournalWarningCount}</strong><span>{t('workflow.review2')}</span></div>
              <div><strong>{correctionJournalInfoCount}</strong><span>Info</span></div>
            </div>
            {!selectedTournament && <p className="muted">{t('workflow.selectATournamentFirst')}</p>}
            {selectedTournament && correctionJournal.length === 0 && (
              <div className="notice success">{t('workflow.noManualInterventionsSpecialResultsOrPending')}</div>
            )}
            {selectedTournament && correctionJournalCriticalCount > 0 && (
              <div className="notice danger">{t('workflow.criticalInterventionsFoundReviewManualPairingsBefore')}</div>
            )}
            {selectedTournament && correctionJournalWarningCount > 0 && (
              <div className="notice warning">{t('workflow.reviewItemsFoundCheckParticipantStatusUnreviewed')}</div>
            )}
            {selectedTournament && correctionJournal.length > 0 && (
              <div className="table-scroll compact correction-journal-table">
                <table>
                  <thead>
                    <tr>
                      <th>{t('workflow.area')}</th>
                      <th>{t('rounds.status')}</th>
                      <th>{t('workflow.entry')}</th>
                      <th>{t('workflow.details')}</th>
                      <th>{t('workflow.action')}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {correctionJournal.map(item => (
                      <tr key={item.key} className={`journal-row ${item.severity}`}>
                        <td>{item.scope}</td>
                        <td><span className={`status-pill ${item.severity === 'critical' ? 'blocked' : item.severity === 'warning' ? 'warning' : 'ready'}`}>{item.severity === 'critical' ? t('workflow.critical') : item.severity === 'warning' ? t('workflow.review2') : 'Info'}</span></td>
                        <td>{item.title}</td>
                        <td>{item.detail}</td>
                        <td>{item.action}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="actions">
              <button type="button" onClick={() => openLatestRoundPrint()} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>{t('workflow.printLastRound')}</button>
              <button type="button" className="secondary" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>{t('workflow.openTournamentReport')}</button>
              <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>{t('workflow.pairingsCSV')}</button>
            </div>
          </article>
          )}

          {activeMainTab === 'print' && (
          <article className="card export-center-card">
              <div className="export-center-header">
                <div>
                  <h3>{lang === 'en' ? 'Tournament director export centre' : 'Turnierleiter-Exportcenter'}</h3>
                  <p className="muted">{lang === 'en' ? 'Local printouts, standings, pairings, previews and backups in one place.' : t('workflow.quickAccessToPostingsStandingsPairingsPreview')}</p>
                </div>
                <span className="export-center-badge">RUN-15 · v0.49</span>
              </div>

              <div className="export-center-metrics">
                <div><strong>{selectedTournament?.players.length ?? 0}</strong><span>{lang === 'en' ? 'players' : t('nav.participants')}</span></div>
                <div><strong>{activePlayerCount()}</strong><span>{lang === 'en' ? 'active' : 'aktiv'}</span></div>
                <div><strong>{inactivePlayerCount()}</strong><span>{lang === 'en' ? 'inactive' : 'inaktiv'}</span></div>
                <div><strong>{selectedTournament?.rounds.length ?? 0}</strong><span>{lang === 'en' ? 'rounds' : t('workflow.rounds')}</span></div>
                <div><strong>{totalOpenBoardCount()}</strong><span>{lang === 'en' ? 'open boards' : 'offene Bretter'}</span></div>
                <div><strong>{totalForfeitBoardCount()}</strong><span>{lang === 'en' ? 'forfeits' : t('workflow.forfeit')}</span></div>
              </div>

              {totalOpenBoardCount() > 0 && <div className="export-center-warning"><strong>{lang === 'en' ? 'Open results:' : 'Offene Ergebnisse:'}</strong> {lang === 'en' ? 'Review open boards before publishing final standings.' : t('workflow.checkPendingResultsBeforeFinalStandingsOr')}</div>}
              {nextRoundPreview?.pairingQuality.hasCriticalIssues && <div className="export-center-warning critical"><strong>{lang === 'en' ? 'Critical preview:' : 'Kritische Vorschau:'}</strong> {lang === 'en' ? 'Review pairing findings before publishing or committing the round.' : t('workflow.reviewPairingNoticesBeforePostingOrPairing')}</div>}

              <div className="export-center-grid">
                <section>
                  <h4>{lang === 'en' ? 'Printouts' : t('workflow.postings')}</h4>
                  <div className="export-center-actions">
                    <button type="button" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>{lang === 'en' ? 'Full tournament print view' : 'Gesamt-Druckansicht'}</button>
                    <button type="button" onClick={openLatestRoundPrint} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>{lang === 'en' ? 'Print current round' : t('workflow.printCurrentRound')}</button>
                    <button type="button" onClick={openNextRoundPreviewPrint} disabled={!selectedTournament || activePlayerCount() < 2}>{lang === 'en' ? 'Print preview' : 'Vorschau drucken'}</button>
                  </div>
                </section>
                <section>
                  <h4>{lang === 'en' ? 'CSV / data' : 'CSV / Daten'}</h4>
                  <div className="export-center-actions">
                    <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>{lang === 'en' ? 'Players CSV' : 'Teilnehmer CSV'}</button>
                    <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.csv')} disabled={!selectedTournament}>{lang === 'en' ? 'Standings CSV' : 'Tabelle CSV'}</button>
                    <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.trf16')} disabled={!selectedTournament}>{lang === 'en' ? 'TRF16 (FIDE tournament report)' : 'TRF16 (FIDE-Turnierbericht)'}</button>
                    <button type="button" className="secondary" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>{lang === 'en' ? 'All pairings CSV' : 'Alle Paarungen CSV'}</button>
                    <button type="button" className="secondary" onClick={openLatestPairingsCsv} disabled={!selectedTournament || selectedTournament.rounds.length === 0}>{lang === 'en' ? 'Current pairings CSV' : 'Aktuelle Paarungen CSV'}</button>
                    <button type="button" className="secondary" onClick={openNextRoundPreviewCsv} disabled={!selectedTournament || activePlayerCount() < 2}>{lang === 'en' ? 'Preview CSV' : 'Vorschau CSV'}</button>
                    <button type="button" className="secondary" onClick={openExportManifest} disabled={!selectedTournament}>{lang === 'en' ? 'Export manifest JSON' : t('workflow.exportManifestJSON')}</button>
                    <button type="button" className="secondary" onClick={() => void exportTournamentJson()} disabled={!selectedTournament}>{lang === 'en' ? 'Backup JSON' : 'Backup JSON'}</button>
                  </div>
                </section>
              </div>

              <p className="muted export-center-note">{lang === 'en' ? 'Preview exports do not save a round. Pairings are committed only after you confirm the round.' : t('workflow.previewExportsDoNotSaveARound')}</p>
            </article>
          )}

          {activeMainTab === 'admin' && (
          <article className="card audit-journal-card">
            <div className="audit-journal-heading">
              <div>
                <h3>{t('workflow.auditJournal')}</h3>
                <p>{t('workflow.persistentRecordOfImportantTournamentDirectorActions')}</p>
              </div>
              <span className={`status-pill ${auditJournalCriticalCount > 0 ? 'audit-critical' : auditJournalWarningCount > 0 ? 'audit-warning' : 'audit-info'}`}>
                {auditJournal.length} {t('workflow.entries')} </span>
            </div>
            <div className="audit-journal-summary">
              <div><strong>{auditJournalInfoCount}</strong><span>Info</span></div>
              <div><strong>{auditJournalWarningCount}</strong><span>{t('workflow.warning')}</span></div>
              <div><strong>{auditJournalCriticalCount}</strong><span>{t('workflow.critical')}</span></div>
              <div><strong>{auditJournalRoundEntryCount}</strong><span>{t('workflow.roundReferences')}</span></div>
              <div><strong>{auditJournalPlayerEntryCount}</strong><span>{t('workflow.playerReferences')}</span></div>
            </div>
            {!selectedTournament && <p>{t('workflow.selectATournamentFirst')}</p>}
            {selectedTournament && auditJournal.length === 0 && <p className="ok">{t('workflow.noAuditEntriesYet')}</p>}
            {auditJournalCriticalCount > 0 && <p className="warning-text">{t('workflow.criticalAuditEntriesFoundReviewBeforePublication')}</p>}
            {selectedTournament && auditJournal.length > 0 && (
              <>
                <div className="table-scroll compact audit-journal-table">
                  <table>
                    <thead><tr><th>{t('workflow.time')}</th><th>{t('workflow.severity')}</th><th>{t('workflow.action')}</th><th>{t('workflow.reference')}</th><th>{t('tournaments.summary')}</th><th>{t('workflow.details')}</th><th>{t('workflow.reason')}</th></tr></thead>
                    <tbody>
                      {auditJournalRecentEntries.map(entry => (
                        <tr key={entry.id} className={auditSeverityClass(entry.severity)}>
                          <td>{auditDateLabel(entry.createdAt, lang)}</td>
                          <td><span className={`audit-pill ${auditSeverityClass(entry.severity)}`}>{auditSeverityLabel(entry.severity, lang === 'en')}</span></td>
                          <td>{auditActionLabel(entry.action, lang === 'en')}<small>{entry.actor}</small></td>
                          <td>{entry.roundNumber ? `R${entry.roundNumber}` : '—'}{entry.boardNumber ? ` · Brett ${entry.boardNumber}` : ''}{entry.playerName ? <small>{entry.playerName}</small> : null}</td>
                          <td>{entry.summary}</td>
                          <td>{entry.details || '—'}</td>
                          <td>{entry.reason || '—'}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {auditJournal.length > auditJournalRecentEntries.length && <p className="muted">{t('workflow.showingTheLatest')} {auditJournalRecentEntries.length} {t('workflow.of')} {auditJournal.length} {t('workflow.entriesExportCSVJSONForTheComplete')}</p>}
              </>
            )}
            <div className="actions">
              <button type="button" onClick={() => exportAuditJournalCsv()} disabled={!selectedTournament || auditJournal.length === 0}>Audit CSV</button>
              <button type="button" className="secondary" onClick={() => exportAuditJournalJson()} disabled={!selectedTournament || auditJournal.length === 0}>Audit JSON</button>
              <button type="button" onClick={() => openTournamentExport('audit-journal/export.jsonl')} disabled={!selectedTournament} title={t('workflow.forensicBundleManifestTournamentSnapshotPairingEvidence')}>Audit-Bundle (JSONL)</button>
              <button type="button" className="secondary" onClick={() => openTournamentExport('audit-journal/export.json')} disabled={!selectedTournament} title="Gleiches Forensik-Bundle als strukturiertes JSON-Dokument.">Audit-Bundle (JSON)</button>
            </div>
            <p className="muted">{t('workflow.exportAnAuditBundleAfterEachRound')}</p>
          </article>
          )}

          {activeMainTab === 'print' && (
          <article className="card">
            <h3>{lang === 'en' ? 'Import / export' : 'Import / Export'}</h3>
            <div className="grid two">
              <section>
                <h4>{t('workflow.participantsCSV')}</h4>
                <p className="muted csv-reimport-note">{csvReimportNote(lang)}</p>
                <textarea value={csvContent} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => updateCsvContent(event.target.value)} rows={7} />
                <label className="checkbox"><input type="checkbox" checked={replacePlayers} onChange={(event: React.ChangeEvent<HTMLInputElement>) => updateReplacePlayers(event.target.checked)} /> {t('workflow.replaceExistingParticipants')}</label>
                <div className="actions">
                  <button type="button" className="secondary" onClick={() => useSampleCsvTemplate()}>{t('workflow.insertCSVTemplate')}</button>
                  <button type="button" onClick={() => void previewPlayersImport()} disabled={!selectedTournament || !csvContent.trim()}>{t('workflow.checkImport')}</button>
                  <button type="button" onClick={() => void importPlayers()} disabled={!selectedTournament || !importPreview || !importPreviewGuard.matches({ tournamentId: selectedTournament.id, content: csvContent, replaceExisting: replacePlayers }, importPreview) || importPreview.hasBlockingIssues || (importPreview.warningRows > 0 && !confirmWarningImport)}>{t('workflow.importCSV')}</button>
                  <button type="button" className="secondary" onClick={() => void exportPlayers()} disabled={!selectedTournament}>{t('workflow.exportCSV')}</button>
                </div>
                {importPreview && (
                  <div className="import-preview">
                    <div className={`preview-summary ${importPreview.hasBlockingIssues ? 'blocked' : importPreview.warningRows > 0 ? 'warning' : 'ready'}`}>
                      <strong>{importPreview.hasBlockingIssues ? 'Import blockiert' : importPreview.warningRows > 0 ? t('workflow.importPossibleWithWarnings') : 'Import bereit'}</strong>
                      <span>{importPreview.totalRows} {t('workflow.rows')} {importPreview.importableRows} {t('workflow.importable')} {importPreview.warningRows} {t('workflow.warningS')} {importPreview.blockingRows} {t('workflow.blocked')} {importPreview.likelyDuplicateRows} {t('workflow.possibleDuplicateS')}</span>
                    </div>
                    {importPreview.globalWarnings.length > 0 && (
                      <ul className="message-list critical">
                        {importPreview.globalWarnings.map((warning, index) => <li key={`import-global-${index}`}>{warning}</li>)}
                      </ul>
                    )}
                    {importPreview.warningRows > 0 && !importPreview.hasBlockingIssues && (
                      <label className="checkbox import-confirm">
                        <input type="checkbox" checked={confirmWarningImport} onChange={(event: React.ChangeEvent<HTMLInputElement>) => setConfirmWarningImport(event.target.checked)} />{t('workflow.iHaveReviewedTheWarningsAndPossible')} </label>
                    )}
                    {importPreview.hasBlockingIssues && <p className="error">{t('workflow.blockingIssuesMustBeResolvedBeforeImport')}</p>}
                    <div className="table-scroll compact import-preview-table">
                      <table>
                        <thead><tr><th>{t('workflow.row')}</th><th>{t('nav.participants')}</th><th>{t('rounds.status')}</th><th>{t('workflow.duplicates')}</th><th>{t('workflow.notices')}</th></tr></thead>
                        <tbody>
                          {importPreview.rows.map(row => (
                            <tr key={`import-preview-${row.rowNumber}`} className={importPreviewStatusClass(row.status)}>
                              <td>{row.rowNumber}</td>
                              <td>{row.player.name}<small>{row.player.fideId ? `FIDE ${row.player.fideId}` : row.player.nationalId ? `DSB ${row.player.nationalId}` : row.player.club ?? ''}</small></td>
                              <td>{importPreviewStatusLabel(row.status, lang === 'en')}</td>
                              <td>{row.duplicateCheck.matches.length === 0 ? '—' : row.duplicateCheck.matches.map(match => `${match.playerName} (${duplicateKindLabel(match.kind, lang === 'en')}, ${match.score})`).join('; ')}</td>
                              <td>{importPreviewMessages(row).length === 0 ? <span className="ok">ok</span> : <ul className="message-list">{importPreviewMessages(row).map((message, index) => <li key={`import-row-${row.rowNumber}-${index}`}>{message}</li>)}</ul>}</td>
                            </tr>
                          ))}
                        </tbody>
                      </table>
                    </div>
                  </div>
                )}
              </section>
              <section>
                <h4>{lang === 'en' ? 'Swiss-Manager / TRF16 (player master data)' : t('workflow.swissManagerTRF16PlayerData')}</h4>
                <p className="muted">{lang === 'en' ? 'Exchange player master data such as name, rating, federation and FIDE ID. Pairings and results are not imported.' : t('workflow.importExportPlayerDataForExchangeWith')}</p>
                <div className="actions">
                  <button type="button" className="secondary" onClick={() => openTournamentExport('players/export-swissmanager.csv')} disabled={!selectedTournament}>{lang === 'en' ? 'Export Swiss-Manager CSV' : 'Swiss-Manager CSV exportieren'}</button>
                  <button type="button" className="secondary" onClick={() => openTournamentExport('standings/export.trf16')} disabled={!selectedTournament}>{lang === 'en' ? 'Export TRF16' : 'TRF16 exportieren'}</button>
                </div>
                <p className="muted csv-reimport-note">{csvReimportNote(lang)}</p>
                <div className="actions">
                  <label className="file-import-label">
                    {lang === 'en' ? 'Import Swiss-Manager CSV' : 'Swiss-Manager CSV importieren'}
                    <input type="file" accept=".csv,.txt" disabled={!selectedTournament} onChange={(event: React.ChangeEvent<HTMLInputElement>) => {
                      const file = event.target.files?.[0];
                      event.target.value = '';
                      if (file) { void importPlayerFile(file, 'players/import-swissmanager.csv'); }
                    }} />
                  </label>
                  <label className="file-import-label">
                    {lang === 'en' ? 'Import TRF16' : 'TRF16 importieren'}
                    <input type="file" accept=".txt,.trf" disabled={!selectedTournament} onChange={(event: React.ChangeEvent<HTMLInputElement>) => {
                      const file = event.target.files?.[0];
                      event.target.value = '';
                      if (file) { void importPlayerFile(file, 'players/import-trf16'); }
                    }} />
                  </label>
                </div>
                {formatImportResult && (
                  <div className="import-preview">
                    <div className={`preview-summary ${formatImportResult.errors.length > 0 ? 'warning' : 'ready'}`}>
                      <strong>{formatImportResult.added} {t('workflow.participantsImported')}</strong>
                      {formatImportResult.errors.length > 0 && <span>{formatImportResult.errors.length} {t('workflow.noticeS2')}</span>}
                    </div>
                    {formatImportResult.errors.length > 0 && (
                      <ul className="message-list">
                        {formatImportResult.errors.map((message, index) => <li key={`format-import-error-${index}`}>{message}</li>)}
                      </ul>
                    )}
                  </div>
                )}
              </section>
              <section>
                <h4>JSON-Backup</h4>
                <textarea value={backupJson} onChange={(event: React.ChangeEvent<HTMLTextAreaElement>) => updateBackupJson(event.target.value)} rows={7} placeholder={t('workflow.pasteBackupJSONHereOrExportIt')} />
                <div className="actions">
                  <button type="button" onClick={() => void exportTournamentJson()} disabled={!selectedTournament}>{t('workflow.exportBackup')}</button>
                  <button type="button" className="secondary" onClick={() => void importTournamentJson()} disabled={!backupJson.trim() || backupImportBusy || backupImportPending !== null}>{backupImportBusy ? t('workflow.checkingImportingBackup') : 'Backup importieren'}</button>
                </div>
              </section>
              <section>
                <h4>{t('workflow.printPosting')}</h4>
                <p className="muted">{t('workflow.createsLocalCSVHTMLFilesForStandings')}</p>
                <div className="actions vertical-actions">
                  <button type="button" onClick={() => openTournamentExport('standings/export.csv')} disabled={!selectedTournament}>{t('workflow.standingsCSV')}</button>
                  <button type="button" onClick={() => openTournamentExport('pairings/export.csv')} disabled={!selectedTournament}>{t('workflow.allPairingsCSV')}</button>
                  <button type="button" onClick={() => openTournamentExport('print/html')} disabled={!selectedTournament}>{t('workflow.tournamentPrintView')}</button>
                  <button type="button" className="secondary" onClick={openExportManifest} disabled={!selectedTournament}>{t('workflow.exportManifestJSON')}</button>
                </div>
                <div className="round-print-list">
                  {selectedTournament?.rounds.map(round => (
                    <button key={`print-${round.roundNumber}`} type="button" className="small secondary" onClick={() => openRoundPrint(round.roundNumber)}>{t('operator.round')} {round.roundNumber} {t('workflow.print')}</button>
                  ))}
                </div>
              </section>
            </div>
          </article>
          )}
        </section>
      </section>
    </main>
  );
}

// Deutsche Basissprache. Diese Datei definiert den vollständigen Schlüsselsatz;
// alle anderen Sprachen sind Partial<Messages> und fallen auf Englisch, dann Deutsch zurück.
export const de = {
  'app.title': 'SchachTurnierManager',
  'hero.eyebrow': 'Lokaler Turnierleiter',
  'hero.subtitle':
    'Persistenter Turnierleiter mit SQLite, Schweizer-System-Audit, manuellen Paarungskorrekturen, Rundensperren, kampflosen Ergebnissen, Kategorien, Kreuztabelle und Im-/Export.',

  'backend.title': 'Backend',
  'backend.checking': 'Prüfe API…',
  'backend.online': 'online',
  'backend.offline': 'nicht erreichbar',

  'language.label': 'Sprache',

  'operator.backend': 'Backend',
  'operator.tournament': 'Turnier',
  'operator.noTournament': 'keins gewählt',
  'operator.round': 'Runde',
  'operator.openResults': 'Offene Ergebnisse',
  'operator.active': 'aktiv',
  'operator.inactive': 'inaktiv',
  'operator.lastBackup': 'Letztes Backup',
  'operator.backupRecommended': 'Backup empfohlen',
  'operator.backupCurrent': 'aktuell',
  'operator.backupNone': 'noch keins',
  'operator.nextStep': 'Nächster Schritt',

  'common.save': 'Speichern',
  'common.cancel': 'Abbrechen',
  'common.delete': 'Löschen',
  'common.edit': 'Bearbeiten',
  'common.close': 'Schließen',
  'common.export': 'Export',
  'common.import': 'Import',
  'common.print': 'Drucken',
  'common.search': 'Suchen',
  'common.loading': 'Lädt…',
  'common.error': 'Fehler',
  'common.yes': 'Ja',
  'common.no': 'Nein',
} as const;

export type Messages = Record<keyof typeof de, string>;

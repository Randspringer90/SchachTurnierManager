# i18n – Mehrsprachigkeit der WebApp

Dependency-freies i18n-Modul (kein i18next o. Ä., bewusst gemäß AGENTS.md „keine unnötigen Dependencies").

## Aufbau

- `locales/de.ts` – **Basissprache und Schlüsselquelle.** Der Typ `Messages` wird aus diesem
  Objekt abgeleitet; neue Schlüssel werden immer zuerst hier ergänzt.
- `locales/<code>.ts` – eine Datei pro Sprache, `Partial<Messages>`. Fehlende Schlüssel fallen
  zurück auf **Englisch, dann Deutsch** (nie leere Anzeige).
- `index.tsx` – `I18nProvider`, Hook `useI18n()` (liefert `t`, `lang`, `setLang`),
  `LanguageSwitcher`-Komponente, Sprachregistry `LANGUAGES`.

## Verhalten

- Sprachwahl wird unter `localStorage["stm.language"]` gespeichert; initial wird die
  Browsersprache erkannt, Fallback Deutsch.
- `document.documentElement.lang`/`dir` werden gesetzt; Arabisch (`ar`) ist als RTL markiert.
- Interpolation: `t('key', { name: 'Wert' })` ersetzt `{name}` im Text.

## Unterstützte Sprachen (18)

Der Build-Week-Demo-Pfad (Einstieg, Hauptnavigation, Demo, Kern-Runden-/Ergebnis- und
Tabellenaktionen) wird in `de` und `en` gepflegt. Dichte Expertenbereiche wie Audit und
Verwaltung enthalten noch einzelne deutsche Fachtexte und werden deshalb nicht als vollständig
übersetzte Gesamtanwendung beworben.

Vorschau mit Fallback auf en/de: `es`, `fr`, `it`, `pt`, `nl`, `pl`, `cs`, `sv`, `da`, `hu`,
`ru`, `uk`, `tr`, `ar`, `zh`, `ja`. Der Sprachumschalter kennzeichnet diese Gruppe ausdrücklich
als Vorschau.

## Arbeitsanweisung für Folge-Läufe (Codex)

1. Strings aus `main.tsx` schrittweise extrahieren: Literal durch `t('bereich.schluessel')`
   ersetzen, Schlüssel in `de.ts` ergänzen, dann `en.ts`/`es.ts` nachziehen.
2. Pro Lauf einen UI-Bereich (z. B. Teilnehmer, Runden, Exporte) komplett umstellen –
   keine halb übersetzten Bereiche hinterlassen.
3. Danach die Stub-Sprachen befüllen (maschinelle Erstübersetzung ist ok, im PR/Commit
   als solche kennzeichnen).
4. `npm run build` muss grün bleiben; fehlende Schlüssel sind Compile-Fehler in `de.ts`-Typen,
   fehlende Übersetzungen sind erlaubt (Partial).
5. Datums-/Zahlenformate später über `Intl.*` mit `lang` lösen, nicht hart codieren.

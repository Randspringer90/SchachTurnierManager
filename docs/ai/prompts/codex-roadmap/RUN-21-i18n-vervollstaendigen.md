# RUN-21 – Mehrsprachigkeit vervollständigen (18 Sprachen)

Vorab `PROMPT_BASE.md` und `src/SchachTurnierManager.WebApp/src/i18n/README.md` lesen.
Dieser RUN ist **mehrfach ausführbar** – pro Lauf ein Teilpaket.

## Ausgangslage (Fundament fertig, 2026-07-06)
- Dependency-freies i18n-Modul: `I18nProvider`, `useI18n()`/`t()`, `LanguageSwitcher`
  im Header, localStorage-Persistenz, Browsersprach-Erkennung, RTL für Arabisch.
- 18 Sprachen registriert; de/en/es mit Kern-Schlüsseln, 15 Stubs mit Fallback en→de.
- Hero-Header/Status-Karte bereits auf `t('…')` umgestellt (Muster).

## Teilpakete (je Lauf eines)
1. String-Extraktion `main.tsx` bereichsweise: Operator-Leiste, Turnieranlage,
   Teilnehmer, Runden/Ergebnisse, Tabelle/Wertungen, Exporte/Druck, Audit, Chess960/QR.
   Pro Bereich: Literale → `t('bereich.schluessel')`, Schlüssel in `de.ts`,
   Übersetzungen in `en.ts`/`es.ts`. Keine halb umgestellten Bereiche hinterlassen.
2. Sprachpakete füllen: fr, it, pt, nl, pl, cs, sv, da, hu, ru, uk, tr, ar, zh, ja.
   Maschinelle Erstübersetzung ok, im Commit als solche kennzeichnen.
3. Datums-/Zahlenformate über `Intl.DateTimeFormat`/`NumberFormat` mit aktueller Sprache.
4. Druck-/HTML-Berichte des Backends mehrsprachig (Sprachwahl mitgeben).

## Abnahme je Lauf
- `npm run build` grün (tsc erzwingt gültige Schlüssel).
- Manueller Sichttest: Sprache umschalten, umgestellter Bereich vollständig übersetzt,
  kein Mischmasch im Bereich, RTL-Layout bei Arabisch nicht zerstört.

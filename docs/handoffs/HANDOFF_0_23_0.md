# Handoff 0.23.0 - Auslosungsvorschau im Dashboard

## Inhalt

- UI-Typ `NextRoundPreview` ergänzt.
- Dashboard-State `nextRoundPreview` ergänzt.
- Button `Auslosungsvorschau` neben `Nächste Runde auslosen` ergänzt.
- Vorschaukarte zeigt:
  - Zusammenfassung,
  - Qualitätswert und Schweregrad,
  - Rematches,
  - Scoregruppen-Abweichungen,
  - Farbfolge-Risiken,
  - Bye-Anzahl,
  - brettweise Hinweise,
  - Audit mit Scoregruppen, Floatern und Farbnotizen.
- Button `Diese Runde jetzt auslosen` ruft weiterhin den echten Persistenz-Endpunkt auf.
- Vorschau wird bei Turnierwechsel, leerem Turnier und echter Auslosung zurückgesetzt.

## Nachkontrolle

Dieses Patch-Skript führt aus:

- dotnet restore
- dotnet build
- dotnet test
- npm install
- npm run build
- scripts/Pack-Portable.ps1

## Nächster sinnvoller Schritt

v0.24.0: Vorschau wirklich übernehmen statt neu generieren, oder tieferer Swiss-Pairing-Verbesserungsblock mit Kandidatenlisten/Penalties.

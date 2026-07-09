# Bericht: RUN-50 Release Operations, Logging und Secrets

## Ergebnis

0.50.0 ergänzt den Release-/Betriebsunterbau:

- konfigurierbare WebApi-Loglevel über appsettings
- HTTP-Request-Logging ohne Querystrings
- DPAPI-Secret-Lesen und SecretSafety-Selftest
- ReleaseCandidateReadiness mit Desktop/Portable/Installer-Readiness und SHA256-Manifest
- Agenten-Skills für Release, Logging und Repository-Security
- Unit-/Contract-Tests gegen Regressionen

## Grenzen

- Echte Setup-EXE benötigt weiterhin lokal installiertes Inno Setup 6.
- BYOK-/Provider-Adapter werden noch nicht aktiviert; Secrets-Infrastruktur ist vorbereitet.
- Keine externen Projekte oder Maschinenpfade werden referenziert.

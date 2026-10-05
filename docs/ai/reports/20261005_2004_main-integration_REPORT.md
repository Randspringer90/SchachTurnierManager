# Lauf-Fortsetzung: bestehende PRs bis main integrieren

Owner-Nachtrag: main ist jetzt ausdruecklich freigegebenes Integrationsziel.
Releases, Tags, Deployments und History-Rewrite bleiben ausgeschlossen.

Vor diesem Nachtrag: Modellkatalog `f6f9e34`, gepruefter PR #63 per Squash
`d1b6213`, Dokumentationsadoption aus Marcel-Mentes PR #54 in `338d271`.
PR #49/#51/#53 mit statischen Git-/Scopebelegen als durch den offenen PR #55
ersetzt geschlossen. Diese Schliessungen belegen keine bestandene Android-
oder Release-Abnahme. PR #55 traegt die noch offenen Anforderungen.

Die zwei main-exklusiven Dokumentationscommits `33abda9` und `53dba48`
wurden unabhaengig statisch gelesen. Ein normales Merge bewahrt beide
Historien. Die alte externe Pflicht fuer ein workstationgebundenes Fleet-Gate
wird im aktuellen Stand durch eine ausdruecklich optionale historische
Referenz ersetzt; repositoryeigene Safety-Gates bleiben erhalten. Alte
PLANS-Prozentwerte/HOLDs sind historisch; BACKLOG bleibt kanonisch.

Git-Basis vor Zusammenfuehrung: development `338d27186238659463d4f8eef78f62f08a4860da`,
origin/main `53dba48fd764c583248c400e1efd0b957a97a348`, gemeinsamer Vorfahr
`5c66c48ddbe5ac888b175ec5fe08f95adcfad601`. Lokales main ist bereits ein
Vorfahr des development-Stands; keine lokalen Commits werden verworfen.

Der lokale Release-Gate-Lauf am 2026-10-05 bestand Build, 516 .NET-Tests
(13 Golden, 108 Application, 20 Infrastructure, 375 Domain), TypeScript/Vite
und lokale Portable-Paketierung. Der anschliessende Commit-Safety-Check
fand einen Owner-Namen in historischen PLANS-Notizen; diese Referenzen
wurden durch die neutrale Rollenbezeichnung Owner ersetzt. Die Gate-Regeln
bleiben unveraendert. Testpakete und Rohlogs bleiben lokal ausserhalb Git.

Die Zusammenfuehrung wurde nach erneut gruenem CommitGuard und unabhaengigem
Finalreview als `9bf429dd803f751e7e88d1b789afab3f505351f0` committed. Beide
Elternhistorien bleiben enthalten. Git-/OpenSource-Safety, Agent-Integrity,
Prompt-Injection-, Skill-, Knowledge- und Katalog-Gates bestanden.
GitHub-CI dieses SHAs bestand ebenfalls:
https://github.com/Randspringer90/SchachTurnierManager/actions/runs/37355573863
Normaler Push nach development und anschliessend main; beide Remote-SHAs
explizit mit dem lokalen Stand abgeglichen. Keine Ruleset-Aenderung,
kein Force-Push, Release, Tag, Deployment oder Artefakt-Upload.

PR #84 wurde auf aktuellen Base-/Head-SHAs erneut statisch geprueft;
164 lokale QR-Tests, voller CommitGuard (516 .NET-Tests, TypeScript/Vite,
lokale Paketierung), unabhaengiger Finalreview und alle acht aktuellen
GitHub-Checks bestanden. PR-Head `d690767a1a5c571d48f31f02edbabd5e33d237b4`,
CI https://github.com/Randspringer90/SchachTurnierManager/actions/runs/37356822059
Merge `50a33671cc6b197ffa4227835e46a138c7ce3247`; integrierter Tree identisch
mit dem getesteten PR-Tree. Auch main normal fast-forwarded/gepusht und
beide Remote-SHAs verifiziert. Branches wurden erhalten.

Startinventur: 29 PRs. Stand nach #84: 2 merged (#63/#84), 4 nachvollziehbar
superseded geschlossen (#49/#51/#53/#54), 23 noch offen. Zwischenzeitlich
erstellte PRs werden davon getrennt inventarisiert. #55/#57/#59 haben
dokumentierte echte technische/fachliche/Security-Blocker; kein blockierter
Head wurde ausgefuehrt. Dies bleibt ein Zwischenbericht bis alle Start-PRs
abschliessend klassifiziert und der konsolidierte Stand verifiziert sind.

# Gesperrte Recovery-Adoption: Reviewkontext

Stand 2026-10-28. Base `d168a5a12a65dd66af18829277b7dab02c4422db`.
#125 Head `628a260165850bf1954871640b9c1986cb0c1b2e`, #129 Head
`df77b4010aae14a3da5c615192d1b67a210c4640`. Beide bleiben
`BLOCKED_UNVERIFIED`. Keine Ausführung oder Übernahme, keine doppelte Integration.

Der statische Review von #129 meldet `PERSISTENCE_MECHANISM`, CRITICAL, in
`tests/scripts/service-worker.test.mjs`, Evidenzhash `152bb7a7dc8f9936`.
Der vollständige Textdiff wurde ohne externe Diff-/Textconv-Helfer gelesen.
Das Wort `startup` kommt im unveränderten Kommentar über statische Shellmodule
vor; dieser Kontext ist auch in der Base vorhanden. Das ist ein begründeter
Fehlalarmkandidat, keine Freigabe und kein Beweis für die Sicherheit des übrigen PRs.
Die neuen Tests prüfen Cacheabschluss, atomare Offline-Shell-Versionen und den
Ausschluss privater Recovery-Pfade. Ihr Code wurde nicht ausgeführt.

#125 enthält zusätzlich einen Credential-Musterbefund in seiner Dokumentation.
#129 ist als sichere Adoption geplant; erst nach tatsächlicher Freigabe ersetzt
es #125. Die Skillregel `safe-pr-adoption` lautet ausdrücklich:
„Bei `BLOCKED_UNVERIFIED`, SHA-/Policy-Drift oder fehlender expliziter
Owner-Dateifreigabe“ nicht anwenden.

Erforderlich: zugelassener unabhängiger Securityreview des vollständigen Heads,
SHA-/Policy-gebundene Einordnung der konkreten Scannerkontexte und vorhandene
Owner-Dateifreigabe. Danach den aktuellen Base-/Headstand erneut prüfen, #128-
Zeitstempelkorrekturen erhalten und Recovery selektiv übernehmen. Scanner,
CI-Vertrauenswurzel und Befundstatus werden nicht durch diesen Bericht verändert.

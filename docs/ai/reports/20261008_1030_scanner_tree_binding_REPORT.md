# Finalintegration: GitHub-Tree-Bindung des statischen Scanners

Der bereits gepruefte Integrationsstand wird weiterverwendet. Dieser kleine Folgefix
behebt ausschliesslich den tatsaechlichen CI-Fehler TEXT_EVIDENCE_TREE_BINDING.

GitHub akzeptiert einen Commit-SHA beim Git-Tree-Endpunkt, gibt dabei im Feld sha
aber diesen Commit-Verweis zurueck. Der vollstaendige Textpatch-Fallback verlangt
zu Recht die exakte Identitaet mit commit.tree.sha. Daher fragt der Online-Adapter
nach validierten Tree-SHAs aus der Commit-Metadatenantwort erneut die Trees ab.
Alle bestehenden Commit-, Tree-, Blob-, Inventar-, Hunk- und Groessenpruefungen
bleiben bestehen. Kein Gate oder Ruleset wird abgeschwaecht.

Der Adapter-Regressionstest fuehrt nur die eigene vertrauenswuerdige Funktion mit
synthetischem Transport aus: der alte Stand scheitert am reproduzierten Binding;
der neue Stand besteht den korrekten Tree-Verweis und die Ablehnung eines
ungueltigen Tree-SHAs vor dessen Verwendung. Keine Netzwerkanfragen oder Ausfuehrung
fremden PR-Codes. Fokussiert gruen: 106 Textpatch-Assertions, 285 Pattern-Assertions,
44 Scanner-Risikofaelle und beide neuen Adapterfaelle. Erste Harnessversuche mit
fehlendem Library-Import und fehlendem ScratchParent bleiben dokumentierte
fehlgeschlagene Versuche und werden nicht als PASS umgedeutet.

Der Live-Online-Test des lokal veraenderten Adapters wird vom unveraenderten
Trusted-Base-Guard erwartungsgemaess abgelehnt. Der eigentliche grosse Integrations-PR
kann erst nach einem regulaeren, vollstaendig CI-geprueften Scanner-Folge-PR erneut
mit dem vertrauenswuerdigen development-Stand geprueft werden.

Offen bei Erstellung: exakter SHA-Review, Remote-CI und geschuetzte Integration.
Es wird kein Bootstrap-Bypass fuer fehlgeschlagene Checks beansprucht.

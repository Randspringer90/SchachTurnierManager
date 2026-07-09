# Skill: Kollegeninstallation und Distribution

Use when building or reviewing release artifacts for colleagues, Vereinswebsite downloads or handoff packages.

## Goals

- Produce a self-contained Windows delivery that does not require .NET, Node, npm or other local projects on the target machine.
- Prefer a Setup EXE when Inno Setup is available; otherwise provide the Desktop ZIP with a clear double-click start file.
- Keep the terminal quiet: logs go to a `D:\Temp\<RunName>_<Timestamp>` folder and the run ends with one upload ZIP.

## Required checks

- Run `scripts/Invoke-ColleagueInstallReadiness.ps1 -BuildInstaller -AllowMissingInnoSetup`.
- Verify `output/SchachTurnierManager_Kollegenpaket_<Version>.zip` exists.
- Verify the package contains `README_START_HIER.txt`, `KOLLEGENPAKET_MANIFEST.txt` and `CHECKSUMS_SHA256.txt`.
- Verify no `.secrets`, `.npmrc`, `.env`, databases, logs, dumps, build folders or real tournament files are included.

## Installation guidance

- With installer: double-click `SchachTurnierManager_Setup_<Version>.exe`.
- Without installer: unpack `SchachTurnierManager_Desktop_<Version>.zip` and double-click `SchachTurnierManager.bat`.
- Healthcheck: `http://127.0.0.1:5088/api/health`.
- Dashboard: `http://127.0.0.1:5088/`.
- Data lives under `%LocalAppData%\SchachTurnierManager`.

## Secrets

- Release packages must not contain real secrets.
- Provider keys, if introduced later, are stored locally per Windows user with DPAPI under `.secrets/local/`.
- DPAPI files are not portable and are never committed.

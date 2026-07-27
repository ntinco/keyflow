# keyflow

Private Windows automation workspace built on AutoHotkey v2. This repo is optimized for fast AI maintenance, not for public packaging.

## AI operating guide

For operational maintenance, use `ai/health-check.summary.json`, `ai/repo-map.json`, and `AGENTS.md` before changing runtime files.
Machine-readable governance rules live in `ai/governance.json`.
Reviewer pass: run `python ai/review_check.py --pretty --summary` after another AI finishes a cycle.
This guide layer is intentionally dual-role: architect selects or reviews the frontier, and executor implements and validates it. One AI may perform both roles when that is simpler.

## Architecture

```text
platforms/windows/keyflow.ahk
  library/bootstrap.ahk
    library/config/constants-core.ahk
    library/automation/ (6 services)
  hotkeys/global.ahk
  hotkeys/sap-gui.ahk
  hotkeys/sap-eclipse.ahk
  hotkeys/domains/productivity.ahk
```

Main service surface:

`hotstring` `launcher` `sap` `snipaste` `windowGroup` `windows`

## Hotkey catalog

`platforms/windows/data/hotkeys.db` is the only human-managed source of hotkey definitions. Humans may edit it with a SQLite editor. The AHK trigger modules and `platforms/windows/hotkeys/README.md` are generated AI-maintenance artifacts.

After changing the database:

```powershell
python ai/hotkey_sync.py --sync
python ai/hotkey_sync.py --check
```

Generic application remaps belong in each application's native keymap. Keyflow keeps compound workflows, SAP/ADT business actions, and Windows automations that still provide meaningful leverage.

The catalog separates implementation from intent:

- `platform` identifies where the current action is implemented. Every current AHK action is `windows`.
- `portability=portable-intent` marks behavior worth evaluating for a native macOS binding.
- `portability=windows-only` marks behavior tied to Windows applications or APIs.

## SAP model

- `platforms/windows/library/automation/sap.ahk` is the public `services.sap` facade for actions inside active SAP GUI/NWBC and Eclipse/ADT contexts.
- Transaction hotstrings are scoped to SAP GUI/NWBC; they no longer launch credential-backed sessions from Eclipse.
- `platforms/windows/tools/sap-gui/sap-gui-cli.bat` remains an optional local execution bridge. It does not store credentials or participate in the main runtime.

## Configuration contract

All machine-specific configuration is local-only. Use these versioned examples as structure references:

| Example file | Purpose |
|---|---|
| `platforms/windows/data/local-paths.example.ini` | Machine paths and ABAP workspace hints |
| `platforms/windows/data/local-startup.example.ini` | Runtime env, SAP delays, UI config, startup launcher config |

Local-only files that must never be committed:

`local-secrets.ini` · `local-paths.ini` · `local-startup.ini` · `memory-vars.ini` · `rom.ini` · `storage.db` · `ai/run-result.json`

## Startup scripts

`platforms/windows/tools/startup/host-startup.ahk` and `vmware-startup.ahk` are secondary launchers. They prepare a local machine context and then launch `platforms/windows/keyflow.ahk`.

The preferred startup contract lives in `local-startup.ini`:

- `[startup-host]`
- `[startup-vmware]`
- `[runtime-env]`
- `[sap-delays]`
- `[ui]`

## Onboarding

1. Install AutoHotkey v2 on Windows.
2. Copy each `*.example.*` file to its local counterpart when needed.
3. Run `python ai/health_check.py --pretty --summary`.
4. Launch `platforms/windows/keyflow.ahk`.

## Current model

- One intentional global remains: `services` in `platforms/windows/keyflow.ahk`.
- The `utils` global object is gone; utility behavior lives in free `util*()` functions.
- Launcher and window-group flows now use clearer intent-first names instead of legacy helper wording.
- The human hotkey catalog is `hotkeys.db`; generated AHK and Markdown drift is enforced by `ai/hotkey_sync.py --check` through the health check.
- The Windows runtime is reduced to 22 hotkeys, 6 hotstrings, and 6 registered services; portable intent is cataloged separately from implementation platform.
- Value resolution and shell-command execution are free utility functions; Everything run-count updates belong privately to `LauncherService`.
- Service APIs and assets retired with removed hotkeys have been deleted; the remaining public methods all have runtime consumers.
- Credential-provider and named SAP session-launch support are currently retired.
- Hotkey usage tracking has been fully removed after serving its purpose in catalog reduction; no service or catalog column instruments hotkeys anymore.
- Catalog review state now lives in `ai/catalog-review.json`, and the current active catalog entries are marked `verified`.
- AI governance contract now lives in `ai/governance.json` and centers on the architect/executor role model.
- This is a summary; AGENTS.md Current Model is authoritative.

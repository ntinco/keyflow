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
    library/config/constants-secrets.ahk
    library/automation/ (13 services)
  hotkeys/hotkey-tracking.ahk
  hotkeys/global.ahk
  hotkeys/sap-gui.ahk
  hotkeys/sap-eclipse.ahk
  hotkeys/editors-ide.ahk
  hotkeys/editors-office.ahk
  hotkeys/editors-text.ahk
  hotkeys/domains/comms.ahk
  hotkeys/domains/productivity.ahk
```

Main service surface:

`dynamic` `everything` `hotkeyTracker` `hotstring` `launcher` `memory` `run` `sap` `snipaste` `video` `whatsapp` `windowGroup` `windows`

## Hotkey catalog

`platforms/windows/data/hotkeys.db` is the only human-managed source of hotkey definitions. Humans may edit it with a SQLite editor. The AHK trigger modules and `platforms/windows/hotkeys/README.md` are generated AI-maintenance artifacts.

After changing the database:

```powershell
python ai/hotkey_sync.py --sync
python ai/hotkey_sync.py --check
```

Generic application remaps belong in each application's native keymap. Keyflow keeps compound workflows, SAP/ADT business actions, and Windows automations that still provide meaningful leverage.

## SAP model

- SAP secrets and session metadata come from KeePassXC through `keepassProviderCommand`.
- Session names are business-first: `pluz dev`, `pluz qas`, `pluz prd`.
- `platforms/windows/library/automation/sap-session.ahk` owns session lookup, entry resolution, launch command assembly, credential filling, and relaunch from project-window context.
- `platforms/windows/library/automation/sap.ahk` is the public `services.sap` facade for SAP GUI and Eclipse automation plus delegated session entrypoints.

KeePass lookup flow:

```text
kp:sap-index/session/pluz dev  ->  kp:company/nttdata/cliente/pluz dev
```

## Configuration contract

All machine-specific configuration is local-only. Use these versioned examples as structure references:

| Example file | Purpose |
|---|---|
| `platforms/windows/data/local-paths.example.ini` | Machine paths, app targets, ABAP workspace hints |
| `platforms/windows/data/local-startup.example.ini` | Runtime env, SAP defaults, UI config, startup launcher config |
| `platforms/windows/data/local-secrets.example.ini` | Secrets and `keepassProviderCommand` |
| `platforms/windows/data/sap-keepass-layout.example.md` | Expected KeePass entry layout |

Local-only files that must never be committed:

`local-secrets.ini` · `local-paths.ini` · `local-startup.ini` · `memory-vars.ini` · `rom.ini` · `storage.db` · `hotkey-usage.json` · `ai/run-result.json`

## Startup scripts

`platforms/windows/tools/startup/host-startup.ahk` and `vmware-startup.ahk` are secondary launchers. They prepare a local machine context and then launch `platforms/windows/keyflow.ahk`.

The preferred startup contract lives in `local-startup.ini`:

- `[startup-host]`
- `[startup-vmware]`
- `[runtime-env]`
- `[sap-defaults]`
- `[sap-delays]`
- `[ui]`

## Onboarding

1. Install AutoHotkey v2 on Windows.
2. Copy each `*.example.*` file to its local counterpart when needed.
3. Configure `keepassProviderCommand` using `platforms/windows/tools/keepass/kp-get.ps1` as the reference provider.
4. Run `python ai/health_check.py --pretty --summary`.
5. Launch `platforms/windows/keyflow.ahk`.

## Current model

- One intentional global remains: `services` in `platforms/windows/keyflow.ahk`.
- The `utils` global object is gone; utility behavior lives in free `util*()` functions.
- Launcher and window-group flows now use clearer intent-first names instead of legacy helper wording.
- The human hotkey catalog is `hotkeys.db`; generated AHK and Markdown drift is enforced by `ai/hotkey_sync.py --check` through the health check.
- Catalog review state now lives in `ai/catalog-review.json`, and the current active catalog entries are marked `verified`.
- AI governance contract now lives in `ai/governance.json` and centers on the architect/executor role model.
- This is a summary; AGENTS.md Current Model is authoritative.

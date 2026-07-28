# keyflow

Private Windows automation workspace built on AutoHotkey v2, with a first macOS Hammerspoon slice. Optimized for fast AI maintenance, not for public packaging.

## AI operating guide

For operational maintenance, use `ai/health-check.summary.json`, `ai/repo-map.json`, and `AGENTS.md` before changing runtime files.
Machine-readable governance rules live in `ai/governance.json`.
Reviewer pass: run `python ai/review_check.py --pretty --summary` after another AI finishes a cycle.
This guide layer is intentionally dual-role: architect selects or reviews the frontier, and executor implements and validates it. One AI may perform both roles when that is simpler.
Runtime code and the guide layer are optimized for AI maintenance; human responsibility is intent and runtime acceptance.

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

platforms/macos/hammerspoon/
  init.lua                    (entrypoint)
  actions.lua                 (non-blocking, hand-authored hotkey behavior)
  hotstrings.lua              (hs.eventtap watcher)
  generated/bindings.lua      (generated from the shared catalog)
```

Windows service surface: `hotstring` `launcher` `sap` `snipaste` `windowGroup` `windows`

## Hotkey catalog

`platforms/shared/data/hotkeys.db` is the only human-managed source of hotkey definitions, shared by the Windows AHK runtime and the macOS Hammerspoon runtime. Humans edit it with a SQLite editor. The AHK trigger modules, `platforms/windows/hotkeys/README.md`, and `platforms/macos/hammerspoon/generated/bindings.lua` are generated AI-maintenance artifacts.

After changing the database:

```bash
python ai/hotkey_sync.py --sync
python ai/hotkey_sync.py --check
```

The catalog separates implementation from intent:

- `platform` identifies which runtime(s) currently implement the action (`windows`, `macos`, or both).
- `portability=portable-intent` marks behavior worth evaluating for a native macOS binding.
- `portability=windows-only` marks behavior tied to Windows applications or APIs.

The `action` column holds raw AHK syntax and is not transpiled; macOS behavior for `platform=macos` rows is hand-authored in `platforms/macos/hammerspoon/actions.lua` and `hotstrings.lua`, matched by row `id`.

## SAP model

- `platforms/windows/library/automation/sap.ahk` is the public `services.sap` facade for actions inside active SAP GUI/NWBC and Eclipse/ADT contexts. No credential storage or session launch is part of the runtime.

## Configuration contract

All machine-specific configuration is local-only. Use these versioned examples as structure references:

| Example file | Purpose |
|---|---|
| `platforms/windows/data/local-paths.example.ini` | Machine paths and ABAP workspace hints |
| `platforms/windows/data/local-startup.example.ini` | Runtime environment and SAP delays |

Local-only files that must never be committed:

`local-secrets.ini` · `local-paths.ini` · `local-startup.ini` · `memory-vars.ini` · `rom.ini` · `storage.db` · `ai/run-result.json` · `ai/run-result-macos.json`

## Onboarding — Windows

1. Install AutoHotkey v2.
2. Copy each `*.example.*` file to its local counterpart when needed.
3. Run `python ai/health_check.py --pretty --summary`.
4. Launch `platforms/windows/keyflow.ahk`.

## Onboarding — macOS

1. Install Hammerspoon.
2. Symlink the repo into Hammerspoon's config dir, e.g. `ln -s <repo>/platforms/macos/hammerspoon ~/.hammerspoon/keyflow`.
3. In `~/.hammerspoon/init.lua`, add: `dofile(hs.configdir .. "/keyflow/init.lua")`.
4. Reload Hammerspoon and check the console for `keyflow: loaded ... app-scoped hotkey(s), hotstring watcher active`.

## Current model

This is a summary; `AGENTS.md` → `Current model` is authoritative for governance-enforced detail.

- Objective counts (services, hotkeys, profiles) live in `ai/health-check.summary.json`.
- The macOS slice covers SAP GUI, Eclipse/ADT, hotstrings, and Raycast launcher workflows. Contextual hotkeys are active only in their target application, and delayed SAP steps stop when SAP GUI loses focus.
- No credential-provider, session-launch, or hotkey-usage-tracking dependency exists in either runtime.

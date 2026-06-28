# keyflow

Private Windows automation workspace built on AutoHotkey v2. This repo is optimized for fast AI maintenance, not for public packaging.

## AI operating guide

Read in this order:

1. `ai/health-check.summary.json`
2. `ai/repo-map.json`
3. `AGENTS.md`
4. `README.md`

Those files are the only operational guide layer. If code changes materially, they must be updated in the same cycle.

## Runtime shape

```text
platforms/windows/keyflow.ahk
  library/bootstrap.ahk
    library/automation/
    library/config/
  hotkeys/global.ahk
  hotkeys/sap.ahk
  hotkeys/editors.ahk
  hotkeys/domains.ahk
```

Main service surface:

`dynamic` `everything` `hotkeyTracker` `hotstring` `launcher` `memory` `run` `sap` `snipaste` `video` `whatsapp` `windowGroup` `windows`

## SAP model

- SAP secrets and session metadata come from KeePassXC through `keepassProviderCommand`.
- Session names are business-first: `pluz dev`, `pluz qas`, `pluz prd`.
- `platforms/windows/library/automation/sap-session.ahk` owns session lookup, entry resolution, launch command assembly, and credential filling.
- `platforms/windows/library/automation/sap.ahk` owns SAP GUI and Eclipse automation over an existing session.

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

`local-secrets.ini` · `local-paths.ini` · `local-startup.ini` · `memory-vars.ini` · `rom.ini` · `storage.db` · `hotkey-usage.json`

## Startup scripts

`platforms/windows/tools/startup/host-startup.ahk` and `vmware-startup.ahk` are secondary launchers. They are not the source of truth for runtime behavior; they only prepare a machine context and then launch `platforms/windows/keyflow.ahk`.

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

## Current evolution status

- The repo is in aggressive simplification mode.
- Retired naming and retired guide paths are treated as regressions.
- The AI operating guide must be refreshed after every important execution cycle.
- Next frontier: continue deleting dormant public surface and optional helpers that no longer accelerate change.

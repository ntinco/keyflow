# keyflow

Private Windows automation workspace built on AutoHotkey v2. Global hotkeys, app grouping, SAP session helpers, dynamic command execution, hotstrings, and machine-local startup automation.

## AI-first entry

| File | Purpose |
|---|---|
| `ai/health-check.summary.json` | Current repo state — read this first |
| `ai/health_check.py` | Generates both summary and full contract |
| `ai/repo-map.json` | Domain routing map |
| `AGENTS.md` | Naming contract and hard rules for agents |

## Runtime shape

```
keyflow.ahk
  library/bootstrap.ahk          — constants, services, hotstring profiles
    library/automation/           — 13 registered services
    library/config/               — constants: paths, apps, rules, secrets
  hotkeys/global.ahk              — global shortcuts
  hotkeys/sap.ahk                 — SAP GUI + Eclipse shortcuts
  hotkeys/editors.ahk             — editor shortcuts
  hotkeys/domains.ahk             — domain shortcuts (comms, media, productivity)
```

## Services

`dynamic` `everything` `hotkeyTracker` `hotstring` `launcher` `memory` `run` `sap` `snipaste` `video` `whatsapp` `windowGroup` `windows`

## Boot flow

1. `keyflow.ahk` loads `bootstrap.ahk`
2. `bootstrap.ahk` loads constants → services → hotstring profiles
3. `keyflowInitServices()` registers all services and activates hotstring catalogs
4. Hotkey modules become active

## Configuration contract

All machine-specific config lives in local files (never versioned). Use example files as reference:

| Example file | Configures |
|---|---|
| `data/local-paths.example.ini` | Machine paths, ABAP workspace, app titles |
| `data/local-startup.example.ini` | Startup behavior, SAP defaults (`YMT1`, `YSAP`, tcodes, delays) |
| `data/local-secrets.example.ini` | `keepassProviderCommand` and other secrets |
| `data/sap-keepass-layout.example.md` | KeePass entry layout for SAP sessions |

## KeePass convention

SAP sessions use a two-level lookup:

```
kp:sap-index/session/pluz dev  →  kp:company/nttdata/cliente/pluz dev
```

`sap-session.ahk` reads `title`, `user`, `pass`, `url`, `mandt`, `sapTcode`, `languageCode` from the resolved entry.

## Onboarding

1. Install AutoHotkey v2 on Windows.
2. Copy example files to local counterparts as needed.
3. Set `keepassProviderCommand` — reference script: `tools/keepass/kp-get.ps1`.
4. Launch `platforms/windows/keyflow.ahk`.

## Local-only files (never commit)

`local-secrets.ini` · `local-paths.ini` · `local-startup.ini` · `memory-vars.ini` · `rom.ini` · `storage.db` · `hotkey-usage.json`

## docs/

| File | Purpose |
|---|---|
| `docs/smoke-test.md` | Manual startup checklist with bundled-exe command |
| `docs/health-check.md` | Runtime contract reference (prose companion to `ai/health-check.json`) |

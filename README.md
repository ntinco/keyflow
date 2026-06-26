# keyflow

`keyflow` is a private reusable Windows automation workspace built on AutoHotkey v2. It acts as a personal productivity and SAP workflow layer: global hotkeys, app grouping, SAP session helpers, dynamic command execution, hotstrings, and machine-local startup automation.

This repository is meant to be reusable across trusted environments, but it is not a generic public package yet. Local configuration, credentials, and runtime artifacts still need to stay outside version control.

## Current status

- The working tree currently has no `.git` directory.
- Before publishing or initializing Git, sanitize local-only files and confirm `.gitignore` matches the files you actually keep on this machine.
- The repository name `keyflow` is acceptable only if this README continues to make the Windows AutoHotkey plus SAP productivity purpose explicit.

## Repository layout

### Core entrypoint

- `platforms/windows/keyflow.ahk`
  - Starts the AutoHotkey app.
  - Loads `library/bootstrap.ahk`.
  - Includes the main hotkey groups.

### Shared code

- `platforms/windows/library/bootstrap.ahk`
  - Loads constants, secrets, shared services, and initializes runtime service objects.
- `platforms/windows/library/config/`
  - Defines core paths, application constants, rules, and secret-loading behavior.
- `platforms/windows/library/automation/`
  - Contains service classes for dynamic actions, launchers, window automation, SAP session flows, hotstrings, clipboard workflows, and related helpers.
- `platforms/windows/library/ui/`
  - Small UI helpers such as overlays and theme handling.

### User behavior

- `platforms/windows/hotkeys/`
  - Global hotkeys and grouped domain behavior.
- `platforms/windows/hotkeys/domains/`
  - Domain-specific bindings such as productivity, comms, and web/media contexts.
- `platforms/windows/hotkeys/layouts/`
  - Layout-specific keyboard support such as Colemak-DH.

### Data and configuration

- `platforms/windows/data/`
  - Versioned catalogs: hotstrings, snippets, SAP transaction metadata, and example config files.
  - Local-only files: secrets, machine paths, startup config, runtime memory vars, and credential payloads.

### Tools

- `platforms/windows/tools/startup/`
  - Startup automation for launching the local workstation stack.
- `platforms/windows/tools/exe/`
  - Bundled helper executables used by the automation environment.

## Boot flow

1. Run `platforms/windows/keyflow.ahk` with AutoHotkey v2.
2. `library/bootstrap.ahk` loads:
   - core constants
   - local path configuration
   - secret configuration
   - shared service classes
3. `keyflowInitServices()` initializes reusable services and registers hotstring profiles.
4. Hotkey modules under `platforms/windows/hotkeys/` become active.
5. Runtime data files under `platforms/windows/data/` drive hotstrings, SAP shortcuts, usage tracking, and local environment behavior.

## Configuration contract

The repo already exposes a stable config contract through example files and environment variables.

### Naming convention

Rules (ordered by priority):

1. **English-first** — all files, classes, services, helpers, groups, and runtime targets use English identifiers.
2. **`keyflow*` prefix** — new runtime APIs and service names use `keyflow` as the product namespace. Do not introduce new `norman*` symbols.
3. **Intent over history** — names express what a thing _does_, not when it was created or what it replaced.
4. **External labels stay as-is** — SAP window titles, executable names, KeePass entry paths, and business domain names (e.g. `pluz dev`, `saplogon.exe`) are never translated or renamed.
5. **`NORMAN_*` env vars are legacy-compatible** — they remain supported as external environment inputs. The pattern is: env-var override first, file fallback second. They are not renamed by default; see the full list under [Environment variables currently supported](#environment-variables-currently-supported).

Preferred vocabulary by layer:

| Layer | Preferred terms |
|---|---|
| Data loading | `session`, `entry`, `provider`, `catalog` |
| Window matching | `window`, `workspace`, `target` |
| Activation scope | `profile`, `group`, `context` |
| Execution | `command`, `run`, `action` |
| Config | `path`, `secret`, `constant` |

### Example files

- `platforms/windows/data/local-paths.example.ini`
  - Machine-specific paths for ABAP workspaces and desktop tools.
- `platforms/windows/data/local-startup.example.ini`
  - Startup behavior, mapped drives, portable app launch list, and SAP defaults.
- `platforms/windows/data/local-secrets.example.ini`
  - Secret placeholders loaded by the runtime.
- `platforms/windows/data/sap-keepass-layout.example.md`
  - Reference layout for SAP and VPN profiles stored fully in KeePass via the local provider command.

### Environment variables currently supported

`platforms/windows/library/config/constants-core-paths.ahk`

- `NORMAN_PATH_ABAP_GIT_REPO`
- `NORMAN_PATH_YM_WORKSPACE`
- `NORMAN_PATH_ABAP_INBOX`
- `NORMAN_FILE_EVERYTHING_CLI`
- `NORMAN_FILE_FORTISSL`
- `NORMAN_FILE_FORTICLIENT_GUI`
- `NORMAN_FILE_PULSE_GUI`
- `NORMAN_FILE_NETEXTENDER_GUI`

`platforms/windows/library/config/constants-secrets.ahk`

- `NORMAN_PATH_GPT_NEWS`
- `NORMAN_NTT_OFFICE_PASS`
- `NORMAN_KEEPASS_XC`
- `NORMAN_KEEPASS_PROVIDER_CMD`

`platforms/windows/tools/startup/host-startup.ahk`

- `NORMAN_STARTUP_DOWNLOADS_PATH`
- `NORMAN_STARTUP_BASE_DRIVE`
- `NORMAN_STARTUP_SYNC_BATCH_FILE`
- `NORMAN_STARTUP_FLOWLAUNCHER_LOGS_DIR`
- `NORMAN_STARTUP_AIMP_PORTABLE_LINK`
- `NORMAN_STARTUP_PORTABLE_LINKS_CSV`

## Versioned files vs local-only files

Safe to version:

- AutoHotkey source under `platforms/windows/`
- versioned JSON catalogs such as `autocorrect.json`, `quick-snippets.json`, and transaction metadata
- `*.example.*` configuration files
- documentation such as this README and `agents.md`

Keep local only:

- `platforms/windows/data/local-secrets.ini`
- `platforms/windows/data/local-paths.ini`
- `platforms/windows/data/local-startup.ini`
- `platforms/windows/data/memory-vars.ini`
- `platforms/windows/data/rom.ini`
- `storage.db`
- `platforms/windows/storage.db`
- any future runtime artifact that stores credentials, usage traces, or machine-specific state

## Onboarding checklist

1. Install AutoHotkey v2 on Windows.
2. Copy each example config file to its live local counterpart only if you need that feature.
3. Fill local secrets and credentials outside version control.
   - Configure `keepassProviderCommand` or `NORMAN_KEEPASS_PROVIDER_CMD`.
   - Store SAP metadata and secrets in KeePass using the direct entry convention described below.
   - `platforms/windows/tools/keepass/kp-get.ps1` is the reference provider script for Windows.
4. Review machine-specific paths before enabling startup automation.
5. Launch `platforms/windows/keyflow.ahk`.

## KeePass convention for SAP

- Lookup refs:
  - `kp:sap-index/session/pluz dev`
  - `kp:sap-index/session/pluz qas`
  - `kp:sap-index/session/pluz prd`
- Each lookup should return a direct entry ref such as `kp:company/nttdata/cliente/pluz prd`.
- `sap-session.ahk` then reads fields from that entry, for example:
  - `kp:company/nttdata/cliente/pluz prd/title`
  - `kp:company/nttdata/cliente/pluz prd/user`
  - `kp:company/nttdata/cliente/pluz prd/pass`
  - `kp:company/nttdata/cliente/pluz prd/url`
  - `kp:company/nttdata/cliente/pluz prd/mandt`
  - `kp:company/nttdata/cliente/pluz prd/sapTcode`
  - `kp:company/nttdata/cliente/pluz prd/languageCode`
- Optional fields may return empty text, but required SAP login fields must resolve to values.
- The reference script `kp-get.ps1` maps `title` to KeePass `Title`, `pass` to `Password`, `user` to `UserName`, and other leaf names to custom attributes on the parent entry.

## Saneamiento before Git init or publish

- Confirm that `platforms/windows/data/memory-vars.ini` only contains local runtime state.
- Keep `storage.db` and `platforms/windows/storage.db` out of version control.
- Recheck `.gitignore` whenever new local config or runtime artifacts are added.

## Notes for future cleanup

- If this repo becomes public-facing, decouple more personal paths, portable app assumptions, and bundled binaries.
- If `keyflow` stops being the visible product name, reevaluate the repository slug after the README and onboarding story are stable.

# AGENTS.md

This repository is a private reusable Windows automation workspace built around AutoHotkey v2. Treat it as an operational codebase with local-only configuration, not as a generic public package.

## Naming convention

### Rules (ordered by priority)

1. **English-first** — all files, classes, services, helpers, groups, and runtime targets use English identifiers.
2. **`keyflow*` prefix** — new runtime APIs and service names use `keyflow` as the product namespace (e.g. `keyflowInitServices`, `keyflowServiceRegistry`). Do not introduce new `norman*` symbols.
3. **Intent over history** — names express what a thing _does_, not when it was created or what it replaced.
4. **External labels stay as-is** — SAP window titles, executable names, KeePass entry paths, and business domain names (e.g. `pluz dev`, `saplogon.exe`) are never translated or renamed.
5. **`NORMAN_*` env vars are legacy-compatible** — they remain supported as external environment inputs. Preserve the pattern: env-var override first, file fallback second. Do not rename them in code unless the user explicitly requests a migration.

### Vocabulary by layer

| Layer | Preferred terms |
|---|---|
| Data loading | `session`, `entry`, `provider`, `catalog` |
| Window matching | `window`, `workspace`, `target` |
| Activation scope | `profile`, `group`, `context` |
| Execution | `command`, `run`, `action` |
| Config | `path`, `secret`, `constant` |

### What to avoid

- Do not mix `logon` / `login` / `session` for the same concept.
- Do not mix `gui` / `window` / `desktop` if they represent the same layer.
- Do not mix `run` / `open` / `execute` / `start` without a clear criterion.
- Do not introduce abbreviations that are not already used in the codebase.

## What this repo is

- `platforms/windows/keyflow.ahk` is the main entrypoint.
- `platforms/windows/library/` contains shared services and bootstrap logic.
- `platforms/windows/library/automation/sap-session.ahk` owns SAP session resolution and KeePassXC-backed login.
- `platforms/windows/library/automation/sap.ahk` owns SAP GUI and Eclipse automation on top of session handling.
- `platforms/windows/hotkeys/` contains user-facing shortcuts grouped by area such as global, SAP, editors, and domain-specific contexts.
- `platforms/windows/data/` mixes versioned catalogs with local-only runtime files. Be careful here.
- `platforms/windows/tools/` contains helper executables and startup scripts used by the Windows workflow.

## Recommended reading order

1. `platforms/windows/keyflow.ahk`
2. `platforms/windows/library/bootstrap.ahk`
3. `platforms/windows/library/config/constants-core-paths.ahk`
4. `platforms/windows/library/config/constants-secrets.ahk`
5. `platforms/windows/hotkeys/global.ahk`
6. `platforms/windows/hotkeys/sap-gui.ahk`
7. `platforms/windows/hotkeys/sap-eclipse.ahk`
8. `platforms/windows/library/automation/sap-session.ahk` for session and credential changes
9. `platforms/windows/library/automation/sap.ahk` for SAP GUI or Eclipse automation changes

## Sensitive and local-only files

Default rule: prefer examples and schemas over live local files.

Do not rely on or modify these files unless the user explicitly asks:

- `platforms/windows/data/local-secrets.ini`
- `platforms/windows/data/local-paths.ini`
- `platforms/windows/data/local-startup.ini`
- `platforms/windows/data/memory-vars.ini`
- `platforms/windows/data/rom.ini`
- `storage.db`
- `platforms/windows/storage.db`

Use these instead when you need structure:

- `platforms/windows/data/local-secrets.example.ini`
- `platforms/windows/data/local-paths.example.ini`
- `platforms/windows/data/local-startup.example.ini`
- `platforms/windows/data/sap-keepass-layout.example.md`

## Editing rules for agents

- Keep changes scoped and preserve the current AHK v2 style.
- Do not replace real local values with guessed values.
- Prefer documenting configuration contracts instead of hardcoding machine-specific paths.
- When changing data-loading behavior, preserve the current pattern of legacy `NORMAN_*` env var override first, file fallback second.
- Treat `kp:sap-index/session/pluz dev` style lookups and direct KeePass entry refs like `kp:company/.../pluz prd` as the supported SAP credential convention unless the user asks to redesign it.
- Keep SAP session concerns in `sap-session.ahk` and SAP GUI or Eclipse automation concerns in `sap.ahk`. Do not merge them again unless the user explicitly asks for it.
- When the user asks to simplify or restart a subsystem, prefer deleting legacy paths and compatibility code instead of preserving historical behavior.
- Assume the repo may be copied around without a `.git` directory. Do not depend on Git metadata at runtime.

## Validation guidance

- For documentation-only changes, verify that the docs match the current code layout and config names.
- For code changes, check the affected include chain from `keyflow.ahk` through `bootstrap.ahk`.
- If a change touches hotkeys or services, inspect the corresponding JSON or INI contract before changing loader logic.
- Avoid “testing” by writing to local secret files or runtime databases.

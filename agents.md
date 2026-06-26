# AGENTS.md

This repository is a private reusable Windows automation workspace built around AutoHotkey v2. Treat it as an operational codebase with local-only configuration, not as a generic public package.

## What this repo is

- `platforms/windows/keyflow.ahk` is the main entrypoint.
- `platforms/windows/library/` contains shared services and bootstrap logic.
- `platforms/windows/hotkeys/` contains user-facing shortcuts grouped by area such as global, SAP, editors, and domain-specific contexts.
- `platforms/windows/data/` mixes versioned catalogs with local-only runtime files. Be careful here.
- `platforms/windows/tools/` contains helper executables and startup scripts used by the Windows workflow.

## Recommended reading order

1. `platforms/windows/keyflow.ahk`
2. `platforms/windows/library/bootstrap.ahk`
3. `platforms/windows/library/config/constants-core-paths.ahk`
4. `platforms/windows/library/config/constants-secrets.ahk`
5. `platforms/windows/hotkeys/global.ahk`
6. `platforms/windows/hotkeys/sap.ahk`
7. The specific service under `platforms/windows/library/automation/` that is touched by the change

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
- When changing data-loading behavior, preserve the current pattern of `NORMAN_*` env var override first, file fallback second.
- Treat `kp:sap-index/session/pluz dev` style lookups and direct KeePass entry refs like `kp:company/.../pluz prd` as the supported SAP credential convention unless the user asks to redesign it.
- When the user asks to simplify or restart a subsystem, prefer deleting legacy paths and compatibility code instead of preserving historical behavior.
- Assume the repo may be copied around without a `.git` directory. Do not depend on Git metadata at runtime.

## Validation guidance

- For documentation-only changes, verify that the docs match the current code layout and config names.
- For code changes, check the affected include chain from `keyflow.ahk` through `bootstrap.ahk`.
- If a change touches hotkeys or services, inspect the corresponding JSON or INI contract before changing loader logic.
- Avoid “testing” by writing to local secret files or runtime databases.

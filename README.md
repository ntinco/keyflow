# keyflow

Personal automation runtime built on AutoHotkey v2 for Windows and Hammerspoon for macOS. The repository is human-owned, AI-operated, machine-verifiable, and validated against real runtime behavior when environment-specific evidence is required.

AI maintenance starts at `AGENTS.md`. Durable AI policy lives in `ai/governance.md`; navigation and ownership live in `ai/repo-map.json`.

## Runtime architecture

```text
platforms/windows/keyflow.ahk
  library/bootstrap.ahk
    library/config/constants-core.ahk
    library/automation/          # registered services
  hotkeys/                       # generated trigger modules

platforms/macos/hammerspoon/
  init.lua                       # entrypoint and contextual binding runtime
  actions.lua                    # hand-authored actions
  hotstrings.lua                 # hotstring watcher
  generated/                     # generated bindings/profile data

platforms/shared/data/hotkeys.db # shared human-managed hotkey source
```

The Windows service registry currently exposes `hotstring`, `launcher`, `sap`, `snipaste`, `windowGroup`, and `windows`. `platforms/windows/library/automation/sap.ahk` is the public SAP facade for actions inside active SAP GUI/NWBC and Eclipse/ADT contexts; credential storage/session launch are outside the runtime.

## Source and generated contracts

`platforms/shared/data/hotkeys.db` is the single human-managed source for shared hotkeys and hotstring profiles. Humans may edit it with a SQLite editor.

`ai/hotkey_sync.py` generates/checks:

- `platforms/windows/hotkeys/*.ahk`;
- `platforms/windows/hotkeys/README.md`;
- `platforms/windows/data/*.json` hotstring profiles;
- `platforms/macos/hammerspoon/generated/*.lua`.

After changing the shared catalog:

```bash
python ai/hotkey_sync.py --sync
python ai/hotkey_sync.py --check
```

Generated artifacts may be versioned for runtime/review convenience, but they are never a second source of truth.

## Validation

Mechanical repository validation:

```bash
python ai/health_check.py --pretty
python ai/hotkey_sync.py --check
```

When runtime wiring changes, use `ai/run_smoke.py` where the environment supports the target platform. Its result JSON is local/generated, not authority. Runtime acceptance that depends on real applications, credentials, UI state or human observation remains human-owned.

## Local configuration

Machine-specific configuration is local-only. Versioned examples provide shape only:

| Example file | Purpose |
|---|---|
| `platforms/shared/data/local-paths.example.ini` | Machine paths (e.g. Everything CLI override) |

Local secrets/state must not be committed. The complete routing/boundary list is in `ai/repo-map.json`.

## Windows onboarding

1. Install AutoHotkey v2, or use the bundled runtime where appropriate.
2. Copy required `*.example.*` files to their local counterparts and fill local values.
3. Run `python ai/health_check.py --pretty`.
4. Launch `platforms/windows/keyflow.ahk`.

## macOS onboarding

1. Install Hammerspoon and required local tools used by the actions you enable.
2. Symlink `platforms/macos/hammerspoon` into the Hammerspoon config, for example `~/.hammerspoon/keyflow`.
3. Load it from `~/.hammerspoon/init.lua` with `dofile(hs.configdir .. "/keyflow/init.lua")`.
4. Reload Hammerspoon and perform the relevant runtime acceptance checks in `ai/current-plan.md` when that active frontier exists.

## Human acceptance boundary

Static checks can prove repository structure, catalog drift, include/service references, generated/source consistency, and syntax where tooling is available. They cannot prove focus behavior, SAP GUI semantics, Finder/Spotlight accessibility behavior, Snipaste handoff, or other environment-dependent interaction without executing against the real runtime.

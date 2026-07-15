# Hotkey simplification plan

Status: completed
Plan: completed

## Outcome

- Reduced the catalog from 112 to 72 active hotkeys while preserving 6 hotstrings.
- Removed generic editor, Office, communication, media/web, and identity remaps.
- Kept high-value SAP/ADT, launcher, Snipaste, window-group, and compound application workflows.
- Made `platforms/windows/data/hotkeys.db` the only human-managed source.
- Made `ai/hotkey_sync.py` generate AHK modules and the hotkey reference and detect drift with `--check`.
- Separated SAP GUI/NWBC hotkey context from Eclipse while retaining the broader runtime group for hotstrings.
- Added hotkey catalog drift validation to `ai/health_check.py`.

## Validation

- `python ai/hotkey_sync.py --check`: passed.
- `python ai/health_check.py --pretty --summary`: passed at 100/100 before closure regeneration.
- `python ai/run_smoke.py --pretty`: launched with no immediate parse errors.
- Final generated health and reviewer checks are required after guide closure.

## Human-only pending work

- Manage future personal shortcut changes directly in `hotkeys.db` with a SQLite editor, then run the generated sync/check workflow.

## Next plan decision

No new technical frontier is evident. Plan creation is deferred until macOS implementation requirements or another concrete workflow hotspot appear.

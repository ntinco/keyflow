# Hotkey usage tracking removal

Status: completed
Plan: completed

## Outcome

- Removed `HotkeyTrackerService` (`platforms/windows/library/automation/hotkey-tracker.ahk`) and the free tracking helpers (`platforms/windows/hotkeys/hotkey-tracking.ahk`).
- Dropped the `track_fn` / `track_args` columns from the `hotkeys.db` schema and from `ai/hotkey_sync.py` generation/validation logic.
- Removed the `hotkeyTracker` include and service registration from `platforms/windows/keyflow.ahk` and `platforms/windows/library/bootstrap.ahk`.
- Removed the `hotkeyTrackerJsonFile` constant from `platforms/windows/library/config/constants-core.ahk`.
- Regenerated all 5 AHK/Markdown artifacts from `hotkeys.db`; every trigger block lost its `trackXxxHotkeyUsage(...)` line.
- Updated `ai/repo-map.json` (`runtime-api`, service count, hotkeys domain description, current-focus) to drop tracking.
- Updated `AGENTS.md` and `README.md` to reflect 6 services (down from 7) and the tracking removal rationale.
- Left `platforms/windows/data/hotkey-usage.json` untouched on disk (still local-only, still gitignored) since it has no active writer now and carries no risk.

## Rationale

Tracking already served its purpose across the reduction cycles (72→54→28→22 hotkeys). It added ~140 lines of infrastructure (service class, free functions, schema columns, generation logic) to instrument only 22 hotkeys — more code than most of the functional services it was supporting. Removing it keeps the runtime aligned with the "simple but functional, AI-first maintenance" goal stated by the user.

## Validation

- `python ai/hotkey_sync.py --sync`: regenerated 5 artifacts from 28 catalog entries (22 hotkeys + 6 hotstrings).
- `python ai/health_check.py --pretty --summary`: 100/100, 0 issues, 6 services.
- Full health check confirms no orphaned classes, constants, groups, or public service methods.

## Human-only pending work

- Launch `platforms/windows/keyflow.ahk` once on Windows to confirm it starts cleanly without the removed tracker.

## Next plan decision

No further Windows runtime reduction is currently justified. The macOS implementation plan remains deferred until the native automation stack is chosen.

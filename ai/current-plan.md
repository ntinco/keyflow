# Windows catalog reduction and cleanup outcome

Status: completed
Plan: completed

## Outcome

- Reduced the active catalog to 22 hotkeys while preserving 6 hotstrings.
- Reduced the service registry from 13 to 7 services.
- Retained the user-selected global, SAP GUI, SAP ADT, and launcher routes.
- Removed `DynamicService`, `VideoService`, and `WhatsappService` plus stale constants, groups, configuration, and public methods.
- Removed the retired XYplorer action from the active catalog.
- Catalog `portability` now classifies 20 active entries as `portable-intent` and 8 as `windows-only`; every current implementation platform is `windows`.
- Updated tracking to qualify new usage keys by context while preserving the existing local data file.
- Regenerated the five AHK and Markdown artifacts from `hotkeys.db`.
- Removed the retired SAP session/debug/navigation endpoints, generic app-launch chain, microphone toggle, target-title normalization, OneDrive assignment, and microphone image.
- Removed the empty YMT post-launch callback chain while preserving SAP transaction hotstrings and quick debug.
- Retired credential-provider support, named SAP session launch, credential-window filling, related examples/constants, and portable-app startup wiring.
- Scoped SAP transaction hotstrings to SAP GUI/NWBC now that Eclipse no longer has a credential-backed session-launch path.
- Replaced the single-purpose memory and command services with `utilResolveMemoryValue()` and `utilRunCommand()`.
- Moved Everything run-count updates into `LauncherService` and removed the three trivial service classes from both runtime registries.
- Added a health-check contract that rejects drift between `ai/repo-map.json` `runtime-api` and the bootstrap service registry.

## Validation

- `python ai/hotkey_sync.py --check`: passed with 5 current generated artifacts.
- `python ai/health_check.py --pretty`: passed at 100/100 with no unused assignments, groups, classes, constants, or public service methods.
- Include and service wiring changed. A direct AutoHotkey smoke run remains a Windows-only verification because the current host cannot execute the bundled PE binary.
- `python ai/review_check.py --pretty --summary`: passed with no issues or warnings after guide closure.

## Human-only pending work

- Launch the refreshed runtime once on Windows, then use it normally so context-qualified tracking evidence accumulates before choosing native macOS bindings.

## Next plan decision

No additional technical frontier is currently selected. A macOS implementation plan is deferred until the user is ready to select the native automation stack and first portable-intent slice.

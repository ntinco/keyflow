# Windows reduction and portability plan

Status: completed
Plan: completed

## Outcome

- Reduced the active catalog from 72 to 54 hotkeys while preserving 6 hotstrings and the full SAP/ADT trigger set.
- Reduced the service registry from 13 to 10 services.
- Removed editor, Office, communication, video, task-tracker, and low-use global routes.
- Removed `DynamicService`, `VideoService`, and `WhatsappService` plus stale constants, groups, configuration, and public methods.
- Replaced the generic dynamic action engine with the explicit two-step XYplorer action stored in `hotkeys.db`.
- Added catalog `portability`: 43 entries are `portable-intent` and 17 are `windows-only`; every current implementation platform is `windows`.
- Updated tracking to qualify new usage keys by context while preserving the existing local data file.
- Updated the main runtime and standalone SAP GUI runtime wiring.

## Validation

- `python ai/hotkey_sync.py --check`: passed with 5 current generated artifacts.
- `python ai/health_check.py --pretty`: passed at 100/100 with no unused assignments, groups, classes, constants, or public service methods.
- `python ai/run_smoke.py --pretty`: launched the main runtime with no immediate parse errors.
- Standalone `sap-gui-runtime.ahk`: exited with code 0 under `/ErrorStdOut=CP65001`.
- Final reviewer validation is required after guide closure.

## Human-only pending work

- Use Windows normally so context-qualified tracking evidence accumulates before choosing native macOS bindings.

## Next plan decision

No further Windows reduction is currently justified. A macOS implementation plan is deferred until the user is ready to select the native automation stack and first portable-intent slice.

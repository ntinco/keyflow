# macOS migration — Hammerspoon slices

Status: in progress

## Implemented

- Eclipse/ADT hotkeys (backtick, F1, F2) and simple hotstrings.
- SAP GUI hotkeys (Alt+5..0 → Workbench/SE16N/SE37/SE38/SE09/SE80) through the native Target Command Field.
- Finder and Spotlight launcher actions share one selected-path flow; Spotlight uses its native Finder reveal command before delegating to it.
- Contextual hotkeys are enabled only for the active application. Spotlight/Finder keys use focused-element dispatch with passthrough outside the launcher. SAP command dispatch is non-blocking and stops if SAP GUI loses focus.
- The retained macOS runtime owns application watchers, contextual hotkeys, and the idempotent console Clear button.
- Governance declares AI as the primary code maintainer. Health validation rejects missing macOS action/context ownership and blocking Hammerspoon sleeps.

## Out of scope for current slices

- `sap_gui_ctrl_b`, `eclipse_ctrl_sh_b`: depend on `WindowGroupService` (Windows-specific concept).
- `snipaste_enter`: `portability=windows-only`; Snipaste is confirmed installed on macOS but not yet reclassified/ported.

## Next actions

1. Human: confirm SAP/Eclipse context switching remains isolated after the loaded configuration change.
2. Human: in Finder and Spotlight, verify F12 with a disposable text file, Ctrl+S with a disposable destination file, and Alt+P with media below a `Music`, `Audio`, or `Video` path.
3. Human: launch the Windows runtime once to confirm a clean start.
4. Architect: after human verification, evaluate whether `snipaste_enter` has a useful native macOS behavior before reclassifying it.

## Design constraint

`hotkeys.db` `action` column holds raw AHK syntax; not transpilable to Lua. `ai/hotkey_sync.py` generates binding metadata only (`generated/bindings.lua`); behavior is hand-authored in `actions.lua`/`hotstrings.lua`, matched by row `id`.

Launcher actions capture and reactivate the exact application behind Finder/Spotlight. Spotlight closes through its native Finder handoff; direct Finder actions use the same path without an intermediate transition.

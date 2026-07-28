# macOS migration — Hammerspoon slices

Status: in progress

## Implemented

- Eclipse/ADT hotkeys (backtick, F1, F2) and simple hotstrings.
- SAP GUI hotkeys (Alt+5..0 → Workbench/SE16N/SE37/SE38/SE09/SE80) through the native Target Command Field.
- Contextual hotkeys are enabled only for the active application. SAP command dispatch is non-blocking and stops if SAP GUI loses focus.

## Out of scope for current slices

- `sap_gui_ctrl_b`, `eclipse_ctrl_sh_b`: depend on `WindowGroupService` (Windows-specific concept).
- `snipaste_enter`: `portability=windows-only`; Snipaste is confirmed installed on macOS but not yet reclassified/ported.

## Next actions

1. Human: reload Hammerspoon, run one SAP shortcut, switch to Eclipse and another application, and confirm that SAP shortcuts no longer capture keys outside SAP GUI and Eclipse shortcuts remain available.
2. Human: launch the Windows runtime once to confirm a clean start.
3. Architect: after human verification, decide the next slice (`snipaste_enter` reclassification, or another `portable-intent` row).

## Design constraint

`hotkeys.db` `action` column holds raw AHK syntax; not transpilable to Lua. `ai/hotkey_sync.py` generates binding metadata only (`generated/bindings.lua`); behavior is hand-authored in `actions.lua`/`hotstrings.lua`, matched by row `id`.

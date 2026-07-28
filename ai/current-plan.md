# macOS migration — Hammerspoon slices

Status: in progress

## Implemented and human-verified

- 3 Eclipse/ADT hotkeys (backtick, F1, F2) + 6 hotstrings (`;;`, `"+`, `"-`, `*+`, `*-`, `sp`).
- 6 SAP GUI hotkeys (Alt+5..0 → Workbench/SE16N/SE37/SE38/SE09/SE80) via `win:focus()` + `Cmd+Option+O` (native "Target Command Field") + clipboard paste + Enter.

## Out of scope for current slices

- `sap_gui_ctrl_b`, `eclipse_ctrl_sh_b`: depend on `WindowGroupService` (Windows-specific concept).
- `snipaste_enter`: `portability=windows-only`; Snipaste is confirmed installed on macOS but not yet reclassified/ported.

## Next actions

1. Human: launch the Windows runtime once to confirm a clean start.
2. Architect: decide next slice (`snipaste_enter` reclassification, or another `portable-intent` row).

## Design constraint

`hotkeys.db` `action` column holds raw AHK syntax; not transpilable to Lua. `ai/hotkey_sync.py` generates binding metadata only (`generated/bindings.lua`); behavior is hand-authored in `actions.lua`/`hotstrings.lua`, matched by row `id`.

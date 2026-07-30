# macOS migration — Hammerspoon slices

Status: in progress

## Implemented

- Eclipse/ADT hotkeys (backtick, F1, F2) and simple hotstrings.
- SAP GUI hotkeys (Alt+5..0 → Workbench/SE16N/SE37/SE38/SE09/SE80) through the native Target Command Field.
- Finder and Spotlight launcher actions share one selected-path flow; Spotlight uses its native Finder reveal command before delegating to it.
- Contextual hotkeys are enabled only for the active application. Spotlight/Finder keys use focused-element dispatch with passthrough outside the launcher. SAP command dispatch is non-blocking and stops if SAP GUI loses focus.
- The retained macOS runtime owns application watchers, contextual hotkeys, and the idempotent console Clear button.
- Governance declares AI as the primary code maintainer. Health validation rejects missing macOS action/context ownership and blocking Hammerspoon sleeps.
- `hotkeys.db` owns `hotstring_profiles`/`hotstring_entries` (autocorrect, quick-snippets, sap-transaction-shortcuts, sap-transaction-catalog, ymt-commands: 672 entries total). `ai/hotkey_sync.py --sync` regenerates the Windows `platforms/windows/data/*.json` profiles and `platforms/macos/hammerspoon/generated/hotstring_profiles.lua` from this single source. `hotstrings.lua` consumes the generated profile catalog (`replace` mode pastes text; `sap-command` mode calls `Actions.runSapTcode`, scoped to `sap-gui-session`); only the six special-behavior hotstrings (`hs_semicolons`, `hs_sap_comment_plus/minus`, `hs_sap_block_plus/minus`, `hs_sp`) remain hand-matched by id.
- Health validation enforces that `init.lua` loads `generated/hotstring_profiles.lua`, that `hotstrings.lua` consumes it, and that `actions.lua` exposes `Actions.runSapTcode`.
- macOS replacements consume the matching `keyDown` event and delete only characters already inserted before pasting. This prevents the completing trigger character from surviving a replacement (for example, `nadia` now becomes `Nadia`, not `nadiNadia`).

## Out of scope for current slices

- `sap_gui_ctrl_b`, `eclipse_ctrl_sh_b`: depend on `WindowGroupService` (Windows-specific concept).
- `snipaste_enter`: `portability=windows-only`; Snipaste is confirmed installed on macOS but not yet reclassified/ported.

## Next actions

1. Human: confirm SAP/Eclipse context switching remains isolated after the loaded configuration change.
2. Human: in Finder and Spotlight, verify F12 with a disposable text file, Ctrl+S with a disposable destination file, and Alt+P with media below a `Music`, `Audio`, or `Video` path.
3. Human: launch the Windows runtime once to confirm the regenerated `platforms/windows/data/*.json` profiles still autocorrect/paste and run SAP transactions as before.
4. Human: on macOS, load Hammerspoon and verify autocorrect/quick-snippets replace correctly and SAP transaction codes run only while SAP GUI is frontmost.
5. Architect: after human verification, evaluate whether `snipaste_enter` has a useful native macOS behavior before reclassifying it.

## Design constraint

`hotkeys.db` `hotkeys.action` column holds raw AHK syntax for hotkeys and the six special hotstrings; not transpilable to Lua. `ai/hotkey_sync.py` generates binding metadata only (`generated/bindings.lua`) for these; behavior is hand-authored in `actions.lua`/`hotstrings.lua`, matched by row `id`.

`hotstring_profiles`/`hotstring_entries` are portable data (trigger, value, mode, context), not AHK syntax — these generate both the Windows JSON profiles and the macOS Lua profile catalog from one source, with `mode` (`replace`/`sap-command`) selecting the platform adapter at runtime.

Launcher actions capture and reactivate the exact application behind Finder/Spotlight. Spotlight closes through its native Finder handoff; direct Finder actions use the same path without an intermediate transition.

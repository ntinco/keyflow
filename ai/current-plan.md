# macOS migration — Hammerspoon slices

Status: in progress

## Implemented

- Eclipse/ADT hotkeys (backtick, F1, F2) and simple hotstrings.
- Global Alt+D rotates among standard windows of running Cursor/VS Code instances; global Alt+E rotates among standard windows of running SAP GUI/Eclipse/ADT instances, including SAP sessions. The macOS adapters use ordered application groups and do not launch missing applications.
- SAP GUI hotkeys (Alt+5..0 → Workbench/SE16N/SE37/SE38/SE09/SE80) through the native Target Command Field.
- `sap-transaction-catalog` hotstrings preserve the typed transaction code and send only Enter when the active SAP window title contains `SAP Easy Access`; all other SAP windows and SAP hotstring profiles retain their normal command-field replacement with `/n`.
- Finder and Spotlight launcher actions share one selected-path flow; Spotlight uses its native Finder reveal command before delegating to it.
- Alt+P invokes IINA's bundled CLI with every selected Finder/Spotlight path, retains the asynchronous task through completion, and delegates media validation to IINA instead of maintaining a duplicate filename/path heuristic.
- Snipaste Command+F1 and Enter share one macOS capture flow: Command+F1 invokes Snipaste, Enter accepts the capture, ImageMagick resizes supported-target images to 80%, and Teams receives an automatic paste. MouseFwd on macOS is an adapter that emits Command+F1; Windows retains its platform-specific MouseFwd capture trigger.
- Contextual hotkeys are enabled only for the active application. Spotlight/Finder keys use focused-element dispatch with passthrough outside the launcher. SAP command dispatch is non-blocking and stops if SAP GUI loses focus.
- The retained macOS runtime owns application watchers, contextual hotkeys, and the idempotent console Clear button.
- Governance declares AI as the primary code maintainer. Health validation rejects missing macOS action/context ownership and blocking Hammerspoon sleeps.
- `hotkeys.db` owns `hotstring_profiles`/`hotstring_entries`; `ai/hotkey_sync.py --sync` regenerates the Windows JSON profiles and macOS Lua profile catalog from this single source. `hotstrings.lua` consumes the generated data (`replace` pastes text; `sap-command` calls `Actions.runSapTcode`); only the six special-behavior hotstrings remain hand-authored.
- Health validation enforces that `init.lua` loads `generated/hotstring_profiles.lua`, that `hotstrings.lua` consumes it, and that `actions.lua` exposes `Actions.runSapTcode`.
- macOS replacements consume the matching `keyDown` event and delete only characters already inserted before pasting. This prevents the completing trigger character from surviving a replacement (for example, `nadia` now becomes `Nadia`, not `nadiNadia`).
- Every replacement uses a single clipboard paste, preserving Unicode and avoiding per-character synthetic typing. A resettable clipboard session captures the original clipboard once and restores it after the last expansion.
- The watcher completes each replacement synchronously. It tags every synthetic Delete, paste shortcut, and cursor event with `eventSourceUserData`, excludes that marker from the trigger buffer, and resets the buffer across applications, mouse focus changes, modified shortcuts, deletion, and non-text keys.

## Next actions

1. Human: confirm repeated Alt+D rotates standard Cursor/VS Code windows and repeated Alt+E rotates SAP GUI/Eclipse/ADT windows, including SAP sessions, without launching a missing application.
2. Human: in a `SAP Easy Access` window, confirm a `sap-transaction-catalog` hotstring preserves the typed code and sends only Enter; outside that title, confirm it continues to replace through the command field with `/n`. Confirm `sap-transaction-shortcuts` and `ymt-commands` retain their normal command behavior.
3. Human: confirm SAP/Eclipse context switching remains isolated after the loaded configuration change.
4. Human: in Finder and Spotlight, verify F12 with a disposable text file and Alt+P with a media file selected from any directory.
5. Human: launch the Windows runtime once to confirm the regenerated `platforms/windows/data/*.json` profiles still autocorrect/paste and run SAP transactions as before.
6. Human: on macOS, verify SAP transaction codes run only while SAP GUI is frontmost.
7. Human: verify Snipaste Command+F1 and MouseFwd start capture, then Enter returns the processed image to the originating application; confirm Teams also pastes automatically.

## Design constraint

`hotkeys.db` `hotkeys.action` column holds implementation intent (raw AHK for Windows entries), not behavior transpilable to Lua. `ai/hotkey_sync.py` filters generated runtime artifacts by platform and generates binding metadata only (`generated/bindings.lua`) for macOS; behavior is hand-authored in `actions.lua`/`hotstrings.lua`, matched by row `id`.

`hotstring_profiles`/`hotstring_entries` are portable data (trigger, value, mode, context), not AHK syntax — these generate both the Windows JSON profiles and the macOS Lua profile catalog from one source, with `mode` (`replace`/`sap-command`) selecting the platform adapter at runtime.

Launcher actions capture and reactivate the exact application behind Finder/Spotlight. Spotlight closes through its native Finder handoff; direct Finder actions use the same path without an intermediate transition.

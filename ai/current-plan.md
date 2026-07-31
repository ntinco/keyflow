# macOS migration — Hammerspoon slices

Status: in progress

## Implemented

- Eclipse/ADT hotkeys (backtick, F1, F2) and simple hotstrings.
- Global Alt+D rotates among standard windows of running Cursor/VS Code instances; global Alt+E rotates among standard windows of running SAP GUI/Eclipse/ADT instances, including SAP sessions. The macOS adapters use ordered application groups and do not launch missing applications.
- SAP GUI hotkeys (Alt+1 → SE11, Alt+3 → SE93, Alt+4..0 → SE24/Workbench/SE16N/SE37/SE38/SE09/SE80) through the native Target Command Field.
- `sap-transaction-catalog` hotstrings preserve the typed transaction code and send only Enter when the active SAP window title contains `SAP Easy Access`; all other SAP windows and SAP hotstring profiles retain their normal command-field replacement with `/n`.
- Finder and Spotlight launcher actions share one selected-path flow; Spotlight uses its native Finder reveal command, then the flow reads Finder's selected `AXURL.filePath` without mutating the clipboard.
- Alt+P invokes IINA's bundled CLI with every selected Finder/Spotlight path, retains the asynchronous task through completion, and delegates media validation to IINA instead of maintaining a duplicate filename/path heuristic.
- Snipaste Command+F1 and Enter share one macOS capture flow: Command+F1 invokes Snipaste, Enter accepts the capture, ImageMagick resizes supported-target images to 80%, and Teams receives an automatic paste. MouseFwd on macOS emits Snipaste's Command+F1 shortcut; Windows retains its platform-specific MouseFwd capture trigger.
- Contextual hotkeys are enabled only for the active application. Spotlight/Finder keys use focused-element dispatch with passthrough outside the launcher. SAP command dispatch is non-blocking and stops if SAP GUI loses focus.
- The retained macOS runtime owns application watchers, contextual hotkeys, and the idempotent console Clear button.
- Governance declares AI as the primary code maintainer. Health validation rejects missing macOS action/context ownership and blocking Hammerspoon sleeps.
- `hotkeys.db` owns `hotstring_profiles`/`hotstring_entries`; `ai/hotkey_sync.py --sync` regenerates the Windows JSON profiles and macOS Lua profile catalog from this single source. `hotstrings.lua` consumes the generated data (`replace` pastes text; `sap-command` calls `Actions.runSapTcode`); only the six special-behavior hotstrings remain hand-authored. An explicit `immediate = 1` expands immediately; name-like autocorrect entries (lowercase ASCII trigger and one-word capitalized replacement) also expand immediately, matching AutoHotkey `:*:` behavior without its `?` inside-word option. Catalog validation rejects any `immediate` value other than `0` or `1`.
- Health validation enforces that `init.lua` loads `generated/hotstring_profiles.lua`, that `hotstrings.lua` consumes it, and that `actions.lua` exposes `Actions.runSapTcode`.
- macOS replacements consume the matching `keyDown` event and delete only characters already inserted before pasting. This prevents the completing trigger character from surviving a replacement (for example, `nadia` now becomes `Nadia`, not `nadiNadia`).
- Every replacement uses a single clipboard paste, preserving Unicode and avoiding per-character synthetic typing. A resettable clipboard session captures the original clipboard once and restores it after the last expansion.
- The watcher completes each replacement synchronously. It tags every synthetic Delete, paste shortcut, and cursor event with `eventSourceUserData`, excludes that marker from the trigger buffer, and resets the buffer across applications, mouse focus changes, modified shortcuts, deletion, and non-text keys. Replacements require a word boundary before their trigger; name-like entries such as `eder` expand immediately on the final `r`, while `acceder` never mutates because the trigger begins inside a word. Other non-immediate replacements wait for a trailing delimiter.

## Next actions

1. Human: confirm repeated Alt+D rotates standard Cursor/VS Code windows and repeated Alt+E rotates SAP GUI/Eclipse/ADT windows, including SAP sessions, without launching a missing application.
2. Human: in a `SAP Easy Access` window, confirm a `sap-transaction-catalog` hotstring preserves the typed code and sends only Enter; outside that title, confirm it continues to replace through the command field with `/n`. Confirm `sap-transaction-shortcuts` and `ymt-commands` retain their normal command behavior.
3. Human: in an active SAP GUI session, confirm Alt+1 runs SE11, Alt+3 runs SE93, and Alt+4 runs SE24 through the native Target Command Field on Windows and macOS.
4. Human: on macOS, confirm `eder` becomes `Eder` immediately when typing the final `r`, and that typing `acceder` remains unchanged.
5. Human: confirm SAP/Eclipse context switching remains isolated after the loaded configuration change.
6. Human: in Finder and Spotlight, verify F12 with a disposable text file and Alt+P with a media file selected from any directory.
7. Human: launch the Windows runtime once to confirm the regenerated `platforms/windows/data/*.json` profiles still autocorrect/paste and run SAP transactions as before.
8. Human: on macOS, verify SAP transaction codes run only while SAP GUI is frontmost.
9. Human: verify Snipaste Command+F1 and MouseFwd start capture, then Enter returns the processed image to the originating application; confirm Teams also pastes automatically. Hammerspoon Console must log `MouseFwd button=4`; if it logs only the ignored side button `3`, the device driver must map its forward side button to 4.

## Design constraint

`hotkeys.db` is the shared source for both runtimes. Its reduced `hotkeys` schema uses one `windows_context` expression for Windows `#HotIf` generation and has no unused notes field. Existing catalogs with legacy `context`, `context_fn`, and `notes` columns migrate transactionally with `python ai/hotkey_sync.py --migrate-hotkeys-schema`; the operation preserves IDs/counts and is idempotent. Most `action` values remain platform-specific implementation owned by the matching runtime `id`; the typed portable action `sap-tcode:<code>` is the intentional exception and requires `portable-intent` on both platforms. `ai/hotkey_sync.py` emits `services.sap.runTcode("<code>")` for Windows and `tcode` metadata in `generated/bindings.lua` for macOS, where one `Actions.runSapTcode` adapter executes it.

`hotstring_profiles`/`hotstring_entries` are portable data (trigger, value, mode, context), not AHK syntax — these generate both the Windows JSON profiles and the macOS Lua profile catalog from one source, with `mode` (`replace`/`sap-command`) selecting the platform adapter at runtime.

Launcher actions capture and reactivate the exact application behind Finder/Spotlight. Spotlight closes through its native Finder handoff; direct Finder actions use the same path without an intermediate transition.

# macOS migration — runtime acceptance

## Current frontier

Complete human runtime acceptance of the current macOS Hammerspoon slice and its shared hotkey/catalog behavior. The technical implementation is present; the remaining frontier is observation in the real Windows/macOS environments.

## Implemented state relevant to continuation

- `platforms/shared/data/hotkeys.db` is the shared human-managed source for Windows and macOS hotkeys/hotstrings; `ai/hotkey_sync.py` generates the platform artifacts and checks drift.
- The macOS runtime covers contextual SAP GUI/Eclipse hotkeys, shared hotstrings, Finder/Spotlight launcher actions, IINA dispatch, and Snipaste capture handoff.
- SAP transaction hotkeys use the portable `sap-tcode:<code>` action where shared intent is required; platform adapters execute the behavior.
- macOS hotstring replacement is synchronous, excludes synthetic events from its trigger buffer, respects word boundaries, and restores the captured clipboard after expansion.

## Pending human verification

1. Confirm repeated Alt+D rotates standard Cursor/VS Code windows and repeated Alt+E rotates SAP GUI/Eclipse/ADT windows, including SAP sessions, without launching a missing application.
2. In `SAP Easy Access`, confirm a `sap-transaction-catalog` hotstring preserves the typed code and sends only Enter; outside that title, confirm command-field replacement with `/n`. Confirm `sap-transaction-shortcuts` and `ymt-commands` retain their normal behavior.
3. In an active SAP GUI session, confirm Alt+1 runs SE11, Alt+3 runs SE93, and Alt+4 runs SE24 through the native Target Command Field on Windows and macOS.
4. On macOS, confirm `eder` becomes `Eder` immediately on the final `r`, while `acceder` remains unchanged.
5. Confirm SAP/Eclipse context switching remains isolated after the loaded configuration change.
6. In Finder and Spotlight, verify F12 with a disposable text file and Alt+P with a media file selected from any directory.
7. Launch the Windows runtime once and confirm the generated `platforms/windows/data/*.json` profiles still autocorrect/paste and run SAP transactions as before.
8. On macOS, verify SAP transaction codes run only while SAP GUI is frontmost.
9. Verify Snipaste Command+F1 starts capture, Enter returns the processed image to the originating application, and Teams pastes automatically. MouseFwd remains intentionally manual on macOS.

## Active design constraints

- `hotkeys.db` remains the single shared source. Generated AHK, Markdown, Windows JSON and macOS Lua artifacts are derivatives, not authorities.
- Most `action` values remain platform-specific implementation; `sap-tcode:<code>` is the intentional portable-action exception.
- Launcher actions capture and reactivate the exact application behind Finder/Spotlight; Spotlight uses the Finder handoff instead of a parallel path model.
- Runtime acceptance remains human because these checks depend on real applications, focus state, accessibility/UI behavior and installed local tools.

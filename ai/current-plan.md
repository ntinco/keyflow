# macOS migration — runtime acceptance

## Current frontier

Complete human runtime acceptance of the current macOS Hammerspoon slice and its shared hotkey/catalog behavior. The technical implementation is present; the remaining frontier is observation in the real Windows/macOS environments.

## Implemented state relevant to continuation

- `platforms/shared/data/hotkeys.db` is the shared human-managed source for Windows and macOS hotkeys/hotstrings; `ai/hotkey_sync.py` generates the platform artifacts and checks drift.
- The macOS runtime covers contextual SAP GUI/Eclipse hotkeys, shared hotstrings, Finder/Spotlight launcher actions, IINA dispatch via LaunchServices, Snipaste return to the most recent allowed target, window-group rotation, and Cmd+Esc height stretch.
- SAP transaction hotkeys use the portable `sap-tcode:<code>` action where shared intent is required; platform adapters execute the behavior.
- macOS hotstring replacement types single-line text as unicode key events (multi-line blocks still paste and restore the clipboard), excludes synthetic events from its trigger buffer, respects word boundaries, and waits for an ending character unless an entry is marked `immediate`.
- SAP commands starting with `/` or `=` are sent as-is; others get the `/n` prefix.

## Pending human verification

macOS acceptance is complete (2026-09-24): hotstrings, SAP tcode hotkeys/hotstrings and `=` OK-codes including all `ymt-commands`, SAP Easy Access, SAP-only scoping, Eclipse keys and context isolation, Alt+D/Alt+E rotation, SAP comment hotstrings, Finder/Spotlight F12, Alt+P reusing the IINA window, Snipaste return to the most recent allowed target (Teams pastes), Cmd+Esc, special-hotstring immediacy from `hotkeys.db` (`;;`, SAP comment triggers, `sp,`), and clipboard restore after quick successive SAP commands. Remaining:

1. macOS regression after the testable-logic refactor (`dispatch.lua`, `clipboard.lua`, `findMatch`): reload Hammerspoon without console errors; confirm autocorrect, `bd,`, `;;`, a SAP command hotstring, Snipaste Enter and F12 still work; a multi-line snippet followed quickly by a SAP command restores the original clipboard. Hotstrings now end only on AutoHotkey's default ending characters, so `=`, `@`, `*` or `_` after a trigger no longer fire it (same as Windows). `;;` now fires inside a word on both platforms (`ma;;ana` → `mañana`, AHK `?` option); re-run `selftest.ahk` on Windows.
2. Windows: `selftest.ahk` passed on 2026-09-24 (AutoHotkey 2.0.28, 1 monitor): profiles load, autocorrect, no trigger inside a word, immediate snippet `bd,`, `;;` keeps the preceding character and restores the clipboard, Win+Esc on the monitor and on a maximized window. `ma;;` does not fire inside a word, matching macOS. Human-confirmed on Windows: SAP Alt+1, Win+Esc (elevated windows now show a tooltip instead of an error). Fixed after the first run, pending re-test: SAP hotstrings never fired because `isTextInputActive` compared the HWND from `ControlGetFocus` to class names; then they sent the profile label as tcode because `this._submitSapTcode.Bind` shifted the arguments (now `ObjBindMethod`); F12 correctly rejects `.cmd` and pasted a `.txt` from Everything; `se11` with space and Enter confirmed (SAP hotstrings use `O`, like macOS); F12 pasted a `.txt` but Everything stayed open because the installed build is `Everything.exe` — `exeEverything` now matches `ahk_class EVERYTHING`; Everything still stayed open after F12, so `dismissLauncherUi` now uses `WinClose` + `WinWaitNotActive` instead of Ctrl+W (pending re-test). Alt+P in Everything confirmed (media detected by extension; non-media shows a tooltip; in File Explorer Alt+P is Windows' own preview pane). Remaining manual checks: SAP transactions and hotstrings wait for the ending character, `=ED_OPTIONS` and `=<ymt code>` are sent without `/n`, Alt+4…0 with the cursor in a SAP data field leaves that field intact (Ctrl+/ focuses the command field first), F12 pastes `.txt` but ignores `.exe`, and Win+Esc on a secondary monitor when one is connected.

## Known parity gaps (deliberately deferred)

- F12 on macOS lacks the Windows `YM` post-paste step (3 s wait + Ctrl+F3); pending implementation.
- macOS hotstrings are case-sensitive; Windows matches case-insensitively and conforms case.
- Alt+P on macOS opens any selection in IINA; Windows filters media paths and uses AIMP.
- Snipaste 80% ImageMagick resize is Windows-only; not needed on macOS for now.
- Snipaste capture on macOS is bound to the mouse side button inside Snipaste, outside keyflow.

## Active design constraints

- `hotkeys.db` remains the single shared source. Generated AHK, Markdown, Windows JSON and macOS Lua artifacts are derivatives, not authorities.
- Most `action` values remain platform-specific implementation; `sap-tcode:<code>` is the intentional portable-action exception.
- Launcher actions capture and reactivate the exact application behind Finder/Spotlight; Spotlight uses the Finder handoff instead of a parallel path model.
- Runtime acceptance remains human because these checks depend on real applications, focus state, accessibility/UI behavior and installed local tools.

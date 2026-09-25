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

1. Windows (no machine available yet): launch once; confirm profiles load without JSON errors, autocorrect/snippets/SAP transactions work, `=ED_OPTIONS` and `=<ymt code>` are sent without `/n`, SAP hotstrings wait for the ending character, F12 pastes `.txt` but ignores `.exe`, and Alt+P plays a media path that contains spaces. Also: Alt+4…0 with the cursor in a SAP data field leaves that field intact (Ctrl+/ focuses the command field first); `;;` produces `ñ` without deleting the preceding character; Win+Esc stretches to the work area on primary and secondary monitors.

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

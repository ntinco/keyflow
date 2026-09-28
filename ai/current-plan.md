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

Accepted on 2026-09-24. macOS: hotstrings, SAP tcode hotkeys/hotstrings and `=` OK-codes, SAP Easy Access, context isolation, Eclipse keys, Alt+D/Alt+E, SAP comment hotstrings, Finder/Spotlight F12, Alt+P via IINA, Snipaste return, Cmd+Esc, clipboard restore. Windows: `selftest.ahk` all PASS, SAP Alt+1, SAP hotstrings with space and Enter, F12 and Alt+P in Everything (`Everything.exe`, matched by `ahk_class EVERYTHING`; Alt+P plays only paths containing `music`), Win+Esc including elevated windows.

Cleanup after acceptance (2026-09-24), pending re-test:

1. Windows: confirmed after cleanup: selftest hotstrings and Win+Esc, `se11`, SAP Alt keys, Alt+E, F12, Alt+P. Open: the human reported `"-` not working; the first selftest block check was invalid (`+` in Send is Shift). Re-run `selftest.ahk`: it now checks `"-`, `"+` and the `*+` block (cursor on the middle line — `utilPaste` used to `Exit()` inside hotstrings, so the `{Up}` never ran). Still to check: Alt+4…0 in a data field, `=ED_OPTIONS`, a `ymt-commands` trigger, Easy Access, Alt+D, Snipaste Enter.
2. macOS: confirmed after cleanup (Hammerspoon reloads without errors; human reported OK).
3. Win+Esc on a secondary monitor when one is connected.
4. macOS host with VMware Fusion frontmost: the human reported Windows hotstrings in the guest typing `a`/`aa` (Hammerspoon replaced them on the host with unicode events on the `a` key). Hammerspoon hotstrings now pass through VMware Fusion, Parallels, UTM and Microsoft Remote Desktop. Reload Hammerspoon and check `nadia `, `"-` and `teh ` inside the Windows VM, and `teh ` still in a native Mac app.
5. macOS Snipaste 80% resize (needs `magick` in `/opt/homebrew/bin` or `/usr/local/bin`): capture, Enter with OneNote/Teams/Obsidian as the last target; the pasted image is 80% of the capture (Console: `Snipaste clipboard resized 80%`), Teams auto-pastes, Word keeps the original size.

## Known parity gaps (deliberately deferred)

- F12 on macOS lacks the Windows `YM` post-paste step (3 s wait + Ctrl+F3); pending implementation.
- macOS hotstrings are case-sensitive; Windows matches case-insensitively and conforms case.
- Alt+P on macOS opens any selection in IINA; Windows filters media paths and uses AIMP.
- Snipaste capture on macOS is bound to the mouse side button inside Snipaste, outside keyflow.

## Active design constraints

- `hotkeys.db` remains the single shared source. Generated AHK, Markdown, Windows JSON and macOS Lua artifacts are derivatives, not authorities.
- Most `action` values remain platform-specific implementation; `sap-tcode:<code>` is the intentional portable-action exception.
- Launcher actions capture and reactivate the exact application behind Finder/Spotlight; Spotlight uses the Finder handoff instead of a parallel path model.
- Runtime acceptance remains human because these checks depend on real applications, focus state, accessibility/UI behavior and installed local tools.

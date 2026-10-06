# macOS migration — runtime acceptance

## Current frontier

Complete human runtime acceptance of the current macOS Hammerspoon slice and its shared hotkey/catalog behavior. The technical implementation is present; the remaining frontier is observation in the real Windows/macOS environments.

## Implemented state relevant to continuation

- `platforms/shared/data/hotkeys.db` is the shared human-managed source for Windows and macOS hotkeys/hotstrings; `ai/hotkey_sync.py` generates the platform artifacts and checks drift.
- The macOS runtime covers contextual SAP GUI/Eclipse hotkeys, shared hotstrings, Finder/Spotlight launcher actions, IINA dispatch via LaunchServices, Snipaste return to the most recent allowed target, window-group rotation, and Cmd+Esc height stretch.
- SAP transaction hotkeys use the portable `sap-tcode:<code>` action where shared intent is required; platform adapters execute the behavior.
- SAP transaction hotstrings preserve the lowercase tcode and add `/n`; SAP hotkeys retain their existing uppercase normalization.
- macOS hotstring replacement types single-line text as unicode key events (multi-line blocks still paste and restore the clipboard), excludes synthetic events from its trigger buffer, respects word boundaries, and waits for an ending character unless an entry is marked `immediate`.
- SAP commands starting with `/` or `=` are sent as-is; others get the `/n` prefix.

## Pending human verification

Accepted on 2026-09-24. macOS: hotstrings, SAP tcode hotkeys/hotstrings and `=` OK-codes, SAP Easy Access, context isolation, Eclipse keys, Alt+D/Alt+E, SAP comment hotstrings, Finder/Spotlight F12, Alt+P via IINA, Snipaste return, Cmd+Esc, clipboard restore. Windows: `selftest.ahk` all PASS, SAP Alt+1, SAP hotstrings with space and Enter, F12 and Alt+P in Everything (`Everything.exe`, matched by `ahk_class EVERYTHING`; Alt+P plays only paths containing `music`), Win+Esc including elevated windows.

New SAP tcode hotstring change (2026-10-01), pending runtime acceptance: on Windows and macOS, type `iw3d` followed by an ending character in a SAP GUI text field and confirm the adapter submits `/niw3d` without uppercasing. In SAP Easy Access, confirm `iw3d` still follows the direct-submit path.

Cleanup after acceptance (2026-09-24), pending re-test:

1. Windows: confirmed after cleanup: selftest hotstrings and Win+Esc, `se11`, SAP Alt keys, Alt+E, F12, Alt+P. Open: the human reported `"-` not working; the first selftest block check was invalid (`+` in Send is Shift). Re-run `selftest.ahk`: it now checks `"-`, `"+` and the `*+` block (cursor on the middle line — `utilPaste` used to `Exit()` inside hotstrings, so the `{Up}` never ran). Still to check: Alt+4…0 in a data field, `=ED_OPTIONS`, a `ymt-commands` trigger, Easy Access, Alt+D, Snipaste Enter.
2. macOS: confirmed after cleanup (Hammerspoon reloads without errors; human reported OK).
3. Win+Esc on a secondary monitor when one is connected.
4. macOS host with VMware Fusion frontmost: the human reported Windows hotstrings in the guest typing `a`/`aa` (Hammerspoon replaced them on the host with unicode events on the `a` key). Hammerspoon hotstrings now pass through VMware Fusion, Parallels, UTM and Microsoft Remote Desktop. Reload Hammerspoon and check `nadia `, `"-` and `teh ` inside the Windows VM, and `teh ` still in a native Mac app.
5. macOS Snipaste 80% resize (needs `magick` in `/opt/homebrew/bin` or `/usr/local/bin`): capture, Enter with OneNote/Teams/Obsidian as the last target; the pasted image is 80% of the capture (Console: `Snipaste clipboard resized 80%`), Teams auto-pastes, Word keeps the original size.
6. `cpm` in a native macOS text field and a Windows text field: typing the last `m` expands once to `commit y push directo a main` without a space or Enter.
7. macOS Alt+D (Option+D) with GitHub Copilot (`com.github.githubapp`) open: it joins the IDE group rotation with Cursor, VS Code and Terminal.

NetNewsWire summary hotkey (2026-10-05), pending runtime acceptance; nothing below has been observed. `⌥⌘S` (`netnewswire_summary_current`, `macos-only`) runs `reader/tools/nnw_summary.py --current` through `/bin/zsh -lc` and shows stdout in an `hs.webview` window. The script path is `hs.settings` `keyflow.netnewswireSummaryScript` when set, otherwise `$HOME/gh/reader/tools/nnw_summary.py` — `reader/main` already contains `nnw-summary` (16e48df, 06e9544), so runtime acceptance should use that default path directly; no override is needed.

1. Reload Hammerspoon; the Console shows no errors and one more contextual binding.
2. Open NetNewsWire and a real article; note its read/starred state.
3. Press `⌥⌘S`: the `Resumiendo…` alert appears.
4. A titled, closable, resizable window (about 760×580, centered) shows the right summary; it scrolls, the text can be selected and copied, line breaks are kept, Escape closes it.
5. NetNewsWire is still open and the article's read/starred state is unchanged.
6. The clipboard is unchanged and no Terminal window opened.
7. With another app frontmost, `⌥⌘S` is not intercepted (the app receives it).
8. Two quick presses: the second shows `El resumen sigue en curso…` and the Console logs a single `NetNewsWire summary finished`.
9. A second summary replaces the previous window.
10. No article selected: an alert with the reason and no window. Override pointing to a missing file: `No se encontró nnw_summary.py.` and nothing runs.

## Known parity gaps (deliberately deferred)

- F12 on macOS lacks the Windows `YM` post-paste step (3 s wait + Ctrl+F3); pending implementation.
- macOS hotstrings are case-sensitive; Windows matches case-insensitively and conforms case.
- Alt+P on macOS opens any selection in IINA; Windows filters media paths and uses AIMP.
- GitHub Copilot is in the macOS Alt+D IDE group only; the Windows `apps_ide` group lacks it until its executable name is confirmed on Windows.
- Snipaste capture on macOS is bound to the mouse side button inside Snipaste, outside keyflow.

## Active design constraints

- `hotkeys.db` remains the single shared source. Generated AHK, Markdown, Windows JSON and macOS Lua artifacts are derivatives, not authorities.
- Most `action` values remain platform-specific implementation; `sap-tcode:<code>` is the intentional portable-action exception.
- Launcher actions capture and reactivate the exact application behind Finder/Spotlight; Spotlight uses the Finder handoff instead of a parallel path model.
- Runtime acceptance remains human because these checks depend on real applications, focus state, accessibility/UI behavior and installed local tools.

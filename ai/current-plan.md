# macOS migration — first vertical slice (Hammerspoon)

Status: implemented
Plan: technically complete; pending human verification

## App confirmation (verified on this machine)

Verified via `mdls -name kMDItemCFBundleIdentifier` and filesystem inspection:

| App | Bundle ID | Notes |
|---|---|---|
| Hammerspoon | `org.hammerspoon.Hammerspoon` | Installed via Homebrew (`hs` CLI at `/opt/homebrew/bin/hs`) |
| Eclipse | `epp.package.committers` | ADT plugins confirmed present (`com.sap.adt.*` jars) |
| SAP GUI for Java | `com.sap.platin` | At `/Applications/SAP Clients/SAPGUI/SAPGUI.app` |
| Snipaste | `com.Snipaste` | Native macOS build — not Windows-only here |

## Catalog location

`hotkeys.db` moved from `platforms/windows/data/` to `platforms/shared/data/`
since it is no longer Windows-exclusive: it now drives both the AHK runtime
and the macOS Hammerspoon runtime. Updated in `ai/hotkey_sync.py`,
`ai/health_check.py`, `ai/governance.json`, `ai/repo-map.json`, `AGENTS.md`,
`README.md`. All other Windows-only JSON catalogs (`autocorrect.json`, etc.)
remain under `platforms/windows/data/` since they have no macOS consumer yet.

## Outcome

- `hotkeys.db` (now at `platforms/shared/data/hotkeys.db`): 10 rows (6
  hotstrings + 4 SAP Eclipse/ADT hotkeys) carry `platform=["windows","macos"]`.
  All other rows remain `["windows"]`. (`eclipse_ctrl_5` was manually removed
  from the catalog by the user during this cycle — human decision, not a
  migration artifact.)
- `ai/hotkey_sync.py` extended with a macOS generation target: emits
  `platforms/macos/hammerspoon/generated/bindings.lua` (binding metadata
  only — id, key/trigger, contextLabel, label) for every row targeting
  macOS. The Windows AHK generator is untouched.
- Hand-authored `platforms/macos/hammerspoon/actions.lua`: one function per
  Eclipse/ADT hotkey id (4 total: backtick, f1, f2, ctrl_sh_b), reimplementing
  the AHK behavior natively (not a line-by-line port). Each function
  documents the AHK behavior it mirrors.
- Hand-authored `platforms/macos/hammerspoon/hotstrings.lua`: a native
  `hs.eventtap` keystroke watcher reproducing AHK's `:*:` (immediate) and
  `::` (terminator-based) hotstring semantics for the 6 catalog entries.
- Hand-authored `platforms/macos/hammerspoon/init.lua`: loads bindings,
  actions, and hotstrings; binds the Eclipse/ADT hotkeys via `hs.hotkey.new`
  guarded by an `hs.application.watcher` that enables/disables them based on
  Eclipse focus (mirrors AHK `#hotif winactive(exeEclipse)`); starts the
  hotstring watcher globally.
- `ai/health_check.py`: added `validate_macos_runtime()`, which checks that
  every `dofile()` target referenced by `init.lua` exists. Returns no
  issues if the macOS runtime hasn't been started (no Windows/macOS parity
  requirement). Wired into `run()`, `build_summary()`, and the full JSON
  output under `issues.macos_runtime`.
- `ai/run_smoke.py`: added `run_smoke_macos()` and `--platform macos`, using
  `luac -p` (parse-only syntax check) since `hs -c` blocks waiting for the
  Hammerspoon app's IPC socket. Writes to `ai/run-result-macos.json`
  (added to `.gitignore`, parallel to `ai/run-result.json`).

## Validation performed

- `luac -p` (Lua 5.5, installed via `brew install lua`) on all 4 Lua files:
  syntax OK.
- `python ai/run_smoke.py --platform macos --pretty`: `outcome: exited_clean`,
  0 errors across 4 Lua files.
- `python ai/hotkey_sync.py --check`: 6 generated artifacts current (5 AHK +
  1 Lua bindings file) from 27 catalog entries.
- `python ai/health_check.py --pretty --summary`: `ai_readiness: 100`, 0
  issues, `macos_runtime` issue list empty (all 3 `dofile()` targets in
  `init.lua` resolve).
- `python ai/review_check.py --pretty --summary`: 0 issues, 0 warnings,
  `plan_state: active` correctly recognized.
- `git diff --check`: clean.

## Design constraint (why bindings.lua only carries metadata)

The `action` column in `hotkeys.db` holds raw AHK syntax
(e.g. `services.sap.insertCommentLine()`). This cannot be mechanically
transpiled to Lua, so the generator emits only binding metadata; behavior
is hand-authored in `actions.lua`/`hotstrings.lua`, matched by `id`.

## What is NOT yet verified (human-only)

- **Manual functional test inside real Eclipse/ADT and while typing
  hotstrings.** `luac -p` only proves the Lua parses — it does not load
  Hammerspoon's `hs.*` APIs or exercise real keystrokes.
- **Eclipse keymap accuracy.** `actions.lua` assumes specific Cmd/Ctrl/Alt
  shortcuts per action (documented inline per function) that may not match
  this machine's actual Eclipse keymap — this was not verifiable from the
  repo alone.

## Real-load bug found and fixed (2026-07-27)

First real load inside Hammerspoon surfaced a bug that `luac -p` could not
catch, because it is a **runtime path bug**, not a syntax error:

```
*** ERROR: cannot open /Users/ntincopa/.hammerspoon/keyflowgenerated/bindings.lua: No such file or directory
```

Root cause: `scriptDir = hs.configdir .. "/keyflow"` produced a path with no
trailing separator (`.../keyflow`), and `scriptDir .. "generated/bindings.lua"`
concatenated directly into `.../keyflowgenerated/bindings.lua`. Fixed by
adding the trailing `/` to `scriptDir` in both the primary and fallback
branches. Re-verified with `luac -p` (still passes, as expected — parse-only
checks cannot catch path-construction bugs) and lesson recorded here: **the
static `luac -p` smoke check validates syntax only; it cannot substitute for
loading the config inside Hammerspoon at least once.**

## Deferred fast-follow (not blocking, unblocked by app confirmation)

- Reclassify `snipaste_enter` to `portable-intent` and add a macOS binding +
  action, now that Snipaste is confirmed installed on this machine.
- SAP GUI for Java hotkeys — deferred because it is a Java/SWT app with a
  different focus-window API than native Cocoa apps; needs its own research
  pass before binding.

## Non-goals (unchanged)

- No SAP session launch, no credential handling.
- No parity requirement between hotkey counts on Windows vs macOS.
- No removal of any Windows runtime code.

## Human-only pending work

1. Hammerspoon is already wired to load `platforms/macos/hammerspoon/init.lua`
   via `~/.hammerspoon/keyflow` symlink + `dofile()` in `~/.hammerspoon/init.lua`.
   Reload the config (`hs -c "hs.reload()"` or menu bar → Reload Config) to
   pick up the trailing-slash path fix and the `eclipse_ctrl_5` removal, and
   confirm the console prints `keyflow: loaded 4 eclipse hotkey(s), hotstring
   watcher active` with no errors.
2. Open Eclipse/ADT and manually test each of the 4 hotkeys
   (`` ` ``, F1, F2, Cmd+Shift+B) against this machine's actual Eclipse
   keymap; adjust `actions.lua` if any binding is wrong.
3. Test the 6 hotstrings (`;;`, `"+`, `"-`, `*+`, `*-`, `sp `) in a plain
   text field to confirm the `hs.eventtap` watcher fires correctly and does
   not interfere with normal typing.
4. Report back which of the 10 bindings work as-is vs. need adjustment.

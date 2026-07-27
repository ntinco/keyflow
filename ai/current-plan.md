# macOS migration — first vertical slice (Hammerspoon)

Status: proposed
Plan: not started

## Goal

Stand up a minimal, parallel macOS runtime using Hammerspoon that proves the
architecture end-to-end (config loading, hotkey binding, app-context detection,
key sending) without attempting full parity with the Windows AHK runtime.

## Stack decision

- **Hammerspoon** is the recommended native automation stack:
  - Lua scripting with full window/app introspection (`hs.window`, `hs.application`).
  - Native hotkey binding (`hs.hotkey.bind`) with app-context guards, equivalent to AHK `#hotif`.
  - Native text-expansion is not built in; hotstrings need `hs.eventtap` or a
    dedicated expander (see Open questions).
  - No compiled binary to manage; config is plain Lua, reloadable at runtime.
- Rejected alternatives: Karabiner-Elements (remap-only, no scripting for
  compound workflows or app automation), Raycast (launcher-first, not a
  general hotkey/automation runtime).

## Scope for this slice

Only migrate entries already marked `portability=portable-intent` in
`hotkeys.db`, and only the ones with **zero dependency on a Windows-only API**
(no `WinActivate`, `GroupAdd`, clipboard-file paste, etc.). Two candidate
groups:

1. **Hotstrings (6 entries, `file=global`, `type=hotstring`)**
   - `hs_semicolons` (`;;` → `ñ`)
   - `hs_sap_comment_plus` / `hs_sap_comment_minus` (`"+` / `"-`)
   - `hs_sap_block_plus` / `hs_sap_block_minus` (`*+` / `*-`)
   - `hs_sp` (`sp` → paste "summary in prompt")
   - These are pure text-expansion, no window-context dependency once SAP GUI
     for Java is confirmed installed.

2. **SAP Eclipse/ADT hotkeys (5 entries, `file=sap-eclipse`)**
   - `eclipse_backtick`, `eclipse_f1`, `eclipse_f2`, `eclipse_ctrl_sh_b`,
     `eclipse_ctrl_5`
   - All are single-app-scoped key remaps or key-sends inside Eclipse/ADT.
     Simplest real-world validation of app-context detection + `hs.eventtap.keyStrokes`.

Do **not** migrate in this slice: SAP GUI hotkeys (needs SAP GUI for Java
confirmed + different focus-window API), launcher/productivity hotkeys
(XYplorer has no macOS equivalent), Snipaste/global hotkeys (no equivalent
app), window-group activation (`windowGroup` service is a Windows-specific
concept with no direct Hammerspoon analog yet).

## Technical steps

1. Create `platforms/macos/hammerspoon/init.lua` as the entrypoint (mirrors
   `keyflow.ahk`).
2. Create `platforms/macos/hammerspoon/bootstrap.lua`: loads constants and a
   minimal service registry (mirrors `bootstrap.ahk`).
3. Add a `platform` value `"macos"` to the 11 candidate hotkeys.db rows
   above (multi-value JSON array like `["windows","macos"]`), so the same
   human-owned catalog drives both runtimes without duplication.
4. Extend `ai/hotkey_sync.py` with a second generation target: emit Lua
   hotkey/hotstring bindings for rows where `platform` includes `"macos"`,
   parallel to the existing AHK generation. Keep the AHK generator untouched.
5. Extend `ai/health_check.py`:
   - Validate the macOS include chain (`init.lua` → `bootstrap.lua`) the same
     way the AHK include graph is validated.
   - Do NOT require macOS/Windows parity — a hotkey existing only for one
     platform is valid and expected.
6. Add a macOS smoke check: `hs -c "print('ok')"` or an equivalent minimal
   invocation, recorded through a small extension to `ai/run_smoke.py`.

## Open questions (human decision required before step 4)

- Hotstring expansion: build a small Hammerspoon text-watcher via
  `hs.eventtap`, or adopt a companion tool (e.g. Espanso) driven by the same
  JSON catalogs (`autocorrect.json`, `quick-snippets.json`)? This decides
  whether hotstrings live inside Hammerspoon or in a second local process.
- Confirm SAP GUI for Java and Eclipse/ADT are the actual apps that will run
  on the target Mac (vs. a VM/Citrix path, which would change the whole
  automation model).

## Non-goals for this slice

- No SAP session launch, no credential handling (already retired on Windows).
- No parity requirement between hotkey counts on Windows vs macOS.
- No removal of any Windows runtime code — both platforms coexist under
  `platforms/`.

## Definition of done for this slice

- `platforms/macos/hammerspoon/init.lua` loads without error under `hs -c`.
- The 5 Eclipse/ADT hotkeys and 6 hotstrings work manually on a real Mac with
  SAP GUI for Java + Eclipse/ADT installed (human verification).
- `ai/health_check.py` validates the macOS include chain and stays at
  `ai_readiness: 100` with both runtimes present.
- `ai/hotkey_sync.py --check` passes for both AHK and Lua generated artifacts.

## Human-only pending work

- Decide the hotstring-expansion approach (open question above).
- Confirm the installed macOS app set (SAP GUI for Java, Eclipse/ADT).
- Provide a Mac with Hammerspoon installed for manual verification.

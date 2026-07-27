# macOS migration — first vertical slice (Hammerspoon)

Status: confirmed
Plan: ready to implement

## App confirmation (verified on this machine)

Verified via `mdls -name kMDItemCFBundleIdentifier` and filesystem inspection —
no longer an open question:

| App | Bundle ID | Notes |
|---|---|---|
| Hammerspoon | `org.hammerspoon.Hammerspoon` | Installed via Homebrew (`hs` CLI available at `/opt/homebrew/bin/hs`) |
| Eclipse | `epp.package.committers` | ADT plugins confirmed present (`com.sap.adt.*` jars under `Contents/Eclipse/plugins`) |
| SAP GUI for Java | `com.sap.platin` | At `/Applications/SAP Clients/SAPGUI/SAPGUI.app` |
| Snipaste | `com.Snipaste` | Native macOS build, not a Windows-only tool as previously assumed |

This removes one of the two blocking open questions from the previous plan
revision. Snipaste being present changes scope: it is not Windows-only here,
so `snipaste_enter` (`~enter` in `hotkeys.db`, currently `portability=windows-only`)
should be reclassified to `portable-intent` in a follow-up catalog edit —
tracked as a fast-follow, not blocking this slice.

## Stack decision (unchanged)

**Hammerspoon**, confirmed installed and ready:
- Lua scripting with full window/app introspection (`hs.window`, `hs.application`).
- Native hotkey binding (`hs.hotkey.bind`) with app-context guards, equivalent to AHK `#hotif`.
- Native text-expansion is not built in; hotstrings need `hs.eventtap` or a
  dedicated expander (still an open question, see below).

## Scope for this slice

Only migrate entries already marked `portability=portable-intent` in
`hotkeys.db`, with zero dependency on a Windows-only API. Confirmed apps
mean the scope for the *next* catalog edit is broader than the previous
draft, but this slice keeps the original two groups to stay small and provable:

1. **Hotstrings (6 entries, `file=global`, `type=hotstring`)**
   - `hs_semicolons` (`;;` → `ñ`)
   - `hs_sap_comment_plus` / `hs_sap_comment_minus` (`"+` / `"-`)
   - `hs_sap_block_plus` / `hs_sap_block_minus` (`*+` / `*-`)
   - `hs_sp` (`sp` → paste "summary in prompt")

2. **SAP Eclipse/ADT hotkeys (5 entries, `file=sap-eclipse`)**
   - `eclipse_backtick`, `eclipse_f1`, `eclipse_f2`, `eclipse_ctrl_sh_b`,
     `eclipse_ctrl_5`
   - Now provable end-to-end on this machine: Eclipse + ADT plugins confirmed.

Deferred to a fast-follow slice (not blocking, now unblocked by app confirmation):
- `snipaste_enter` reclassification + migration (Snipaste confirmed present).
- SAP GUI hotkeys (SAP GUI for Java confirmed present; needs its own
  focus-window API research since it is a Java app, not a native Cocoa app).

Still out of scope for any near-term slice: launcher/productivity hotkeys
(XYplorer has no macOS equivalent), window-group activation (`windowGroup`
service is a Windows-specific concept with no direct Hammerspoon analog yet).

## Technical steps

1. Create `platforms/macos/hammerspoon/init.lua` as the entrypoint (mirrors
   `keyflow.ahk`).
2. Create `platforms/macos/hammerspoon/bootstrap.lua`: loads constants and a
   minimal service registry (mirrors `bootstrap.ahk`).
3. Add `"macos"` to the `platform` JSON array for the 11 candidate
   `hotkeys.db` rows above (e.g. `["windows","macos"]`), so the same
   human-owned catalog drives both runtimes without duplication.
4. Extend `ai/hotkey_sync.py` with a second generation target: emit Lua
   hotkey/hotstring bindings for rows where `platform` includes `"macos"`,
   parallel to the existing AHK generation. Keep the AHK generator untouched.
5. Extend `ai/health_check.py`:
   - Validate the macOS include chain (`init.lua` → `bootstrap.lua`) the same
     way the AHK include graph is validated.
   - Do NOT require macOS/Windows parity — a hotkey existing only for one
     platform is valid and expected.
6. Add a macOS smoke check: `hs -c "print('ok')"`, recorded through a small
   extension to `ai/run_smoke.py`.
7. Fast-follow (separate cycle): reclassify `snipaste_enter` to
   `portable-intent` and add it to the macOS-targeted rows once the first
   slice is validated.

## Open questions (only one remains)

- Hotstring expansion: build a small Hammerspoon text-watcher via
  `hs.eventtap`, or adopt a companion tool (e.g. Espanso) driven by the same
  JSON catalogs (`autocorrect.json`, `quick-snippets.json`)? This decides
  whether hotstrings live inside Hammerspoon or in a second local process.
  **This is the only remaining blocking decision before step 4.**

## Non-goals for this slice

- No SAP session launch, no credential handling (already retired on Windows).
- No parity requirement between hotkey counts on Windows vs macOS.
- No removal of any Windows runtime code — both platforms coexist under
  `platforms/`.
- No SAP GUI for Java automation yet (deferred to fast-follow).

## Definition of done for this slice

- `platforms/macos/hammerspoon/init.lua` loads without error under `hs -c`.
- The 5 Eclipse/ADT hotkeys and 6 hotstrings work manually on this Mac with
  Eclipse + ADT (human verification, app presence already confirmed).
- `ai/health_check.py` validates the macOS include chain and stays at
  `ai_readiness: 100` with both runtimes present.
- `ai/hotkey_sync.py --check` passes for both AHK and Lua generated artifacts.

## Human-only pending work

- Decide the hotstring-expansion approach (only remaining open question).
- Manually verify the 5 Eclipse/ADT hotkeys and 6 hotstrings once implemented.

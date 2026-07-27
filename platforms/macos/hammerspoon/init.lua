-- Hammerspoon entrypoint for the keyflow macOS runtime.
-- Mirrors platforms/windows/keyflow.ahk: load generated bindings, load
-- hand-authored actions/hotstrings, bind hotkeys guarded by app context.
--
-- Scope: first vertical slice only (see ai/current-plan.md).
--   - 5 SAP Eclipse/ADT hotkeys, active only while Eclipse is frontmost.
--   - 6 global hotstrings, active everywhere.
-- Not included in this slice: SAP GUI, launcher, window-group, Snipaste.

local scriptDir = hs.configdir .. "/keyflow/"
-- Fallback for running this file directly from the repo path during
-- development (outside ~/.hammerspoon/keyflow symlink setup).
if not hs.fs.attributes(hs.configdir .. "/keyflow") then
  scriptDir = debug.getinfo and debug.getinfo(1, "S").source:match("@(.*/)") or "./"
end

package.path = package.path .. ";" .. scriptDir .. "?.lua"

local bindings = dofile(scriptDir .. "generated/bindings.lua")
local Actions = dofile(scriptDir .. "actions.lua")
local Hotstrings = dofile(scriptDir .. "hotstrings.lua")

-- AHK key notation -> Hammerspoon modifier/key notation.
-- Only covers the symbols present in the current sap-eclipse catalog rows
-- (^ = ctrl, + = shift, ` = backtick, f1/f2 = function keys).
-- macOS keeps Eclipse ADT shortcuts on their SWT/cross-platform defaults
-- (Ctrl/Cmd as noted per-action in actions.lua), so bindings here use the
-- literal AHK modifier semantics translated 1:1 to Hammerspoon's ctrl/cmd —
-- verify against this machine's actual Eclipse keymap per action comments.
local function parseAhkKey(ahkKey)
  local mods = {}
  local key = ahkKey
  local prefixMap = {["^"] = "ctrl", ["+"] = "shift", ["!"] = "alt", ["#"] = "cmd"}
  while #key > 0 and prefixMap[key:sub(1, 1)] do
    table.insert(mods, prefixMap[key:sub(1, 1)])
    key = key:sub(2)
  end
  return mods, key
end

local ECLIPSE_CONTEXT_LABEL = "sap-eclipse"
local eclipseHotkeys = {}

for _, binding in ipairs(bindings) do
  if binding.type == "hotkey" and binding.contextLabel == ECLIPSE_CONTEXT_LABEL then
    local action = Actions[binding.id]
    if action then
      local mods, key = parseAhkKey(binding.key)
      local hotkey = hs.hotkey.new(mods, key, action)
      table.insert(eclipseHotkeys, hotkey)
    else
      hs.printf("keyflow: no action registered for binding id '%s'", binding.id)
    end
  end
end

-- Context guard equivalent to AHK's `#hotif winactive(exeEclipse)`: only
-- enable the Eclipse-scoped hotkeys while Eclipse is the frontmost app.
local eclipseWatcher = hs.application.watcher.new(function(appName, eventType, app)
  if appName ~= "Eclipse" then
    return
  end
  if eventType == hs.application.watcher.activated then
    for _, hotkey in ipairs(eclipseHotkeys) do
      hotkey:enable()
    end
  elseif eventType == hs.application.watcher.deactivated then
    for _, hotkey in ipairs(eclipseHotkeys) do
      hotkey:disable()
    end
  end
end)
eclipseWatcher:start()

Hotstrings.start()

hs.printf(
  "keyflow: loaded %d eclipse hotkey(s), hotstring watcher active",
  #eclipseHotkeys
)

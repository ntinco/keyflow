-- Hammerspoon entrypoint. Mirrors platforms/windows/keyflow.ahk.
-- Scope: first vertical slice (see ai/current-plan.md) — 3 Eclipse/ADT
-- hotkeys (active only while Eclipse is frontmost) + 6 global hotstrings.

local scriptDir = hs.configdir .. "/keyflow/"
if not hs.fs.attributes(hs.configdir .. "/keyflow") then
  scriptDir = debug.getinfo and debug.getinfo(1, "S").source:match("@(.*/)") or "./"
end

package.path = package.path .. ";" .. scriptDir .. "?.lua"

local bindings = dofile(scriptDir .. "generated/bindings.lua")
local Actions = dofile(scriptDir .. "actions.lua")
local Hotstrings = dofile(scriptDir .. "hotstrings.lua")

-- AHK modifier notation -> Hammerspoon. Verify against real Eclipse keymap.
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
      table.insert(eclipseHotkeys, hs.hotkey.new(mods, key, action))
    else
      hs.printf("keyflow: no action registered for binding id '%s'", binding.id)
    end
  end
end

-- Mirrors AHK #hotif winactive(exeEclipse).
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

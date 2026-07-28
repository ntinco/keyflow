-- Hammerspoon entrypoint. Mirrors platforms/windows/keyflow.ahk.

-- _G survives a config reload within the same Hammerspoon process; local
-- hotkey objects from the previous load do not get deleted automatically
-- and would otherwise keep firing globally alongside the new ones.
if _G.keyflowHotkeys then
  for _, hotkey in ipairs(_G.keyflowHotkeys) do hotkey:delete() end
end
_G.keyflowHotkeys = {}

local scriptDir = hs.configdir .. "/keyflow/"
if not hs.fs.attributes(hs.configdir .. "/keyflow") then
  scriptDir = debug.getinfo and debug.getinfo(1, "S").source:match("@(.*/)") or "./"
end

package.path = package.path .. ";" .. scriptDir .. "?.lua"

local bindings = dofile(scriptDir .. "generated/bindings.lua")
local Actions = dofile(scriptDir .. "actions.lua")
local Hotstrings = dofile(scriptDir .. "hotstrings.lua")

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

local CONTEXT_APP_NAMES = {
  ["sap-eclipse"] = "Eclipse",
  ["sap-gui-session"] = "SAPGUI",
}

-- disable(), not a global bind: some of these keys (Option+number) type
-- special characters in other apps and must pass through when inactive.
local hotkeysByApp = {}
for contextLabel in pairs(CONTEXT_APP_NAMES) do
  hotkeysByApp[contextLabel] = {}
end

local loadedCount = 0
for _, binding in ipairs(bindings) do
  if binding.type == "hotkey" and CONTEXT_APP_NAMES[binding.contextLabel] then
    local action = Actions[binding.id]
    if action then
      local mods, key = parseAhkKey(binding.key)
      local hotkey = hs.hotkey.new(mods, key, action)
      table.insert(hotkeysByApp[binding.contextLabel], hotkey)
      table.insert(_G.keyflowHotkeys, hotkey)
      loadedCount = loadedCount + 1
    else
      hs.printf("keyflow: no action registered for binding id '%s'", binding.id)
    end
  end
end

local function syncHotkeysForFrontApp()
  local front = hs.application.frontmostApplication()
  local frontAppName = front and front:name()
  for contextLabel, watchedAppName in pairs(CONTEXT_APP_NAMES) do
    local isFront = frontAppName == watchedAppName
    for _, hotkey in ipairs(hotkeysByApp[contextLabel]) do
      if isFront then hotkey:enable() else hotkey:disable() end
    end
  end
end

syncHotkeysForFrontApp()

-- Must be kept in a local: an unreferenced hs.timer/hs.watcher object is
-- eligible for GC and silently stops firing once collected.
local appWatcher = hs.application.watcher.new(function(_, eventType)
  if eventType == hs.application.watcher.activated
      or eventType == hs.application.watcher.deactivated then
    syncHotkeysForFrontApp()
  end
end)
appWatcher:start()

local syncTimer = hs.timer.new(1, syncHotkeysForFrontApp)
syncTimer:start()

Hotstrings.start()

hs.printf("keyflow: loaded %d app-scoped hotkey(s), hotstring watcher active", loadedCount)

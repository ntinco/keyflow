-- Hammerspoon entrypoint. Mirrors platforms/windows/keyflow.ahk.

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

-- contextLabel -> frontmost app name, mirrors AHK #hotif winactive(...).
local CONTEXT_APP_NAMES = {
  ["sap-eclipse"] = "Eclipse",
  ["sap-gui-session"] = "SAPGUI",
}

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
      table.insert(hotkeysByApp[binding.contextLabel], hs.hotkey.new(mods, key, action))
      loadedCount = loadedCount + 1
    else
      hs.printf("keyflow: no action registered for binding id '%s'", binding.id)
    end
  end
end

-- Deterministic sync: on every focus change, enable hotkeys only for the
-- context whose app is actually frontmost, disable all others. This does
-- not depend on paired activated/deactivated events (a missed deactivated
-- event would otherwise leave a hotkey enabled globally forever).
local function syncHotkeysForFrontApp(frontAppName)
  for contextLabel, watchedAppName in pairs(CONTEXT_APP_NAMES) do
    local isFront = frontAppName == watchedAppName
    for _, hotkey in ipairs(hotkeysByApp[contextLabel]) do
      if isFront then hotkey:enable() else hotkey:disable() end
    end
  end
end

syncHotkeysForFrontApp(hs.application.frontmostApplication() and hs.application.frontmostApplication():name())

local appWatcher = hs.application.watcher.new(function(appName, eventType)
  if eventType == hs.application.watcher.activated then
    syncHotkeysForFrontApp(appName)
  elseif eventType == hs.application.watcher.deactivated then
    syncHotkeysForFrontApp(hs.application.frontmostApplication() and hs.application.frontmostApplication():name())
  end
end)
appWatcher:start()

Hotstrings.start()

hs.printf("keyflow: loaded %d app-scoped hotkey(s), hotstring watcher active", loadedCount)

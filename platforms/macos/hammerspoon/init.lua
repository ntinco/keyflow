-- Hammerspoon entrypoint. Mirrors platforms/windows/keyflow.ahk.

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
      hs.hotkey.deleteAll(mods, key)
      local hotkey = hs.hotkey.new(mods, key, action)
      if hotkey then
        table.insert(hotkeysByApp[binding.contextLabel], hotkey)
        loadedCount = loadedCount + 1
      end
    else
      hs.printf("keyflow: no action registered for binding id '%s'", binding.id)
    end
  end
end

local activeContextLabel

local function frontAppContext()
  local front = hs.application.frontmostApplication()
  local frontAppName = front and front:name()
  for contextLabel, watchedAppName in pairs(CONTEXT_APP_NAMES) do
    if frontAppName == watchedAppName then
      return contextLabel
    end
  end
  return nil
end

local function syncHotkeysForFrontApp()
  local nextContextLabel = frontAppContext()
  if nextContextLabel == activeContextLabel then
    return
  end

  if activeContextLabel then
    for _, hotkey in ipairs(hotkeysByApp[activeContextLabel]) do
      hotkey:disable()
    end
  end

  if nextContextLabel then
    for _, hotkey in ipairs(hotkeysByApp[nextContextLabel]) do
      hotkey:enable()
    end
  end

  activeContextLabel = nextContextLabel
end

syncHotkeysForFrontApp()

local appWatcher = hs.application.watcher.new(function(appName, eventType)
  if eventType == hs.application.watcher.deactivated
      and appName == CONTEXT_APP_NAMES["sap-gui-session"] then
    Actions.cancelSapRun()
  end
  if eventType == hs.application.watcher.activated
      or eventType == hs.application.watcher.deactivated then
    hs.timer.doAfter(0, syncHotkeysForFrontApp)
  end
end)
appWatcher:start()

Hotstrings.start()

hs.printf("keyflow: loaded %d app-scoped hotkey(s), hotstring watcher active", loadedCount)

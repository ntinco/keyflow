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

local CONTEXT_APPS = {
  ["launcher"] = {
    {bundleID = "com.apple.Spotlight", name = "Spotlight"},
    {bundleID = "com.raycast.macos", name = "Raycast"},
  },
  ["sap-eclipse"] = {
    {bundleID = "epp.package.committers", name = "Eclipse"},
  },
  ["sap-gui-session"] = {
    {bundleID = "com.sap.platin", name = "SAPGUI"},
  },
}

local hotkeysByApp = {}
for contextLabel in pairs(CONTEXT_APPS) do
  hotkeysByApp[contextLabel] = {}
end

local loadedCount = 0
for _, binding in ipairs(bindings) do
  if binding.type == "hotkey" and CONTEXT_APPS[binding.contextLabel] then
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

local function matchesApp(app, expectedApps)
  if not app then return false end
  for _, expected in ipairs(expectedApps) do
    if app:bundleID() == expected.bundleID or app:name() == expected.name then
      return true
    end
  end
  return false
end

local function frontAppContext()
  local front = hs.application.frontmostApplication()
  for contextLabel, expectedApp in pairs(CONTEXT_APPS) do
    if matchesApp(front, expectedApp) then
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

local appWatcher = hs.application.watcher.new(function(_, eventType, app)
  if eventType == hs.application.watcher.deactivated
      and matchesApp(app, CONTEXT_APPS["sap-gui-session"]) then
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

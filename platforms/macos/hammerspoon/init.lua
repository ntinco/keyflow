-- Hammerspoon entrypoint. Mirrors platforms/windows/keyflow.ahk.

local scriptDir = hs.configdir .. "/keyflow/"
if not hs.fs.attributes(hs.configdir .. "/keyflow") then
  scriptDir = debug.getinfo and debug.getinfo(1, "S").source:match("@(.*/)") or "./"
end

package.path = package.path .. ";" .. scriptDir .. "?.lua"

local bindings = dofile(scriptDir .. "generated/bindings.lua")
local hotstringProfiles = dofile(scriptDir .. "generated/hotstring_profiles.lua")
local Actions = dofile(scriptDir .. "actions.lua")
local Hotstrings = dofile(scriptDir .. "hotstrings.lua")
local Runtime = {hotkeysByApp = {}}
package.loaded["keyflow.runtime"] = Runtime

local function parseAhkKey(ahkKey)
  local mods = {}
  local key = ahkKey
  key = key:gsub("^~", "")
  local prefixMap = {["^"] = "ctrl", ["+"] = "shift", ["!"] = "alt", ["#"] = "cmd"}
  while #key > 0 and prefixMap[key:sub(1, 1)] do
    table.insert(mods, prefixMap[key:sub(1, 1)])
    key = key:sub(2)
  end
  return mods, key
end

local CONTEXT_APPS = {
  ["launcher"] = {
    {bundleID = "com.apple.finder", name = "Finder"},
    {bundleID = "com.apple.Spotlight", name = "Spotlight"},
  },
  ["sap-eclipse"] = {
    {bundleID = "epp.package.committers", name = "Eclipse"},
  },
  ["sap-gui-session"] = {
    {bundleID = "com.sap.platin", name = "SAPGUI"},
  },
  ["snipaste"] = {
    {bundleID = "com.Snipaste", name = "Snipaste"},
  },
}

for contextLabel in pairs(CONTEXT_APPS) do
  Runtime.hotkeysByApp[contextLabel] = {}
end

local loadedCount = 0
local overlayBindings = {}
local mouseBindings = {}
local MOUSE_BUTTONS = {xbutton1 = 3, xbutton2 = 4}
for _, binding in ipairs(bindings) do
  if binding.type == "hotkey"
      and (binding.contextLabel == "global" or CONTEXT_APPS[binding.contextLabel]) then
    local action = Actions[binding.id]
    if action then
      local mods, key = parseAhkKey(binding.key)
      local mouseButton = MOUSE_BUTTONS[key:lower()]
      if mouseButton then
        mouseBindings[mouseButton] = action
        loadedCount = loadedCount + 1
      elseif binding.contextLabel == "launcher"
          or binding.contextLabel == "snipaste" then
        overlayBindings[#overlayBindings + 1] = {
          action = action,
          contextLabel = binding.contextLabel,
          keyCode = hs.keycodes.map[key:lower()],
          mods = mods,
          passthrough = binding.key:sub(1, 1) == "~",
        }
        loadedCount = loadedCount + 1
      else
        hs.hotkey.deleteAll(mods, key)
        local hotkey = hs.hotkey.new(mods, key, action)
        if hotkey then
          if binding.contextLabel == "global" then
            hotkey:enable()
          else
            table.insert(Runtime.hotkeysByApp[binding.contextLabel], hotkey)
          end
          loadedCount = loadedCount + 1
        end
      end
    else
      hs.printf("keyflow: no action registered for binding id '%s'", binding.id)
    end
  end
end

local function matchesModifiers(flags, expectedMods)
  local expected = {}
  for _, mod in ipairs(expectedMods) do expected[mod] = true end
  for _, mod in ipairs({"cmd", "ctrl", "alt", "shift"}) do
    if (flags[mod] == true) ~= (expected[mod] == true) then return false end
  end
  return true
end

local function overlayIsActive(contextLabel)
  if contextLabel == "launcher" then
    return Actions.launcherSourceBundleID() ~= nil
  end
  return contextLabel == "snipaste" and Actions.snipasteIsActive()
end

Runtime.overlayWatcher = hs.eventtap.new(
  {hs.eventtap.event.types.keyDown},
  function(event)
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()
    for _, binding in ipairs(overlayBindings) do
      if keyCode == binding.keyCode
          and matchesModifiers(flags, binding.mods) then
        if not overlayIsActive(binding.contextLabel) then return false end
        binding.action()
        return not binding.passthrough
      end
    end
    return false
  end
)
Runtime.overlayWatcher:start()

Runtime.mouseWatcher = hs.eventtap.new({
  hs.eventtap.event.types.otherMouseDown,
  hs.eventtap.event.types.otherMouseUp,
}, function(event)
  local button = event:getProperty(
    hs.eventtap.event.properties.mouseEventButtonNumber
  )
  local action = mouseBindings[button]
  if not action then return false end
  if event:getType() == hs.eventtap.event.types.otherMouseDown then action() end
  return true
end)
Runtime.mouseWatcher:start()

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
      return contextLabel, front
    end
  end
  return nil, front
end

local function syncHotkeysForFrontApp()
  local nextContextLabel, front = frontAppContext()
  if nextContextLabel == activeContextLabel then
    return
  end

  if activeContextLabel then
    for _, hotkey in ipairs(Runtime.hotkeysByApp[activeContextLabel]) do
      hotkey:disable()
    end
  end

  if nextContextLabel then
    for _, hotkey in ipairs(Runtime.hotkeysByApp[nextContextLabel]) do
      hotkey:enable()
    end
  end

  activeContextLabel = nextContextLabel
  hs.printf(
    "keyflow: front app=%s (%s), active context=%s",
    front and front:name() or "none",
    front and front:bundleID() or "none",
    activeContextLabel or "none"
  )
end

Actions.rememberLauncherTarget(hs.application.frontmostApplication())
syncHotkeysForFrontApp()

Runtime.appWatcher = hs.application.watcher.new(function(_, eventType, app)
  if eventType == hs.application.watcher.activated
      or eventType == hs.application.watcher.deactivated then
    Hotstrings.reset()
  end
  if eventType == hs.application.watcher.deactivated then
    Actions.rememberLauncherTarget(app)
  end
  if eventType == hs.application.watcher.deactivated
      and matchesApp(app, CONTEXT_APPS["sap-gui-session"]) then
    Actions.cancelSapRun()
  end
  if eventType == hs.application.watcher.activated
      or eventType == hs.application.watcher.deactivated then
    hs.timer.doAfter(0, syncHotkeysForFrontApp)
  end
end)
Runtime.appWatcher:start()

Hotstrings.start(Actions, bindings, hotstringProfiles)

local consoleToolbar = hs.console.toolbar()
local clearConsoleItem = {
  id = "keyflowClearConsole",
  image = hs.image.imageFromName("NSTrashFull"),
  fn = function() hs.console.clearConsole() end,
  label = "Clear",
  tooltip = "Clear Console",
}

local function includes(values, expected)
  for _, value in ipairs(values) do
    if value == expected then return true end
  end
  return false
end

if not includes(consoleToolbar:allowedItems(), clearConsoleItem.id) then
  consoleToolbar:addItems(clearConsoleItem)
end
consoleToolbar:modifyItem(clearConsoleItem)
consoleToolbar:autosaves(true)
if not hs.settings.get("keyflow.consoleClearInstalled") then
  consoleToolbar:insertItem(
    clearConsoleItem.id,
    #consoleToolbar:visibleItems() + 1
  )
  hs.settings.set("keyflow.consoleClearInstalled", true)
end
Runtime.consoleToolbar = consoleToolbar

hs.printf("keyflow: loaded %d contextual binding(s), watchers active", loadedCount)

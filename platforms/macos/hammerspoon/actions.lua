-- Hand-authored actions matched by hotkeys.db id; see
-- platforms/windows/library/automation/sap.ahk for source behavior.

local Actions = {}

local APP_BUNDLE_IDS = {
  eclipse = "epp.package.committers",
  iina = "com.colliderli.iina",
  raycast = "com.raycast.macos",
  sap = "com.sap.platin",
  spotlight = "com.apple.Spotlight",
}

local function isFrontApp(bundleID)
  local front = hs.application.frontmostApplication()
  return front and front:bundleID() == bundleID
end

local function focusedApp()
  local ok, app = pcall(function()
    local element = hs.axuielement.systemWideElement()
      :attributeValue("AXFocusedUIElement")
    return element
      and hs.application.applicationForPID(element:pid())
      or nil
  end)
  return ok and app or hs.application.frontmostApplication()
end

function Actions.launcherSourceBundleID()
  local app = focusedApp()
  local bundleID = app and app:bundleID()
  if bundleID == APP_BUNDLE_IDS.raycast
      or bundleID == APP_BUNDLE_IDS.spotlight then
    return bundleID
  end
  return nil
end

local function captureClipboard()
  return {
    data = hs.pasteboard.readAllData(),
    text = hs.pasteboard.getContents(),
  }
end

local function restoreClipboard(snapshot)
  if snapshot.data and next(snapshot.data) then
    hs.pasteboard.writeAllData(snapshot.data)
  else
    hs.pasteboard.clearContents()
  end
end

Actions.eclipse_backtick = function()
  if not isFrontApp(APP_BUNDLE_IDS.eclipse) then return end
  hs.eventtap.keyStroke({"cmd", "shift"}, "a")
  hs.timer.doAfter(0.15, function()
    if isFrontApp(APP_BUNDLE_IDS.eclipse) then
      hs.eventtap.keyStrokes("zpm*")
    end
  end)
end

Actions.eclipse_f1 = function()
  if isFrontApp(APP_BUNDLE_IDS.eclipse) then
    hs.eventtap.keyStroke({"cmd"}, "o")
  end
end

Actions.eclipse_f2 = function()
  if isFrontApp(APP_BUNDLE_IDS.eclipse) then
    hs.eventtap.keyStroke({"alt", "shift"}, "r")
  end
end

local function pasteText(text, savedClipboard)
  savedClipboard = savedClipboard or captureClipboard()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v")
  hs.timer.doAfter(0.2, function()
    restoreClipboard(savedClipboard)
  end)
end

local sapRunToken = 0

function Actions.cancelSapRun()
  sapRunToken = sapRunToken + 1
end

local function scheduleSapStep(token, delaySeconds, action)
  hs.timer.doAfter(delaySeconds, function()
    if token == sapRunToken and isFrontApp(APP_BUNDLE_IDS.sap) then
      action()
    end
  end)
end

local function runTcode(tcode)
  if not isFrontApp(APP_BUNDLE_IDS.sap) then return end

  Actions.cancelSapRun()
  local token = sapRunToken

  hs.eventtap.keyStroke({"cmd", "alt"}, "o")
  scheduleSapStep(token, 0.3, function()
    hs.eventtap.keyStroke({"cmd"}, "a")
    scheduleSapStep(token, 0.05, function()
      pasteText("/n" .. tcode)
      scheduleSapStep(token, 0.25, function()
        hs.eventtap.keyStroke({}, "return")
      end)
    end)
  end)
end

Actions.sap_gui_alt_5 = function() runTcode("ed") end
Actions.sap_gui_alt_6 = function() runTcode("se16n") end
Actions.sap_gui_alt_7 = function() runTcode("se37") end
Actions.sap_gui_alt_8 = function() runTcode("se38") end
Actions.sap_gui_alt_9 = function() runTcode("se09") end
Actions.sap_gui_alt_0 = function() runTcode("se80") end

local PASTEABLE_EXTENSIONS = {
  abap = true,
  ahk = true,
  md = true,
  txt = true,
}

local function decodePath(path)
  path = path:match("^%s*(.-)%s*$")
  path = path:gsub("^file://", "")
  return path:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)
end

local function parsePaths(value)
  local paths = {}
  for line in (value or ""):gmatch("[^\r\n]+") do
    local path = decodePath(line)
    if path:sub(1, 1) == "/" then
      paths[#paths + 1] = path
    end
  end
  return paths
end

local function readClipboardPaths()
  local paths = {}
  local seen = {}
  local urls = hs.pasteboard.readURL(nil, true)
  if type(urls) == "string" then urls = {urls} end

  local function add(path)
    path = decodePath(path):gsub("^localhost/", "/")
    if path:sub(1, 1) == "/" and not seen[path] then
      paths[#paths + 1] = path
      seen[path] = true
    end
  end

  for _, url in ipairs(urls or {}) do add(url) end
  for _, path in ipairs(parsePaths(hs.pasteboard.getContents())) do add(path) end
  return paths
end

local function axValue(element, attribute)
  local ok, value = pcall(element.attributeValue, element, attribute)
  return ok and value or nil
end

local function axFilePath(element)
  for _, attribute in ipairs({"AXURL", "AXDocument", "AXPath"}) do
    local value = axValue(element, attribute)
    if type(value) == "string" then
      local path = decodePath(value):gsub("^localhost/", "/")
      if path:sub(1, 1) == "/" then return path end
    end
  end
  return nil
end

local function hasSelectedAncestor(element)
  local ok, path = pcall(element.path, element)
  if not ok then return false end
  for _, ancestor in ipairs(path) do
    if axValue(ancestor, "AXSelected") == true then return true end
  end
  return false
end

local function withCopiedPaths(sourceBundleID, shortcuts, callback)
  if Actions.launcherSourceBundleID() ~= sourceBundleID then return end

  local clipboard = captureClipboard()
  local shortcutIndex = 1

  local function copy()
    hs.pasteboard.clearContents()
    hs.pasteboard.callbackWhenChanged(0.75, function(changed)
      if Actions.launcherSourceBundleID() ~= sourceBundleID then
        restoreClipboard(clipboard)
        return
      end

      local paths = changed and readClipboardPaths() or {}
      hs.printf(
        "keyflow: launcher source=%s copy=%d changed=%s paths=%d",
        sourceBundleID,
        shortcutIndex,
        tostring(changed),
        #paths
      )
      if #paths > 0 then
        callback(paths, clipboard, sourceBundleID)
      elseif shortcutIndex < #shortcuts then
        shortcutIndex = shortcutIndex + 1
        copy()
      else
        restoreClipboard(clipboard)
      end
    end)

    local shortcut = shortcuts[shortcutIndex]
    hs.eventtap.keyStroke(shortcut.mods, shortcut.key)
  end

  copy()
end

local spotlightSearch

local function withSpotlightPaths(callback)
  local app = focusedApp()
  if not app or app:bundleID() ~= APP_BUNDLE_IDS.spotlight then return end

  local clipboard = captureClipboard()
  local root = hs.axuielement.applicationElementForPID(app:pid())
  if not root then
    restoreClipboard(clipboard)
    return
  end

  spotlightSearch = root:elementSearch(
    function(message, results)
      spotlightSearch = nil
      if Actions.launcherSourceBundleID() ~= APP_BUNDLE_IDS.spotlight then
        restoreClipboard(clipboard)
        return
      end

      local candidates = {}
      local selected = {}
      local seen = {}
      for _, element in ipairs(results) do
        local path = axFilePath(element)
        if path and not seen[path] then
          candidates[#candidates + 1] = path
          seen[path] = true
          if hasSelectedAncestor(element) then
            selected[#selected + 1] = path
          end
        end
      end

      local paths = #selected > 0 and selected
        or (#candidates == 1 and candidates)
        or {}
      hs.printf(
        "keyflow: spotlight ax=%s candidates=%d selected=%d paths=%d",
        message,
        #candidates,
        #selected,
        #paths
      )
      if #paths > 0 then
        callback(paths, clipboard, APP_BUNDLE_IDS.spotlight)
      else
        restoreClipboard(clipboard)
      end
    end,
    function(element) return axFilePath(element) ~= nil end,
    {depth = 12, count = 100}
  )
end

local function withLauncherPaths(callback)
  local sourceBundleID = Actions.launcherSourceBundleID()
  if sourceBundleID == APP_BUNDLE_IDS.raycast then
    withCopiedPaths(APP_BUNDLE_IDS.raycast, {
      {mods = {"cmd", "shift"}, key = "c"},
    }, callback)
  elseif sourceBundleID == APP_BUNDLE_IDS.spotlight then
    withSpotlightPaths(callback)
  end
end

local function dismissLauncher(sourceBundleID, callback, clipboard)
  if sourceBundleID == APP_BUNDLE_IDS.raycast
      or sourceBundleID == APP_BUNDLE_IDS.spotlight then
    hs.eventtap.keyStroke({}, "escape")
  else
    restoreClipboard(clipboard)
    return
  end

  hs.timer.doAfter(0.1, function()
    if Actions.launcherSourceBundleID() then
      restoreClipboard(clipboard)
      return
    end
    callback()
  end)
end

Actions.launcher_f12 = function()
  hs.printf("keyflow: launcher F12 received")
  withLauncherPaths(function(paths, clipboard, sourceBundleID)
    local contents = {}
    for _, path in ipairs(paths) do
      local extension = path:match("%.([^./]+)$")
      local file = extension and PASTEABLE_EXTENSIONS[extension:lower()] and io.open(path, "rb")
      if file then
        contents[#contents + 1] = file:read("*a")
        file:close()
      end
    end
    if #contents == 0 then
      restoreClipboard(clipboard)
      return
    end
    dismissLauncher(sourceBundleID, function()
      pasteText(table.concat(contents), clipboard)
    end, clipboard)
  end)
end

Actions.launcher_ctrl_s = function()
  withLauncherPaths(function(paths, clipboard, sourceBundleID)
    local path = paths[1]
    local file = path and clipboard.text and io.open(path, "wb")
    if not file then
      restoreClipboard(clipboard)
      return
    end
    local written = file:write(clipboard.text)
    file:close()
    if not written then
      restoreClipboard(clipboard)
      return
    end
    dismissLauncher(sourceBundleID, function()
      hs.pasteboard.clearContents()
    end, clipboard)
  end)
end

Actions.launcher_alt_p = function()
  withLauncherPaths(function(paths, clipboard, sourceBundleID)
    local path = paths[1]
    local lowerPath = path and path:lower() or ""
    if not lowerPath:find("music", 1, true)
        and not lowerPath:find("audio", 1, true)
        and not lowerPath:find("video", 1, true) then
      restoreClipboard(clipboard)
      return
    end
    dismissLauncher(sourceBundleID, function()
      restoreClipboard(clipboard)
      local task = hs.task.new("/usr/bin/open", nil, {"-b", APP_BUNDLE_IDS.iina, path})
      if task then task:start() end
    end, clipboard)
  end)
end

return Actions

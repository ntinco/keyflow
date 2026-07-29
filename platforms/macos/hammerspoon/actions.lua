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

local function withCopiedPaths(sourceBundleID, shortcuts, callback)
  if not isFrontApp(sourceBundleID) then return end

  local clipboard = captureClipboard()
  local shortcutIndex = 1

  local function copy()
    hs.pasteboard.clearContents()
    hs.pasteboard.callbackWhenChanged(0.75, function(changed)
      if not isFrontApp(sourceBundleID) then
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

local function withLauncherPaths(callback)
  if isFrontApp(APP_BUNDLE_IDS.raycast) then
    withCopiedPaths(APP_BUNDLE_IDS.raycast, {
      {mods = {"cmd", "shift"}, key = "c"},
    }, callback)
  elseif isFrontApp(APP_BUNDLE_IDS.spotlight) then
    withCopiedPaths(APP_BUNDLE_IDS.spotlight, {
      {mods = {"cmd", "shift"}, key = "c"},
      {mods = {"cmd"}, key = "c"},
    }, callback)
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
    if isFrontApp(APP_BUNDLE_IDS.raycast)
        or isFrontApp(APP_BUNDLE_IDS.spotlight) then
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

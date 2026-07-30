-- Hand-authored actions matched by hotkeys.db id; see
-- platforms/windows/library/automation/sap.ahk for source behavior.

local Actions = {}

local APP_BUNDLE_IDS = {
  eclipse = "epp.package.committers",
  finder = "com.apple.finder",
  iina = "com.colliderli.iina",
  sap = "com.sap.platin",
  snipaste = "com.Snipaste",
  spotlight = "com.apple.Spotlight",
}

local SNIPASTE_RESIZE_TARGETS = {
  ["com.microsoft.onenote.mac"] = true,
  ["com.microsoft.teams2"] = true,
  ["com.microsoft.Outlook"] = true,
  ["md.obsidian"] = true,
  ["net.whatsapp.WhatsApp"] = true,
  ["notion.id"] = true,
  ["org.libreoffice.script"] = true,
}

local SNIPASTE_PASTE_TARGETS = {
  ["com.microsoft.teams2"] = true,
}

local launcherTargetApp
local snipasteTargetApp

local function isLauncherApp(app)
  local bundleID = app and app:bundleID()
  return bundleID == APP_BUNDLE_IDS.finder
    or bundleID == APP_BUNDLE_IDS.spotlight
end

function Actions.rememberLauncherTarget(app)
  if app and not isLauncherApp(app) then
    launcherTargetApp = app
  end
end

local function currentLauncherTarget()
  local front = hs.application.frontmostApplication()
  if front and not isLauncherApp(front) then
    Actions.rememberLauncherTarget(front)
  end
  return launcherTargetApp
end

local function isFrontApp(bundleID)
  local front = hs.application.frontmostApplication()
  return front and front:bundleID() == bundleID
end

local function isFrontSap()
  local front = hs.application.frontmostApplication()
  return front and (
    front:bundleID() == APP_BUNDLE_IDS.sap
    or front:name() == "SAPGUI"
  )
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
  if bundleID == APP_BUNDLE_IDS.finder
      or bundleID == APP_BUNDLE_IDS.spotlight then
    return bundleID
  end
  return nil
end

function Actions.snipasteIsActive()
  local app = focusedApp()
  return app and app:bundleID() == APP_BUNDLE_IDS.snipaste
end

local function currentSnipasteTarget()
  local front = hs.application.frontmostApplication()
  if front and front:bundleID() ~= APP_BUNDLE_IDS.snipaste then
    snipasteTargetApp = front
  end
  return snipasteTargetApp
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

local function pasteText(text, savedClipboard, targetApp)
  savedClipboard = savedClipboard or captureClipboard()
  hs.pasteboard.setContents(text)
  local front = hs.application.frontmostApplication()
  hs.printf(
    "keyflow: paste dispatched app=%s bytes=%d",
    front and front:bundleID() or "none",
    #text
  )
  hs.eventtap.keyStroke({"cmd"}, "v", 200000, targetApp)
  hs.timer.doAfter(0.5, function()
    restoreClipboard(savedClipboard)
  end)
end

local sapRunToken = 0

function Actions.cancelSapRun()
  sapRunToken = sapRunToken + 1
end

local function normalizeTcode(tcode)
  local normalized = tcode:match("^%s*(.-)%s*$")
  if normalized:sub(1, 1) == "/" then
    return normalized
  end
  return "/n" .. normalized:upper()
end

local function runTcode(tcode)
  if not isFrontSap() then return end

  Actions.cancelSapRun()
  local token = sapRunToken

  hs.eventtap.keyStroke({"cmd", "alt"}, "o")
  hs.timer.doAfter(0.3, function()
    if token == sapRunToken and isFrontSap() then
      hs.eventtap.keyStroke({"cmd"}, "a")
      hs.timer.doAfter(0.05, function()
        if token == sapRunToken and isFrontSap() then
          pasteText(normalizeTcode(tcode))
          hs.timer.doAfter(0.25, function()
            if token == sapRunToken and isFrontSap() then
              hs.eventtap.keyStroke({}, "return")
            end
          end)
        end
      end)
    end
  end)
end

Actions.runSapTcode = runTcode

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

local function withFinderPaths(sourceBundleID, targetApp, clipboard, callback)
  local copyAttempts = 0

  local function copySelection()
    copyAttempts = copyAttempts + 1
    hs.pasteboard.clearContents()
    hs.pasteboard.callbackWhenChanged(0.75, function(changed)
      local paths = changed and readClipboardPaths() or {}
      hs.printf(
        "keyflow: finder copy=%d changed=%s paths=%d",
        copyAttempts,
        tostring(changed),
        #paths
      )
      if #paths > 0 then
        callback(paths, clipboard, targetApp)
      elseif copyAttempts < 4 and isFrontApp(APP_BUNDLE_IDS.finder) then
        hs.timer.doAfter(0.25, copySelection)
      else
        restoreClipboard(clipboard)
        if targetApp then targetApp:activate() end
      end
    end)
    hs.eventtap.keyStroke({"cmd", "alt"}, "c")
  end

  hs.timer.doAfter(sourceBundleID == APP_BUNDLE_IDS.spotlight and 0.3 or 0, copySelection)
end

local function withSpotlightPaths(targetApp, clipboard, callback)
  local finderAttempts = 0

  local function copyFromFinder()
    finderAttempts = finderAttempts + 1
    if isFrontApp(APP_BUNDLE_IDS.finder) then
      withFinderPaths(APP_BUNDLE_IDS.spotlight, targetApp, clipboard, callback)
    elseif finderAttempts < 20 then
      hs.timer.doAfter(0.1, copyFromFinder)
    else
      restoreClipboard(clipboard)
      if targetApp then targetApp:activate() end
      hs.printf("keyflow: spotlight Finder handoff timed out")
    end
  end

  hs.eventtap.keyStroke({"cmd"}, "r")
  hs.timer.doAfter(0.1, copyFromFinder)
end

local function withLauncherPaths(callback)
  local sourceBundleID = Actions.launcherSourceBundleID()
  local targetApp = currentLauncherTarget()
  local clipboard = captureClipboard()
  if sourceBundleID == APP_BUNDLE_IDS.finder then
    withFinderPaths(sourceBundleID, targetApp, clipboard, callback)
  elseif sourceBundleID == APP_BUNDLE_IDS.spotlight then
    withSpotlightPaths(targetApp, clipboard, callback)
  end
end

local function withRestoredTarget(targetApp, clipboard, callback)
  if not targetApp or not targetApp:activate() then
    restoreClipboard(clipboard)
    return
  end

  local attempts = 0
  local function waitForTarget()
    attempts = attempts + 1
    if targetApp:isFrontmost() then
      hs.printf("keyflow: launcher target restored app=%s", targetApp:bundleID())
      hs.timer.doAfter(0.15, callback)
    elseif attempts < 20 then
      hs.timer.doAfter(0.1, waitForTarget)
    else
      restoreClipboard(clipboard)
      hs.printf("keyflow: launcher target restore timed out")
    end
  end
  waitForTarget()
end

Actions.launcher_f12 = function()
  hs.printf("keyflow: launcher F12 received")
  withLauncherPaths(function(paths, clipboard, targetApp)
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
    withRestoredTarget(targetApp, clipboard, function()
      pasteText(table.concat(contents), clipboard, targetApp)
    end)
  end)
end

Actions.launcher_alt_p = function()
  withLauncherPaths(function(paths, clipboard)
    local mediaPaths = {}
    for _, path in ipairs(paths) do
      local lowerPath = path:lower()
      if lowerPath:find("music", 1, true)
          or lowerPath:find("audio", 1, true)
          or lowerPath:find("video", 1, true) then
        mediaPaths[#mediaPaths + 1] = path
      end
    end
    if #mediaPaths == 0 then
      restoreClipboard(clipboard)
      return
    end
    restoreClipboard(clipboard)
    local appPath = hs.application.pathForBundleID(APP_BUNDLE_IDS.iina)
    local cliPath = appPath and appPath .. "/Contents/MacOS/iina-cli"
    local args = {"--no-stdin"}
    for _, path in ipairs(mediaPaths) do args[#args + 1] = path end
    local task = cliPath and hs.task.new(cliPath, nil, args)
    if task then task:start() end
  end)
end

local magickPath
local snipasteRunToken = 0

local function withMagick(callback)
  if magickPath then
    callback(magickPath)
    return
  end
  local task = hs.task.new("/bin/zsh", function(exitCode, output)
    local path = exitCode == 0 and output:match("^%s*(.-)%s*$") or ""
    if path ~= "" then magickPath = path end
    callback(magickPath)
  end, {"-lc", "command -v magick"})
  if task then
    task:start()
  else
    callback(nil)
  end
end

local function completeSnipaste(targetApp)
  if not targetApp then return end
  targetApp:activate()
  if SNIPASTE_PASTE_TARGETS[targetApp:bundleID()] then
    hs.timer.doAfter(0.15, function()
      hs.eventtap.keyStroke({"cmd"}, "v", 200000, targetApp)
    end)
  end
end

local function resizeSnipasteImage(image, targetApp)
  if not targetApp or not SNIPASTE_RESIZE_TARGETS[targetApp:bundleID()] then
    completeSnipaste(targetApp)
    return
  end

  withMagick(function(executable)
    local temporaryDirectory = hs.fs.temporaryDirectory()
    local token = tostring(hs.timer.absoluteTime())
    local inputPath = temporaryDirectory .. "keyflow-snipaste-" .. token .. ".png"
    local outputPath = temporaryDirectory .. "keyflow-snipaste-" .. token .. "-80.png"
    if not executable or not image:saveToFile(inputPath, true, "png") then
      hs.printf("keyflow: Snipaste ImageMagick unavailable")
      completeSnipaste(targetApp)
      return
    end

    local task = hs.task.new(executable, function(exitCode)
      local resized = exitCode == 0 and hs.image.imageFromPath(outputPath) or nil
      if resized then
        hs.pasteboard.writeObjects(resized)
      else
        hs.printf("keyflow: Snipaste ImageMagick failed (%d)", exitCode)
      end
      os.remove(inputPath)
      os.remove(outputPath)
      completeSnipaste(targetApp)
    end, {inputPath, "-resize", "80%", outputPath})
    if not task or not task:start() then
      os.remove(inputPath)
      os.remove(outputPath)
      hs.printf("keyflow: Snipaste ImageMagick task did not start")
      completeSnipaste(targetApp)
    end
  end)
end

Actions.global_mouse_fwd = function()
  currentSnipasteTarget()
  local appPath = hs.application.pathForBundleID(APP_BUNDLE_IDS.snipaste)
  local executable = appPath and appPath .. "/Contents/MacOS/Snipaste"
  local task = executable and hs.task.new(executable, nil, {"snip"})
  if not task or not task:start() then
    hs.printf("keyflow: Snipaste capture did not start")
  end
end

Actions.snipaste_enter = function()
  if not Actions.snipasteIsActive() then return end

  local targetApp = currentSnipasteTarget()
  local initialChangeCount = hs.pasteboard.changeCount()
  snipasteRunToken = snipasteRunToken + 1
  local token = snipasteRunToken
  local attempts = 0

  local function readCapture()
    if token ~= snipasteRunToken then return end
    attempts = attempts + 1
    if hs.pasteboard.changeCount() ~= initialChangeCount then
      local image = hs.pasteboard.readImage()
      if image then
        resizeSnipasteImage(image, targetApp)
        return
      end
    end
    if attempts < 30 then
      hs.timer.doAfter(0.1, readCapture)
    else
      hs.printf("keyflow: Snipaste capture timed out")
    end
  end
  hs.timer.doAfter(0.1, readCapture)
end

return Actions

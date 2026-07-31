-- Hand-authored actions matched by hotkeys.db id; see
-- platforms/windows/library/automation/sap.ahk for source behavior.

local Actions = {}

local APP_BUNDLE_IDS = {
  cursor = "com.todesktop.230313mzl4w4u",
  eclipse = "epp.package.committers",
  finder = "com.apple.finder",
  iina = "com.colliderli.iina",
  sap = "com.sap.platin",
  snipaste = "com.Snipaste",
  spotlight = "com.apple.Spotlight",
  vscode = "com.microsoft.VSCode",
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
local iinaTask

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

local function focusNextRunningWindow(bundleIDs)
  local windows = {}
  for _, bundleID in ipairs(bundleIDs) do
    for _, app in ipairs(hs.application.applicationsForBundleID(bundleID) or {}) do
      for _, window in ipairs(app:allWindows()) do
        if window:isStandard() then
          windows[#windows + 1] = window
        end
      end
    end
  end
  if #windows == 0 then return false end

  local front = hs.window.frontmostWindow()
  local nextIndex = 1
  for index, window in ipairs(windows) do
    if window:id() == (front and front:id()) then
      nextIndex = index % #windows + 1
      break
    end
  end
  return windows[nextIndex]:focus()
end

Actions.global_alt_d = function()
  focusNextRunningWindow({
    APP_BUNDLE_IDS.cursor,
    APP_BUNDLE_IDS.vscode,
  })
end

Actions.global_alt_e = function()
  focusNextRunningWindow({
    APP_BUNDLE_IDS.sap,
    APP_BUNDLE_IDS.eclipse,
  })
end

local function isFrontSap()
  local front = hs.application.frontmostApplication()
  return front and (
    front:bundleID() == APP_BUNDLE_IDS.sap
    or front:name() == "SAPGUI"
  )
end

function Actions.shouldSubmitExistingSapCatalogTcode(profileID)
  if profileID ~= "sap-transaction-catalog" then return false end
  local window = hs.window.frontmostWindow()
  return window and window:title():find("SAP Easy Access", 1, true) ~= nil
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

local function runTcode(tcode, profileID)
  if not isFrontSap() then return end
  if Actions.shouldSubmitExistingSapCatalogTcode(profileID) then
    hs.eventtap.keyStroke({}, "return")
    return
  end

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

local PASTEABLE_EXTENSIONS = {
  abap = true,
  ahk = true,
  md = true,
  txt = true,
}

local function readFinderSelectionPaths()
  local paths = {}
  local seen = {}
  local function collect(element)
    if not element then return end
    local url = element:attributeValue("AXURL")
    local path = type(url) == "table" and url.filePath or nil
    if path and not seen[path] then
      paths[#paths + 1] = path
      seen[path] = true
    end
    for _, child in ipairs(element:attributeValue("AXChildren") or {}) do
      collect(child)
    end
  end
  local ok = pcall(function()
    local finder = hs.application.get(APP_BUNDLE_IDS.finder)
    local app = finder and hs.axuielement.applicationElement(finder)
    local focused = app and app:attributeValue("AXFocusedUIElement")
    for _, selected in ipairs(
      focused and focused:attributeValue("AXSelectedChildren") or {}
    ) do
      collect(selected)
    end
  end)
  if not ok then return {} end
  return paths
end

local function withFinderPaths(sourceBundleID, targetApp, clipboard, callback)
  local readAttempts = 0

  local function readSelection()
    readAttempts = readAttempts + 1
    local paths = readFinderSelectionPaths()
    hs.printf("keyflow: finder selection=%d paths=%d", readAttempts, #paths)
    if #paths > 0 then
      callback(paths, clipboard, targetApp)
    elseif readAttempts < 20 and isFrontApp(APP_BUNDLE_IDS.finder) then
      hs.timer.doAfter(0.1, readSelection)
    else
      restoreClipboard(clipboard)
      if targetApp then targetApp:activate() end
    end
  end

  hs.timer.doAfter(
    sourceBundleID == APP_BUNDLE_IDS.spotlight and 0.3 or 0,
    readSelection
  )
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
    restoreClipboard(clipboard)
    local appPath = hs.application.pathForBundleID(APP_BUNDLE_IDS.iina)
    local cliPath = appPath and appPath .. "/Contents/MacOS/iina-cli"
    if not cliPath then
      hs.printf("keyflow: IINA application not found")
      return
    end
    local args = {"--no-stdin"}
    for _, path in ipairs(paths) do args[#args + 1] = path end
    iinaTask = hs.task.new(cliPath, function(exitCode, _, errorOutput)
      hs.printf(
        "keyflow: IINA CLI finished exit=%d error=%s",
        exitCode,
        (errorOutput or ""):match("^%s*(.-)%s*$")
      )
      iinaTask = nil
    end, args)
    if not iinaTask or not iinaTask:start() then
      iinaTask = nil
      hs.printf("keyflow: IINA CLI did not start")
      return
    end
    hs.printf("keyflow: IINA CLI started paths=%d", #paths)
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

Actions.mouseFwd = function()
  hs.eventtap.keyStroke({"cmd"}, "f1")
end

Actions.global_snipaste_capture = function()
  hs.printf("keyflow: Snipaste Command+F1 received")
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

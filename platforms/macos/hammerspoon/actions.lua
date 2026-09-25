-- Hand-authored actions matched by hotkeys.db id; see
-- platforms/windows/library/automation/sap.ahk for source behavior.

local Clipboard = require("keyflow.clipboard")

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
  terminal = "com.apple.Terminal",
}

-- Mirrors Windows snipasteTargets: after capture, return to the most recent
-- open window of these apps; resize = scale the clipboard image to 80% first
-- (Windows "magick"); paste = also send Cmd+V.
local SNIPASTE_TARGETS = {
  ["com.microsoft.onenote.mac"] = {resize = true},
  ["com.microsoft.Outlook"] = {resize = true},
  ["com.microsoft.teams2"] = {resize = true, paste = true},
  ["com.microsoft.Word"] = {},
  ["md.obsidian"] = {resize = true},
  ["net.whatsapp.WhatsApp"] = {resize = true},
  ["notion.id"] = {resize = true},
  ["org.libreoffice.script"] = {resize = true},
}

-- ImageMagick's clipboard: format is Windows-only, so macOS round-trips a file.
local MAGICK_PATHS = {"/opt/homebrew/bin/magick", "/usr/local/bin/magick"}

-- hs.eventtap.keyStroke blocks for its delay (default 200 ms) between down/up.
local KEYSTROKE_DELAY = 20000

local launcherTargetApp
-- hs.task objects held only by locals can be garbage-collected mid-run.
local runningTasks = {}

local function startTask(path, callback, args)
  local task
  task = hs.task.new(path, function(...)
    runningTasks[task] = nil
    if callback then callback(...) end
  end, args)
  if not task or not task:start() then return nil end
  runningTasks[task] = true
  return task
end

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

local function focusNextRunningWindow(label, bundleIDs)
  local wanted = {}
  for _, bundleID in ipairs(bundleIDs) do wanted[bundleID] = true end

  local windows = {}
  for bundleID in pairs(wanted) do
    for _, app in ipairs(hs.application.applicationsForBundleID(bundleID) or {}) do
      for _, window in ipairs(app:allWindows()) do
        -- SAP GUI (Java) windows may not report a standard subrole; accept
        -- any titled window of document size instead.
        local frame = window:frame()
        if window:isStandard()
            or ((window:title() or "") ~= "" and frame.w >= 200 and frame.h >= 150) then
          windows[#windows + 1] = window
        end
      end
    end
  end
  hs.printf("keyflow: %s windows=%d", label, #windows)
  if #windows == 0 then
    hs.alert.show("Windows not open: " .. label)
    return
  end

  -- Front-to-back order; minimized/other-Space windows sort last.
  local zIndex = {}
  for index, window in ipairs(hs.window.orderedWindows()) do
    zIndex[window:id()] = index
  end
  table.sort(windows, function(left, right)
    return (zIndex[left:id()] or math.huge) < (zIndex[right:id()] or math.huge)
  end)

  -- Outside the group, jump to its most recent window; inside it, raise the
  -- back-most one so repeated presses visit every window.
  local focused = hs.window.focusedWindow()
  local target = windows[1]
  if focused and focused:id() == windows[1]:id() then
    target = windows[#windows]
  end
  if target:isMinimized() then target:unminimize() end
  target:focus()
end

Actions.global_alt_d = function()
  focusNextRunningWindow("IDE", {
    APP_BUNDLE_IDS.cursor,
    APP_BUNDLE_IDS.vscode,
    APP_BUNDLE_IDS.terminal,
  })
end

Actions.global_alt_e = function()
  focusNextRunningWindow("SAP", {
    APP_BUNDLE_IDS.sap,
    APP_BUNDLE_IDS.eclipse,
  })
end

-- Mirrors WindowsService.resizeHeight: keep x/width, span the usable height.
Actions.global_win_esc = function()
  local window = hs.window.focusedWindow()
  if not window or not window:isStandard() or window:isFullScreen() then return end
  local screen = window:screen():frame()
  local frame = window:frame()
  frame.y = screen.y
  frame.h = screen.h
  window:setFrame(frame, 0)
end

function Actions.isFrontSap()
  local front = hs.application.frontmostApplication()
  return front and (
    front:bundleID() == APP_BUNDLE_IDS.sap
    or front:name() == "SAPGUI"
  )
end
local isFrontSap = Actions.isFrontSap

-- The catalog trigger is the tcode itself: in SAP Easy Access, submit what
-- was typed instead of pasting /n<tcode> (same as Windows).
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

local function lastSnipasteTargetWindow()
  for _, window in ipairs(hs.window.orderedWindows()) do
    local app = window:application()
    if app and SNIPASTE_TARGETS[app:bundleID()] then
      return window
    end
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
  Clipboard.paste(text, function()
    local front = hs.application.frontmostApplication()
    hs.printf(
      "keyflow: paste dispatched app=%s bytes=%d",
      front and front:bundleID() or "none",
      #text
    )
    hs.eventtap.keyStroke({"cmd"}, "v", KEYSTROKE_DELAY, targetApp)
  end, savedClipboard)
end

local sapRunToken = 0

function Actions.cancelSapRun()
  sapRunToken = sapRunToken + 1
end

-- Mirrors SapService._normalizeTcode in platforms/windows/library/automation/sap.ahk.
local function normalizeTcode(tcode)
  local normalized = tcode:match("^%s*(.-)%s*$")
  if normalized:sub(1, 1) == "/" then
    return normalized
  end
  -- "=" OK-codes are already complete commands; "/n" would break them.
  if normalized:sub(1, 1) == "=" then
    return normalized:upper()
  end
  return "/n" .. normalized:upper()
end

local function runTcode(tcode)
  if not isFrontSap() then return end
  Actions.cancelSapRun()
  local token = sapRunToken

  hs.eventtap.keyStroke({"cmd", "alt"}, "o", KEYSTROKE_DELAY)
  hs.timer.doAfter(0.2, function()
    if token == sapRunToken and isFrontSap() then
      hs.eventtap.keyStroke({"cmd"}, "a", KEYSTROKE_DELAY)
      hs.timer.doAfter(0.05, function()
        if token == sapRunToken and isFrontSap() then
          pasteText(normalizeTcode(tcode))
          hs.timer.doAfter(0.15, function()
            if token == sapRunToken and isFrontSap() then
              hs.eventtap.keyStroke({}, "return", KEYSTROKE_DELAY)
            end
          end)
        end
      end)
    end
  end)
end

Actions.runSapTcode = runTcode
-- Pure helper exposed for ai/tests.
Actions.normalizeTcode = normalizeTcode

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
      Clipboard.restore(clipboard)
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
      Clipboard.restore(clipboard)
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
  local clipboard = Clipboard.capture()
  if sourceBundleID == APP_BUNDLE_IDS.finder then
    withFinderPaths(sourceBundleID, targetApp, clipboard, callback)
  elseif sourceBundleID == APP_BUNDLE_IDS.spotlight then
    withSpotlightPaths(targetApp, clipboard, callback)
  end
end

local function withRestoredTarget(targetApp, clipboard, callback)
  if not targetApp or not targetApp:activate() then
    Clipboard.restore(clipboard)
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
      Clipboard.restore(clipboard)
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
      Clipboard.restore(clipboard)
      return
    end
    withRestoredTarget(targetApp, clipboard, function()
      pasteText(table.concat(contents), clipboard, targetApp)
    end)
  end)
end

Actions.launcher_alt_p = function()
  withLauncherPaths(function(paths, clipboard)
    Clipboard.restore(clipboard)
    -- `open -b` hands files to the running IINA (honoring its reuse-window
    -- preference); iina-cli always spawns a new player instance.
    local args = {"-b", APP_BUNDLE_IDS.iina}
    for _, path in ipairs(paths) do args[#args + 1] = path end
    local task = startTask("/usr/bin/open", function(exitCode, _, errorOutput)
      hs.printf(
        "keyflow: IINA open finished exit=%d error=%s",
        exitCode,
        (errorOutput or ""):match("^%s*(.-)%s*$")
      )
    end, args)
    if not task then
      hs.printf("keyflow: IINA open did not start")
      return
    end
    hs.printf("keyflow: IINA open started paths=%d", #paths)
  end)
end

local snipasteRunToken = 0

local function magickPath()
  for _, path in ipairs(MAGICK_PATHS) do
    if hs.fs.attributes(path) then return path end
  end
end

-- Calls done() whether or not the resize succeeded, so the return still runs.
local function resizeClipboardImage(token, done)
  local magick = magickPath()
  local image = hs.pasteboard.readImage()
  local dir = (os.getenv("TMPDIR") or "/tmp/"):gsub("/?$", "/")
  local input = dir .. "keyflow-snipaste-in.png"
  local output = dir .. "keyflow-snipaste-out.png"
  if not magick or not image or not image:saveToFile(input) then
    hs.printf("keyflow: Snipaste resize skipped")
    return done()
  end
  local changeCount = hs.pasteboard.changeCount()
  local task = startTask(magick, function(exitCode)
    if token ~= snipasteRunToken then return end
    local resized = exitCode == 0 and hs.image.imageFromPath(output)
    -- Keep whatever the user copied while magick was running.
    if resized and hs.pasteboard.changeCount() == changeCount then
      hs.pasteboard.writeObjects(resized)
      hs.printf("keyflow: Snipaste clipboard resized 80%%")
    else
      hs.printf("keyflow: Snipaste resize failed exit=%s", tostring(exitCode))
    end
    os.remove(input)
    os.remove(output)
    done()
  end, {input, "-resize", "80%", output})
  if not task then
    hs.printf("keyflow: Snipaste resize did not start")
    done()
  end
end

local function completeSnipaste(token)
  local window = lastSnipasteTargetWindow()
  local app = window and window:application()
  hs.printf(
    "keyflow: Snipaste return target=%s",
    app and app:bundleID() or "none"
  )
  if not window then return end
  local target = SNIPASTE_TARGETS[app:bundleID()]
  local function returnToTarget()
    window:focus()
    if target.paste then
      hs.timer.doAfter(0.15, function()
        hs.eventtap.keyStroke({"cmd"}, "v", KEYSTROKE_DELAY, app)
      end)
    end
  end
  if target.resize then
    resizeClipboardImage(token, returnToTarget)
  else
    returnToTarget()
  end
end

Actions.global_snipaste_capture = function()
  hs.printf("keyflow: Snipaste capture requested")
  local appPath = hs.application.pathForBundleID(APP_BUNDLE_IDS.snipaste)
  local executable = appPath and appPath .. "/Contents/MacOS/Snipaste"
  local task = executable and startTask(executable, nil, {"snip"})
  if not task then
    hs.printf("keyflow: Snipaste capture did not start")
  end
end

-- Context (Snipaste focused) is checked by the key watcher before dispatch.
Actions.snipaste_enter = function()
  local initialChangeCount = hs.pasteboard.changeCount()
  snipasteRunToken = snipasteRunToken + 1
  local token = snipasteRunToken
  local attempts = 0

  local function readCapture()
    if token ~= snipasteRunToken then return end
    attempts = attempts + 1
    if hs.pasteboard.changeCount() ~= initialChangeCount then
      if hs.pasteboard.readImage() then
        completeSnipaste(token)
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

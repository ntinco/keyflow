-- Hand-authored actions matched by hotkeys.db id; see
-- platforms/windows/library/automation/sap.ahk for source behavior.

local Actions = {}

local function isFrontApp(appName)
  local front = hs.application.frontmostApplication()
  return front and front:name() == appName
end

Actions.eclipse_backtick = function()
  if not isFrontApp("Eclipse") then return end
  hs.eventtap.keyStroke({"cmd", "shift"}, "a")
  hs.timer.doAfter(0.15, function()
    if isFrontApp("Eclipse") then
      hs.eventtap.keyStrokes("zpm*")
    end
  end)
end

Actions.eclipse_f1 = function()
  if isFrontApp("Eclipse") then
    hs.eventtap.keyStroke({"cmd"}, "o")
  end
end

Actions.eclipse_f2 = function()
  if isFrontApp("Eclipse") then
    hs.eventtap.keyStroke({"alt", "shift"}, "r")
  end
end

local function pasteText(text)
  local savedClipboard = hs.pasteboard.getContents()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v")
  hs.timer.doAfter(0.2, function()
    if savedClipboard then
      hs.pasteboard.setContents(savedClipboard)
    else
      hs.pasteboard.clearContents()
    end
  end)
end

local sapRunToken = 0

function Actions.cancelSapRun()
  sapRunToken = sapRunToken + 1
end

local function scheduleSapStep(token, delaySeconds, action)
  hs.timer.doAfter(delaySeconds, function()
    if token == sapRunToken and isFrontApp("SAPGUI") then
      action()
    end
  end)
end

local function runTcode(tcode)
  if not isFrontApp("SAPGUI") then return end

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

return Actions

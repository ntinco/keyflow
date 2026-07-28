-- Hand-authored actions matched by hotkeys.db id; see
-- platforms/windows/library/automation/sap.ahk for source behavior.

local Actions = {}

Actions.eclipse_backtick = function()
  hs.eventtap.keyStroke({"cmd", "shift"}, "a")
  hs.timer.usleep(150000)
  hs.eventtap.keyStrokes("zpm*")
end

Actions.eclipse_f1 = function()
  hs.eventtap.keyStroke({"cmd"}, "o")
end

Actions.eclipse_f2 = function()
  hs.eventtap.keyStroke({"alt", "shift"}, "r")
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

-- win:focus() is required: app:activate() alone leaves AX focus on the
-- nav tree, so Cmd+Option+O ("Target Command Field") has no effect.
local function runTcode(tcode)
  local app = hs.application.get("SAPGUI")
  if app then
    local win = app:mainWindow()
    if win then win:focus() end
  end
  hs.timer.usleep(100000)
  hs.eventtap.keyStroke({"cmd", "alt"}, "o")
  hs.timer.usleep(300000)
  hs.eventtap.keyStroke({"cmd"}, "a")
  hs.timer.usleep(50000)
  pasteText("/n" .. tcode)
  hs.timer.usleep(250000)
  hs.eventtap.keyStroke({}, "return")
end

Actions.sap_gui_alt_5 = function() runTcode("ed") end
Actions.sap_gui_alt_6 = function() runTcode("se16n") end
Actions.sap_gui_alt_7 = function() runTcode("se37") end
Actions.sap_gui_alt_8 = function() runTcode("se38") end
Actions.sap_gui_alt_9 = function() runTcode("se09") end
Actions.sap_gui_alt_0 = function() runTcode("se80") end

return Actions

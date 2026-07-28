-- Hand-authored actions matched by hotkeys.db id. Not line-by-line AHK
-- ports; see platforms/windows/library/automation/sap.ahk for source behavior.

local Actions = {}

-- Mirrors promptAndOpenAbapObject(): open-object dialog + "zpm*" filter.
Actions.eclipse_backtick = function()
  hs.eventtap.keyStroke({"cmd", "shift"}, "a")
  hs.timer.usleep(150000)
  hs.eventtap.keyStrokes("zpm*")
end

-- Mirrors promptAndSearchAbapObject().
Actions.eclipse_f1 = function()
  hs.eventtap.keyStroke({"cmd"}, "o")
end

-- Eclipse rename-in-file.
Actions.eclipse_f2 = function()
  hs.eventtap.keyStroke({"alt", "shift"}, "r")
end

-- SAP GUI tcode runner. Cmd+Option+O = native "Target Command Field" (SAP
-- GUI for Java Edit menu). Clipboard paste (not char-by-char typing) is
-- required: SAP GUI needs time to move focus after Cmd+Option+O, and a
-- single Cmd+V keystroke is immune to that timing.
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

local function runTcode(tcode)
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

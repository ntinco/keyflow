-- Hand-authored actions matched by hotkeys.db id. Not line-by-line AHK
-- ports; see platforms/windows/library/automation/sap.ahk for the source
-- behavior and ai/current-plan.md for design rationale.

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

-- Mirrors focusEclipseWindows(); no windowGroup equivalent on macOS yet.
Actions.eclipse_ctrl_sh_b = function()
  local app = hs.application.get("org.eclipse.platform") or hs.application.get("Eclipse")
  if app then
    app:activate()
  end
end

return Actions

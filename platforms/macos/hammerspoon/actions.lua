-- Hand-authored Hammerspoon actions, matched by hotkeys.db id.
-- Human source of intent: platforms/windows/data/hotkeys.db
-- These are NOT line-by-line ports of the AHK implementation in
-- platforms/windows/library/automation/sap.ahk — each function reimplements
-- the same user-facing behavior natively for macOS/Hammerspoon.
--
-- Reference (AHK behavior being reproduced):
--   eclipse_backtick  -> services.sap.promptAndOpenAbapObject()
--                        Send("^+a") then paste "zpm*"
--   eclipse_f1        -> services.sap.promptAndSearchAbapObject()
--                        Send("^o")
--   eclipse_f2        -> Send("!+r")  (Eclipse rename-in-file shortcut)
--   eclipse_ctrl_sh_b -> services.sap.focusEclipseWindows()
--                        activates the Eclipse window group

local Actions = {}

-- Eclipse ADT: prompt for an ABAP object name and open it.
-- AHK sends Ctrl+Shift+A (Eclipse "Open ABAP Development Object" dialog)
-- then pastes a default filter "zpm*". macOS Eclipse uses Cmd instead of
-- Ctrl for most bindings, but ADT-specific shortcuts are typically left at
-- their SWT/cross-platform defaults (Ctrl+Shift+A). Verify on this machine.
Actions.eclipse_backtick = function()
  hs.eventtap.keyStroke({"cmd", "shift"}, "a")
  hs.timer.usleep(150000) -- 150ms, mirrors sapDelayPollMs default
  hs.eventtap.keyStrokes("zpm*")
end

-- Eclipse ADT: open the "Open ABAP Object" search dialog (Ctrl+O in AHK).
Actions.eclipse_f1 = function()
  hs.eventtap.keyStroke({"cmd"}, "o")
end

-- Eclipse: rename-in-file (Alt+Shift+R in Eclipse's default keymap,
-- reproduced here rather than the raw AHK Alt+Shift+R passthrough).
Actions.eclipse_f2 = function()
  hs.eventtap.keyStroke({"alt", "shift"}, "r")
end

-- Focus/cycle Eclipse windows. AHK delegates to WindowGroupService, which
-- has no direct Hammerspoon equivalent yet (tracked as a Windows-specific
-- concept in ai/current-plan.md). For this slice, approximate by activating
-- the Eclipse application directly.
Actions.eclipse_ctrl_sh_b = function()
  local app = hs.application.get("org.eclipse.platform") or hs.application.get("Eclipse")
  if app then
    app:activate()
  end
end

return Actions

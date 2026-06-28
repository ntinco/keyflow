; SAP GUI: solo disparadores hacia services.sap.*; la logica vive en library/automation/sap.ahk.
#hotif winactive("Logon for Project")
f1::{
trackSapGuiHotkeyUsage("f1", "sap-gui-project-session")
services.sap.reopenSessionFromProjectWindow()
}
#hotif winactive("YMT")
#hotif services.sap.isTextInputActive("ahk_group group_sap_runtime_windows")
$enter::{
trackSapGuiHotkeyUsage("$enter", "sap-gui-ymt-input")
services.sap.runTcodeFromFocusedInput()
}
#hotif winactive("ahk_group group_sap_runtime_windows")
!left::{
trackSapGuiHotkeyUsage("!left", "sap-gui-session")
Send("+{f6}")
}
!right::{
trackSapGuiHotkeyUsage("!right", "sap-gui-session")
Send("+{f7}")
}
!up::{
trackSapGuiHotkeyUsage("!up", "sap-gui-session")
Send("^!{up}")
}
!down::{
trackSapGuiHotkeyUsage("!down", "sap-gui-session")
Send("^!{down}")
}
!+down::{
trackSapGuiHotkeyUsage("!+down", "sap-gui-session")
Send("^d")
}
^g::{
trackSapGuiHotkeyUsage("^g", "sap-gui-session")
Send("^o")
}
^+w::{
trackSapGuiHotkeyUsage("^+w", "sap-gui-session")
services.sap.exitSession()
}
^+k::{
trackSapGuiHotkeyUsage("^+k", "sap-gui-session")
Send("^+l")
}
; ^`::{
; trackSapGuiHotkeyUsage("ctrl+backtick", "sap-gui-session")
; Send("^w")
; }
^d::{
trackSapGuiHotkeyUsage("^d", "sap-gui-session")
services.sap.toggleDebugMode()
}
^b::{
trackSapGuiHotkeyUsage("^b", "sap-gui-session")
services.sap.focusGuiWindows()
}
!5::{
trackSapGuiHotkeyUsage("!5", "sap-gui-session")
services.sap.openWorkbenchOptions()
}
!6::{
trackSapGuiHotkeyUsage("!6", "sap-gui-session")
services.sap.openSe16n()
}
!7::{
trackSapGuiHotkeyUsage("!7", "sap-gui-session")
services.sap.openSe37()
}
!8::{
trackSapGuiHotkeyUsage("!8", "sap-gui-session")
services.sap.openSe38()
}
!9::{
trackSapGuiHotkeyUsage("!9", "sap-gui-session")
services.sap.openSe09()
}
!0::{
trackSapGuiHotkeyUsage("!0", "sap-gui-session")
services.sap.openSe80()
}

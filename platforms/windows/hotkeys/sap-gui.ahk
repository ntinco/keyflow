; SAP GUI: solo disparadores â†’ services.saplogon.* (logica y tcodes en library/automation/saplogon.ahk).
#hotif winactive("Logon for Project")
f1::{
trackSapHotkeyUsage("f1", "sap-gui-logon")
services.saplogon.reloginSapFromLogonProjectWindow()
}
#hotif winactive("YMT")
#hotif services.saplogon.isInputBoxActive("ahk_group group_sap_gui_sessions")
$enter::{
trackSapHotkeyUsage("$enter", "sap-gui-ymt-input")
services.saplogon.openSapTcodeFromGuiCommandField()
}
#hotif winactive("ahk_group group_sap_gui_sessions")
!left::{
trackSapHotkeyUsage("!left", "sap-gui-session")
Send("+{f6}")
}
!right::{
trackSapHotkeyUsage("!right", "sap-gui-session")
Send("+{f7}")
}
!up::{
trackSapHotkeyUsage("!up", "sap-gui-session")
Send("^!{up}")
}
!down::{
trackSapHotkeyUsage("!down", "sap-gui-session")
Send("^!{down}")
}
!+down::{
trackSapHotkeyUsage("!+down", "sap-gui-session")
Send("^d")
}
^g::{
trackSapHotkeyUsage("^g", "sap-gui-session")
Send("^o")
}
^+w::{
trackSapHotkeyUsage("^+w", "sap-gui-session")
services.saplogon.exitSapGuiWithNex()
}
^+k::{
trackSapHotkeyUsage("^+k", "sap-gui-session")
Send("^+l")
}
; ^`::{
; trackSapHotkeyUsage("ctrl+backtick", "sap-gui-session")
; Send("^w")
; }
^d::{
trackSapHotkeyUsage("^d", "sap-gui-session")
services.saplogon.toggleSapDebugMode()
}
^b::{
trackSapHotkeyUsage("^b", "sap-gui-session")
services.saplogon.activateSapGuiAllCodeArtifacts()
}
!5::{
trackSapHotkeyUsage("!5", "sap-gui-session")
services.saplogon.openSapGuiTcodeEdWorkbenchOptions()
}
!6::{
trackSapHotkeyUsage("!6", "sap-gui-session")
services.saplogon.openSapGuiTcodeSe16n()
}
!7::{
trackSapHotkeyUsage("!7", "sap-gui-session")
services.saplogon.openSapGuiTcodeSe37()
}
!8::{
trackSapHotkeyUsage("!8", "sap-gui-session")
services.saplogon.openSapGuiTcodeSe38()
}
!9::{
trackSapHotkeyUsage("!9", "sap-gui-session")
services.saplogon.openSapGuiTcodeSe09()
}
!0::{
trackSapHotkeyUsage("!0", "sap-gui-session")
services.saplogon.openSapGuiTcodeSe80()
}


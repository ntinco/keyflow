; SAP ADT/Eclipse: cableado a services.saplogon.*; implementacion en library/automation/saplogon.ahk.
#hotif winactive(exeECLIPSE)
!pgdn::{
trackSapHotkeyUsage("!pgdn", "sap-eclipse")
Send("^pgdn")
}
!pgup::{
trackSapHotkeyUsage("!pgup", "sap-eclipse")
Send("^pgup")
}
!+down::{
trackSapHotkeyUsage("!+down", "sap-eclipse")
Send("^!down")
}
^g::{
trackSapHotkeyUsage("^g", "sap-eclipse")
Send("^1")
}
`::{
trackSapHotkeyUsage("backtick", "sap-eclipse")
services.saplogon.runEclipseAbapObjectPickerFromHotkey()
}
; ^`::{
; trackSapHotkeyUsage("ctrl+backtick", "sap-eclipse")
; Send("^w")
; }
^/::{
trackSapHotkeyUsage("^/", "sap-eclipse")
Send("^7")
}
^+k::{
trackSapHotkeyUsage("^+k", "sap-eclipse")
Send("^d")
}
f1::{
trackSapHotkeyUsage("f1", "sap-eclipse")
services.saplogon.runEclipseWildcardSearchFromHotkey()
}
!f1::{
trackSapHotkeyUsage("!f1", "sap-eclipse")
Send("^+a")
}
f2::{
trackSapHotkeyUsage("f2", "sap-eclipse")
Send("!+r")
}
+f2::{
trackSapHotkeyUsage("+f2", "sap-eclipse")
Send("{f2}")
}
!f2::{
trackSapHotkeyUsage("!f2", "sap-eclipse")
Send("!{f2}")
}
^+f2::{
trackSapHotkeyUsage("^+f2", "sap-eclipse")
Send("^+{f2}")
}
^n::{
trackSapHotkeyUsage("^n", "sap-eclipse")
Send("!{f8}")
}
^+b::{
trackSapHotkeyUsage("^+b", "sap-eclipse")
services.saplogon.activateEclipseAllCodeArtifacts()
}
^5::{
trackSapHotkeyUsage("^5", "sap-eclipse")
services.saplogon.runEclipseQuickDebugFromHotkey()
}
!j::{
trackSapHotkeyUsage("!j", "sap-eclipse")
Send("{down}")
}
!k::{
trackSapHotkeyUsage("!k", "sap-eclipse")
Send("{up}")
}
!i::{
trackSapHotkeyUsage("!i", "sap-eclipse")
Send("^!i")
}
#hotif winactive("- DATABASE TABLE")
!up::{
trackSapHotkeyUsage("!up", "sap-eclipse-database-table")
Send("!{up}")
}
!down::{
trackSapHotkeyUsage("!down", "sap-eclipse-database-table")
Send("!{down}")
}


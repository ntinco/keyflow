#Requires AutoHotkey v2.0
#SingleInstance Force

; Minimal runtime for tools/sap-gui — intentionally does NOT use bootstrap.ahk.
; bootstrap.ahk initialises the full service registry and hotstring profiles.
; This tool only needs the launcher and SAP services.
; If a new service is added to bootstrap.ahk it does NOT need to be mirrored here
; unless this tool explicitly requires it.
SetTitleMatchMode(2)
SetWinDelay(-1)
FileEncoding("UTF-8")
DetectHiddenText(1)
SetWorkingDir(A_ScriptDir "\..\..")

#Include "..\..\library\json-service.ahk"
#Include "..\..\library\util.ahk"
#Include "..\..\library\config\constants-core.ahk"

#Include "..\..\library\automation\launcher.ahk"
#Include "..\..\library\automation\sap.ahk"

loadCoreConstants()
global services := sapGuiInitServices()

sapGuiInitServices() {
  return {
    launcher: LauncherService(),
    sap: SapService(),
  }
}

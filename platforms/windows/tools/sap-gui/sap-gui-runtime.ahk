#Requires AutoHotkey v2.0
#SingleInstance Force

; Minimal runtime for tools/sap-gui: avoids loading main script hotkeys and startup.
SetTitleMatchMode(2)
SetWinDelay(-1)
FileEncoding("UTF-8")
DetectHiddenText(1)
SetWorkingDir(A_ScriptDir "\..\..")

#Include "..\..\library\json-service.ahk"
#Include "..\..\library\util.ahk"
#Include "..\..\library\ui\dark-theme.ahk"
#Include "..\..\library\ui\window-border-overlay.ahk"

#Include "..\..\library\config\constants-core-base.ahk"
#Include "..\..\library\config\constants-core-paths.ahk"
#Include "..\..\library\config\constants-core-apps.ahk"
#Include "..\..\library\config\constants-core-rules.ahk"
#Include "..\..\library\config\constants-core.ahk"
#Include "..\..\library\config\constants-secrets.ahk"

#Include "..\..\library\automation\dynamic.ahk"
#Include "..\..\library\automation\launcher.ahk"
#Include "..\..\library\automation\memory.ahk"
#Include "..\..\library\automation\run.ahk"
#Include "..\..\library\automation\saplogon.ahk"

global utils := AppUtils()
loadCoreConstants()
loadSecretConstants()
global services := sapguiInitServices()

sapguiInitServices() {
  return {
    dynamic: DynamicService(),
    launcher: LauncherService(),
    memory: MemoryService(),
    run: RunService(),
    saplogon: SapLogonService(),
  }
}


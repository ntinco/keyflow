#Requires AutoHotkey v2.0
FileEncoding("UTF-8")
#Include library\bootstrap.ahk
global services := keyflowInitServices()
;global windowBorderOverlay := new WindowBorderOverlay(activeWindowIdProvider, uiBorderThickness, uiBorderColor)
;SetTimer(windowBorderOverlay, 100)
#Include hotkeys\global.ahk
#Include hotkeys\sap.ahk
#Include hotkeys\editors.ahk
#Include hotkeys\domains.ahk

activeWindowIdProvider(*) {
  return WinExist("A")
}

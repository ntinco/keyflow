; Orden importante: sap-gui debe cargarse antes que sap-eclipse para mantener precedencia esperada de #HotIf (ej. Logon for Project).
#Include "sap-gui.ahk"
#Include "sap-eclipse.ahk"

trackSapHotkeyUsage(hotkeyId, sourceGroup := "sap", sourceFile := "hotkeys/sap.ahk") {
  trackHotkeyUsageScoped(hotkeyId, sourceFile, sourceGroup)
}

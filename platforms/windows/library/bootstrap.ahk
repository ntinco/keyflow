#Requires AutoHotkey v2.0
; Load application constants before any service class runs.
#Include config\constants-core.ahk

loadCoreConstants()

#Include json-service.ahk
#Include util.ahk

#Include automation\launcher.ahk
#Include automation\hotstring.ahk
#Include automation\windows.ahk
#Include automation\window-group.ahk
#Include automation\sap.ahk
#Include automation\snipaste.ahk

keyflowServiceRegistry() {
  return {
    sap: SapService(),
    windows: WindowsService(),
    windowGroup: WindowGroupService(),
    launcher: LauncherService(),
    snipaste: SnipasteService(),
    hotstring: HotstringService(),
  }
}

keyflowHotstringProfiles() {
  return [
    {label: "autocorrect", group: "", mode: "replace"},
    {label: "quick-snippets", group: "", mode: "replace"},
    {label: "sap-transaction-shortcuts", group: "group_sap_runtime_windows", mode: "sap-command"},
    {label: "sap-transaction-catalog", group: "group_sap_runtime_windows", mode: "sap-command"},
    {label: "ymt-commands", group: "group_sap_runtime_windows", mode: "sap-command"},
  ]
}

keyflowInitServices() {
  services := keyflowServiceRegistry()
  for hotstringProfile in keyflowHotstringProfiles()
    services.hotstring.set(hotstringProfile)
  return services
}

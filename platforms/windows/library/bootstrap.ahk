#Requires AutoHotkey v2.0
; Load application constants before any service class runs.
#Include config\constants-core.ahk
#Include config\constants-secrets.ahk

loadCoreConstants()
loadSecretConstants()

#Include json-service.ahk
#Include util.ahk

#Include automation\memory.ahk
#Include automation\hotkey-tracker.ahk
#Include automation\run.ahk
#Include automation\everything.ahk
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
    run: RunService(),
    memory: MemoryService(),
    launcher: LauncherService(),
    snipaste: SnipasteService(),
    hotstring: HotstringService(),
    hotkeyTracker: HotkeyTrackerService(),
    everything: EverythingService(),
  }
}

keyflowHotstringProfiles() {
  return [
    {label: "autocorrect", group: "", mode: "autocorrect"},
    {label: "quick-snippets", group: "", mode: "autocorrect"},
    {label: "sap-transaction-shortcuts", group: "group_sap_runtime_windows", mode: "sapTransaction"},
    {label: "sap-transaction-catalog", group: "group_sap_runtime_windows", mode: "sapTransaction"},
    {label: "ymt-commands", group: "group_sap_runtime_windows", mode: "ymtCommand"},
  ]
}

keyflowInitServices() {
  services := keyflowServiceRegistry()
  for hotstringProfile in keyflowHotstringProfiles()
    services.hotstring.set(hotstringProfile)
  return services
}

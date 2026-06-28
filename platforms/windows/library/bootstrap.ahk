#Requires AutoHotkey v2.0
; Load application constants and `utils` before any service class runs (see health_check_custom/repo_config.py snippets).
#Include config\constants-core-base.ahk
#Include config\constants-core-paths.ahk
#Include config\constants-core-apps.ahk
#Include config\constants-core-rules.ahk
#Include config\constants-core.ahk
#Include config\constants-secrets.ahk

loadProductionConstants()
loadSecretConstants()

#Include json-service.ahk
#Include util.ahk
global utils := AppUtils()

#Include automation\memory.ahk
#Include automation\hotkey-tracker.ahk
#Include automation\run.ahk
#Include automation\everything.ahk
#Include automation\launcher.ahk
#Include automation\hotstring.ahk
#Include automation\dynamic.ahk
#Include automation\windows.ahk
#Include automation\window-group.ahk
#Include automation\sap.ahk
#Include automation\video.ahk
#Include automation\snipaste.ahk
#Include automation\whatsapp.ahk

keyflowServiceRegistry() {
  return {
    dynamic: DynamicService(),
    sap: SapService(),
    windows: WindowsService(),
    windowGroup: WindowGroupService(),
    video: VideoService(),
    run: RunService(),
    memory: MemoryService(),
    launcher: LauncherService(),
    snipaste: SnipasteService(),
    whatsapp: WhatsappService(),
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
    {label: "abap-snippets", group: "group_sap_runtime_windows", mode: "autocorrect"},
    {label: "ymt-commands", group: "group_sap_runtime_windows", mode: "ymtCommand"},
  ]
}

keyflowInitServices() {
  services := keyflowServiceRegistry()
  for hotstringProfile in keyflowHotstringProfiles()
    services.hotstring.set(hotstringProfile)
  return services
}

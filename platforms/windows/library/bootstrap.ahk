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
#Include automation\hotkey-usage.ahk
#Include automation\run.ahk
#Include automation\everything.ahk
#Include automation\launcher.ahk
#Include automation\paste.ahk
#Include automation\hotstring.ahk
#Include automation\dynamic.ahk
#Include automation\windows.ahk
#Include automation\windows-group.ahk
#Include ui\dark-theme.ahk
#Include automation\saplogon.ahk
#Include automation\video.ahk
#Include automation\snipaste.ahk
#Include automation\whatsapp.ahk

normanServiceRegistry() {
  return {
    dynamic: DynamicService(),
    saplogon: SapLogonService(),
    windows: WindowsService(),
    windowsGroup: WindowsGroupService(),
    video: VideoService(),
    run: RunService(),
    memory: MemoryService(),
    launcher: LauncherService(),
    snipaste: SnipasteService(),
    whatsapp: WhatsappService(),
    hotstring: HotstringService(),
    hotkeyUsage: HotkeyUsageService(),
    everything: EverythingService(),
  }
}

normanHotstringProfiles() {
  return [
    {label: "autocorrect", group: "", mode: "autocorrect"},
    {label: "quick-snippets", group: "", mode: "autocorrect"},
    {label: "sap-transaction-shortcuts", group: "group_sap_gui_sessions", mode: "sapTransaction"},
    {label: "ymt-commands", group: "group_sap_gui_sessions", mode: "ymtCommand"},
  ]
}

normanInitServices() {
  services := normanServiceRegistry()
  for hotstringProfile in normanHotstringProfiles()
    services.hotstring.set(hotstringProfile)
  return services
}

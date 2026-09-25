loadCoreConstants() {
  loadCoreBaseConstants()
  loadCorePathConstants()
  loadCoreApplicationConstants()
  loadCoreRuleConstants()
}

loadCoreBaseConstants() {
  global
  constDayEs := FormatTime(, "dd.MM.yy")
  sapDelayMs := 100
}

loadCorePathConstants() {
  global
  ; library\config -> platforms\windows -> platforms
  SplitPath(A_LineFile, , &pathWindows)
  SplitPath(pathWindows, , &pathWindows)
  SplitPath(pathWindows, , &pathWindows)
  SplitPath(pathWindows, , &pathPlatforms)
  dataDir := pathWindows "\data\"
  memoryVarsIniFile := pathPlatforms "\shared\data\memory-vars.ini"
  localPathsFile := pathPlatforms "\shared\data\local-paths.ini"
  fileEverythingCli := IniRead(localPathsFile, "paths", "fileEverythingCli", pathWindows "\tools\exe\everything\es.exe")
}

loadCoreApplicationConstants() {
  global
  exeCursor := "ahk_exe Cursor.exe"
  exeEclipse := "ahk_exe eclipse.exe"
  exeNotion := "ahk_exe Notion.exe"
  exeNwbc := "ahk_exe NWBC.exe"
  exeObsidian := "ahk_exe Obsidian.exe"
  exeOutlookNew := "ahk_exe olk.exe"
  exeOnenote := "ahk_exe ONENOTE.EXE"
  exeOutlook := "ahk_exe OUTLOOK.EXE"
  exeLibreOfficeBinary := "ahk_exe soffice.bin"
  exeWinword := "ahk_exe WINWORD.EXE"
  exeWordpad := "ahk_exe wordpad.exe"
  ; Window class matches both Everything64.exe and Everything.exe builds.
  exeEverything := "ahk_class EVERYTHING"
  exeFlowlauncher := "ahk_exe Flow.Launcher.exe"
  exeMsTeams := "ahk_exe ms-teams.exe"
  exeVscode := "ahk_exe Code.exe"
  classSapGuiSession := "ahk_class SAP_FRONTEND_SESSION"
  titleSnipaste := "Snipper - Snipaste"
  titleWhatsapp := "WhatsApp"
  titleWrite := "LibreOffice Writer"
}

loadCoreRuleConstants() {
  global
  snipasteTargets := []
  snipasteTargets.Push(["magick", exeOnenote])
  snipasteTargets.Push(["magick_paste", exeMsTeams])
  snipasteTargets.Push(["magick", titleWhatsapp])
  snipasteTargets.Push(["magick", titleWrite])
  snipasteTargets.Push(["magick", exeLibreOfficeBinary])
  snipasteTargets.Push(["magick", exeOutlookNew])
  snipasteTargets.Push(["magick", exeOutlook])
  snipasteTargets.Push(["magick", exeObsidian])
  snipasteTargets.Push(["magick", exeNotion])
  snipasteTargets.Push(["", exeWinword])
  snipasteTargets.Push(["", exeWordpad])

  appActivationTargets := []
  appActivationTargets.Push(["apps_ide", exeVscode])
  appActivationTargets.Push(["apps_ide", exeCursor])
  appActivationTargets.Push(["apps_sap_workspace", classSapGuiSession])
  appActivationTargets.Push(["apps_sap_workspace", exeNwbc])
  appActivationTargets.Push(["apps_sap_workspace", exeEclipse])

  GroupAdd("group_launcher", exeEverything)
  GroupAdd("group_launcher", exeFlowlauncher)
  GroupAdd("group_sap_gui_windows", classSapGuiSession)
  GroupAdd("group_sap_gui_windows", exeNwbc)
  GroupAdd("group_sap_runtime_windows", classSapGuiSession)
  GroupAdd("group_sap_runtime_windows", exeNwbc)
}

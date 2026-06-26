loadCorePathConstants() {
  global
  pathAppData := StrReplace(A_AppData, "Roaming")
  pathUser := StrReplace(pathAppData, "AppData\")
  pathOneDrive := EnvGet("onedrive")
  SplitPath(A_LineFile, , &pathScript)
  SplitPath(pathScript, , &pathScript)
  SplitPath(pathScript, , &pathScript)
  SplitPath(pathScript, , &pathScriptOnelevelup)
  dataDir := normanResolveDataDir(pathScript)
  dataConstantsDir := dataDir
  pathScriptSync := pathScriptOnelevelup "\install_sync\"
  romConfigFile := dataDir "rom.ini"
  memoryVarsIniFile := dataDir "memory-vars.ini"
  hotkeyUsageJsonFile := dataDir "hotkey-usage.json"
  sapQasSnippetsJsonFile := dataDir "qas-snippets.json"
  constAbapExtProg := ".prog.abap"
  constAbapExtClas := ".clas.abap"
  constAbapExt := ".abap"
  localPathsFile := normanLocalPathsFile(pathScript)
  pathAbapGitRepo := normanPathConfigValue(localPathsFile, "pathAbapGitRepo", EnvGet("NORMAN_PATH_ABAP_GIT_REPO"), "H:\.sync\norman_src\abap\abapgit\")
  pathYmWorkspace := normanPathConfigValue(localPathsFile, "pathYmWorkspace", EnvGet("NORMAN_PATH_YM_WORKSPACE"), "H:\.sync\norman_src\abap\abap-gestor\ym\")
  pathAbapInbox := normanPathConfigValue(localPathsFile, "pathAbapInbox", EnvGet("NORMAN_PATH_ABAP_INBOX"), "H:\.sync\norman_src\abap\abap-inbox\")
  fileEverythingCli := normanPathConfigValue(localPathsFile, "fileEverythingCli", EnvGet("NORMAN_FILE_EVERYTHING_CLI"), pathScriptOnelevelup "\exe\everything\es.exe")
  fileFortissl := normanPathConfigValue(localPathsFile, "fileFortissl", EnvGet("NORMAN_FILE_FORTISSL"), pathScriptOnelevelup "\exe\forticlient\fortisslvpnclient.exe")
  fileFortiClientGui := normanPathConfigValue(localPathsFile, "fileFortiClientGui", EnvGet("NORMAN_FILE_FORTICLIENT_GUI"), "C:\Program Files\Fortinet\FortiClient\FortiClient.exe")
  filePulseGui := normanPathConfigValue(localPathsFile, "filePulseGui", EnvGet("NORMAN_FILE_PULSE_GUI"), "C:\Program Files (x86)\Common Files\Pulse Secure\JamUI\Pulse.exe")
  fileNetExtenderGui := normanPathConfigValue(localPathsFile, "fileNetExtenderGui", EnvGet("NORMAN_FILE_NETEXTENDER_GUI"), "C:\Program Files (x86)\SonicWall\SSL-VPN\NetExtender\NEGui.exe")
}

normanLocalPathsFile(pathScript) {
  return pathScript "\data\local-paths.ini"
}

normanPathConfigValue(localPathsFile, key, envValue, defaultValue := "") {
  if envValue
    return envValue
  return IniRead(localPathsFile, "paths", key, defaultValue)
}


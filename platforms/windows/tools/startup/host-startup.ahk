scriptDir := RegExReplace(A_LineFile, "\\[^\\]+$")
rootDir := scriptDir "\..\.."
localStartupFile := rootDir "\data\local-startup.ini"
downloadsPath := startupConfigValue(localStartupFile, "downloadsPath", EnvGet("NORMAN_STARTUP_DOWNLOADS_PATH"), EnvGet("USERPROFILE") "\Downloads")
baseDrive := startupConfigValue(localStartupFile, "baseDrive", EnvGet("NORMAN_STARTUP_BASE_DRIVE"), "h:")
syncBatchFile := startupConfigValue(localStartupFile, "syncBatchFile", EnvGet("NORMAN_STARTUP_SYNC_BATCH_FILE"), baseDrive "\.sync\norman_src\install_sync\.sync.ffs_batch")
flowLauncherLogsDir := startupConfigValue(localStartupFile, "flowLauncherLogsDir", EnvGet("NORMAN_STARTUP_FLOWLAUNCHER_LOGS_DIR"), baseDrive "\.sync\..apps\PortableApps_updauto\FlowLauncher\app-2.0.3\UserData\Logs")
aimpPortableLink := startupConfigValue(localStartupFile, "aimpPortableLink", EnvGet("NORMAN_STARTUP_AIMP_PORTABLE_LINK"), "\.sync\links\AimpPortable.exe.lnk")
portableLinksCsv := startupConfigValue(
  localStartupFile,
  "portableLinksCsv",
  EnvGet("NORMAN_STARTUP_PORTABLE_LINKS_CSV"),
  "\.sync\links\everything.exe.lnk;\.sync\links\flow.Launcher.exe.lnk;\.sync\links\keePassXCPortable.exe.lnk;\.sync\links\rbtray.exe.lnk;\.sync\links\ShareX.exe.lnk;\.sync\links\Snipaste.exe.lnk;\.sync\links\stretchly.exe.lnk;\.sync\links\workrave.exe.lnk;\.sync\links\tbaction.exe.lnk;\.sync\links\handy.exe.lnk;\.sync\links\cherry-studio.exe.lnk"
)

run(A_ComSpec ' /k subst ' baseDrive ' "' downloadsPath '"', , "hide")
;run(A_ComSpec ' /k subst l: "' downloadsPath '\..local\..disk_l_www"', , "hide")
run(A_ComSpec ' /k subst i: "' downloadsPath '\.sync\GitHub"', , "hide")
sleep 5000

run rootDir "\keyflow.ahk"

if (A_Wday = 6) {
  folderDelete baseDrive "\.sync\..apps\PortableApps\LibreOfficePortable\Data\settings\cache"
  folderDelete baseDrive "\.sync\..apps\PortableApps\LibreOfficePortable\Data\settings\crash"
  folderDelete baseDrive "\.sync\..apps\PortableApps\LibreOfficePortable\Data\settings\temp"
  folderDelete baseDrive "\.sync\..apps\PortableApps\LibreOfficePortable\Data\settings\updates"
  folderDelete baseDrive "\.sync\..apps\PortableApps\Notepad++Portable\Data\Config\backup"
  folderDelete baseDrive "\.sync\..apps\PortableApps_updauto\Snipaste\history"
  folderDelete flowLauncherLogsDir
  folderDelete baseDrive "\.sync\..apps\PortableApps_updmanual\ShareX\ShareX\Backup"
  folderDelete baseDrive "\.sync\..apps\PortableApps_updmanual\ShareX\ShareX\Logs"
  folderDelete baseDrive "\.sync\..apps\PortableApps_updmanual\xyplorer_full_noinstall\Data\AutoBackup"
  filedelete baseDrive "\.sync\..apps\PortableApps_updauto\Snipaste\splog.txt"

  runwait syncBatchFile
}

portableLinks := startupConfigCsvArray(portableLinksCsv)
runPortable baseDrive aimpPortableLink
runPortable baseDrive "\.sync\links\DittoPortable.exe.lnk"
for linkSuffix in portableLinks
  run baseDrive linkSuffix

runPortable(linkPath) {
  run(linkPath)
  if WinWait("(PortableApps.com Launcher)", , 5)
  {
    WinActivate("(PortableApps.com Launcher)")
    sleep 100
    send "{enter}"
    sleep 100
    run(linkPath)
  }
}
folderDelete(folderPath) {
  if (DirExist(folderPath)) {
    dirdelete folderPath, true
  }
}

startupConfigValue(configFile, key, envValue, defaultValue := "") {
  if envValue
    return envValue
  value := IniRead(configFile, "startup", key, defaultValue)
  if (Trim(value) = "")
    return defaultValue
  return value
}

startupConfigCsvArray(csvText) {
  output := []
  for part in StrSplit(csvText, ";")
  {
    value := Trim(part)
    if value
      output.Push(value)
  }
  return output
}


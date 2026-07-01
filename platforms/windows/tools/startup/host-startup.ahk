scriptDir := RegExReplace(A_LineFile, "\\[^\\]+$")
rootDir := scriptDir "\..\.."
localStartupFile := rootDir "\data\local-startup.ini"

downloadsPath := readStartupValue(localStartupFile, "startup-host", "downloadsPath", EnvGet("USERPROFILE") "\Downloads")
baseDrive := readStartupValue(localStartupFile, "startup-host", "baseDrive", "h:")
workspaceDrive := readStartupValue(localStartupFile, "startup-host", "workspaceDrive", "i:")
workspacePath := readStartupValue(localStartupFile, "startup-host", "workspacePath", downloadsPath "\.sync\GitHub")
aimpPortableLink := readStartupValue(localStartupFile, "startup-host", "aimpPortableLink", baseDrive "\.sync\links\AimpPortable.exe.lnk")
dittoPortableLink := readStartupValue(localStartupFile, "startup-host", "dittoPortableLink", baseDrive "\.sync\links\DittoPortable.exe.lnk")
portableLinksCsv := readStartupValue(localStartupFile, "startup-host", "portableLinksCsv", "\.sync\links\everything.exe.lnk;\.sync\links\flow.Launcher.exe.lnk;\.sync\links\keePassXCPortable.exe.lnk;\.sync\links\rbtray.exe.lnk;\.sync\links\ShareX.exe.lnk;\.sync\links\Snipaste.exe.lnk;\.sync\links\stretchly.exe.lnk;\.sync\links\workrave.exe.lnk;\.sync\links\tbaction.exe.lnk;\.sync\links\handy.exe.lnk;\.sync\links\cherry-studio.exe.lnk")
launchDelayMs := readStartupNumber(localStartupFile, "startup-host", "launchDelayMs", 5000)

run(A_ComSpec ' /k subst ' baseDrive ' "' downloadsPath '"', , "hide")
run(A_ComSpec ' /k subst ' workspaceDrive ' "' workspacePath '"', , "hide")
Sleep(launchDelayMs)

Run(rootDir "\keyflow.ahk")

runPortableLink(aimpPortableLink)
runPortableLink(dittoPortableLink)
for linkPath in startupConfigCsvArray(portableLinksCsv)
  runPortableLink(linkPath)

runPortableLink(linkPath) {
  if !linkPath
    return
  if !FileExist(linkPath)
    return

  Run(linkPath)
  if WinWait("(PortableApps.com Launcher)", , 5)
  {
    WinActivate("(PortableApps.com Launcher)")
    Sleep(100)
    Send("{enter}")
    Sleep(100)
    Run(linkPath)
  }
}

readStartupValue(configFile, sectionName, keyName, defaultValue := "") {
  value := IniRead(configFile, sectionName, keyName, defaultValue)
  if (Trim(value) = "")
    return defaultValue
  return value
}

readStartupNumber(configFile, sectionName, keyName, defaultValue) {
  value := readStartupValue(configFile, sectionName, keyName, defaultValue)
  return IsNumber(value) ? value + 0 : defaultValue
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

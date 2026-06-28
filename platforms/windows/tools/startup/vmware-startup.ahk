scriptDir := RegExReplace(A_LineFile, "\\[^\\]+$")
rootDir := scriptDir "\..\.."
localStartupFile := rootDir "\data\local-startup.ini"

downloadsPath := readStartupValue(localStartupFile, "startup-vmware", "downloadsPath", "\\vmware-host\Shared Folders\Downloads")
baseDrive := readStartupValue(localStartupFile, "startup-vmware", "baseDrive", "h:")
launchDelayMs := readStartupNumber(localStartupFile, "startup-vmware", "launchDelayMs", 1000)

substCommand := '""' '"subst ' baseDrive ' "' downloadsPath '""'
Run(A_ComSpec " /k " substCommand, , "hide")
Sleep(launchDelayMs)

Run(rootDir "\keyflow.ahk")

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

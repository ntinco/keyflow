scriptDir := RegExReplace(A_LineFile, "\\[^\\]+$")
rootDir := scriptDir "\..\.."
localStartupFile := rootDir "\data\local-startup.ini"
downloadsPath := startupConfigValue(localStartupFile, "vmwareDownloadsPath", EnvGet("NORMAN_VMWARE_DOWNLOADS_PATH"), "\\vmware-host\Shared Folders\Downloads")

substCommand := '""' '"subst h: "' downloadsPath '""'
run(A_ComSpec " /k " substCommand , , "hide")

run rootDir "\keyflow.ahk"

startupConfigValue(configFile, key, envValue, defaultValue := "") {
  if envValue
    return envValue
  value := IniRead(configFile, "startup", key, defaultValue)
  if (Trim(value) = "")
    return defaultValue
  return value
}


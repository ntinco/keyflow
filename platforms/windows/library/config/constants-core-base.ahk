loadCoreBaseConstants() {
  global
  constDayEs := FormatTime(, "dd.MM.yy")
  tab := "{tab}"
  enter := "{enter}"
  runtimeEnvFile := runtimeEnvFilePath()
  EnvSet("YMT1", runtimeEnvValue(runtimeEnvFile, "YMT1", "ym.lnk||X|"))
  EnvSet("YSAP", runtimeEnvValue(runtimeEnvFile, "YSAP", "ym.lnk||X|"))
  sapDefaultTcodeFallback := runtimeConfigValue(runtimeEnvFile, "sap-defaults", "defaultTcodeFallback", "smen")
  sapDelayPollMs := runtimeConfigValue(runtimeEnvFile, "sap-delays", "pollMs", "100")
  uiBorderColor := runtimeConfigValue(runtimeEnvFile, "ui", "borderColor", "4444FF")
  uiBorderThickness := runtimeConfigValue(runtimeEnvFile, "ui", "borderThickness", "3")
}

runtimeEnvFilePath() {
  SplitPath(A_LineFile, , &configDir)
  return configDir "\..\..\data\local-startup.ini"
}

runtimeEnvValue(configFile, key, defaultValue := "") {
  return IniRead(configFile, "runtime-env", key, defaultValue)
}

runtimeConfigValue(configFile, section, key, defaultValue := "") {
  return IniRead(configFile, section, key, defaultValue)
}

; Local secret loader. Real values belong in data/local-secrets.ini.
loadSecretConstants() {
  global
  local secretsFile := secretsFilePath()
  keepassProviderCommand := secretConfigValue(secretsFile, "keepassProviderCommand", "")
}

secretsFilePath() {
  dataSecrets := A_ScriptDir "\data\local-secrets.ini"
  if FileExist(dataSecrets)
    return dataSecrets
  return dataSecrets
}

secretConfigValue(secretsFile, key, defaultValue := "") {
  return IniRead(secretsFile, "secrets", key, defaultValue)
}

; Local secret loader. Real values belong in data/local-secrets.ini or env vars.
loadSecretConstants() {
  global
  local secretsFile := normanSecretsFile()
  pathGptNews := normanSecretValue(secretsFile, "pathGptNews", EnvGet("NORMAN_PATH_GPT_NEWS"))
  nttOfficePass := normanSecretValue(secretsFile, "nttOfficePass", EnvGet("NORMAN_NTT_OFFICE_PASS"))
  keepassXc := normanSecretValue(secretsFile, "keepassXc", EnvGet("NORMAN_KEEPASS_XC"))
  keepassProviderCommand := normanSecretValue(secretsFile, "keepassProviderCommand", EnvGet("NORMAN_KEEPASS_PROVIDER_CMD"))
  breakId := normanSecretValue(secretsFile, "breakId", "BREAK-POINT ID abapcg.")
}

normanSecretsFile() {
  dataSecrets := A_ScriptDir "\data\local-secrets.ini"
  if FileExist(dataSecrets)
    return dataSecrets
  return dataSecrets
}

normanSecretValue(secretsFile, key, defaultValue := "") {
  return IniRead(secretsFile, "secrets", key, defaultValue)
}

loadTestModeConstants() {
  return loadSecretConstants()
}

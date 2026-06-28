class SapSessionService {
  openPluzDevSession() {
    this._openPinnedSession("pluz dev")
  }

  openPluzQasSession() {
    this._openPinnedSession("pluz qas")
  }

  openPluzPrdSession() {
    this._openPinnedSession("pluz prd")
  }

  openNamedSession(inputValue) {
    services.launcher.closeAndWait()
    inputValue := services.memory.getValue(inputValue)
    inputValue := utils.keyClear(inputValue)
    utils.tooltip(inputValue)

    sessionConfig := this._resolveSessionConfig(inputValue)
    validationError := this._validateSessionConfig(sessionConfig, inputValue)
    if validationError
    {
      this._showRuntimeError(validationError)
      return
    }

    if this._tryHandleCredentialWindows(sessionConfig["mandt"], sessionConfig["sapUser"], sessionConfig["sapPassword"])
      return

    this._runLaunchCommand(sessionConfig)
    this._handleMultipleSessionPopup(sessionConfig["sendEnter"])
    this._afterSapLaunch(sessionConfig)

    if utils.isExit()
      Exit()
  }

  _openPinnedSession(sessionName) {
    this.openNamedSession(sessionName)
  }

  _resolveSessionConfig(inputValue) {
    sessionKey := this._normalizeSessionLookup(inputValue)
    entryRef := this._resolveSessionEntryRef("session/" sessionKey)
    if !entryRef
      return Map()
    return this._loadSessionRecordFromKeepass(entryRef)
  }

  _normalizeSessionLookup(inputValue) {
    return StrLower(Trim(inputValue))
  }

  _validateSessionConfig(sessionConfig, originalInput) {
    if !(sessionConfig is Map)
      return "SAP session is not configured for " originalInput
    requiredFields := ["connectionName", "mandt", "sapUser", "sapPassword"]
    for fieldName in requiredFields
    {
      if !sessionConfig[fieldName]
        return "Verificar configuracion KeePass de " originalInput " campo " fieldName
    }
    return ""
  }

  _reopenSessionFromWindowContext() {
    utils.winNow()

    Send("1")
    Sleep(10)
    text := ControlGetText("Edit4")
    if !text
      text := ControlGetText("Edit3")
    loginParts := StrSplit(text, " ")
    if !loginParts.Has(6) or !loginParts.Has(7)
      return
    Send("{backspace}")
    this.openNamedSession(loginParts[6] A_Space loginParts[7])
  }

  _buildLaunchCommand(sessionConfig) {
    connectionName := sessionConfig["connectionName"]
    mandt := sessionConfig["mandt"]
    sapUser := sessionConfig["sapUser"]
    sapPassword := sessionConfig["sapPassword"]
    sapTcode := sessionConfig["sapTcode"] ? sessionConfig["sapTcode"] : sapDefaultTcodeFallback
    languageCode := sessionConfig["languageCode"] ? sessionConfig["languageCode"] : "es"
    baseCmd := "nwbc.exe /shortcut=-"
    return baseCmd "type=Transaction -command=" sapTcode " -language=" languageCode " -maxgui -sysname=`"" connectionName "`" -system= -client=" mandt " -user=" sapUser " -pw=`"" sapPassword "`" -reuse=1"
  }

  _runLaunchCommand(sessionConfig) {
    launchCmd := this._buildLaunchCommand(sessionConfig)
    Run(A_Comspec " /c start " launchCmd, , "hide")
  }

  _tryHandleCredentialWindows(mandt, user, pass) {
    if WinExist(titleSap000)
    {
      WinActivate(titleSap000)
      WinWaitActive(titleSap000)
      this._fillCredentials(mandt, user, pass)
      return true
    }

    if WinActive(titleSapGui) or WinActive(titleLogonDataEntry)
    {
      this._fillCredentials(mandt, user, pass)
      return true
    }

    if WinActive(titleSystemEntry)
    {
      this._fillCredentials("", user, pass)
      return true
    }

    if WinActive("Logon for Project")
    {
      Send("^a")
      utils.paste(pass, True)
      Send("{enter}")
      return true
    }

    if WinActive("New ABAP Project")
    {
      Send("^a")
      utils.paste(mandt, True)
      Send("{tab}^a")
      utils.paste(user, True)
      Send("{tab}^a")
      utils.paste(pass, True)
      Send("{tab}^a")
      Send("ES")
      Send("{enter}")
      return true
    }

    if WinActive(titleEclipseTransport)
    {
      this._fillCredentials(mandt, user, pass)
      return true
    }

    return false
  }

  _handleMultipleSessionPopup(sendEnter) {
    multiple := "ltiple"
    if WinWait(multiple, , 5)
    {
      WinActivate(multiple)
      WinWaitActive(multiple)
      Send("^{i}")
      Sleep(100)
      Send("{tab}{up}")
      WinWaitActive(multiple, , 1)

      if (sendEnter = "")
        Send("{enter}")
    }
  }

  _fillCredentials(mandt, user, pass) {
    if mandt {
      Send("+{tab}")
      utils.paste(mandt, True)
      Send("{tab}")
    }
    utils.paste(user, True)
    Send("{tab}")
    utils.paste(pass, True)
    Send("{enter}")
  }

  _resolveSessionEntryRef(indexPath) {
    lookupRef := "kp:sap-index/" indexPath
    entryRef := services.memory.resolveProviderValue(lookupRef, "SAP session lookup " indexPath, true)
    if !entryRef
      return ""
    return this._normalizeSessionEntryRef(entryRef)
  }

  _normalizeSessionEntryRef(entryRef) {
    normalizedRef := Trim(entryRef)
    if !normalizedRef
      return ""
    if InStr(normalizedRef, "kp:") = 1
      return normalizedRef
    return "kp:" normalizedRef
  }

  _loadSessionRecordFromKeepass(entryRef) {
    if this.HasOwnProp("_sapSessionRecordCache") && this._sapSessionRecordCache.Has(entryRef)
      return this._sapSessionRecordCache[entryRef]

    parsedUrl := this._parseSessionEntryUrl(entryRef)
    connectionName := this._resolveSessionField(entryRef, "title")
    if !connectionName
      connectionName := this._mapGet(parsedUrl, "connectionName")

    record := Map(
      "entryRef", entryRef,
      "connectionName", connectionName,
      "mandt", this._resolveSessionFieldOrFallback(entryRef, "mandt", this._mapGet(parsedUrl, "mandt")),
      "sapUser", this._resolveSessionFieldOrFallback(entryRef, "user", this._mapGet(parsedUrl, "user")),
      "sapPassword", services.memory.resolveSecretValue(entryRef "/pass", "SAP password for " connectionName),
      "sendEnter", this._resolveSessionField(entryRef, "sendEnter"),
      "sapTcode", this._resolveSessionField(entryRef, "sapTcode"),
      "languageCode", this._resolveSessionFieldOrFallback(entryRef, "languageCode", "es")
    )

    if !this.HasOwnProp("_sapSessionRecordCache")
      this._sapSessionRecordCache := Map()
    this._sapSessionRecordCache[entryRef] := record
    return record
  }

  _resolveSessionField(entryRef, fieldName) {
    fieldRef := entryRef "/" fieldName
    return services.memory.resolveProviderValue(fieldRef, "SAP entry field " fieldRef, true)
  }

  _resolveSessionFieldOrFallback(entryRef, fieldName, fallbackValue := "") {
    resolvedValue := this._resolveSessionField(entryRef, fieldName)
    if resolvedValue != ""
      return resolvedValue
    return fallbackValue
  }

  _parseSessionEntryUrl(entryRef) {
    urlValue := this._resolveSessionField(entryRef, "url")
    if !urlValue
      return Map()

    matches := []
    startPos := 1
    while RegExMatch(urlValue, '"([^"]*)"', &capture, startPos)
    {
      matches.Push(capture[1])
      startPos := capture.Pos(0) + capture.Len(0)
    }

    output := Map()
    if matches.Length >= 1
      output["user"] := matches[1]
    if matches.Length >= 3
      output["connectionName"] := matches[3]
    if matches.Length >= 4
      output["mandt"] := matches[4]
    return output
  }

  _mapGet(source, key, defaultValue := "") {
    if (source is Map) && source.Has(key)
      return source[key]
    return defaultValue
  }

  _showRuntimeError(message) {
    MsgBox(message)
  }

  _afterSapLaunch(sessionConfig) {
  }
}

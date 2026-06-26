class SapSessionConfigService {
  resolve(inputValue) {
    sessionKey := this._normalizeSapSessionLookup(inputValue)
    entryRef := this._resolveSapSessionEntryRef("session/" sessionKey)
    if !entryRef
      return Map()
    return this._loadSapSessionRecordFromKeepass(entryRef)
  }

  validate(sessionConfig, originalInput) {
    if !(sessionConfig is Map)
      return "SAP session is not configured for " originalInput

    requiredFields := ["connectionName", "mandt", "sapUser", "sapPassword"]
    for fieldName in requiredFields
    {
      if !sessionConfig.Has(fieldName) || !sessionConfig[fieldName]
        return "Verificar configuracion KeePass de " originalInput " campo " fieldName
    }
    return ""
  }

  resolveByIndexRef(indexPath) {
    if !indexPath
      return ""

    entryRef := this._resolveSapSessionEntryRef(indexPath)
    if !entryRef
      return ""

    return this._loadSapSessionRecordFromKeepass(entryRef)
  }

  _normalizeSapSessionLookup(inputValue) {
    return StrLower(Trim(inputValue))
  }

  _resolveSapSessionEntryRef(indexPath) {
    lookupRef := "kp:sap-index/" indexPath
    entryRef := services.memory.resolveProviderValue(lookupRef, "SAP session lookup " indexPath, true)
    if !entryRef
      return ""
    return this._normalizeSapSessionEntryRef(entryRef)
  }

  _normalizeSapSessionEntryRef(entryRef) {
    normalizedRef := Trim(entryRef)
    if !normalizedRef
      return ""
    if InStr(normalizedRef, "kp:") = 1
      return normalizedRef
    return "kp:" normalizedRef
  }

  _loadSapSessionRecordFromKeepass(entryRef) {
    if this.HasOwnProp("_sapSessionRecordCache") && this._sapSessionRecordCache.Has(entryRef)
      return this._sapSessionRecordCache[entryRef]

    parsedUrl := this._parseSapEntryUrl(entryRef)
    connectionName := this._resolveSapEntryField(entryRef, "title")
    if !connectionName
      connectionName := this._mapGet(parsedUrl, "connectionName")

    record := Map(
      "entryRef", entryRef,
      "connectionName", connectionName,
      "mandt", this._resolveSapEntryFieldOrFallback(entryRef, "mandt", this._mapGet(parsedUrl, "mandt")),
      "sapUser", this._resolveSapEntryFieldOrFallback(entryRef, "user", this._mapGet(parsedUrl, "user")),
      "sapPassword", this._resolveSapEntryField(entryRef, "pass"),
      "sapPasswordRef", entryRef "/pass",
      "sendEnter", this._resolveSapEntryField(entryRef, "sendEnter"),
      "sapTcode", this._resolveSapEntryField(entryRef, "sapTcode"),
      "languageCode", this._resolveSapEntryFieldOrFallback(entryRef, "languageCode", "es")
    )

    if !this.HasOwnProp("_sapSessionRecordCache")
      this._sapSessionRecordCache := Map()
    this._sapSessionRecordCache[entryRef] := record
    return record
  }

  _resolveSapEntryField(entryRef, fieldName) {
    fieldRef := entryRef "/" fieldName
    return services.memory.resolveProviderValue(fieldRef, "SAP entry field " fieldRef, true)
  }

  _resolveSapEntryFieldOrFallback(entryRef, fieldName, fallbackValue := "") {
    resolvedValue := this._resolveSapEntryField(entryRef, fieldName)
    if resolvedValue != ""
      return resolvedValue
    return fallbackValue
  }

  _parseSapEntryUrl(entryRef) {
    urlValue := this._resolveSapEntryField(entryRef, "url")
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
}

class SapLogonSessionConfigService extends SapLogonService {
  _resolveSapLoginConfig(inputValue) {
    return services.sapSessions.resolve(inputValue)
  }

  _normalizeSapSessionLookup(inputValue) {
    return services.sapSessions._normalizeSapSessionLookup(inputValue)
  }

  _validateSapLoginConfig(sessionConfig, originalInput) {
    return services.sapSessions.validate(sessionConfig, originalInput)
  }

  _loadSapSessionRecordByIndexRef(indexPath) {
    return services.sapSessions.resolveByIndexRef(indexPath)
  }

  _resolveSapSessionEntryRef(indexPath) {
    return services.sapSessions._resolveSapSessionEntryRef(indexPath)
  }

  _normalizeSapSessionEntryRef(entryRef) {
    return services.sapSessions._normalizeSapSessionEntryRef(entryRef)
  }
}

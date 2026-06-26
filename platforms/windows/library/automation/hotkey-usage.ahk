class HotkeyUsageService {
  track(hotkeyId, sourceFile := "", sourceGroup := "") {
    if !hotkeyId
      return

    usageData := this._loadUsageData()
    key := this._normalizeKey(hotkeyId)
    nowUtc := A_NowUTC

    if !usageData["hotkeys"].Has(key) {
      usageData["hotkeys"][key] := Map(
        "count", 0,
        "firstSeenUtc", nowUtc,
        "lastSeenUtc", nowUtc,
        "sourceFile", sourceFile,
        "sourceGroup", sourceGroup
      )
    }

    entry := usageData["hotkeys"][key]
    entry["count"] += 1
    entry["lastSeenUtc"] := nowUtc
    if sourceFile
      entry["sourceFile"] := sourceFile
    if sourceGroup
      entry["sourceGroup"] := sourceGroup

    usageData["meta"]["updatedAtUtc"] := nowUtc
    this._saveUsageData(usageData)
  }

  _loadUsageData() {
    if !FileExist(hotkeyUsageJsonFile)
      return this._defaultUsageData()

    try {
      jsonText := FileRead(hotkeyUsageJsonFile, "UTF-8")
      parsed := JsonService.load(&jsonText)
      return this._normalizeUsageData(parsed)
    } catch {
      return this._defaultUsageData()
    }
  }

  _saveUsageData(usageData) {
    jsonText := JsonService.dump(usageData, 2)
    if FileExist(hotkeyUsageJsonFile)
      FileDelete(hotkeyUsageJsonFile)
    FileAppend(jsonText, hotkeyUsageJsonFile, "UTF-8")
  }

  _normalizeUsageData(parsed) {
    if !IsObject(parsed)
      return this._defaultUsageData()
    if !parsed.Has("meta")
      parsed["meta"] := Map()
    if !parsed.Has("hotkeys") || !(parsed["hotkeys"] is Map)
      parsed["hotkeys"] := Map()
    if !parsed["meta"].Has("version")
      parsed["meta"]["version"] := 1
    if !parsed["meta"].Has("updatedAtUtc")
      parsed["meta"]["updatedAtUtc"] := A_NowUTC
    return parsed
  }

  _defaultUsageData() {
    return Map(
      "meta", Map(
        "version", 1,
        "updatedAtUtc", A_NowUTC
      ),
      "hotkeys", Map()
    )
  }

  _normalizeKey(hotkeyId) {
    return StrLower(Trim(hotkeyId))
  }
}

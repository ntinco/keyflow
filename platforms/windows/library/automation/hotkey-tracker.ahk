class HotkeyTrackerService {
  track(hotkeyId, sourceFile := "", sourceGroup := "") {
    if !hotkeyId
      return

    usageData := this._loadUsageData()
    key := this._usageKey(hotkeyId, sourceFile, sourceGroup)
    nowUtc := A_NowUTC

    if !usageData["hotkeys"].Has(key) {
      usageData["hotkeys"][key] := Map(
        "count", 0,
        "firstSeenUtc", nowUtc,
        "lastSeenUtc", nowUtc,
        "hotkeyId", this._normalizeKey(hotkeyId),
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
    if !FileExist(hotkeyTrackerJsonFile)
      return this._defaultUsageData()

    try {
      jsonText := FileRead(hotkeyTrackerJsonFile, "UTF-8")
      parsed := jsonLoad(&jsonText)
      return this._normalizeUsageData(parsed)
    } catch {
      return this._defaultUsageData()
    }
  }

  _saveUsageData(usageData) {
    jsonText := jsonDump(usageData, 2)
    if FileExist(hotkeyTrackerJsonFile)
      FileDelete(hotkeyTrackerJsonFile)
    FileAppend(jsonText, hotkeyTrackerJsonFile, "UTF-8")
  }

  _normalizeUsageData(parsed) {
    if !IsObject(parsed)
      return this._defaultUsageData()
    if !parsed.Has("meta")
      parsed["meta"] := Map()
    if !parsed.Has("hotkeys") || !(parsed["hotkeys"] is Map)
      parsed["hotkeys"] := Map()
    parsed["meta"]["version"] := 2
    if !parsed["meta"].Has("updatedAtUtc")
      parsed["meta"]["updatedAtUtc"] := A_NowUTC
    return parsed
  }

  _defaultUsageData() {
    return Map(
      "meta", Map(
        "version", 2,
        "updatedAtUtc", A_NowUTC
      ),
      "hotkeys", Map()
    )
  }

  _normalizeKey(hotkeyId) {
    return StrLower(Trim(hotkeyId))
  }

  _usageKey(hotkeyId, sourceFile, sourceGroup) {
    context := sourceGroup ? sourceGroup : sourceFile
    return StrLower(Trim(context)) "::" this._normalizeKey(hotkeyId)
  }
}

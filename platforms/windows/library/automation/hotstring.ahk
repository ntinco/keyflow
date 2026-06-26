class HotstringService {
  set(profile) {
    global services
    label := profile.label
    groupName := profile.group
    mode := profile.mode

    if this._isSapInputMode(mode)
      HotIf(hk => services.saplogon.isInputBoxActive("ahk_group " groupName))
    else if (groupName != "")
      HotIfWinActive("ahk_group " groupName)
    else
      HotIfWinActive()

    registerEntries(this._loadEntries(label), mode)
    this._resetHotstringContext()

    applySapTcode(hotstringValue, *) => services.saplogon.openTcodeFromInput(hotstringValue)
    applySapLogon(hotstringValue) => services.saplogon.openSapSession(hotstringValue)

    registerEntries(entries, mode) {
      for entry in entries {
        trigger := entry["trigger"]
        value := entry["value"]
        if !trigger
          continue

        hotstringOptions := this._resolveHotstringOptions(mode, trigger, value, entry)
        if this._isSapInputMode(mode)
          hotstring(hotstringOptions . trigger, applySapTcode.Bind(value))
        else if (mode = "sapLogon")
          hotstring(hotstringOptions . trigger, applySapLogon)
        else
          hotstring(hotstringOptions . trigger, value)
      }
    }
  }

  _resolveHotstringOptions(mode, trigger := "", value := "", entry := "") {
    if this._isSapInputMode(mode)
      return ":X*b0:"
    if (mode = "sapLogon")
      return ":*:"
    if (mode = "autocorrectImmediate")
      return ":*:"
    if (mode = "autocorrect" and entry is Map and entry.Has("immediate") and !entry["immediate"])
      return "::"
    if (mode = "autocorrect" and this._isImmediatePersonName(trigger, value))
      return ":*:"
    if (mode = "autocorrect")
      return "::"
    return "::"
  }

  _isImmediatePersonName(trigger, value) {
    if !(trigger is String) || !(value is String)
      return false
    if (trigger = "" or value = "")
      return false
    if !RegExMatch(trigger, "^[a-z]+$")
      return false
    ; Name-like value: one word, starts uppercase, only letters (supports accents).
    return RegExMatch(value, "^[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+$")
  }

  _isSapInputMode(mode) {
    return (mode = "sapTransaction" or mode = "ymtCommand")
  }

  _resetHotstringContext() {
    ; Clear any temporary HotIf scope so subsequent file-defined hotstrings
    ; (e.g. in hotkeys/global.ahk) are not accidentally constrained.
    HotIf()
    HotIfWinActive()
  }


  _loadEntries(label) {
    jsonPath := dataDir label ".json"
    if !FileExist(jsonPath)
    {
      this._showRuntimeError("Required file does not exist: " jsonPath)
      return []
    }
    return this._loadEntriesFromJson(jsonPath)
  }

  _loadEntriesFromJson(path) {
    jsonData := this._readJsonPayload(path)
    if !(jsonData is Map)
      return []
    if !this._validateHotstringJsonPayload(jsonData, path)
      return []

    entries := []
    for item in jsonData["items"] {
      jsonEntry := this._buildEntryFromJsonItem(item)
      if jsonEntry is Map
        entries.Push(jsonEntry)
    }
    return entries
  }

  _readJsonPayload(path) {
    try
    {
      jsonText := FileRead(path)
      return JsonService.load(&jsonText)
    }
    catch as errorInfo
    {
      this._showRuntimeError("Could not read " path ". Verify JSON format. Detail: " errorInfo.Message)
      return ""
    }
  }

  _validateHotstringJsonPayload(jsonData, path) {
    if !(jsonData is Map) || !jsonData.Has("items")
    {
      this._showRuntimeError("Invalid JSON in " path ". Expected an object with items[].")
      return false
    }
    if !(jsonData["items"] is Array)
    {
      this._showRuntimeError("Invalid JSON in " path ". items must be a list.")
      return false
    }
    return true
  }

  _buildEntryFromJsonItem(item) {
    if !(item is Map)
      return ""
    trigger := item.Has("trigger") ? item["trigger"] : ""
    value := this._resolveEntryValue(item)
    if !trigger
      return ""
    if !value
      return ""
    entry := Map("trigger", trigger, "value", value)
    if item.Has("immediate")
      entry["immediate"] := item["immediate"]
    return entry
  }

  _resolveEntryValue(item) {
    if item.Has("value")
      return item["value"]
    return ""
  }

  _showRuntimeError(message) {
    MsgBox(message)
  }

}



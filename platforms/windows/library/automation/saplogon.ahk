class SapLogonService extends SapBase {
  openFavoriteTcodes() {
    quickTitle := "Tcode Fav"

    dark := DarkTheme()
    dynpro := dynpro()
    dark.win(dynpro)

    dynpro.Opt(" +Owner")
    dynpro.OnEvent("Close", GuiClose)
    dynpro.SetFont("s10")
    loList := dynpro.Add("ListView", "r20 w80", [quickTitle])

    favoriteTcodes := this._loadFavoriteTcodes()
    if (favoriteTcodes.Length = 0)
    {
      this._showRuntimeError("sap-transaction-favorites.json has no favorites. Add items[] in data/sap-transaction-favorites.json.")
      return
    }

    for tcode in favoriteTcodes
      loList.Add(, tcode)

    loList.OnEvent("Click", btnClick)

    dark.ctrl(dynpro)
    dynpro.Title := quickTitle
    dynpro.Show()

    WinActivate(quickTitle)
    WinWaitActive(quickTitle)
    Return

    btnClick(refobj, RowNumber)
    {
      RowText := refobj.GetText(RowNumber)
      if RowText and RowText != quickTitle
      {
        send("!{esc}")
        WinWaitActive(exeNwbc, , 3)
        if WinActive(exeNwbc)
        {
          send("^!l")
          Sleep(1000)
          Send("/n" RowText "{enter}")
          dynpro.Destroy()
        }
      }
    }
    GuiClose(*)
    {
      Return
    }
  }

  handleF1ContextAction() {
    if WinActive("Core")
      Send("^+{f9}")
    else if WinActive("YM")
      Send("^/")
    else if WinActive("factura")
      Send("^{f10}")
    else
    {
      Send("+{F5}")
      if WinActive("odif") or WinActive("Visual")
        return

      this._waitAndSend("variante", "{f8}", 3)
    }
  }

  activateCodeArtifacts(activateAll := "") {
    this.saveCurrentCodeArtifact()

    if WinActive(exeVscode)
      Send("+!{F3}")
    else if WinActive(exeEclipse)
      Send("^{F3}")
    else if WinActive("InfoSet")
    {
      Send("+{F6}")
      this._waitAndSendEnter("modificado", 2)
      this._waitAndSendEnter("Informacion", 5)
      this._waitAndSendEnter("Visualizar log", 5)
    }
    else
    {
      Send("^{f3}")
      if WinWaitActive("Objetos inactivos de", , 5)
      {
        if activateAll
          Send("{f9}")
        Sleep(1000)
        Send("{enter}")
      }
      this._waitAndSendEnter("ctiva", 5)
      if utils.isExit()
        Exit()
    }
  }

  openEclipseAbapObject() {
    services.dynamic.execute("^+a; WinWaitActive,Open ABAP; zpm*", 100)
  }

  runEclipseAbapObjectPickerFromHotkey() {
    this.openEclipseAbapObject()
  }

  openEclipseSearchByWildcard() {
    services.dynamic.execute("^o; *")
  }

  runEclipseWildcardSearchFromHotkey() {
    this.openEclipseSearchByWildcard()
  }

  executeEclipseQuickDebugFlow() {
    services.dynamic.execute("^a; ^4; Click; Sleep,2000; +{f1}; ^{f3}", 300)
  }

  runEclipseQuickDebugFromHotkey() {
    this.executeEclipseQuickDebugFlow()
  }

  toggleSapDebugMode() {
    this.executeSapGuiDebugToggleTcode()
  }

  openSapTcodeFromHotkey(tcode) {
    if !tcode
    {
      this._showRuntimeError("TCode vacio en hotkey SAP. Verifica configuracion del atajo.")
      return
    }
    this.executeTcode(tcode)
  }

  ; Atajos SAP GUI (hotkeys/sap-gui.ahk): delegacion explicita para evitar literales en el dominio hotkey.
  openSapGuiTcodeEdWorkbenchOptions() {
    this.openSapTcodeFromHotkey("=ED_OPTIONS")
  }

  openSapGuiTcodeSe16n() {
    this.openSapTcodeFromHotkey("se16n")
  }

  openSapGuiTcodeSe37() {
    this.openSapTcodeFromHotkey("se37")
  }

  openSapGuiTcodeSe38() {
    this.openSapTcodeFromHotkey("se38")
  }

  openSapGuiTcodeSe09() {
    this.openSapTcodeFromHotkey("se09")
  }

  openSapGuiTcodeSe80() {
    this.openSapTcodeFromHotkey("se80")
  }

  insertSapCommentLineFromHotkey(hotkeyLabel, userMemoryKey, ticketMemoryKey) {
    this.codeCommentline(hotkeyLabel, userMemoryKey, ticketMemoryKey)
  }

  insertSapCommentBlockFromHotkey(hotkeyLabel, userMemoryKey, ticketMemoryKey) {
    this.codeCommentblock(hotkeyLabel, userMemoryKey, ticketMemoryKey)
  }

  ; Global hotstrings (hotkeys/global.ahk): project default user/ticket.
  insertSapCommentLineWithProjectDefaults() {
    userMemoryKey := "sap_comment_user"
    ticketMemoryKey := "sap_comment_ticket"
    this.insertSapCommentLineFromHotkey(A_ThisHotkey, userMemoryKey, ticketMemoryKey)
  }

  insertSapCommentBlockWithProjectDefaults() {
    userMemoryKey := "sap_comment_user"
    ticketMemoryKey := "sap_comment_ticket"
    this.insertSapCommentBlockFromHotkey(A_ThisHotkey, userMemoryKey, ticketMemoryKey)
  }

  openSapDevSessionFromHotkey() {
    this.openSapNamedSessionFromMemory("sap_logon_dev")
  }

  openSapQasSessionFromHotkey() {
    this.openSapNamedSessionFromMemory("sap_logon_qas")
  }

  openSapPrdSessionFromHotkey() {
    this.openSapNamedSessionFromMemory("sap_logon_prd")
  }

  exitSapGuiWithNex() {
    this.executeSapGuiLogoffNexTcode()
  }

  activateSapGuiAllCodeArtifacts() {
    this.activateCodeArtifacts("all")
  }

  activateEclipseAllCodeArtifacts() {
    this.activateCodeArtifacts("activate_all")
  }

  reloginSapFromLogonProjectWindow() {
    this.reloginFromCurrentWindow()
  }

  openSapTcodeFromGuiCommandField() {
    this.openTcodeFromInput()
  }

  ; tools/sap-gui: tcodes usados por scripts auxiliares (auditoria centralizada).
  openSapPurchasingDisplayMe23n() {
    this.executeTcode("me23n")
  }

  openSapTableMaintenanceGenerationTmge() {
    this.executeTcode("=TMGE")
  }

  saveCurrentCodeArtifact() {
    utils.winNow()

    names := StrSplit(utils.A_Title, " ")
    name := ""
    for idx in [7, 6, 5, 4, 3, 2, 1] {
      try name := names[idx]
      if (substr(name, 1, 1) ~= "i)(Z|Y)")
        break
    }

    if instr(utils.A_Title, "YM")
      path := pathYmWorkspace
    else
      path := pathAbapInbox
    if !path
      return

    if instr(utils.A_Title, "Gener.clases") or instr(utils.A_Title, "Class")
      name := path StrLower(name) constAbapExtClas
    else if instr(utils.A_Title, "Report") or instr(utils.A_Title, "Program")
      name := path StrLower(name) constAbapExtProg
    else if instr(utils.A_Title, "funciones") or instr(utils.A_Title, "Function")
      name := path StrLower(name) constAbapExtProg
    else
      return
    if !name
      return

    codes := utils.clipboardRead("^a^c", 1.5)
    if !codes
      return

    if FileExist(name)
      FileDelete(name)
    FileAppend(codes, name, "UTF-8")

    utils.tooltip(name " se sincronizo - " utils.lines(codes) " lineas")
  }
}

class SapBase {
  activate() {
    if !WinActive(exeNwbc)
    {
      WinActivate(exeNwbc)
      Sleep(100)
    }
  }

  codeCommentblock(label, ini, task) {
    line := this._buildCodeCommentLine(label, ini, task, "*")
    Sleep(200)
    utils.paste(this._buildCommentMarkup(line, True))
  }

  codeCommentline(label, ini, task) {
    line := this._buildCodeCommentLine(label, ini, task, Chr(34))
    Sleep(200)
    utils.paste(this._buildCommentMarkup(line, False))
  }

  isInputBoxActive(group) {
    try{
      pos := this._getcursorrelativetocontrol()
      if !pos.y
        return false
      else if pos.y <= 180 and WinActive(group) and InStr(utils.winControl(), "Edit")
        return true
    }
  }

  openSapSession(inputValue) {
    services.launcher.closeAndWait()
    inputValue := services.memory.getValue(inputValue)
    inputValue := utils.keyClear(inputValue)
    utils.tooltip(inputValue)

    sessionConfig := this._resolveSapLoginConfig(inputValue)
    validationError := this._validateSapLoginConfig(sessionConfig, inputValue)
    if validationError
    {
      this._showRuntimeError(validationError)
      return
    }

    if this._tryHandleCredentialWindows(sessionConfig["mandt"], sessionConfig["sapUser"], sessionConfig["sapPassword"])
      return

    this._runSapLaunch(sessionConfig)
    this._handleMultipleSessionPopup(sessionConfig["sendEnter"])

    if (sessionConfig["sapTcode"] = "YMT.")
      this._syncYmtProgramFromLocal(sessionConfig["sapTcode"])

    if utils.isExit()
      Exit()
  }

  openSapNamedSessionFromMemory(memoryKey) {
    sessionName := services.memory.getValue(memoryKey)
    if !sessionName || sessionName = memoryKey
    {
      this._showRuntimeError(
        "SAP session is not configured for " memoryKey
        ". Define the value in data/memory-vars.ini [data] with a direct session name like pluz dev."
      )
      return
    }
    this.openSapSession(sessionName)
  }

  _resolveSapLoginConfig(inputValue) {
    sessionKey := this._normalizeSapSessionLookup(inputValue)
    entryRef := this._resolveSapSessionEntryRef("session/" sessionKey)
    if !entryRef
      return Map()
    return this._loadSapSessionRecordFromKeepass(entryRef)
  }

  _normalizeSapSessionLookup(inputValue) {
    return StrLower(Trim(inputValue))
  }

  _validateSapLoginConfig(sessionConfig, originalInput) {
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

  openSapSessionFromScriptName() {
    this.openSapSession(fileScriptname)
    ExitApp()
  }

  reloginFromCurrentWindow() {
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
    this.openSapSession(loginParts[6] A_Space loginParts[7])
  }

  openQasBreakpointFunction() {
    this.openSapFunctionLibraryViaOse37()
    if WinWaitActive("Biblioteca de funciones: Acceso", , 5)
    {
      Sleep(500)
      utils.paste("TRINT_OBJECTS_CHECK_AND_INSERT", True)
      this._sendAndWaitActive("{F7}", "TRINT_OBJECTS_CHECK_AND_INSERT", 5)
      Sleep(500)
      Send("^o")
      WinWait("Pasar a")
      WinActivate("A")
      Send("658{enter}")
      Sleep(100)
      Send("^+{F12}")
      Sleep(500)
      Send("^{w}")
    }
    if utils.isExit()
      Exit()
  }

  openQasVariables() {
    this.activate()
    snippets := this._loadQasSnippetsText()
    if !snippets
      return
    utils.paste(snippets)
    Send("{enter}{up 4}")
    Sleep(1000)
    this.openQasValueDialog()
  }

  _loadQasSnippetsText() {
    if FileExist(sapQasSnippetsJsonFile)
    {
      try
      {
        jsonText := FileRead(sapQasSnippetsJsonFile)
        jsonData := JsonService.load(&jsonText)
        if (jsonData is Map) && jsonData.Has("items")
        {
          snippetLines := []
          for item in jsonData["items"]
          {
            if !(item is Map)
              continue
            snippetValue := item.Has("value") ? Trim(item["value"]) : ""
            if snippetValue
              snippetLines.Push(snippetValue)
          }
          if snippetLines.Length > 0
            return this._joinLines(snippetLines)
        }
      }
    }

    return ""
  }

  _loadFavoriteTcodes() {
    favoritesPath := dataDir "sap-transaction-favorites.json"
    tcodes := []
    if !FileExist(favoritesPath)
      return tcodes

    try
    {
      jsonText := FileRead(favoritesPath)
      payload := JsonService.load(&jsonText)
      if (payload is Map) && payload.Has("items")
      {
        for item in payload["items"]
        {
          if !(item is Map)
            continue
          tcode := item.Has("value") ? Trim(item["value"]) : ""
          if !tcode
            tcode := item.Has("trigger") ? Trim(item["trigger"]) : ""
          if tcode
            tcodes.Push(tcode)
        }
      }
    }
    return tcodes
  }

  _joinLines(lines) {
    output := ""
    for line in lines
      output .= (output ? "`r`n" : "") line
    return output
  }

  openQasValueDialog() {
    char := chr(34)
    stepDelayMs := 700
    steps := ["{tab}{space}", "{down}{tab}{space}", "{down}{tab}{space}"]
    for step in steps
    {
      Send(step)
      Sleep(stepDelayMs)
    }
    Send(char "{up}" char "{up}" char "{up}")
    Sleep(100)
    Send("{enter}")
    Sleep(1500)
    Send("{f8}")
  }

  openSapFunctionLibraryViaOse37() {
    this.executeTcode("/ose37", True)
  }

  openSapAbapEditorSe38() {
    this.executeTcode("se38", True)
  }

  executeSapGuiDebugToggleTcode() {
    this.executeTcode("/h")
  }

  executeSapGuiLogoffNexTcode() {
    this.executeTcode("/nex")
  }

  executeTcode(tcode := "", noExit := "", button := "") {
    Sleep(300)
    tcode := services.memory.getValue(tcode)
    tcode := this._normalizeTcodeForSap(tcode)

    if WinActive(exeAnydesk)
      Send("^+{7}")
    else
      Send("^{/}")

    Sleep(200)
    Send(tcode "{enter}")

    this._runTcodePostAction(StrUpper(StrReplace(tcode, "/n")), button)

    if utils.isExit(noExit)
      Exit()
  }

  openTcodeFromInput(tcode := "", noExit := "", button := "") {
    Sleep(150)
    if !tcode
      try tcode := strlower(ControlGetText(utils.A_Control))

    if !tcode
      return

    tcode := this._normalizeTcodeForSap(tcode, True)

    ControlSetText(tcode, utils.A_Control)
    ControlSend("{enter}", utils.A_Control)

    this._runTcodePostAction(StrUpper(StrReplace(tcode, "/n")), button)

    if utils.isExit(noExit)
      Exit()
  }

  installSe38Object(name := "", filename := "", actionKey := "f5", company := "") {
    name := StrUpper(name)
    if !name
    {
      name := utils.clipboardRead("^a^c", 0.4)
      if !name
        return
    }
    name := Trim(name)
    filename := services.memory.getValue(filename)
    if !filename or !FileExist(filename)
      return


    operationDelayMs := this._resolveOperationDelayMs(company)
    activationTimeoutMs := 3 * operationDelayMs

    this._openSe38AndExecuteAction(name, actionKey, True)

    sleep(operationDelayMs)
    Send("^{a}")
    Sleep(200)
    utils.paste(FileRead(filename), True)
    sleep(operationDelayMs)

    Send("^{f3}")
    if WinWait("Objetos inactivos", , 3)
      Send("{enter}")

    WinWaitActive("ABAP", , activationTimeoutMs / 1000)
    Send("{f3}")
    WinWaitActive("ABAP", , 1)
    Send("{f8}")
  }


  _buildCodeSignature(key, task, ini) {
    if services.memory.getValue("sap_module") = "GERENCIA" or services.memory.getValue("sap_request_type") = "Requerimiento"
      tiempo := FormatTime(, "01MMyy")
    else
      tiempo := FormatTime(, "ddMMyy")

    if key = "R"
      key := "+-"

    if SubStr(task, 1, 1) = 1
      sign := key . "YMQ-" . A_Year . "" . A_Mm
    else if SubStr(task, 1, 1) != 3
      sign := key . ini . A_Year . "" . A_Mm . ""
    else
      sign := key . ini . tiempo . "-" . task
    return sign
  }

  _buildCodeCommentLine(label, ini, task, letter) {
    utils.winNow()
    Sleep(10)
    key := utils.keyClear(label)
    key := StrReplace(key, letter, "")
    key := StrUpper(key)
    line := this._buildCodeSignature(key, services.memory.getValue(task), services.memory.getValue(ini))
    return line
  }


  _buildCommentMarkup(line, isBlock := False) {
    if (utils.A_Title ~= "i)(\.js|\.ps)")
      return isBlock ? "//{" line "`n//}" line : "//" line

    if instr(utils.A_Title, ".css")
      return isBlock ? "/*{" line "*/`n/*}" line "*/" : "/*" line "*/"

    if isBlock and instr(utils.A_Title, "Web IDE")
      return "<!--{" line "-->`n<!--}" line "-->"

    return isBlock ? "*{" line "`n*}" line : Chr(34) line
  }

  _buildSapLaunchCmd(sessionConfig) {
    connectionName := sessionConfig["connectionName"]
    mandt := sessionConfig["mandt"]
    sapUser := sessionConfig["sapUser"]
    sapPassword := sessionConfig["sapPassword"]
    sapTcode := sessionConfig["sapTcode"] ? sessionConfig["sapTcode"] : sapDefaultTcodeFallback
    languageCode := sessionConfig["languageCode"] ? sessionConfig["languageCode"] : "es"
    baseCmd := "nwbc.exe /shortcut=-"
    return baseCmd "type=Transaction -command=" sapTcode " -language=" languageCode " -maxgui -sysname=`"" connectionName "`" -system= -client=" mandt " -user=" sapUser " -pw=`"" sapPassword "`" -reuse=1"
  }

  _runSapLaunch(sessionConfig) {
    launchCmd := this._buildSapLaunchCmd(sessionConfig)
    Run(A_Comspec " /c start " launchCmd, , "hide")
  }

  _waitAnySapLogin(timeoutMs := 7000) {
    pollMs := sapDelayPollMs
    startTick := A_TickCount
    while (A_TickCount - startTick < timeoutMs)
    {
      if this._hasAnySapLoginWindow()
        return true
      Sleep(pollMs)
    }
    return false
  }

  _waitAndSendEnter(title, timeout := 0) {
    return this._waitAndSend(title, "{enter}", timeout)
  }

  _sendAndWaitActive(keys, title, timeout := 0) {
    Send(keys)
    return WinWaitActive(title, , timeout)
  }

  _waitAndSend(title, keys, timeout := 0) {
    if WinWaitActive(title, , timeout)
    {
      Send(keys)
      return true
    }
    return false
  }

  _hasAnySapLoginWindow() {
    return WinExist(titleSap000) or WinExist(titleSapGui) or WinExist(titleLogonDataEntry) or WinExist(titleSystemEntry) or WinExist(titleEclipseTransport)
  }

  _openSe38AndExecuteAction(name, actionKey := "f8", noExit := "", company := "") {
    creationDelayMs := this._resolveOperationDelayMs(company) * 3

    Sleep(100)
    if !WinActive("ini")
      this.openSapAbapEditorSe38()

    WinWaitActive("ABAP")
    Sleep(300)
    Send("^a")
    utils.paste(name, True)

    if (actionKey = "+f2")
    {
      Send("{" actionKey "}")
      this._waitAndSendEnter("program", 3)
    }
    else if (actionKey = "f5")
    {
      if this._sendAndWaitActive("+{f2}", "program", 3)
      {
        Send("{esc}")
        WinWaitActive("ini", , 7)
        Send("{f6}")
        WinWaitActive("odif", , 7)
      }
      else
      {
        this._sendAndWaitActive("{" actionKey "}", "Propie", 5)
        Send(name constDot "{tab}")
        Sleep(100)
        Send("1{enter}")
        if !WinWaitActive("Crea", , 2)
        {
          Send("{enter}")
          WinWaitActive("Crea", , 5)
        }
        Send("$tmp{enter}")
        WinWaitActive("Modif", , 7)
        sleep(creationDelayMs)
      }
    }
    else
    {
      waitTitles := Map("f6", "odif", "f7", "vi")
      if waitTitles.Has(actionKey)
        this._sendAndWaitActive("{" actionKey "}", waitTitles[actionKey], 7)
    }

    if utils.isExit(noExit)
      Exit()
  }

  _runTcodePostAction(tcode, button := "") {
    if instr(tcode, "YM")
      this._syncYmtProgramFromLocal(tcode)
    else if button
      this._submitTcodeButton(button)
  }

  _normalizeTcodeForSap(tcode, forBox := False) {
    if forBox
    {
      utils.winNow()
      if instr(utils.A_Title, "YMT")
        return tcode
      if !(tcode ~= "i)(/h|/n|/o|/0|!|=|prfb|jdbg|ed_upload)") and !WinActive(titleSapEasyAccess)
        tcode := "/n" . tcode
      return tcode
    }

    if !(tcode ~= "i)(/h|/n|/o|/0|!|=)") and !WinActive(titleSapEasyAccess)
      tcode := "/n" tcode
    return tcode
  }

  _submitTcodeButton(button) {
    Sleep(900)
    try ControlSetText(button, utils.A_Control)
    catch
      Send(button)

    Sleep(50)
    try ControlSend("{enter}", utils.A_Control)
    catch
      Send("{enter}")

    Sleep(1000)
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

  _resolveOperationDelayMs(company := "") {
    factor := 1000
    if (company ~= "i)(cons|exal)")
      factor := 2000
    return factor
  }

  _syncYmtProgramFromLocal(tcode) {
    utils.winNow()

    if WinWait(SubStr(utils.A_Title, 1, 12) tcode constDot, , 8)
    {
      WinActivate(tcode constDot)
      WinWaitActive(tcode constDot, , 1)
      utils.winNow()
      chars := StrSplit(utils.A_Title, constDot)
      version := ""
      filename := pathYmWorkspace tcode constAbapExtProg
      try version := chars[2]
      if version AND version != utils.fileLines(filename)
        this.installSe38Object(tcode, filename, "f6")
    }
  }

  _loadSapSessionRecordByIndexRef(indexPath) {
    if !indexPath
      return ""

    entryRef := this._resolveSapSessionEntryRef(indexPath)
    if !entryRef
      return ""

    return this._loadSapSessionRecordFromKeepass(entryRef)
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

  _mapGetMap(source, key) {
    value := this._mapGet(source, key, "")
    return (value is Map) ? value : Map()
  }

  _showRuntimeError(message) {
    MsgBox(message)
  }

  _getcursorrelativetocontrol() {
    CaretGetPos(&caretX, &caretY)

    if (caretX = "" || caretY = "")
      MouseGetPos(&caretX, &caretY)

    if (caretX = "" || caretY = "")
      return {x: 10, y: 50}

    WinGetPos(&winX, &winY, , , "A")

    relativeX := caretX - winX - 8
    relativeY := caretY - winY - 35

    if (relativeX < 10)
      relativeX := 10
    if (relativeY < 50)
      relativeY := 50

    return {x: relativeX, y: relativeY}
  }
}





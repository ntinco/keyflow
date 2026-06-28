#Include sap-session.ahk

class SapService extends SapSessionService {
  _afterSapLaunch(sessionConfig) {
    if !(sessionConfig is Map)
      return
    if (sessionConfig["sapTcode"] = "YMT.")
      this._syncYmtProgramFromLocal(sessionConfig["sapTcode"])
  }

  insertCommentLine() {
    this._insertCommentLine()
  }

  insertCommentBlock() {
    this._insertCommentBlock()
  }

  _insertCommentLine() {
    utils.paste(this._buildCodeCommentLine())
  }

  _insertCommentBlock() {
    utils.paste(this._buildCommentMarkup())
  }

  _buildCodeSignature() {
    commentUser := services.memory.getValue("sap_comment_user")
    if !commentUser || (commentUser = "sap_comment_user")
      commentUser := "NTP"
    return commentUser " " constDayEs
  }

  _buildCodeCommentLine() {
    return Chr(34) " " this._buildCodeSignature()
  }

  _buildCommentMarkup() {
    signature := this._buildCodeSignature()
    return "*---------------------------------------------------------------------*`r`n"
      . "* " signature "`r`n"
      . "*---------------------------------------------------------------------*"
  }

  reopenSessionFromProjectWindow() {
    this._reopenSessionFromWindowContext()
  }

  isTextInputActive(winTitle := "A") {
    if !WinActive(winTitle)
      return false

    try focusedControl := ControlGetFocus("A")
    catch
      return false

    if !focusedControl
      return false

    focusedControl := StrLower(focusedControl)
    return InStr(focusedControl, "edit") || InStr(focusedControl, "richedit")
  }

  runTcodeFromFocusedInput() {
    tcode := this._readActiveInputValue()
    if !tcode
      return
    this.runTcode(tcode)
  }

  runTcode(tcode) {
    normalizedTcode := this._normalizeTcodeForSap(tcode)
    if !normalizedTcode
      return

    if WinActive(exeEclipse)
    {
      this.openNamedSession(normalizedTcode)
      return
    }

    this._submitTcodeButton(normalizedTcode)
    this._runTcodePostAction(normalizedTcode)
  }

  toggleDebugMode() {
    this._runDebugToggleCommand()
  }

  _runDebugToggleCommand() {
    this._submitTcodeButton("/h")
  }

  exitSession() {
    this._runExitCommand()
  }

  _runExitCommand() {
    this._submitTcodeButton("/nex")
  }

  openWorkbenchOptions() {
    this.runTcode("ed")
  }

  openSe16n() {
    this.runTcode("se16n")
  }

  openSe37() {
    this.runTcode("se37")
  }

  openSe38() {
    this.runTcode("se38")
  }

  openSe09() {
    this.runTcode("se09")
  }

  openSe80() {
    this.runTcode("se80")
  }

  saveCodeArtifact() {
    Send("^s")
  }

  focusGuiWindows() {
    if !(services.HasOwnProp("windowGroup"))
      return
    services.windowGroup.activateGroup(appActivationTargets, "apps_sap_windows")
  }

  focusEclipseWindows() {
    if !(services.HasOwnProp("windowGroup"))
      return
    services.windowGroup.activateGroup(appActivationTargets, "apps_sap_eclipse")
  }

  _openAbapObject(objectName := "") {
    objectName := Trim(objectName)
    if !objectName
      return

    Send("^+a")
    Sleep(this._resolveOperationDelayMs())
    utils.paste(objectName, true)
    Send("{enter}")
  }

  promptAndOpenAbapObject() {
    objectName := this._promptValue("ABAP object", "Open ABAP Object")
    if !objectName
      return
    this._openAbapObject(objectName)
  }

  _searchAbapObject(searchText := "") {
    searchText := Trim(searchText)
    if !searchText
      return

    Send("^h")
    Sleep(this._resolveOperationDelayMs())
    utils.paste(searchText, true)
    Send("{enter}")
  }

  promptAndSearchAbapObject() {
    searchText := this._promptValue("Wildcard", "Search ABAP Object")
    if !searchText
      return
    this._searchAbapObject(searchText)
  }

  _runQuickDebug() {
    this.saveCodeArtifact()
    Sleep(this._resolveOperationDelayMs())
    Send("^+{f2}")
  }

  startQuickDebug() {
    this._runQuickDebug()
  }

  _runTcodePostAction(normalizedTcode) {
    if (StrUpper(normalizedTcode) = "YMT")
      this._syncYmtProgramFromLocal(normalizedTcode)
  }

  _normalizeTcodeForSap(tcode) {
    normalizedTcode := Trim(tcode)
    if !normalizedTcode
      return ""

    if InStr(normalizedTcode, "/") = 1
      return normalizedTcode

    if RegExMatch(normalizedTcode, "i)^ymt(\.|$)")
      return "YMT"

    return StrUpper(normalizedTcode)
  }

  _submitTcodeButton(tcode) {
    Send("^a")
    commandText := InStr(tcode, "/") = 1 ? tcode : "/n" tcode
    utils.paste(commandText, true)
    Send("{enter}")
  }

  _resolveOperationDelayMs() {
    if IsNumber(sapDelayPollMs)
      return sapDelayPollMs + 0
    return 100
  }

  _syncYmtProgramFromLocal(*) {
    ; Reserved hook for future YMT sync logic. Keep login flow independent from file sync details.
  }

  _readActiveInputValue() {
    savedClipboard := ClipboardAll()
    try {
      A_Clipboard := ""
      Send("^a")
      Sleep(50)
      Send("^c")
      ClipWait(0.5)
      return Trim(A_Clipboard)
    }
    catch {
      return ""
    }
    finally {
      A_Clipboard := savedClipboard
    }
  }

  _promptValue(promptLabel, titleText) {
    result := InputBox("Enter " promptLabel, titleText, "w360 h140")
    if (result.Result != "OK")
      return ""
    return Trim(result.Value)
  }
}

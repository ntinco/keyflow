#Include sap-session.ahk

class SapService {
  __New() {
    this.session := SapSessionService(ObjBindMethod(this, "_afterSapLaunch"))
  }

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
    utilPaste(this._buildCodeCommentLine())
  }

  _insertCommentBlock() {
    utilPaste(this._buildCommentMarkup())
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
    this.session.reopenSessionFromProjectWindow()
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
      this.session.openNamedSession(normalizedTcode)
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

  promptAndOpenAbapObject() {
    Send("^+a")
    Sleep(this._resolveOperationDelayMs())
    utilPaste("zpm*", true)
  }

  promptAndSearchAbapObject() {
    Send("^o")
  }

  _runQuickDebug() {
    this.saveCodeArtifact()
    Sleep(this._resolveOperationDelayMs())
    Send("^+{f2}")
  }

  startQuickDebug() {
    this._runQuickDebug()
  }

  openPluzDevSession() {
    this.session.openPluzDevSession()
  }

  openPluzQasSession() {
    this.session.openPluzQasSession()
  }

  openPluzPrdSession() {
    this.session.openPluzPrdSession()
  }

  openNamedSession(inputValue) {
    this.session.openNamedSession(inputValue)
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
    utilPaste(commandText, true)
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
}

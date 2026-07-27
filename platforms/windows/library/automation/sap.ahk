#Include sap-session.ahk

class SapService {
  __New() {
    this.session := SapSessionService()
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
    Send("^s")
    Sleep(this._resolveOperationDelayMs())
    Send("^+{f2}")
  }

  startQuickDebug() {
    this._runQuickDebug()
  }

  openNamedSession(inputValue) {
    this.session.openNamedSession(inputValue)
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

}

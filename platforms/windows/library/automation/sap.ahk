class SapService {
  ; symbol is the hotstring trigger's second character ("+" or "-"),
  ; preserved in the inserted text so the user can see which trigger fired.
  ; "+"/"-  -> single-line inline comment (one code line).
  ; *+/*-   -> multi-line comment frame: opens with "{", closes with "}",
  ;            cursor is left on the blank line in between to write the
  ;            commented code block right away.
  insertCommentLine(symbol := "-") {
    this._insertCommentLine(symbol)
  }

  insertCommentBlock(symbol := "-") {
    this._insertCommentBlock(symbol)
  }

  _insertCommentLine(symbol) {
    utilPaste(this._buildCodeCommentLine(symbol))
  }

  _insertCommentBlock(symbol) {
    utilPaste(this._buildCommentMarkup(symbol))
    ; Move the cursor up from the closing line to the blank line left
    ; between the opening and closing frame lines.
    Send("{Up}")
  }

  _buildCodeSignature() {
    commentUser := utilResolveMemoryValue("sap_comment_user")
    if !commentUser || (commentUser = "sap_comment_user")
      commentUser := "NTP"
    return commentUser " " constDayEs
  }

  _buildCodeCommentLine(symbol) {
    return Chr(34) symbol this._buildCodeSignature()
  }

  _buildCommentMarkup(symbol) {
    signature := this._buildCodeSignature()
    openLine := "*" symbol "{" signature
    closeLine := "*" symbol "}" signature
    return openLine "`r`n`r`n" closeLine
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

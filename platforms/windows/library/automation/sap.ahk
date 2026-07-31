class SapService {
  ; symbol: trigger's "+"/"-". "+/-" = one line; *+/*- = {..} block frame,
  ; cursor left on the blank line between open/close.
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

  promptAndOpenAbapObject() {
    Send("^+a")
    Sleep(this._resolveOperationDelayMs())
    utilPaste("zpm*", true)
  }

  promptAndSearchAbapObject() {
    Send("^o")
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

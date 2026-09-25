class SapService {
  ; symbol is the trigger's "+" or "-". A line is `"+SIGNATURE`; a block is a
  ; *+{ ... *+} frame with the cursor left on the blank line between.
  insertCommentLine(symbol := "-") {
    utilPaste(Chr(34) symbol this._codeSignature())
  }

  insertCommentBlock(symbol := "-") {
    signature := this._codeSignature()
    utilPaste("*" symbol "{" signature "`r`n`r`n*" symbol "}" signature)
    Send("{Up}")
  }

  _codeSignature() {
    return utilMemoryValue("sap_comment_user", "NTP") " " constDayEs
  }

  isTextInputActive(winTitle := "A") {
    if !WinActive(winTitle)
      return false

    ; ControlGetFocus returns an HWND in v2; the class name ("Edit2") is what
    ; identifies a text field. No focused control makes ControlGetClassNN throw.
    try focusedControl := StrLower(ControlGetClassNN(ControlGetFocus("A")))
    catch
      return false

    return InStr(focusedControl, "edit")
  }

  runTcode(tcode) {
    command := this._normalizeTcode(tcode)
    if !command
      return

    ; Ctrl+/ focuses the SAP GUI command field so a data field is never
    ; overwritten when the hotkey fires elsewhere (macOS uses Cmd+Alt+O).
    Send("^/")
    Sleep(sapDelayMs)
    Send("^a")
    utilPaste(command)
    Send("{enter}")
  }

  promptAndOpenAbapObject() {
    Send("^+a")
    Sleep(sapDelayMs)
    utilPaste("zpm*")
  }

  promptAndSearchAbapObject() {
    Send("^o")
  }

  ; Mirrors normalizeTcode in platforms/macos/hammerspoon/actions.lua.
  _normalizeTcode(tcode) {
    command := Trim(tcode)
    if !command
      return ""
    if InStr(command, "/") = 1
      return command
    ; "=" OK-codes are already complete commands; "/n" would break them.
    if InStr(command, "=") = 1
      return StrUpper(command)
    return "/n" StrUpper(command)
  }
}

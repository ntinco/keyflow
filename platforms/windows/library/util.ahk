utilIsWindow(id) {
  s := WinGetStyle(id)
  return !((s & 0x08000000) || !(s & 0x10000000)) && !(WinGetExStyle(id) & 0x00000080)
}

utilKeyClear(key := "") {
  key := key ? key : A_Thishotkey
  key := StrReplace(key, "::", "")
  key := StrReplace(key, ":*:", "")
  key := StrReplace(key, ":*b0:", "")
  key := StrReplace(key, ":X*b0:", "")
  return StrReplace(key, "$<", "")
}

utilIsExit(noExit := "") {
  return !noExit && (InStr(A_Thishotkey, ":*") || InStr(A_Thishotkey, "::"))
}

utilClipboardRead(copyKeys := "^+c", waitSeconds := 0.5) {
  clipboardsaved := ClipboardAll()
  try {
    A_Clipboard := ""
    Send(copyKeys)
    ClipWait(waitSeconds)
    return A_Clipboard
  }
  finally {
    A_Clipboard := clipboardsaved
  }
}

utilPaste(data, noExit := "", clear := "") {
  if clear 
    Send("{backspace}")
  clipboardsaved := ClipboardAll()
  A_Clipboard := data
  ClipWait(0.5)
  Send("^v")
  Sleep(50)
  A_Clipboard := clipboardsaved
  if utilIsExit(noExit)
    Exit()
}

utilTooltip(msgv1, msgv2 := "", timer := 3000) {
  message := msgv1 " " msgv2
  if message {
    if WinActive(exeEverything) {
      CaretGetPos(&x, &y)
      if !x x := 0
        if !y y := 0
          try ToolTip(message, x + 15, y + 30, 13)
    }
    else ToolTip(message, , , 13)
    SetTimer(tooltipClose, timer)
  }
  tooltipClose() {
    ToolTip(, , , 13)
    SetTimer(, 0)
  }
}

utilGetMonitor(&right, &bottom) {
  static monitorDefault := 0x00000001
  monitorH := DllCall("user32\MonitorFromWindow", "ptr", WinGetID("A"), "uint", monitorDefault)
  monitorNow := Buffer(40, 0)
  NumPut("uint", monitorNow.size, monitorNow, 0)
  if (DllCall("user32\GetMonitorInfo", "ptr", monitorH, "ptr", monitorNow)) {
    right := NumGet(monitorNow, 12, "Int")
    bottom := NumGet(monitorNow, 16, "Int")
  }
}
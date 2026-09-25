utilIsWindow(id) {
  s := WinGetStyle(id)
  return !((s & 0x08000000) || !(s & 0x10000000)) && !(WinGetExStyle(id) & 0x00000080)
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

; Value from shared/data/memory-vars.ini [data], or defaultValue.
utilMemoryValue(name, defaultValue := "") {
  try value := IniRead(memoryVarsIniFile, "data", name, "")
  catch
    value := ""
  return value != "" ? value : defaultValue
}

utilRunCommand(command) {
  utilTooltip(command)
  Run(A_Comspec ' /c ' command, , "hide")
}

utilPaste(data) {
  clipboardsaved := ClipboardAll()
  A_Clipboard := data
  ClipWait(0.5)
  Send("^v")
  ; Some apps read the clipboard well after Ctrl+V; restoring too early pastes
  ; the user's previous clipboard instead (macOS waits 0.5 s).
  Sleep(300)
  A_Clipboard := clipboardsaved
}

utilTooltip(msgv1, msgv2 := "", timer := 3000) {
  message := Trim(msgv1 " " msgv2)
  if !message
    return
  ; Everything's window is large; show the tooltip next to its search caret.
  if WinActive(exeEverything) && CaretGetPos(&x, &y)
    ToolTip(message, x + 15, y + 30, 13)
  else
    ToolTip(message, , , 13)
  SetTimer(tooltipClose, -timer)

  tooltipClose() {
    ToolTip(, , , 13)
  }
}

; Work area (monitor minus taskbar) of the monitor holding the active window.
utilGetWorkArea(&top, &bottom) {
  static monitorDefaultToNearest := 0x00000002
  monitorH := DllCall("user32\MonitorFromWindow", "ptr", WinGetID("A"), "uint", monitorDefaultToNearest, "ptr")
  monitorInfo := Buffer(40, 0)
  NumPut("uint", monitorInfo.size, monitorInfo, 0)
  if !DllCall("user32\GetMonitorInfo", "ptr", monitorH, "ptr", monitorInfo)
    return false
  ; MONITORINFO.rcWork: left 20, top 24, right 28, bottom 32.
  top := NumGet(monitorInfo, 24, "Int")
  bottom := NumGet(monitorInfo, 32, "Int")
  return true
}

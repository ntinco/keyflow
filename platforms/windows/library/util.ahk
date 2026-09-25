utilIsWindow(id) {
  s := WinGetStyle(id)
  return !((s & 0x08000000) || !(s & 0x10000000)) && !(WinGetExStyle(id) & 0x00000080)
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

utilResolveMemoryValue(name) {
  value := ""
  try value := IniRead(memoryVarsIniFile, "data", name, "")
  catch
    value := ""
  if value != ""
    return value

  try value := %name%
  if value != ""
    return value

  return name
}

utilRunCommand(command) {
  global services
  if InStr(A_Thishotkey, "b0:") && services.HasOwnProp("launcher")
    services.launcher.dismissLauncherUi()

  utilTooltip(command)
  Run(A_Comspec ' /c ' command, , "hide")
}

utilPaste(data, noExit := "") {
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

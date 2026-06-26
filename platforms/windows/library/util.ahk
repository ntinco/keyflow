class AppUtils {
  __new() {
    this.A_Title := ""
    this.A_Class := ""
    this.A_Exe := ""
    this.A_Id := ""
    this.A_Control := ""
    this.A_Classnn := ""
  }

  isExit(noExit := "") {
    return this.shouldExitAfterHotkey(noExit)
  }

  shouldExitAfterHotkey(noExit := "") {
    subrc := false
    If !noExit
    {
      if instr(A_Thishotkey, ":*")
        subrc := true
      if instr(A_Thishotkey, "::")
        subrc := true
    }
    return subrc
  }

  iswindow(id) {
    style := WinGetStyle(id)
    if ((style & 0x08000000) || !(style & 0x10000000))
      return false
    if (WinGetExStyle(id) & 0x00000080)
      return false
    return true
  }

  keyClear(key := "") {
    If !key
      key := A_Thishotkey
    key := StrReplace(key, "::", "")
    key := StrReplace(key, ":*:", "")
    key := StrReplace(key, ":*b0:", "")
    key := StrReplace(key, ":X*b0:", "")
    key := StrReplace(key, "$<", "")
    return key
  }

  fileLines(file) {
    if !FileExist(file)
      return 0
    lines := 0
    Loop read, file
      lines := A_Index
    return lines
  }

  lines(data) {
    lines := 0
    loop parse data, "`n", "`r"
      lines := A_Index
    return lines
  }

  clipboardRead(copyKeys := "^+c", waitSeconds := 0.5) {
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

  paste(data, noExit := "", clear := "") {
    If clear
      Send("{backspace}")

    clipboardsaved := ClipboardAll()
    A_Clipboard := data
    ClipWait(0.5)
    Send("^v")
    Sleep(50)
    A_Clipboard := clipboardsaved

    If this.isExit(noExit)
      Exit()
  }

  tooltip(msgv1, msgv2 := "", timer := 3000) {
    message := msgv1 " " msgv2

    If message
    {
      if WinActive(exeEverything)
      {
        CaretGetPos(&x, &y)
        if !x
          x := 0
        if !y
          y := 0
        try ToolTip(message, x + 15, y + 30, 13)
      }
      Else
        ToolTip(message, , , 13)
      SetTimer(tooltipClose, timer)
    }

    tooltipClose()
    {
      ToolTip(, , , 13)
      SetTimer(, 0)
    }
  }

  winControl() {
    this.A_Classnn := "a_classnn"
    try this.A_Control := ControlGetFocus("A")
    If this.A_Control
      try this.A_Classnn := ControlGetClassNN(this.A_Control)
    return this.A_Classnn
  }

  winNow() {
    try this.A_Id := WinGetID("A")
    this._winSetFromId("A")
  }

  winNowMouse() {
    MouseGetPos(, , &id)
    this._winSetFromId("ahk_id " id)
  }

  _winSetFromId(winId) {
    try this.A_Title := WinGetTitle(winId)
    try this.A_Class := WinGetClass(winId)
    try this.A_Exe := WinGetProcessname(winId)
    If !this.A_Title
      this.A_Title := this.A_Class
  }

  getMonitor(&right, &bottom) {
    monitorData := this.getMonitorData()
    if monitorData
    {
      right := monitorData.right
      bottom := monitorData.bottom
    }
  }

  getMonitorId() {
    monitorData := this.getMonitorData()
    if monitorData
      return monitorData.right "" monitorData.bottom
  }

  getMonitorData() {
    static monitorDefault := 0x00000001
    monitorH := DllCall("user32\MonitorFromWindow", "ptr", WinGetID("A"), "uint", monitorDefault)
    monitorNow := Buffer(40, 0)
    NumPut("uint", monitorNow.size, monitorNow, 0)
    if (DllCall("user32\GetMonitorInfo", "ptr", monitorH, "ptr", monitorNow))
    {
      right := NumGet(monitorNow, 12, "Int")
      bottom := NumGet(monitorNow, 16, "Int")
      return {right: right, bottom: bottom}
    }
    return ""
  }
}


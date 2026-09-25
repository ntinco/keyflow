#Requires AutoHotkey v2.0
#SingleInstance Force
; Automatic runtime checks for the keyflow behavior that needs no SAP, Explorer
; or AIMP. Start keyflow first, run this script, and do not touch the keyboard
; or mouse until the report appears. The report is copied to the clipboard.

SendMode("Event")
SetKeyDelay(40, 10)
; keyflow's hooks ignore input from other scripts at SendLevel 0.
SendLevel(1)
SetTitleMatchMode(2)

results := []

addResult(name, status, detail := "") {
  results.Push({name: name, status: status, detail: detail})
}

check(name, actual, expected) {
  addResult(name, actual == expected ? "PASS" : "FAIL",
    actual == expected ? "" : "expected [" expected "] got [" actual "]")
}

DetectHiddenWindows(true)
if !WinExist("keyflow.ahk ahk_class AutoHotkey")
{
  MsgBox("keyflow.ahk is not running. Start it, then run this self-test again.", "keyflow self-test", "Icon!")
  ExitApp()
}
DetectHiddenWindows(false)

userClipboard := ClipboardAll()

; Hotstrings ---------------------------------------------------------------
typingGui := Gui("+AlwaysOnTop", "keyflow self-test")
typingEdit := typingGui.Add("Edit", "w500 r3")
typingGui.Show()

; keysAfter are sent once keyflow has finished reacting to keys.
typeAndRead(keys, keysAfter := "") {
  typingEdit.Value := ""
  WinActivate(typingGui.Hwnd)
  WinWaitActive(typingGui.Hwnd, , 2)
  ControlFocus(typingEdit)
  Sleep(150)
  Send(keys)
  Sleep(500)
  if keysAfter
  {
    Send(keysAfter)
    Sleep(200)
  }
  return typingEdit.Value
}

check("autocorrect: 'teh' + space", typeAndRead(" teh "), " the ")
check("no hotstring inside a word: 'xteh' + space", typeAndRead(" xteh "), " xteh ")
check("immediate snippet: 'bd,'", typeAndRead(" bd,"), " Buen día,")
A_Clipboard := "keyflow-selftest-clipboard"
ClipWait(1)
check(";; keeps the preceding character", typeAndRead("x `;;"), "x ñ")
check(";; restores the clipboard", A_Clipboard, "keyflow-selftest-clipboard")
check(";; fires inside a word", typeAndRead("ma;;ana"), "mañana")
; In Send, + is Shift: type a literal plus as {+}.
signaturePattern := "\S+ \d\d\.\d\d\.\d\d"
for symbol in ["-", "+"]
{
  typed := typeAndRead(' "' (symbol = "+" ? "{+}" : symbol))
  ok := typed ~= '^ "\' symbol signaturePattern '$'
  addResult('SAP comment line: ' Chr(34) symbol, ok ? "PASS" : "FAIL", ok ? "" : "got [" typed "]")
}
blockLines := StrSplit(typeAndRead("*{+}", "x"), "`n", "`r")
check("SAP comment block leaves the cursor on the middle line",
  blockLines.Length = 3 ? blockLines[2] : "(" blockLines.Length " lines)", "x")
typingGui.Destroy()

; Win+Esc ------------------------------------------------------------------
; Mirrors windows.ahk resizeHeight: 6 px overshoot for invisible frame borders.
border := 6

resizeCase(label, monitor, maximized) {
  MonitorGetWorkArea(monitor, &left, &top, &right, &bottom)
  windowGui := Gui("+Resize", "keyflow self-test " label)
  windowGui.Show("x" (left + 100) " y" (top + 100) " w400 h300")
  if maximized
    WinMaximize(windowGui.Hwnd)
  WinActivate(windowGui.Hwnd)
  WinWaitActive(windowGui.Hwnd, , 2)
  Sleep(200)
  if !maximized
    WinGetPos(&startX, , &startW, , windowGui.Hwnd)
  Send("#{Esc}")
  Sleep(600)
  WinGetPos(&x, &y, &w, &h, windowGui.Hwnd)
  state := WinGetMinMax(windowGui.Hwnd)
  windowGui.Destroy()

  expectedY := top - border
  expectedH := bottom - top + border * 2
  ok := state = 0 && Abs(y - expectedY) <= 2 && Abs(h - expectedH) <= 2
  if !maximized
    ok := ok && x = startX && w = startW
  addResult("Win+Esc " label, ok ? "PASS" : "FAIL",
    ok ? "" : Format("work area top={} bottom={}; expected y={} h={}, got x={} y={} w={} h={} state={}",
      top, bottom, expectedY, expectedH, x, y, w, h, state))
}

loop MonitorGetCount()
  resizeCase("monitor " A_Index, A_Index, false)
resizeCase("maximized window (primary)", MonitorGetPrimary(), true)

; Report ------------------------------------------------------------------
A_Clipboard := userClipboard
failures := 0
report := "keyflow self-test " FormatTime(, "yyyy-MM-dd HH:mm") " - AutoHotkey " A_AhkVersion
  . " - " MonitorGetCount() " monitor(s)`n`n"
for result in results
{
  if result.status = "FAIL"
    failures += 1
  report .= result.status "  " result.name (result.detail ? "`n      " result.detail : "") "`n"
}
report .= "`nManual checks still needed: SAP (Alt+4…0 in a data field, SAP hotstrings, =ED_OPTIONS),"
  . " F12 in Everything (.txt pastes, .exe ignored), Alt+P in Everything on a music path."
A_Clipboard := report
MsgBox(report "`n`nThis report was copied to the clipboard.", "keyflow self-test",
  failures ? "Icon!" : "Iconi")
ExitApp()

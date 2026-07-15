class WindowsService {
  resizeHeight() {
    if WinGetMinMax("A") = -1
      return
    if WinGetMinMax("A") = 1
    {
      WinRestore("A")
      Sleep(60)
    }

    this._winSizes(&x, &y, &width, &height, &right, &monitorHeight)
    targetY := -6
    targetHeight := monitorHeight + targetY * -2 - this._taskbarHeight()
    WinMove(x, targetY, width, targetHeight, "A")
  }

  _winSizes(&x, &y, &w, &h, &right, &monH) {
    CoordMode("Mouse")
    WinGetPos(&x, &y, &w, &h, "A")
    Sleep(100)
    utilGetMonitor(&right, &monH)
  }

_taskbarHeight() {
    if !WinExist("ahk_class Shell_TrayWnd")
        return 0
    WinGetPos(, &y1, , &h, "ahk_class Shell_TrayWnd")
    return (y1 = A_ScreenHeight - h) ? h : 0
}

  microphoneToggle(){
    CoordMode "Pixel"
    microphoneImage := A_ScriptDir "\\assets\\images\\microphone-icon.png"
    if not FileExist(microphoneImage)
      return

    if not ImageSearch(&FoundX, &FoundY, 0, 0, A_Screenwidth, A_Screenheight, microphoneImage)
      return

    Send("#!k")
    KeyWait "\"
    send("#!k")
  }

}

class WindowsService {
  closeWindow(closeRules := []) {
    utils.winNow()

    If this._isWindowActiveForGroup(closeRules, "sapCloseFlow")
      SetTimer(handleSapCloseCase, 100)

    if this._isWindowActiveForGroup(closeRules, "ctrlw")
      Send("^{w}")
    else if this._isWindowActiveForGroup(closeRules, "ctrlf4")
      Send("^{F4}")
    else
      Send("!{F4}")

    handleSapCloseCase() {
      If instr(utils.A_Title, "ebugg")
      {
        If WinWait("func.debugg.", , 5)
          Send("{enter}")
      }
      else if WinWait("Salir del sistema", , 5)
      {
        If !InStr(utils.A_Title, "odif")
          send "{tab}{enter}"
      }
      SetTimer , 0
    }
  }

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

  snapWindowRight(){
    this.resizeHeight()
    this._winSizes(&x, &y, &width, &height, &right, &bottom)
    WinMove(x, y, right - x, height, "A")
  }

  snapWindowLeft(){
    this.resizeHeight()
    this._winSizes(&x, &y, &width, &height, &right, &monitorHeight)
    height += y * -1 * 2 - this._taskbarHeight()
    WinMove(0, 0, x + width, height, "A")
  }

  _winSizes(&x, &y, &w, &h, &right, &monH) {
    utils.winNow()
    CoordMode("Mouse")
    WinGetPos(&x, &y, &w, &h, "A")
    Sleep(100)
    utils.getMonitor(&right, &monH)
  }

  _taskbarHeight() {
    WinGetPos(, &y1, , &h, classTaskbar)
    return (y1 = A_Screenheight - h) ? h : 0
  }

  soundToggle(lmin, lmax) {
    sleep(300)
    level := SoundGetVolume()

    If (level >= lmax)
      level := lmin
    Else If (level < lmax)
      level := lmax

    SoundSetVolume(level)
    sleep 2000
    Send("{Media_play_pause}")
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

  _isWindowActiveForGroup(groupRules, groupName) {
    For table in groupRules
    {
      If table[1] = groupName and WinActive(table[2])
        return true
    }
    return false
  }

}




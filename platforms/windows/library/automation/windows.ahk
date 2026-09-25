class WindowsService {
  resizeHeight() {
    if WinGetMinMax("A") = -1
      return
    if WinGetMinMax("A") = 1
    {
      WinRestore("A")
      Sleep(60)
    }

    if !utilGetWorkArea(&workTop, &workBottom)
      return
    WinGetPos(&x, , &width, , "A")
    ; Windows 10/11 frames carry ~6 px invisible borders; overshoot so the
    ; visible edges meet the work area.
    border := 6
    WinMove(x, workTop - border, width, workBottom - workTop + border * 2, "A")
  }
}

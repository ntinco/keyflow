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
    ; Elevated (admin) and some system windows reject moves from a
    ; non-elevated script with "Access is denied".
    try WinMove(x, workTop - border, width, workBottom - workTop + border * 2, "A")
    catch
      utilTooltip("Win+Esc: Windows does not allow resizing this window", "(admin or system window)")
  }
}

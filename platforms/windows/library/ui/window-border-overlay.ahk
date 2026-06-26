class WindowBorderOverlay extends Gui {
  __New(winFun := (*) => WinExist('A'), borderThickness := "3", borderColor := "red", offset := 0) {
    this.winFun := winFun
    this.borderThickness := borderThickness
    this.offset := offset
    super.__New("+AlwaysOnTop -Caption +ToolWindow", "GUI4Boarder")
    super.BackColor := borderColor
  }

  Call() {
    if (win := this.winFun()) && WinGetMinMax(win) == 0 {
      WinGetPos(&x, &y, &w, &h, win)
      offset := this.offset
      borderThickness := this.borderThickness
      outerX := offset
      outerY := offset
      outerX2 := w - offset
      outerY2 := h - offset
      innerX := borderThickness + offset
      innerY := borderThickness + offset
      innerX2 := w - borderThickness - offset
      innerY2 := h - borderThickness - offset
      WinSetRegion(outerX "-" outerY " " outerX2 "-" outerY " " outerX2 "-" outerY2 " " outerX "-" outerY2 " " outerX "-" outerY " " innerX "-" innerY " " innerX2 "-" innerY " " innerX2 "-" innerY2 " " innerX "-" innerY2 " " innerX "-" innerY, super.Hwnd)
      super.Show("w" . w . " h" . h . " x" . x . " y" . y . " NoActivate")
      super.Opt("+E0x800A8")
    } else {
      super.Hide()
    }
  }
}

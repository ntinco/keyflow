class DarkTheme {
  win(GuiObj, DarkMode := True)
  {
    global DarkColors := Map("Background", "0x202020", "Controls", "0x404040", "Font", "0xE0E0E0")
    global TextBackgroundBrush := DllCall("gdi32\CreateSolidBrush", "UInt", DarkColors["Background"], "Ptr")
    static PreferredAppMode := Map("Default", 0, "AllowDark", 1, "ForceDark", 2, "ForceLight", 3, "Max", 4)

    if (VerCompare(A_Osversion, "10.0.17763") >= 0)
    {
      dwmwaUseImmersiveDarkMode := 19
      if (VerCompare(A_Osversion, "10.0.18985") >= 0)
      {
        dwmwaUseImmersiveDarkMode := 20
      }
      global uxtheme := DllCall("kernel32\GetModuleHandle", "Str", "uxtheme", "Ptr")
      SetPreferredAppMode := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 135, "Ptr")
      FlushMenuThemes := DllCall("kernel32\GetProcAddress", "Ptr", uxtheme, "Ptr", 136, "Ptr")
      switch DarkMode
      {
        case True:
        {
          DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", GuiObj.hWnd, "Int", dwmwaUseImmersiveDarkMode, "Int*", True, "Int", 4)
          DllCall(SetPreferredAppMode, "Int", PreferredAppMode["ForceDark"])
          DllCall(FlushMenuThemes)
          GuiObj.BackColor := DarkColors["Background"]
        }
        default:
        {
          DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", GuiObj.hWnd, "Int", dwmwaUseImmersiveDarkMode, "Int*", False, "Int", 4)
          DllCall(SetPreferredAppMode, "Int", PreferredAppMode["Default"])
          DllCall(FlushMenuThemes)
          GuiObj.BackColor := "Default"
        }
      }
    }
  }

  ctrl(GuiObj, DarkMode := True)
  {
    static gwlWndproc := -4
    static gwlStyle := -16
    static esMultiline := 0x0004
    static lvmGettextcolor := 0x1023
    static lvmSettextcolor := 0x1024
    static lvmGettextbkcolor := 0x1025
    static lvmSettextbkcolor := 0x1026
    static lvmGetbkcolor := 0x1000
    static lvmSetbkcolor := 0x1001
    static lvmGetheader := 0x101F
    static GetWindowLong := A_Ptrsize = 8 ? "GetWindowLongPtr" : "GetWindowLong"
    static SetWindowLong := A_Ptrsize = 8 ? "SetWindowLongPtr" : "SetWindowLong"
    static Init := False
    static lvInit := False
    global IsDarkMode := DarkMode

    modeExplorer := (DarkMode ? "DarkMode_Explorer" : "Explorer")
    modeCfd := (DarkMode ? "DarkMode_CFD" : "CFD")
    modeItemsview := (DarkMode ? "DarkMode_ItemsView" : "ItemsView")

    for hWnd, GuiCtrlObj in GuiObj
    {
      switch GuiCtrlObj.Type
      {
        case "Button", "CheckBox", "ListBox", "UpDown":
          {
            DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", modeExplorer, "Ptr", 0)
          }
        case "ComboBox", "DDL":
          {
            DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", modeCfd, "Ptr", 0)
          }
        case "Edit":
          {
            if (DllCall("user32\" GetWindowLong, "Ptr", GuiCtrlObj.hWnd, "Int", gwlStyle) & esMultiline)
            {
              DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", modeExplorer, "Ptr", 0)
            }
            else
            {
              DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", modeCfd, "Ptr", 0)
            }
          }
        case "ListView":
          {
            if !(lvInit)
            {
              static lvTextcolor := SendMessage(lvmGettextcolor, 0, 0, GuiCtrlObj.hWnd)
              static lvTextbkcolor := SendMessage(lvmGettextbkcolor, 0, 0, GuiCtrlObj.hWnd)
              static lvBkcolor := SendMessage(lvmGetbkcolor, 0, 0, GuiCtrlObj.hWnd)
              lvInit := True
            }
            GuiCtrlObj.Opt("-Redraw")
            switch DarkMode
            {
              case True:
              {
                SendMessage(lvmSettextcolor, 0, DarkColors["Font"], GuiCtrlObj.hWnd)
                SendMessage(lvmSettextbkcolor, 0, DarkColors["Background"], GuiCtrlObj.hWnd)
                SendMessage(lvmSetbkcolor, 0, DarkColors["Background"], GuiCtrlObj.hWnd)
              }
              default:
              {
                SendMessage(lvmSettextcolor, 0, lvTextcolor, GuiCtrlObj.hWnd)
                SendMessage(lvmSettextbkcolor, 0, lvTextbkcolor, GuiCtrlObj.hWnd)
                SendMessage(lvmSetbkcolor, 0, lvBkcolor, GuiCtrlObj.hWnd)
              }
            }
            DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", modeExplorer, "Ptr", 0)

            ; To color the selection - scrollbar turns back to normal
            ;DllCall("uxtheme\SetWindowTheme", "Ptr", GuiCtrlObj.hWnd, "Str", Mode_ItemsView, "Ptr", 0)

            ; Header Text needs some NM_CUSTOMDRAW coloring
            lvHeader := SendMessage(lvmGetheader, 0, 0, GuiCtrlObj.hWnd)
            DllCall("uxtheme\SetWindowTheme", "Ptr", lvHeader, "Str", modeItemsview, "Ptr", 0)
            GuiCtrlObj.Opt("+Redraw")
          }
      }
    }

    if !(Init)
    {
      ; https://www.autohotkey.com/docs/v2/lib/CallbackCreate.htm#ExSubclassGUI
      global WindowProcNew := CallbackCreate(uiWindowproc)  ; Avoid fast-mode for subclassing.
      global WindowProcOld := DllCall("user32\" SetWindowLong, "Ptr", GuiObj.Hwnd, "Int", gwlWndproc, "Ptr", WindowProcNew, "Ptr")
      Init := True
    }
  }
}

; Used by SapLogonService GUI helpers (`dynpro := dynpro()` in saplogon.ahk).
dynpro() {
  return Gui()
}

uiWindowproc(hwnd, uMsg, wParam, param)
{
  critical
  static wmCtlcoloredit := 0x0133
  static wmCtlcolorlistbox := 0x0134
  static wmCtlcolorbtn := 0x0135
  static wmCtlcolorstatic := 0x0138
  static dcBrush := 18

  if (IsDarkMode)
  {
    switch uMsg
    {
      case wmCtlcoloredit, wmCtlcolorlistbox:
      {
        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkColors["Font"])
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkColors["Controls"])
        DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkColors["Controls"], "UInt")
        return DllCall("gdi32\GetStockObject", "Int", dcBrush, "Ptr")
      }
      case wmCtlcolorbtn:
      {
        DllCall("gdi32\SetDCBrushColor", "Ptr", wParam, "UInt", DarkColors["Background"], "UInt")
        return DllCall("gdi32\GetStockObject", "Int", dcBrush, "Ptr")
      }
      case wmCtlcolorstatic:
      {
        DllCall("gdi32\SetTextColor", "Ptr", wParam, "UInt", DarkColors["Font"])
        DllCall("gdi32\SetBkColor", "Ptr", wParam, "UInt", DarkColors["Background"])
        return TextBackgroundBrush
      }
    }
  }
  return DllCall("user32\CallWindowProc", "Ptr", WindowProcOld, "Ptr", hwnd, "UInt", uMsg, "Ptr", wParam, "Ptr", param)
}

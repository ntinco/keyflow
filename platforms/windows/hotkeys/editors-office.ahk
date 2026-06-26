#hotif winactive(exeWinword)
!6::{
trackEditorsHotkeyUsage("!6", "winword")
services.snipaste.resizeOffice("60")
}
!7::{
trackEditorsHotkeyUsage("!7", "winword")
services.snipaste.resizeOffice("70")
}
~^v::{
trackEditorsHotkeyUsage("~^v", "winword")
services.snipaste.pasteResizeOffice()
}

#hotif winactive(classExcel)
!right::{
trackEditorsHotkeyUsage("!right", "excel")
Send("^pgdn")
}
!left::{
trackEditorsHotkeyUsage("!left", "excel")
Send("^pgup")
}
^right::{
trackEditorsHotkeyUsage("^right", "excel")
Send("!{right}")
}
^left::{
trackEditorsHotkeyUsage("^left", "excel")
Send("!{left}")
}

#hotif winactive(titleLibreCalc)
!right::{
trackEditorsHotkeyUsage("!right", "libre-calc")
Send("^pgdn")
}
!left::{
trackEditorsHotkeyUsage("!left", "libre-calc")
Send("^pgup")
}

#hotif winactive("Visual Basic")
f5::{
trackEditorsHotkeyUsage("f5", "visual-basic")
Send("{f8}")
}
f6::{
trackEditorsHotkeyUsage("f6", "visual-basic")
Send("+{f8}")
}
f7::{
trackEditorsHotkeyUsage("f7", "visual-basic")
Send("^+{f8}")
}
f8::{
trackEditorsHotkeyUsage("f8", "visual-basic")
Send("{f5}")
}


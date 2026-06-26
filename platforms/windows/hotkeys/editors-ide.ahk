#hotif winactive("ahk_group group_vscode_editors")
!pgdn::{
trackEditorsHotkeyUsage("!pgdn", "vscode-group")
Send("^pgdn")
}
!pgup::{
trackEditorsHotkeyUsage("!pgup", "vscode-group")
Send("^pgup")
}
+f1::{
trackEditorsHotkeyUsage("+f1", "vscode-group")
Send("^+o")
}
!f1::{
trackEditorsHotkeyUsage("!f1", "vscode-group")
services.dynamic.openEditorCommandPaletteWithPercent()
}
^f1::{
trackEditorsHotkeyUsage("^f1", "vscode-group")
Send("^+p")
}
!k::{
trackEditorsHotkeyUsage("!k", "vscode-group")
Send("^!i")
}

#hotif winactive(exeCursor)
+f1::{
trackEditorsHotkeyUsage("+f1", "cursor")
Send("^+o")
}
!f1::{
trackEditorsHotkeyUsage("!f1", "cursor")
services.dynamic.openEditorCommandPaletteWithPercent()
}
^f1::{
trackEditorsHotkeyUsage("^f1", "cursor")
Send("^+p")
}


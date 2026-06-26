#hotif winactive("ock") or winactive(".kdbx")
f1::{
trackDomainsHotkeyUsage("f1", "keepass")
services.dynamic.unlockKeepassAndClosePrompt()
}

#hotif winactive(titleSnipaste)
~enter::{
trackDomainsHotkeyUsage("~enter", "snipaste")
services.snipaste.copyPaste("",snipasteTargets)
}

#hotif winactive("ahk_group group_launcher")
f12::{
trackDomainsHotkeyUsage("f12", "launcher")
services.launcher.paste()
}
^s::{
trackDomainsHotkeyUsage("^s", "launcher")
services.launcher.save()
}
!p::{
trackDomainsHotkeyUsage("!p", "launcher")
services.launcher.playSelectedMedia()
}

#hotif winactive(exeXyplorer)
f5::{
trackDomainsHotkeyUsage("f5", "xyplorer")
services.dynamic.refreshAndCloseXyplorerTab()
}

#hotif winactive(titleTaskTimeTracker)
f1::{
trackDomainsHotkeyUsage("f1", "task-time-tracker")
services.dynamic.copyAndRefreshAppTime()
}


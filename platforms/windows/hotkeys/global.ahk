:*:;;::{
utils.paste("ñ",,True)
}
:*:"+::{
services.saplogon.insertSapCommentLineWithProjectDefaults()
}
:*:"-::{
services.saplogon.insertSapCommentLineWithProjectDefaults()
}
:*:*+::{
services.saplogon.insertSapCommentBlockWithProjectDefaults()
}
:*:*-::{
services.saplogon.insertSapCommentBlockWithProjectDefaults()
}
::sp::{
utils.paste("summary in prompt",,true)
}
!e::{
trackHotkeyUsageScoped("!e", "hotkeys/global.ahk", "global")
services.windowsGroup.activateGroup(appActivationTargets,"apps_sap")
}
!a::{
trackHotkeyUsageScoped("!a", "hotkeys/global.ahk", "global")
services.windowsGroup.activateGroup(appActivationTargets,"apps_control")
}
!s::{
trackHotkeyUsageScoped("!s", "hotkeys/global.ahk", "global")
services.windowsGroup.activateGroup(appActivationTargets,"apps_support")
}
!d::{
trackHotkeyUsageScoped("!d", "hotkeys/global.ahk", "global")
services.windowsGroup.activateGroup(appActivationTargets,"apps_ide")
}
!f::{
trackHotkeyUsageScoped("!f", "hotkeys/global.ahk", "global")
services.windowsGroup.activateGroup(appActivationTargets,"apps_note")
}
f12::{
trackHotkeyUsageScoped("f12", "hotkeys/global.ahk", "global")
services.video.control()
}
#f1::{
trackHotkeyUsageScoped("#f1", "hotkeys/global.ahk", "global")
services.saplogon.openSapDevSessionFromHotkey()
}
#f2::{
trackHotkeyUsageScoped("#f2", "hotkeys/global.ahk", "global")
services.saplogon.openSapQasSessionFromHotkey()
}
#f3::{
trackHotkeyUsageScoped("#f3", "hotkeys/global.ahk", "global")
services.saplogon.openSapPrdSessionFromHotkey()
}
#esc::{
trackHotkeyUsageScoped("#esc", "hotkeys/global.ahk", "global")
services.windows.resizeHeight()
}
#!left::{
trackHotkeyUsageScoped("#!left", "hotkeys/global.ahk", "global")
services.windows.snapWindowLeft()
}
#!right::{
trackHotkeyUsageScoped("#!right", "hotkeys/global.ahk", "global")
services.windows.snapWindowRight()
}
#e::{
trackHotkeyUsageScoped("#e", "hotkeys/global.ahk", "global")
services.run.openApp(exeXyplorer)
}
#b::{
trackHotkeyUsageScoped("#b", "hotkeys/global.ahk", "global")
services.windows.soundToggle("40","90")
}
~\::{
trackHotkeyUsageScoped("~\", "hotkeys/global.ahk", "global")
services.windows.microphoneToggle()
}
^\::{
trackHotkeyUsageScoped("^\", "hotkeys/global.ahk", "global")
Send("#!k")
}
xbutton2::{
trackHotkeyUsageScoped("xbutton2", "hotkeys/global.ahk", "global")
services.snipaste.copyPaste("{printscreen}",snipasteTargets)
}
xbutton1::{
trackHotkeyUsageScoped("xbutton1", "hotkeys/global.ahk", "global")
services.snipaste.copyPaste("^{printscreen}",snipasteTargets)
}
$^!+a::{
trackHotkeyUsageScoped("$^!+a", "hotkeys/global.ahk", "global")
reload()
}
~^c::{
trackHotkeyUsageScoped("~^c", "hotkeys/global.ahk", "global")
services.snipaste.ctrlC()
}

trackHotkeyUsageScoped(hotkeyId, sourceFile := "hotkeys/global.ahk", sourceGroup := "global") {
  if IsSet(services) && services.HasOwnProp("hotkeyUsage")
    services.hotkeyUsage.track(hotkeyId, sourceFile, sourceGroup)
}

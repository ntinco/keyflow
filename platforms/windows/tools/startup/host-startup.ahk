scriptDir := RegExReplace(A_LineFile, "\\[^\\]+$")
rootDir := scriptDir "\..\.."

; --- Configuration: edit these values directly ---
downloadsPath := EnvGet("USERPROFILE") "\Downloads"
baseDrive := "h:"
workspaceDrive := "i:"
workspacePath := downloadsPath "\.sync\GitHub"
aimpPortableLink := baseDrive "\.sync\links\AimpPortable.exe.lnk"
dittoPortableLink := baseDrive "\.sync\links\DittoPortable.exe.lnk"
portableLinksCsv := "\.sync\links\everything.exe.lnk;\.sync\links\flow.Launcher.exe.lnk;\.sync\links\keePassXCPortable.exe.lnk;\.sync\links\rbtray.exe.lnk;\.sync\links\ShareX.exe.lnk;\.sync\links\Snipaste.exe.lnk;\.sync\links\stretchly.exe.lnk;\.sync\links\workrave.exe.lnk;\.sync\links\tbaction.exe.lnk;\.sync\links\handy.exe.lnk;\.sync\links\cherry-studio.exe.lnk"
launchDelayMs := 5000
; -------------------------------------------------

run(A_ComSpec ' /k subst ' baseDrive ' "' downloadsPath '"', , "hide")
run(A_ComSpec ' /k subst ' workspaceDrive ' "' workspacePath '"', , "hide")
Sleep(launchDelayMs)

Run(rootDir "\keyflow.ahk")

runPortableLink(aimpPortableLink)
runPortableLink(dittoPortableLink)
for linkPath in startupConfigCsvArray(portableLinksCsv)
  runPortableLink(baseDrive . linkPath)

runPortableLink(linkPath) {
  if !linkPath
    return
  if !FileExist(linkPath)
    return

  Run(linkPath)
  if WinWait("(PortableApps.com Launcher)", , 5)
  {
    WinActivate("(PortableApps.com Launcher)")
    Sleep(100)
    Send("{enter}")
    Sleep(100)
    Run(linkPath)
  }
}

startupConfigCsvArray(csvText) {
  output := []
  for part in StrSplit(csvText, ";")
  {
    value := Trim(part)
    if value
      output.Push(value)
  }
  return output
}

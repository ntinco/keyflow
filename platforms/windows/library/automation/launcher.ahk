class LauncherService {
  supportedPasteExtensionsPattern := "i)(txt|abap|md|ahk)"

  _isMediaPath(filename) {
    return InStr(filename, "music") or InStr(filename, "audio") or InStr(filename, "video")
  }

  dismissLauncherUi(shortWait := true) {
    If winactive(exeEverything)
    {
      Sleep(50)
      Send("^{w}")
    }

    if winactive(exeSwitcheroo) or WinActive(exeFlowlauncher)
      Send("{esc}")

    Sleep(shortWait ? 10 : 500)
  }

  openSelectedMedia() {
    filename := utilClipboardRead("^+c", 0.3)

    if this._isMediaPath(filename)
    {
      this.dismissLauncherUi()
      this._incrementRunCount(filename)
      utilRunCommand("aimpportable " filename)
    }
  }

  pasteSelectedFiles() {
    files := this._readSelectedFiles()
    pastedAny := false

    this.dismissLauncherUi()

    Loop Parse, files, "`n", "`r"
    {
      selectedFile := A_Loopfield
      if !this._isPasteableTextFile(selectedFile)
        continue
      if !FileExist(selectedFile)
        continue

      this._incrementRunCount(selectedFile)
      utilPaste(Fileread(selectedFile), True)
      pastedAny := true
    }

    this._waitAfterPaste()

    utilTooltip("Pasted", pastedAny ? "ok" : "no valid file")
  }

  _readSelectedFiles() {
    files := utilClipboardRead("^+c", 0.7)
    if !files
    {
      Send("{down}")
      files := utilClipboardRead("^+c", 0.7)
    }
    return files
  }

  _incrementRunCount(filename) {
    if SubStr(filename, -1) = "\"
      filename := SubStr(filename, 1, -1)

    if InStr(filename, ":\")
      utilRunCommand('""' fileEverythingCli '" -inc-run-count "' filename '""')
  }

  _isPasteableTextFile(filename) {
    return (filename ~= this.supportedPasteExtensionsPattern)
  }

  _waitAfterPaste() {
    If WinActive("YM")
    {
      Sleep 3000
      Send("^{f3}")
      return
    }
    Sleep 200
  }
}

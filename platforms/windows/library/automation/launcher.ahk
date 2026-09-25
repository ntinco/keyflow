class LauncherService {
  supportedPasteExtensionsPattern := "i)\.(txt|abap|md|ahk)$"

  _isMediaPath(filename) {
    return InStr(filename, "music")
  }

  _dismissLauncherUi() {
    if WinActive(exeEverything)
    {
      Sleep(50)
      Send("^{w}")
    }
    else if WinActive(exeFlowlauncher)
      Send("{esc}")
    Sleep(10)
  }

  openSelectedMedia() {
    ; Only the first selected path is played; a multi-line value would break
    ; the quoted command line.
    filename := Trim(StrSplit(utilClipboardRead("^+c", 0.3), "`n", "`r")[1])

    if !this._isMediaPath(filename)
    {
      utilTooltip("Alt+P: not a media file", filename)
      return
    }
    this._dismissLauncherUi()
    this._incrementRunCount(filename)
    utilRunCommand('aimpportable "' filename '"')
  }

  pasteSelectedFiles() {
    files := this._readSelectedFiles()
    pastedAny := false

    this._dismissLauncherUi()

    loop parse, files, "`n", "`r"
    {
      selectedFile := A_LoopField
      if !this._isPasteableTextFile(selectedFile)
        continue
      if !FileExist(selectedFile)
        continue

      this._incrementRunCount(selectedFile)
      utilPaste(FileRead(selectedFile))
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
    ; "YM" matches windows titled with the YMT workspace prefix; that app
    ; needs a long settle delay before Ctrl+F3.
    if WinActive("YM")
    {
      Sleep 3000
      Send("^{f3}")
      return
    }
    Sleep 200
  }
}

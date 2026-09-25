class LauncherService {
  supportedPasteExtensionsPattern := "i)\.(txt|abap|md|ahk)$"

  mediaExtensionsPattern := "i)\.(mp3|m4a|aac|flac|wav|ogg|opus|wma|mp4|m4v|mkv|avi|mov|wmv|webm|flv)$"

  _isMediaPath(filename) {
    return (filename ~= this.mediaExtensionsPattern)
      or InStr(filename, "music") or InStr(filename, "audio") or InStr(filename, "video")
  }

  dismissLauncherUi(shortWait := true) {
    ; Close the window directly instead of sending Ctrl+W, which can be lost
    ; while the Ctrl+Shift+C copy is still releasing; then wait until the
    ; window behind it is active so the paste lands there.
    if WinActive(exeEverything)
    {
      WinClose(exeEverything)
      WinWaitNotActive(exeEverything, , 1)
    }

    if winactive(exeSwitcheroo) or WinActive(exeFlowlauncher)
      Send("{esc}")

    Sleep(shortWait ? 10 : 500)
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
    this.dismissLauncherUi()
    this._incrementRunCount(filename)
    utilRunCommand('aimpportable "' filename '"')
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
    ; "YM" matches any window titled with the YMT workspace prefix
    ; (see constants-core.ahk); that app needs a long settle delay before Ctrl+F3.
    If WinActive("YM")
    {
      Sleep 3000
      Send("^{f3}")
      return
    }
    Sleep 200
  }
}

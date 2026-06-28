class LauncherService {
  supportedPasteExtensionsPattern := "i)(txt|abap|md|ahk)"

  _isMediaPath(filename) {
    return InStr(filename, "music") or InStr(filename, "audio") or InStr(filename, "video")
  }

  closeAndWait(shortWait := true) {
    If winactive(exeEverything)
    {
      Sleep(50)
      Send("^{w}")
    }

    if winactive(exeSwitcheroo) or WinActive(exeFlowlauncher)
      Send("{esc}")

    Sleep(shortWait ? 10 : 500)
  }

  playSelectedMedia() {
    filename := utils.clipboardRead("^+c", 0.3)

    if this._isMediaPath(filename)
    {
      this.closeAndWait()
      services.everything.incrementRunCount(filename)
      services.run.runCommand("aimpportable " filename)
    }
  }

  paste() {
    files := this._readSelectedFiles()
    pastedAny := false

    utils.winNow()
    this.closeAndWait()

    Loop Parse, files, "`n", "`r"
    {
      selectedFile := A_Loopfield
      if !this._isPasteableTextFile(selectedFile)
        continue
      if !FileExist(selectedFile)
        continue

      services.everything.incrementRunCount(selectedFile)
      utils.paste(Fileread(selectedFile), True)
      pastedAny := true
    }

    this._waitAfterPaste()

    utils.tooltip("Pasted", pastedAny ? "ok" : "no valid file")
  }

  save() {
    codes := A_Clipboard
    selectedFile := this._readSelectedFile()

    this.closeAndWait()

    If codes and selectedFile
    {
      services.everything.incrementRunCount(selectedFile)
      FileDelete(selectedFile)
      FileAppend(codes, selectedFile, "UTF-8")
      A_Clipboard := ""
    }

    utils.tooltip("Saved", selectedFile)
  }

  _readSelectedFiles() {
    files := utils.clipboardRead("^+c", 0.7)
    if !files
    {
      Send("{down}")
      files := utils.clipboardRead("^+c", 0.7)
    }
    return files
  }

  _readSelectedFile() {
    if winactive(exeXyplorer)
      return utils.clipboardRead("^p", 0.5)
    return utils.clipboardRead("^+c", 0.4)
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


class RunService {
  open(target, noExit := "") {
    this._prepareHotkeyLaunch()

    target := services.memory.resolveTargetTitle(target, &title)
    if !target
      msgbox(A_Thisfunc ": " target " - app esta vacia")
    else
      this._activateOrRunTarget(target, title)

    if utils.isExit(noExit)
      Exit()

    return title
  }

  runCommand(command) {
    this._prepareHotkeyLaunch()

    utils.tooltip(command)
    Run(A_Comspec ' /c ' command, ,"hide")
  }

  runPythonScript(filename) {
    this._prepareHotkeyLaunch()

    utils.tooltip(filename)
    this.runCommand( '"python "' filename '""' )
  }

  openApp(appCandidates) {
    app := this._firstAppItem(appCandidates)

    if this._activateIfExists(app)
    {
      return
    }

    this.open(this._normalizeAppTarget(app))
  }

  createFromTemplate(app, title, model := "", confirm := "") {
    if !confirm
      confirm := MsgBox("Desea crear " app "?", "", 4)
    if (confirm = "yes")
    {
      If model
      {
        Try FileCopy(services.memory.getValue(model), app)
      }
      Else
        DirCreate(app)

      this._run(app)
      If WinWait(title, , 10)
        WinActivate(title)
    }
  }

  _run(filename) {
    utils.tooltip(filename)

    try run(filename)
    catch as e
      MsgBox(type(e) " en " e.What ", linea " e.Line "`nTarget: " filename)
  }

  _prepareHotkeyLaunch() {
    if instr(A_Thishotkey, "b0:")
      services.launcher.closeAndWait()
  }

  _firstAppItem(appCandidates) {
    apps := strsplit(appCandidates, ",")
    return Trim(apps[1])
  }

  _normalizeAppTarget(app) {
    app := StrReplace(app, "ahk_exe ")
    app := StrReplace(app, ".exe")
    app := StrReplace(app, ".bin")
    return app
  }

  _activateIfExists(target) {
    if WinExist(target)
    {
      WinActivate(target)
      return true
    }
    return false
  }

  _activateOrRunTarget(target, title := "") {
    if (title and WinExist(title))
    {
      WinActivate(title)
      return
    }

    this._run(target)
    if title and WinWait(title, , 7)
      WinActivate(title)
  }

}


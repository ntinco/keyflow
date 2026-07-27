class RunService {
  runCommand(command) {
    this._prepareHotkeyLaunch()

    utilTooltip(command)
    Run(A_Comspec ' /c ' command, ,"hide")
  }

  _prepareHotkeyLaunch() {
    if instr(A_Thishotkey, "b0:")
      services.launcher.dismissLauncherUi()
  }
}

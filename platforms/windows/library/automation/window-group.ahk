class WindowGroupService {
  __new() {
    this.cachedWindows := []
    this.currentId := ""
    this.currentTitle := ""
    this.currentClass := ""
    this.currentExe := ""
  }

  activateGroup(rules := [], name := "") {
    this._captureCurrentWindowContext()

    ; The window list is cached while Alt stays held so repeated presses
    ; rotate through the same snapshot.
    windows := this.cachedWindows
    if windows.Length = 0
      this._collectWindows(rules, &windows)
    this._activate(&windows, name)
    this.cachedWindows := windows
  }

  _activate(&windows, name) {
    actives := []
    this._groupActive(&windows, &name, &actives)
    if actives.Length > 0
    {
      targetId := actives[1].id
      ; If the top match in this group is the window already active, cycle
      ; its internal tabs/documents instead of re-activating the same window.
      sameWindowAlreadyActive := targetId = "ahk_id " this.currentId
      WinActivate(targetId)
      if sameWindowAlreadyActive
        Send("^{tab}")
      this.currentId := targetId
    }
    else
      utilTooltip("Windows not open: " StrUpper(name))

    SetTimer(_watchAltRelease, 10)
    _watchAltRelease() {
      if !GetKeyState("Alt")
      {
        this._resetGroupState()
        SetTimer , 0
      }
    }
  }

  ; rules: [group, pattern] pairs; pattern is an ahk_exe/ahk_class spec or a
  ; title fragment (see appActivationTargets in constants-core.ahk).
  _collectWindows(rules, &windows) {
    managers := WinGetList(, , "Program Manager",)
    for manager in managers
    {
      id := "ahk_id " manager
      try exe := WinGetProcessname(id)
      catch
        continue
      classLocal := WinGetClass(id)
      title := WinGetTitle(WinExist(id))

      if !title or !utilIsWindow(id)
        continue

      matchedPattern := ""
      matchedGroup := ""
      for rule in rules
      {
        ruleGroup := rule[1], rulePattern := rule[2]
        if InStr(rulePattern, exe)
          matchedPattern := exe
        else if InStr(rulePattern, classLocal)
          matchedPattern := classLocal
        else if InStr(title, rulePattern)
          matchedPattern := rulePattern
        else
          continue
        matchedGroup := ruleGroup "," matchedGroup
      }

      if matchedPattern
        windows.Push({id: id, group: matchedGroup, match: matchedPattern})
      else
        windows.Push({id: id, group: "zzz", match: exe})
    }
  }

  _groupActive(&windows, &name, &actives) {
    if !name
    {
      name := "zzz"
      for win in windows
      {
        if InStr(win.match, this.currentExe) or InStr(win.match, this.currentClass) or InStr(this.currentTitle, win.match)
        {
          name := win.group
          break
        }
      }
    }

    for i, win in windows
    {
      if this._isGroupMatch(win, name)
      {
        if win.id = "ahk_id " this.currentId
        {
          windows.Push(win)
          windows.RemoveAt(i)
        }
        break
      }
    }

    for win in windows
    {
      if this._isGroupMatch(win, name)
        actives.Push(win)
    }
  }

  _isGroupMatch(win, name) {
    return InStr(win.group, name) or InStr(name, win.match)
  }

  _captureCurrentWindowContext() {
    this.currentId := (WinExist("A") ? WinGetID("A") : "")
    this.currentTitle := (this.currentId ? (t := WinGetTitle("A"), t ? t : WinGetClass("A")) : "")
    this.currentClass := (this.currentId ? WinGetClass("A") : "")
    this.currentExe := (this.currentId ? WinGetProcessname("A") : "")
  }

  _resetGroupState() {
    this.cachedWindows := []
    this.currentId := ""
    this.currentTitle := ""
    this.currentClass := ""
    this.currentExe := ""
  }
}

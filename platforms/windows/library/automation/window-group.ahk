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

    windows := this.cachedWindows
    if this.cachedWindows.Length = 0
      this._collectWindows(rules, &windows, name)
    this.cachedWindows := windows
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

  _collectWindows(rules, &windows, lastNumber) {
    correl := 0

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
        rulePattern := this._rulePattern(rule)
        ruleGroup := this._ruleGroup(rule)

        if !rulePattern
          continue

        currentMatch := ""
        if InStr(rulePattern, exe)
          currentMatch := matchedPattern := exe
        else if InStr(rulePattern, classLocal)
          currentMatch := matchedPattern := classLocal
        else if InStr(title, rulePattern)
          currentMatch := matchedPattern := rulePattern

        if currentMatch
          matchedGroup := ruleGroup "," matchedGroup
      }
      correl += 1

      if matchedPattern
        windows.Push(this._windowInfo(exe, classLocal, title, id, matchedGroup, matchedPattern, correl))
      else if StrLen(lastNumber) > 2
        windows.Push(this._windowInfo(exe, classLocal, title, id, "zzz", exe, correl))
      else
      {
        windows.Push(this._windowInfo(exe, classLocal, title, id, lastNumber, exe, correl))
        if windows.Length = lastNumber
          return
      }
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

  _windowInfo(exe, className, title, id, group, match, index) {
    return {
      exe: exe,
      className: className,
      title: title,
      id: id,
      group: group,
      match: match,
      index: index
    }
  }

  _ruleGroup(rule) {
    if (Type(rule) = "Object")
    {
      if rule.HasOwnProp("group")
        return rule.group
      if rule.HasOwnProp("name")
        return rule.name
    }

    try return rule[1]
    return ""
  }

  _rulePattern(rule) {
    if (Type(rule) = "Object")
    {
      if rule.HasOwnProp("pattern")
        return rule.pattern
      if rule.HasOwnProp("match")
        return rule.match
    }

    try return rule[2]
    return ""
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

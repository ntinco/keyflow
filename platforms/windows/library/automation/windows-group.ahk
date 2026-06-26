class WindowsGroupService {
  __new() {
    this.wgWin := []
    this.wgId := ""
    this.wgIdlast := ""
    this.wgKey := ""
  }

  activateGroup(rules := [], name := "") {
    utils.winNow()
    this.wgKey := A_Thishotkey
    if !this.wgId
      this.wgId := utils.A_Id
    this.wgIdlast := utils.A_Id

    windows := this.wgWin
    if this.wgWin.Length = 0
      this._collectWindows(rules, &windows, name)
    this.wgWin := windows
    this._activate(&windows, name)
    this.wgWin := windows
  }

  _activate(&windows, name) {
    actives := []
    this._groupActive(&windows, &name, &actives)
    if actives.Length > 0
    {
      targetId := actives[1].id
      If WinActivate(targetId) = utils.A_Exe
        send("^{tab}")
      else
        WinActivate(targetId)
      utils.A_Id := targetId
    }
    else
      utils.tooltip("Windows not open: " StrUpper(name))

    SetTimer(jobGroupKey, 10)
    jobGroupKey() {
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
    For manager in managers
    {
      id := "ahk_id " manager
      try exe := WinGetProcessname(id)
      catch
        continue
      classLocal := WinGetClass(id)
      title := WinGetTitle(WinExist(id))

      if !title or !utils.iswindow(id)
        Continue

      matchedPattern := ""
      matchedGroup := ""
      for rule in rules
      {
        rulePattern := this._rulePattern(rule)
        ruleGroup := this._ruleGroup(rule)

        if !rulePattern
          continue

        currentMatch := ""
        if instr(rulePattern, exe)
          currentMatch := matchedPattern := exe
        else if instr(rulePattern, classLocal)
          currentMatch := matchedPattern := classLocal
        else if instr(title, rulePattern)
          currentMatch := matchedPattern := rulePattern

        if currentMatch
          matchedGroup := ruleGroup "," matchedGroup
      }
      correl += 1

      if matchedPattern
        windows.push(this._windowInfo(exe, classLocal, title, id, matchedGroup, matchedPattern, correl))
      else if StrLen(lastNumber) > 2
        windows.push(this._windowInfo(exe, classLocal, title, id, "zzz", exe, correl))
      else
      {
        windows.push(this._windowInfo(exe, classLocal, title, id, lastNumber, exe, correl))
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
        if instr(win.match, utils.A_Exe) or instr(win.match, utils.A_Class) or instr(utils.A_Title, win.match)
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
        if win.id = "ahk_id " utils.A_Id
        {
          windows.push(win)
          windows.RemoveAt(i)
        }
        break
      }
    }

    for win in windows
    {
      if this._isGroupMatch(win, name)
        actives.push(win)
    }
  }

  _isGroupMatch(win, name) {
    return instr(win.group, name) or instr(name, win.match)
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

  _resetGroupState() {
    this.wgKey := ""
    this.wgWin := []
    this.wgId := ""
    this.wgIdlast := ""
  }
}


/**
 * DynamicService
 * Executes dynamic action sequences: Send, WinWaitActive, Click, Sleep
 * Supports memory var substitution: %varName%
 * 
 * Usage:
 *   services.dynamic.execute("^+a; WinWaitActive,Open ABAP; zpm*", 100)
 *   services.dynamic.execute("^c; ^r", 500)
 *   services.dynamic.execute("%keepassXc%; {enter}; WinWaitActive,Password; !{f4}", 100)
 */

class DynamicService {
  debugMode := false  ; Set true to see debug logs for each action

  openEditorCommandPaletteWithPercent() {
    return this.execute("^p; %")
  }

  openSublimeCommandPaletteByTag() {
    return this.execute("^p; {#}")
  }

  openTeamsSearchAndGoToField() {
    return this.execute("^e; ^g", 200)
  }

  ; unlockKeepassAndClosePrompt() {
  ;   return this.execute("%keepassXc%; {enter}; WinWaitActive,Password", 100)
  ; }

  refreshAndCloseXyplorerTab() {
    return this.execute("{f5}; ^+{f4}")
  }

  copyAndRefreshAppTime() {
    return this.execute("^c; ^r", 500)
  }

  openEdgeReadAloud() {
    return this.execute("!{q}; {down 2}; {enter}", 1200)
  }

  clearChatAndSend() {
    return this.execute("^+{backspace}; {enter};", 2000)
  }

  fillNttOfficeCredentials() {
    return this.execute("%nttOfficePass%; tab; %nttOfficePass%; enter")
  }
  
  /** 
   * Executes an action chain separated by ";"
   * @param actions - action string: "Send1; WWA,title; Send2; SL,1000"
   * @param globalSleep - initial delay before first action (ms)
   */
  execute(actions, globalSleep := 0) {
    if (globalSleep > 0)
      Sleep(globalSleep)
    
    if (!actions || actions == "")
      return
    
    local actionList := StrSplit(actions, ";")
    
    for action in actionList {
      action := Trim(action)
      
      if (action == "")
        continue
      
      try {
        this._executeAction(action)
      } catch Error as err {
        this._logError(action, err.Message)
        return false
      }
    }
    
    return true
  }

  /**
   * Processes and executes ONE individual action
   */
  _executeAction(action) {
    ; Resolve memory vars before parsing to support vars in params.
    action := this._resolveMemoryVars(action)
    actionParts := this._parseActionParts(action)
    method := actionParts["method"]
    params := actionParts["params"]

    this._logDebug("Action: " method " | Params: " params)
    
    ; Execute by method type
    normalizedMethod := StrLower(method)
    switch normalizedMethod {
      case "winwaitactive", "wwa":
        this._handleWWA(params)
      case "sleep", "sl":
        this._handleSL(params)
      case "click", "c":
        this._handleClick(params)
      default:
        ; Assume Send if it does not match a known method
        this._handleSend(action)
    }
  }

  _parseActionParts(action) {
    if InStr(action, ",")
    {
      separatorPos := InStr(action, ",")
      return Map(
        "method", Trim(SubStr(action, 1, separatorPos - 1)),
        "params", Trim(SubStr(action, separatorPos + 1))
      )
    }
    return Map("method", Trim(action), "params", "")
  }
  
  /**
   * WinWaitActive - wait until a window becomes active
   * Format: "WWA,Window Title" or "WWA,Window Title,Timeout"
   */
  _handleWWA(params) {
    local parts := StrSplit(params, ",")
    local title := Trim(parts[1])
    local timeout := (parts.Length > 1) ? Trim(parts[2]) : 10
    
    if (title == "")
      throw Error("WWA requires a window title")
    
    this._logDebug("WinWaitActive: " title)
    
    if (!WinWaitActive(title, , timeout))
      throw Error("WinWaitActive timeout: " title)
  }
  
  /**
   * Sleep - wait for specified time (ms)
   * Format: "SL,1000"
   */
  _handleSL(params) {
    local ms := Trim(params)
    
    if (!ms || !IsNumber(ms))
      throw Error("SL requires milliseconds: SL,1000")
    
    this._logDebug("Sleep: " ms " ms")
    Sleep(ms)
  }
  
  /**
   * Click - click at coordinates
   * Format: "C" or "C,x,y" or "C,x,y,button"
   */
  _handleClick(params) {
    local parts := StrSplit(params, ",")
    
    if (params == "") {
      this._logDebug("Click: current cursor position")
      Click()
    } else if (parts.Length >= 2) {
      local x := Trim(parts[1])
      local y := Trim(parts[2])
      local button := (parts.Length > 2) ? Trim(parts[3]) : "left"
      
      if (!IsNumber(x) || !IsNumber(y))
        throw Error("Click: coordinates must be numbers")
      
      this._logDebug("Click: " x "," y " (" button ")")
      Click(x, y, button)
    }
  }
  
  /**
   * Send - sends keystrokes
   * Supports: {key}, ^c (ctrl), +shift, !alt, #win, etc.
   */
  _handleSend(text) {
    if (!text || text == "")
      return
    
    this._logDebug("Send: " text)
    Send(text)
  }
  
  /**
  * Resolves memory variables: %varName%
  * Example: "%keepassXc%" -> value stored in services.memory
   */
  _resolveMemoryVars(text) {
    local result := text
    local regex := "%(\w+)%"
    local match := 0
    
    while (match := RegExMatch(result, regex, &captures)) {
      local varName := captures[1]
      local varValue := ""
      
      try {
        varValue := services.memory.getValue(varName)
      } catch {
        this._logDebug("Memory var not found: " varName)
      }
      
      if (varValue != "") {
        result := StrReplace(result, "%" varName "%", varValue, , &count)
        this._logDebug("Memory resolved: %" varName "% = " varValue)
      } else {
        break
      }
    }
    
    return result
  }

  /**
   * Debug log (if DEBUG is enabled)
   */
  _logDebug(msg) {
    if (this.debugMode)
      OutputDebug("DYN DEBUG: " msg)
  }
  
  /**
   * Error log
   */
  _logError(action, errorMsg) {
    OutputDebug("DYN ERROR in [" action "]: " errorMsg)
    if this.debugMode
      ToolTip("DYN ERROR: " errorMsg)
  }
}



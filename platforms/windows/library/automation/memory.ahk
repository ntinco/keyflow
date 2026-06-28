class MemoryService {
  getValue(var) {
    value := ""
    try value := IniRead(memoryVarsIniFile, "data", var, "")
    catch
      value := ""
    if value != ""
      return value

    ; Fallback para secretos locales cuando no estan en memory-vars.ini.
    try value := IniRead(secretsFilePath(), "secrets", var, "")
    catch
      value := ""
    if value != ""
      return value

    try value := %var%
    if value != ""
      return value

    return var
  }

  resolveProviderValue(value, contextLabel := "", allowEmpty := true) {
    if !(value is String)
      return value

    trimmedValue := Trim(value)
    if trimmedValue = ""
      return ""

    if this._isKeepassReference(trimmedValue)
      return this._resolveKeepassReference(trimmedValue, contextLabel, allowEmpty)

    return value
  }

  resolveSecretValue(value, contextLabel := "") {
    return this.resolveProviderValue(value, contextLabel, false)
  }

  resolveTargetTitle(var, &title := "") {
    target := this.getValue(var)
    this._normalizeTargetAndTitle(&target, &title)
    return target
  }

  _normalizeTargetAndTitle(&target, &title := "") {
    title := ""

    if instr(target, "\") and !instr(target, ":\")
    {
      targetSegments := strsplit(target, "\")
      firstSegment := targetSegments[1]
      if instr(firstSegment, "pathOneDrive")
        target := StrReplace(target, firstSegment, pathOneDrive)
    }

    if instr(target, "~")
    {
      targetParts := StrSplit(target, "~")
      target := targetParts[1]
      if targetParts.Has(2)
        title := targetParts[2]
    }

    If !title
    {
      SplitPath(target, &titlefull, &dir, &extension, &title)

      If extension
      {
        if instr(extension, "doc")
          title := title " - Word"
        else if instr(extension, "xls")
          title := title " - Excel"
        else if instr(extension, "code-workspace")
          title := title " (Workspace)"
      }
      Else if instr(target, ":\")
        title := target
      Else if instr(title, "?")
      {
        titleParts := StrSplit(title, "?")
        title := titleParts[1]
      }
    }
  }

  _isKeepassReference(value) {
    return InStr(value, "kp:") = 1
  }

  _resolveKeepassReference(referenceValue, contextLabel := "", allowEmpty := false) {
    providerCommand := this._getKeepassProviderCommand()
    if !providerCommand
    {
      this._showRuntimeError(
        "KeePass reference found"
        . this._buildContextSuffix(contextLabel)
        . ", but keepassProviderCommand is not configured in local-secrets.ini."
      )
      return ""
    }

    commandLine := providerCommand
    commandLine := StrReplace(commandLine, "{ref_quoted}", this._quoteForCommandLine(referenceValue))
    commandLine := StrReplace(commandLine, "{ref}", referenceValue)

    if (commandLine = providerCommand) && !InStr(providerCommand, "{ref}")
      commandLine := providerCommand " " this._quoteForCommandLine(referenceValue)

    return this._runCommandForStdout(commandLine, contextLabel, allowEmpty)
  }

  _getKeepassProviderCommand() {
    global keepassProviderCommand

    if IsSet(keepassProviderCommand) && keepassProviderCommand
      return keepassProviderCommand

    try return IniRead(secretsFilePath(), "secrets", "keepassProviderCommand", "")
    catch
      return ""
  }

  _runCommandForStdout(commandLine, contextLabel := "", allowEmpty := false) {
    shell := ComObject("WScript.Shell")
    try exec := shell.Exec(commandLine)
    catch as errorInfo
    {
      this._showRuntimeError(
        "Could not execute KeePass provider command"
        . this._buildContextSuffix(contextLabel)
        . ". Detail: " errorInfo.Message
      )
      return ""
    }

    while (exec.Status = 0)
      Sleep(50)

    outputText := Trim(exec.StdOut.ReadAll(), "`r`n`t ")
    errorText := Trim(exec.StdErr.ReadAll(), "`r`n`t ")
    exitCode := exec.ExitCode

    if (exitCode != 0)
    {
      detail := errorText != "" ? errorText : "Exit code " exitCode
      this._showRuntimeError(
        "KeePass provider command failed"
        . this._buildContextSuffix(contextLabel)
        . ". Detail: " detail
      )
      return ""
    }

    if (outputText = "")
    {
      if allowEmpty
        return ""
      this._showRuntimeError(
        "KeePass provider command returned an empty value"
        . this._buildContextSuffix(contextLabel)
        . "."
      )
      return ""
    }

    return outputText
  }

  _quoteForCommandLine(value) {
    return Chr(34) StrReplace(value, Chr(34), Chr(34) Chr(34)) Chr(34)
  }

  _buildContextSuffix(contextLabel := "") {
    if !contextLabel
      return ""
    return " for " contextLabel
  }

  _showRuntimeError(message) {
    MsgBox(message)
  }

}

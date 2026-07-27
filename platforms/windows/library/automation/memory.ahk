class MemoryService {
  getValue(var) {
    value := ""
    try value := IniRead(memoryVarsIniFile, "data", var, "")
    catch
      value := ""
    if value != ""
      return value

    try value := %var%
    if value != ""
      return value

    return var
  }
}

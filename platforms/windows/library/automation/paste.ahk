class PasteService {
  pasteFromMemoryKey(valueKey, noExit := "") {
    utils.winNow()
    pasteValue := services.memory.getValue(valueKey)

    if instr(exeEverything, utils.A_Exe)
      pasteValue := pasteValue "*\"
    utils.paste(pasteValue, noExit)

    If utils.isExit(noExit)
      Exit()
  }
}



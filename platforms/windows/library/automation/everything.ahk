class EverythingService {
  incrementRunCount(filename) {
    if SubStr(filename, -1) = "\"
      filename := SubStr(filename, 1, -1)

    if instr(filename, ":\")
      services.run.runCommand( '""' fileEverythingCli '" -inc-run-count "' filename '""' )
  }
}



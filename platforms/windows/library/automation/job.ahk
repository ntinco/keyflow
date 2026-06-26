class JobService {

  __New() {
    settimer(jobMin, 60000)

    jobMin()
    {
      try {
        if WinGetProcessName("A") {
          this.handleInactivity()
          this.checkBreakSchedule()
          this.handleHourlyReminders()
        }
      }
    }

  }

  handleInactivity() {
    if (A_Timeidle >= 60000 * 3)
    {
      MouseGetPos &x, &y
    }

    if WinExist("SAP GUI for Windows 800")
      WinClose("SAP GUI for Windows 800")
  }

  checkBreakSchedule() {
    timeNow := FormatTime(, "yyyyMMddHHmm00")

    taskTimestamp := services.memory.getValue("task_start_time")

    workMinutes := 50
    breakMinutes := -8
    timeBreakStart := timeBreakEnd := 0
    breakStartIndex := breakEndIndex := 1

    While (timeBreakStart < timeNow) or (timeBreakEnd < timeNow)
    {
      if (timeBreakStart < timeNow)
      {
        timeBreakStart := DateAdd(taskTimestamp, (workMinutes * breakStartIndex) + breakMinutes, 'min')
        breakStartIndex += 1
      }

      if (timeBreakEnd < timeNow)
      {
        timeBreakEnd := DateAdd(taskTimestamp, (workMinutes * breakEndIndex), 'min')
        timeElapsed := round(workMinutes * breakEndIndex / 60, 1)
        breakEndIndex += 1
      }
    }

    If timeNow = timeBreakStart
    {
      If A_Hour != 13
        this.speak("Take a break, escapular flexion huckle.")
      SetTimer(jobBreak, breakMinutes * 60 * 1000 * -1)
    }

    If timeNow = timeBreakEnd
      MsgBox("Se ha completado: " timeElapsed "h", , "48 T3")

    jobBreak()
    {
      If A_Hour != 13
        this.speak("Finish break, stand or sit.")
      SetTimer(jobBreak, 0)
    }
  }

  handleHourlyReminders() {
    if A_Hour = 9 and A_Min = 0
      this.syncDependencies()

    if (A_Min = 30)
      this.speak("Work sitting. Maintain good posture.")
    else if (A_Min = 0)
      this.speak("Work standing. Keep your weight balanced and move slightly.")

    if (A_Min = 0)
      this.speak("Drink a glass of water.")
  }

  syncDependencies() {
    ymg := "https://raw.githubusercontent.com/abapGit/build/main/zabapgit_standalone.prog.abap"
    Download(ymg, pathAbapGitRepo "ymg.github" constAbapExtProg)

    if A_Isadmin
      services.run.runCommand("winget upgrade --all")
    else
      services.run.runCommand("winget upgrade --all --scope user")

  }

  speak(phrase) {
    static voice := 0
    try {
      if !voice
        voice := ComObject("SAPI.SpVoice")
      voice.Volume := 60
      voice.Speak(phrase)
    }
  }

}



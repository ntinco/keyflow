class ChatgptService {
  save() {
    text := utils.clipboardRead("^+c", 1)
    if !text
      return
    fileappend text, pathGptNews A_Now ".md"
    send("!{esc}")
    utils.tooltip("Saved")
  }
}


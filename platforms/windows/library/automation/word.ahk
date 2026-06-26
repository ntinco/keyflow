class WordService {
  comment() {
    Send("{home}+{end}")
    Send("^c")
    sleep("100")
    send("^!m")
    sleep("300")
    vals := StrSplit(A_Clipboard, ":")
    if vals.Length < 2
      vals := StrSplit(A_Clipboard, ".")
    if vals.Length < 2
      vals := StrSplit(A_Clipboard, A_Space)
    send(vals[1])
    Send("^{enter}")
  }
}

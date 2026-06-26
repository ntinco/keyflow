class WhatsappService {
  archive() {
    this.performContextAction(4)
  }
  delete() {
    this.performContextAction(2, "yes")
  }
  clearArchive() {
    this.performContextAction(3, "yes")
    this.archive()
  }
  performContextAction(menuSteps, confirmWithEnter := "") {
    Send("^w")
    sleep 100
    send("{AppsKey}")
    sleep 100
    send("{tab}{up " menuSteps "}{enter}")
    sleep 200
    if confirmWithEnter
      send("{enter}")
  }
}

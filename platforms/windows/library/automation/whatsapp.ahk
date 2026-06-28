class WhatsappService {
  archive() {
    this._performContextAction(4)
  }
  delete() {
    this._performContextAction(2, "yes")
  }
  clearArchive() {
    this._performContextAction(3, "yes")
    this.archive()
  }
  _performContextAction(menuSteps, confirmWithEnter := "") {
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

class FancyzonesService {
  zones := []
  monitors := []

  __New() {
    this.getMonitors()

    this.addZone(-823617, -1930, -6, 1117, 633)

    this.addZone(19201080, 311, 0, 1613, 1047)
    this.addZone(19201080, 1110, 0, 815, 1047)
    this.addZone(19201080, 308, 0, 815, 1047)
    this.addZone(19201080, 585, 0, 815, 1047)

    this.addZone(30001379, 1913, -78, 1094, 1464)
    this.addZone(30001379, 1913, -78, 1094, 1249)

    this.addZone(19201040, 311, 0, 1613, 1007)
    this.addZone(19201040, 1110, 0, 815, 1007)
    this.addZone(19201040, 308, 0, 815, 1007)
    this.addZone(19201040, 585, 0, 815, 1007)
  }

  getMonitors() {
    monitorCount := MonitorGetCount()

    Loop monitorCount {
      MonitorGet A_Index, &L, &T, &R, &B
      this.monitors.Push({ monitorId: R "" B })
    }
  }

  addZone(monitorId, x, y, w, h) {
    for key, monitor in this.monitors
    {
      if monitor.monitorId = monitorId
      {
        zone := {
          monitorId: monitorId,
          x: x,
          y: y,
          w: w,
          h: h,
        }
        this.zones.Push(zone)
        return
      }
    }
  }

  getZone(x, y, w, h) {
    for key, zone in this.zones {
      if (x = zone.x && y = zone.y && w = zone.w && h = zone.h) {
        return key
      }
    }
    monitorId := this._getMonitor()
    for key, zone in this.zones {
      if (zone.monitorId = monitorId) {
        return key - 1
      }
    }
    return 0
  }

  right() {
    WinGetPos(&x, &y, &w, &h, "A")
    zone := this._zoneByStep(x, y, w, h, 1, 1)
    this._moveZone(zone)
  }

  left() {
    WinRestore("A")
    WinGetPos(&x, &y, &w, &h, "A")

    zone := this._zoneByStep(x, y, w, h, -1, this.zones.Length)
    this._moveZone(zone)
  }

  _zoneByStep(x, y, w, h, step, fallbackIndex) {
    try {
      return this.zones.get(this.getZone(x, y, w, h) + step)
    } catch {
      return this.zones.get(fallbackIndex)
    }
  }

  _moveZone(zone) {
    WinMove(zone.x, zone.y, zone.w, zone.h, "A")
    WinMove(zone.x, zone.y, zone.w, zone.h, "A")
  }

  _getMonitor() {
    return utils.getMonitorId()
  }
}



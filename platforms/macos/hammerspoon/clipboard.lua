-- Shared paste-with-restore. actions.lua and hotstrings.lua must share one
-- instance (init.lua preloads it as "keyflow.clipboard"): overlapping pastes
-- from either module have to restore the user's clipboard, not an earlier
-- paste's text.

local Clipboard = {}

Clipboard.RESTORE_DELAY = 0.5

local pending
local restoreTimer

function Clipboard.capture()
  return {data = hs.pasteboard.readAllData()}
end

function Clipboard.restore(snapshot)
  if snapshot.data and next(snapshot.data) then
    hs.pasteboard.writeAllData(snapshot.data)
  else
    hs.pasteboard.clearContents()
  end
end

-- Puts text on the clipboard, calls sendPaste(), and restores the snapshot
-- taken before the first of any overlapping pastes. savedClipboard is a
-- snapshot the caller already took (it may have changed the clipboard since).
function Clipboard.paste(text, sendPaste, savedClipboard)
  pending = pending or savedClipboard or Clipboard.capture()
  if restoreTimer then restoreTimer:stop() end
  hs.pasteboard.setContents(text)
  sendPaste()
  restoreTimer = hs.timer.doAfter(Clipboard.RESTORE_DELAY, function()
    Clipboard.restore(pending)
    pending = nil
    restoreTimer = nil
  end)
end

return Clipboard

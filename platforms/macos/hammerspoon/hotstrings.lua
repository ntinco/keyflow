-- Minimal hs.eventtap-based hotstring watcher for the 6-entry first slice.
-- Human source of intent: platforms/shared/data/hotkeys.db
--
-- AHK semantics being reproduced (see platforms/windows/hotkeys/global.ahk):
--   ":*:" triggers fire immediately, no terminator needed, and AHK
--         auto-backspaces the matched trigger text before pasting.
--   "::"  triggers require a non-alnum terminator (space/tab/enter/punct)
--         to fire; AHK auto-backspaces the trigger text (not the terminator).
--
-- This watcher keeps a small rolling buffer of recently typed characters,
-- checks it against the trigger table below, and on match: deletes the
-- typed trigger via synthetic backspaces, then pastes the replacement via
-- the clipboard (mirrors AHK's utilPaste clipboard-save/restore dance).
--
-- BUG FIXED (2026-07-27): clipboard-paste is required here, not optional.
-- An earlier version typed the replacement with hs.eventtap.keyStrokes(),
-- which synthesizes one keyDown event per character. Because this same
-- eventtap watcher listens to ALL keyDown events — including its own
-- synthetic ones — and the SAP comment-block replacement text contains
-- repeated "*-" sequences (its own "*---...---*" separator lines), the
-- watcher re-triggered itself while typing its own output, producing
-- recursive, fractally nested comment blocks. Pasting via a single Cmd+V
-- keystroke avoids this because it generates one synthetic keyDown (the
-- paste command itself), not one per character of the pasted text.

local Hotstrings = {}

-- Mirrors SapService._buildCodeSignature(): "<user> <dd.MM.yy>".
-- No macOS equivalent of MemoryService yet, so the user segment is a fixed
-- placeholder. Revisit if/when a macOS memory-value service exists.
local function buildCodeSignature()
  local user = "NTP"
  local dateStr = os.date("%d.%m.%y")
  return user .. " " .. dateStr
end

local function buildCodeCommentLine()
  return "\" " .. buildCodeSignature()
end

local function buildCommentMarkup()
  local signature = buildCodeSignature()
  return "*---------------------------------------------------------------------*\n"
    .. "* " .. signature .. "\n"
    .. "*---------------------------------------------------------------------*"
end

-- immediate = true  -> fires with no terminator (AHK ":*:" option)
-- immediate = false -> fires on a following non-alnum terminator (AHK "::")
local TRIGGERS = {
  {id = "hs_semicolons",        pattern = ";;", immediate = true,  replacement = function() return "ñ" end},
  {id = "hs_sap_comment_plus",  pattern = "\"+", immediate = true, replacement = buildCodeCommentLine},
  {id = "hs_sap_comment_minus", pattern = "\"-", immediate = true, replacement = buildCodeCommentLine},
  {id = "hs_sap_block_plus",    pattern = "*+", immediate = true,  replacement = buildCommentMarkup},
  {id = "hs_sap_block_minus",   pattern = "*-", immediate = true,  replacement = buildCommentMarkup},
  {id = "hs_sp",                pattern = "sp", immediate = false, replacement = function() return "summary in prompt" end},
}

local MAX_BUFFER = 8
local buffer = ""

local function isTerminator(char)
  return char:match("%s") ~= nil or char:match("%p") ~= nil
end

-- Paste text via the clipboard, preserving whatever the user had there
-- before (mirrors AHK's utilPaste clipboard-save/restore behavior).
local function pasteText(text)
  local savedClipboard = hs.pasteboard.getContents()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v")
  -- Restore the original clipboard shortly after the paste completes.
  hs.timer.doAfter(0.2, function()
    if savedClipboard then
      hs.pasteboard.setContents(savedClipboard)
    else
      hs.pasteboard.clearContents()
    end
  end)
end

local function fireTrigger(trigger)
  for _ = 1, #trigger.pattern do
    hs.eventtap.keyStroke({}, "delete")
  end
  pasteText(trigger.replacement())
  buffer = ""
end

local function fireTerminatedTrigger(trigger)
  -- Backspace only the trigger text; the terminator character itself was
  -- already typed by the user and stays on screen.
  for _ = 1, #trigger.pattern do
    hs.eventtap.keyStroke({}, "delete")
  end
  pasteText(trigger.replacement())
  buffer = ""
end

local eventWatcher

function Hotstrings.start()
  if eventWatcher then
    return
  end
  eventWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local chars = event:getCharacters()
    if not chars or chars == "" then
      return false
    end

    buffer = (buffer .. chars):sub(-MAX_BUFFER)

    for _, trigger in ipairs(TRIGGERS) do
      if trigger.immediate then
        if buffer:sub(-#trigger.pattern) == trigger.pattern then
          fireTrigger(trigger)
          return false
        end
      else
        local withTerminator = trigger.pattern .. chars
        if isTerminator(chars) and buffer:sub(-#withTerminator) == withTerminator then
          fireTerminatedTrigger(trigger)
          return false
        end
      end
    end

    return false
  end)
  eventWatcher:start()
end

function Hotstrings.stop()
  if eventWatcher then
    eventWatcher:stop()
    eventWatcher = nil
  end
end

return Hotstrings

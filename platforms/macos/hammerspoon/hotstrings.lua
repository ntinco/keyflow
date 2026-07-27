-- Minimal hs.eventtap-based hotstring watcher for the 6-entry first slice.
-- Human source of intent: platforms/windows/data/hotkeys.db
--
-- AHK semantics being reproduced (see platforms/windows/hotkeys/global.ahk):
--   ":*:" triggers fire immediately, no terminator needed, and AHK
--         auto-backspaces the matched trigger text before pasting.
--   "::"  triggers require a non-alnum terminator (space/tab/enter/punct)
--         to fire; AHK auto-backspaces the trigger text (not the terminator).
--
-- This watcher keeps a small rolling buffer of recently typed characters,
-- checks it against the trigger table below, and on match: deletes the
-- typed trigger via synthetic backspaces, then types the replacement.
-- Clipboard-based paste (like AHK's utilPaste) is avoided here in favor of
-- direct keystroke typing, since Hammerspoon does not need the
-- clipboard-save/restore dance AHK uses to avoid disturbing the user's
-- clipboard for short literal strings.

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

local function fireTrigger(trigger)
  for _ = 1, #trigger.pattern do
    hs.eventtap.keyStroke({}, "delete")
  end
  hs.eventtap.keyStrokes(trigger.replacement())
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
          -- Backspace only the trigger text; let the terminator pass through.
          for _ = 1, #trigger.pattern do
            hs.eventtap.keyStroke({}, "delete")
          end
          hs.eventtap.keyStrokes(trigger.replacement())
          buffer = ""
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

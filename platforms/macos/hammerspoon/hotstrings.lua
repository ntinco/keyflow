-- hs.eventtap hotstring watcher. Source: platforms/shared/data/hotkeys.db

local Hotstrings = {}

local function buildCodeSignature()
  local user = "NTP"
  return user .. " " .. os.date("%d.%m.%y")
end

-- "+"/"-  single-line comment.
local function buildCodeCommentLine(symbol)
  return "\"" .. symbol .. buildCodeSignature()
end

-- *+/*-  block frame {..}, blank line between open/close (cursor lands there).
local function buildCommentMarkup(symbol)
  local signature = buildCodeSignature()
  local openLine = "*" .. symbol .. "{" .. signature
  local closeLine = "*" .. symbol .. "}" .. signature
  return openLine .. "\n\n" .. closeLine
end

-- moveCursorUpAfter: reposition cursor to the blank frame line after paste.
local TRIGGERS = {
  {id = "hs_semicolons",        pattern = ";;", immediate = true,  replacement = function() return "ñ" end},
  {id = "hs_sap_comment_plus",  pattern = "\"+", immediate = true, replacement = function() return buildCodeCommentLine("+") end},
  {id = "hs_sap_comment_minus", pattern = "\"-", immediate = true, replacement = function() return buildCodeCommentLine("-") end},
  {id = "hs_sap_block_plus",    pattern = "*+", immediate = true,  replacement = function() return buildCommentMarkup("+") end, moveCursorUpAfter = true},
  {id = "hs_sap_block_minus",   pattern = "*-", immediate = true,  replacement = function() return buildCommentMarkup("-") end, moveCursorUpAfter = true},
  {id = "hs_sp",                pattern = "sp", immediate = false, replacement = function() return "summary in prompt" end},
}

local MAX_BUFFER = 8
local buffer = ""

local function isTerminator(char)
  return char:match("%s") ~= nil or char:match("%p") ~= nil
end

-- Must paste via clipboard: keyStrokes() would fire one keyDown per char,
-- which this same watcher observes, causing self-retrigger on patterns
-- that appear inside the pasted text (e.g. "*-" inside a comment block).
local function pasteText(text)
  local savedClipboard = hs.pasteboard.getContents()
  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v")
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
  if trigger.moveCursorUpAfter then
    hs.timer.doAfter(0.05, function()
      hs.eventtap.keyStroke({}, "up")
    end)
  end
  buffer = ""
end

-- Deletes pattern+1 chars: the terminator char is already on screen
-- (event was let through) by the time this callback runs.
local function fireTerminatedTrigger(trigger, terminatorChar)
  for _ = 1, #trigger.pattern + 1 do
    hs.eventtap.keyStroke({}, "delete")
  end
  pasteText(trigger.replacement() .. terminatorChar)
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
          fireTerminatedTrigger(trigger, chars)
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

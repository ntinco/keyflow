-- hs.eventtap hotstring watcher. Catalog data is generated from
-- platforms/shared/data/hotkeys.db.

local Hotstrings = {}

local function buildCodeSignature()
  return "NTP " .. os.date("%d.%m.%y")
end

local function buildCodeCommentLine(symbol)
  return "\"" .. symbol .. buildCodeSignature()
end

local function buildCommentMarkup(symbol)
  local signature = buildCodeSignature()
  return "*" .. symbol .. "{" .. signature .. "\n\n*" .. symbol .. "}" .. signature
end

local SPECIAL_BEHAVIORS = {
  hs_semicolons = {replacement = function() return "ñ" end},
  hs_sap_comment_plus = {replacement = function() return buildCodeCommentLine("+") end},
  hs_sap_comment_minus = {replacement = function() return buildCodeCommentLine("-") end},
  hs_sap_block_plus = {
    replacement = function() return buildCommentMarkup("+") end,
    moveCursorUpAfter = true,
  },
  hs_sap_block_minus = {
    replacement = function() return buildCommentMarkup("-") end,
    moveCursorUpAfter = true,
  },
  hs_sp = {replacement = function() return "summary in prompt" end},
}

local MAX_BUFFER = 64
local CLIPBOARD_RESTORE_DELAY = 0.5
local buffer = ""
local eventWatcher
local clipboardSnapshot
local clipboardRestoreTimer

local function isTerminator(char)
  return char:match("%s") ~= nil or char:match("%p") ~= nil
end

local function isFrontSap()
  local front = hs.application.frontmostApplication()
  return front and front:bundleID() == "com.sap.platin"
end

local function isImmediatePersonName(trigger, value)
  return trigger:match("^[a-z]+$")
    and value:match("^[A-Z][a-z]+$")
end

local function captureClipboard()
  return {
    data = hs.pasteboard.readAllData(),
    text = hs.pasteboard.getContents(),
  }
end

local function restoreClipboard(snapshot)
  if snapshot.data and next(snapshot.data) then
    hs.pasteboard.writeAllData(snapshot.data)
  else
    hs.pasteboard.clearContents()
  end
end

local function pasteText(text)
  if not clipboardSnapshot then
    clipboardSnapshot = captureClipboard()
  end
  if clipboardRestoreTimer then
    clipboardRestoreTimer:stop()
  end

  hs.pasteboard.setContents(text)
  hs.eventtap.keyStroke({"cmd"}, "v")

  clipboardRestoreTimer = hs.timer.doAfter(CLIPBOARD_RESTORE_DELAY, function()
    restoreClipboard(clipboardSnapshot)
    clipboardSnapshot = nil
    clipboardRestoreTimer = nil
  end)
end

local function fireReplacement(trigger, replacement, terminator, visibleCount)
  for _ = 1, visibleCount do
    hs.eventtap.keyStroke({}, "delete")
  end
  pasteText(replacement .. (terminator or ""))
  if trigger.moveCursorUpAfter then
    hs.timer.doAfter(0.05, function()
      hs.eventtap.keyStroke({}, "up")
    end)
  end
  buffer = ""
end

local function triggerMatchesContext(trigger)
  return trigger.contextLabel == "global"
    or trigger.contextLabel == ""
    or (trigger.contextLabel == "sap-gui-session" and isFrontSap())
end

local function buildTriggers(bindings, profiles)
  local triggers = {}

  for _, binding in ipairs(bindings) do
    local behavior = binding.type == "hotstring" and SPECIAL_BEHAVIORS[binding.id]
    if behavior then
      triggers[#triggers + 1] = {
        id = binding.id,
        pattern = binding.key,
        immediate = binding.id ~= "hs_sp",
        contextLabel = binding.contextLabel,
        replacement = behavior.replacement,
        moveCursorUpAfter = behavior.moveCursorUpAfter,
      }
    end
  end

  for _, profile in ipairs(profiles) do
    for _, entry in ipairs(profile.entries) do
      local value = entry.value
      local mode = profile.mode
      triggers[#triggers + 1] = {
        pattern = entry.trigger,
        immediate = entry.immediate or (
          mode == "replace" and isImmediatePersonName(entry.trigger, value)
        ),
        contextLabel = profile.contextLabel,
        replacement = function()
          return value
        end,
        run = mode == "sap-command" and function(actions)
          actions.runSapTcode(value)
        end or nil,
      }
    end
  end

  table.sort(triggers, function(left, right)
    return #left.pattern > #right.pattern
  end)
  return triggers
end

function Hotstrings.start(actions, bindings, profiles)
  if eventWatcher then
    return
  end

  local triggers = buildTriggers(bindings, profiles)
  eventWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
    local chars = event:getCharacters()
    if not chars or chars == "" then
      return false
    end

    buffer = (buffer .. chars):sub(-MAX_BUFFER)
    for _, trigger in ipairs(triggers) do
      if triggerMatchesContext(trigger) then
        if trigger.immediate and buffer:sub(-#trigger.pattern) == trigger.pattern then
          local visibleCount = #trigger.pattern - 1
          if trigger.run then
            for _ = 1, visibleCount do
              hs.eventtap.keyStroke({}, "delete")
            end
            trigger.run(actions)
            buffer = ""
          else
            fireReplacement(trigger, trigger.replacement(), nil, visibleCount)
          end
          return true
        end

        if not trigger.immediate and isTerminator(chars) then
          local match = trigger.pattern .. chars
          if buffer:sub(-#match) == match then
            local visibleCount = #trigger.pattern
            if trigger.run then
              for _ = 1, visibleCount do
                hs.eventtap.keyStroke({}, "delete")
              end
              trigger.run(actions)
              buffer = ""
            else
              fireReplacement(trigger, trigger.replacement(), chars, visibleCount)
            end
            return true
          end
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

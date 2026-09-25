-- hs.eventtap hotstring watcher. Catalog data is generated from
-- platforms/shared/data/hotkeys.db.

local Clipboard = require("keyflow.clipboard")

local Hotstrings = {}

local function shellQuote(str)
  return "'" .. str:gsub("'", "'\\''") .. "'"
end

local function moduleDir()
  local source = debug.getinfo(1, "S").source:match("@(.*/)")
  return source or "./"
end

-- moduleDir() may be a symlinked path (~/.hammerspoon/keyflow/); resolve the
-- physical directory so ".." traversal reaches the real repo, not the symlink parent.
local function physicalDir(dir)
  local handle = io.popen("cd " .. shellQuote(dir) .. " 2>/dev/null && pwd -P")
  if not handle then return dir end
  local result = handle:read("*l")
  handle:close()
  return result and (result .. "/") or dir
end

local MEMORY_VARS_INI = physicalDir(moduleDir()) .. "../../shared/data/memory-vars.ini"

local function readMemoryVarsValue(name, defaultValue)
  local file = io.open(MEMORY_VARS_INI, "r")
  if not file then return defaultValue end
  local value = defaultValue
  for line in file:lines() do
    local key, iniValue = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
    if key == name and iniValue ~= "" then
      value = iniValue
      break
    end
  end
  file:close()
  return value
end

local function buildCodeSignature()
  return readMemoryVarsValue("sap_comment_user", "NTP") .. " " .. os.date("%d.%m.%y")
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
}

local MAX_BUFFER = 64
local SYNTHETIC_EVENT_MARKER = 926491
local log
local buffer = ""
local bufferAppPID
local eventWatcher

-- AutoHotkey's default EndChars (Enter arrives as "\r"); mirrored by
-- HOTSTRING_END_CHARS in ai/hotkey_sync.py.
local END_CHARS = {}
for char in ("-()[]{}':;\"/\\,.?! \t\r\n"):gmatch(".") do
  END_CHARS[char] = true
end

local function isTerminator(char)
  return END_CHARS[char] == true
end

local function isFrontSap()
  local front = hs.application.frontmostApplication()
  return front and (
    front:bundleID() == "com.sap.platin"
    or front:name() == "SAPGUI"
  )
end

-- Like AHK without the ? option: no trigger inside a word. Bytes >= 0x80 are
-- parts of non-ASCII letters (ñ, á), which count as word characters too.
local function hasWordCharacterBefore(buffer, pattern, terminator)
  local startIndex = #buffer - #pattern - #(terminator or "") + 1
  if startIndex <= 1 then return false end
  local preceding = buffer:sub(startIndex - 1, startIndex - 1)
  return preceding:match("[%w_\128-\255]") ~= nil
end

local function postSyntheticKey(modifiers, key)
  for _, isDown in ipairs({true, false}) do
    local event = hs.eventtap.event.newKeyEvent(modifiers, key, isDown)
    event:setProperty(
      hs.eventtap.event.properties.eventSourceUserData,
      SYNTHETIC_EVENT_MARKER
    )
    event:post()
  end
end

local function pasteText(text)
  Clipboard.paste(text, function()
    postSyntheticKey({"cmd"}, "v")
  end)
end

-- CGEventKeyboardSetUnicodeString accepts at most 20 UTF-16 units per event;
-- 10 code points stays under that even for surrogate pairs.
local UNICODE_CHUNK = 10

local function postUnicodeText(text)
  local chunk = {}
  local function flush()
    if #chunk == 0 then return end
    local str = table.concat(chunk)
    for _, isDown in ipairs({true, false}) do
      local event = hs.eventtap.event.newKeyEvent({}, "a", isDown)
      event:setUnicodeString(str)
      event:setProperty(
        hs.eventtap.event.properties.eventSourceUserData,
        SYNTHETIC_EVENT_MARKER
      )
      event:post()
    end
    chunk = {}
  end
  for _, codepoint in utf8.codes(text) do
    chunk[#chunk + 1] = utf8.char(codepoint)
    if #chunk == UNICODE_CHUNK then flush() end
  end
  flush()
end

local function fireReplacement(trigger, replacement, terminator, visibleCount)
  for _ = 1, visibleCount do
    postSyntheticKey({}, "delete")
  end
  -- Return/Tab must be re-sent as real keys, not as typed characters.
  local terminatorKey = ({["\r"] = "return", ["\t"] = "tab"})[terminator or ""]
  local text = replacement .. (terminatorKey and "" or (terminator or ""))
  -- Typing directly avoids the clipboard round-trip (slow, and a fast next
  -- keystroke could be lost around Cmd+V). Multi-line blocks still paste so
  -- editors do not auto-indent each typed newline.
  if text:find("\n", 1, true) then
    pasteText(text)
  else
    postUnicodeText(text)
  end
  if terminatorKey then
    postSyntheticKey({}, terminatorKey)
  end
  if trigger.moveCursorUpAfter then
    hs.timer.doAfter(0.05, function()
      postSyntheticKey({}, "up")
    end)
  end
  buffer = ""
end

local function isSyntheticEvent(event)
  return event:getProperty(hs.eventtap.event.properties.eventSourceUserData)
    == SYNTHETIC_EVENT_MARKER
end

local function resetBuffer()
  buffer = ""
  local front = hs.application.frontmostApplication()
  bufferAppPID = front and front:pid() or nil
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
        immediate = binding.immediate,
        insideWord = binding.insideWord,
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
        -- SAP commands always wait for an ending character, matching Windows.
        immediate = mode ~= "sap-command" and entry.immediate,
        contextLabel = profile.contextLabel,
        profileID = profile.id,
        replacement = function()
          return value
        end,
        run = mode == "sap-command" and function(actions)
          actions.runSapTcode(value, profile.id)
        end or nil,
      }
    end
  end

  table.sort(triggers, function(left, right)
    return #left.pattern > #right.pattern
  end)
  return triggers
end

-- Returns the trigger completed by the last typed chars, the number of
-- visible characters to erase, and the ending character (nil if immediate).
local function findMatch(triggers, typed, chars, contextIsActive)
  for _, trigger in ipairs(triggers) do
    if contextIsActive(trigger) then
      if trigger.immediate
          and typed:sub(-#trigger.pattern) == trigger.pattern
          and (trigger.insideWord or not hasWordCharacterBefore(typed, trigger.pattern)) then
        -- The last trigger character was swallowed, never typed.
        return trigger, utf8.len(trigger.pattern) - 1, nil
      end
      if not trigger.immediate and isTerminator(chars) then
        local match = trigger.pattern .. chars
        if typed:sub(-#match) == match
            and (trigger.insideWord
              or not hasWordCharacterBefore(typed, trigger.pattern, chars)) then
          return trigger, utf8.len(trigger.pattern), chars
        end
      end
    end
  end
  return nil
end

function Hotstrings.start(actions, bindings, profiles)
  if eventWatcher then
    return
  end

  log = log or hs.logger.new("keyflow.hotstrings", "warning")
  local triggers = buildTriggers(bindings, profiles)
  eventWatcher = hs.eventtap.new({
    hs.eventtap.event.types.keyDown,
    hs.eventtap.event.types.leftMouseDown,
    hs.eventtap.event.types.rightMouseDown,
    hs.eventtap.event.types.otherMouseDown,
    hs.eventtap.event.types.tapDisabledByTimeout,
    hs.eventtap.event.types.tapDisabledByUserInput,
  }, function(event)
    local eventType = event:getType()
    if eventType == hs.eventtap.event.types.tapDisabledByTimeout
      or eventType == hs.eventtap.event.types.tapDisabledByUserInput then
      log.w("event tap disabled (type " .. eventType .. "); restarting")
      hs.timer.doAfter(0, function()
        if eventWatcher then
          eventWatcher:start()
        end
      end)
      return false
    end

    if isSyntheticEvent(event) then
      return false
    end

    local front = hs.application.frontmostApplication()
    local frontPID = front and front:pid() or nil
    if frontPID ~= bufferAppPID then
      buffer = ""
      bufferAppPID = frontPID
    end

    if eventType ~= hs.eventtap.event.types.keyDown then
      buffer = ""
      return false
    end

    local flags = event:getFlags()
    if flags.cmd or flags.ctrl or flags.alt then
      buffer = ""
      return false
    end

    local chars = event:getCharacters()
    if not chars or chars == "" or chars == "\127" or chars == "\b" then
      buffer = ""
      return false
    end

    buffer = (buffer .. chars):sub(-MAX_BUFFER)
    local trigger, visibleCount, terminator =
      findMatch(triggers, buffer, chars, triggerMatchesContext)
    if not trigger then return false end
    if trigger.run then
      if actions.shouldSubmitExistingSapCatalogTcode(trigger.profileID) then
        hs.timer.doAfter(0, function()
          postSyntheticKey({}, "return")
        end)
        buffer = ""
        return false
      end
      for _ = 1, visibleCount do
        postSyntheticKey({}, "delete")
      end
      trigger.run(actions)
      buffer = ""
    else
      fireReplacement(trigger, trigger.replacement(), terminator, visibleCount)
    end
    return true
  end)
  eventWatcher:start()
end

Hotstrings.reset = resetBuffer
-- Pure helpers exposed for ai/tests.
Hotstrings.buildTriggers = buildTriggers
Hotstrings.findMatch = findMatch

return Hotstrings

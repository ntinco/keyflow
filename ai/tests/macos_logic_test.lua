-- Pure-logic tests for the Hammerspoon runtime. Run: lua ai/tests/macos_logic_test.lua
-- Modules only touch hs.* inside functions, so a stub is enough to load them;
-- tests that need hs.* install fakes afterwards.

hs = setmetatable({}, {__index = function() error("hs.* used at load time") end})

local root = arg[0]:match("^(.*)/ai/tests/") or "."
local dir = root .. "/platforms/macos/hammerspoon/"
package.loaded["keyflow.clipboard"] = dofile(dir .. "clipboard.lua")
local Clipboard = package.loaded["keyflow.clipboard"]
local Actions = dofile(dir .. "actions.lua")
local Dispatch = dofile(dir .. "dispatch.lua")
local Hotstrings = dofile(dir .. "hotstrings.lua")

local failures = 0
local function expectEqual(actual, expected, label)
  if actual ~= expected then
    failures = failures + 1
    io.stderr:write(string.format("FAIL %s: expected %s, got %s\n", label, tostring(expected), tostring(actual)))
  end
end

-- SAP tcode normalization ---------------------------------------------------
local normalize = Actions.normalizeTcode
expectEqual(normalize("se16n"), "/nSE16N", "plain tcode gets /n")
expectEqual(normalize("  va03 "), "/nVA03", "whitespace trimmed")
expectEqual(normalize("/nse38"), "/nse38", "slash commands sent as-is")
expectEqual(normalize("/o"), "/o", "session command sent as-is")
expectEqual(normalize("=da"), "=DA", "OK-codes keep = and get no /n")

-- Key parsing and dispatch --------------------------------------------------
local mods, key = Dispatch.parseAhkKey("~^Enter")
expectEqual(table.concat(mods, ","), "ctrl", "~^Enter modifiers")
expectEqual(key, "return", "Enter maps to return")
mods, key = Dispatch.parseAhkKey("#+Esc")
expectEqual(table.concat(mods, ","), "cmd,shift", "#+Esc modifiers")
expectEqual(key, "escape", "Esc maps to escape")

local snipasteEnter = {keyCode = 36, mods = {}, contextLabel = "snipaste"}
local launcherEnter = {keyCode = 36, mods = {}, contextLabel = "launcher"}
local cmdF1 = {keyCode = 122, mods = {"cmd"}, contextLabel = "global"}
local bindings = {snipasteEnter, launcherEnter, cmdF1}
local function onlyLauncher(label) return label == "launcher" or label == "global" end
local function nothing(label) return label == "global" end
expectEqual(Dispatch.find(bindings, 36, {}, onlyLauncher), launcherEnter,
  "inactive match does not hide a later active binding")
expectEqual(Dispatch.find(bindings, 36, {}, nothing), nil, "no active context lets the key through")
expectEqual(Dispatch.find(bindings, 122, {cmd = true}, nothing), cmdF1, "global binding matches")
expectEqual(Dispatch.find(bindings, 122, {cmd = true, shift = true}, nothing), nil,
  "extra modifier does not match")

-- Hotstring matching --------------------------------------------------------
local triggers = Hotstrings.buildTriggers(
  {
    {id = "hs_semicolons", type = "hotstring", key = ";;", immediate = true, insideWord = true,
      contextLabel = "global"},
    {id = "hs_unknown", type = "hotstring", key = "zz", immediate = true, contextLabel = "global"},
  },
  {
    {id = "autocorrect", mode = "replace", contextLabel = "global",
      entries = {{trigger = "teh", value = "the", immediate = false}}},
    {id = "snippets", mode = "replace", contextLabel = "global",
      entries = {{trigger = "bd,", value = "Buen día,", immediate = true},
                 {trigger = "ñd,", value = "x", immediate = true}}},
    {id = "sap", mode = "sap-command", contextLabel = "sap-gui-session",
      entries = {{trigger = "da", value = "=DA", immediate = true}}},
  }
)
expectEqual(#triggers, 5, "special hotstrings without behavior are skipped")

local function inSap(trigger) return true end
local function outsideSap(trigger) return trigger.contextLabel ~= "sap-gui-session" end
local function match(typed, contextIsActive)
  return Hotstrings.findMatch(triggers, typed, typed:sub(-1), contextIsActive or outsideSap)
end

local trigger, count, terminator = match("teh ")
expectEqual(trigger and trigger.replacement(), "the", "ending character fires replacement")
expectEqual(count, 3, "erases the typed trigger")
expectEqual(terminator, " ", "ending character is kept")
trigger, count, terminator = match("teh\r")
expectEqual(terminator, "\r", "Return ends a hotstring")
expectEqual(match("teh="), nil, "= is not an AHK ending character")
expectEqual(match("teh@"), nil, "@ is not an AHK ending character")
expectEqual(match("xteh "), nil, "no trigger inside an ASCII word")
expectEqual(match("ñteh "), nil, "no trigger inside a non-ASCII word")
expectEqual(select(1, match("(teh "))  ~= nil, true, "punctuation before the trigger is allowed")

trigger, count, terminator = match("bd,")
expectEqual(trigger and trigger.replacement(), "Buen día,", "immediate trigger fires")
expectEqual(count, 2, "immediate trigger erases all but the swallowed char")
expectEqual(terminator, nil, "immediate trigger has no ending character")
trigger, count = match("ñd,")
expectEqual(count, 2, "visible count uses characters, not bytes")
trigger, count = match(" ;;")
expectEqual(trigger and trigger.id, "hs_semicolons", "special hotstring fires")
expectEqual(count, 1, ";; erases only the first ;")
trigger, count = match("ma;;")
expectEqual(trigger and trigger.id, "hs_semicolons", ";; fires inside a word (AHK ? option)")
expectEqual(count, 1, ";; inside a word erases only the first ;")

expectEqual(Hotstrings.isGuestApp("com.vmware.fusion"), true, "VMware Fusion passes hotstrings to the guest")
expectEqual(Hotstrings.isGuestApp("com.apple.TextEdit"), false, "native apps keep hotstrings")
expectEqual(Hotstrings.isGuestApp(nil), false, "no frontmost bundle keeps hotstrings")
expectEqual(match("mabd,"), nil, "triggers without ? still respect word boundaries")

expectEqual(match("da", inSap), nil, "SAP commands never fire immediately")
trigger, count, terminator = match("da ", inSap)
expectEqual(trigger and trigger.run ~= nil, true, "SAP command runs on ending character")
expectEqual(count, 2, "SAP command erases its trigger")
expectEqual(match("da "), nil, "SAP command is scoped to SAP")

-- Clipboard restore with a fake clock ---------------------------------------
local clock, timers = 0, {}
local pasteboard = {contents = "USER"}
hs = {
  pasteboard = {
    readAllData = function()
      return pasteboard.contents and {text = pasteboard.contents} or {}
    end,
    setContents = function(text) pasteboard.contents = text end,
    writeAllData = function(data) pasteboard.contents = data.text end,
    clearContents = function() pasteboard.contents = nil end,
  },
  timer = {
    doAfter = function(delay, fn)
      local timer = {at = clock + delay, fn = fn}
      function timer:stop() self.stopped = true end
      timers[#timers + 1] = timer
      return timer
    end,
  },
}
local function advance(seconds)
  clock = clock + seconds
  for _, timer in ipairs(timers) do
    if not timer.stopped and not timer.fired and timer.at <= clock + 1e-9 then
      timer.fired = true
      timer.fn()
    end
  end
end

local pasted = {}
local function sendPaste() pasted[#pasted + 1] = pasteboard.contents end
Clipboard.paste("/nVA03", sendPaste)
advance(0.2)
Clipboard.paste("=DA", sendPaste)
expectEqual(table.concat(pasted, "|"), "/nVA03|=DA", "each paste sends its own text")
advance(0.4)
expectEqual(pasteboard.contents, "=DA", "overlapping paste postpones the restore")
advance(0.2)
expectEqual(pasteboard.contents, "USER", "overlapping pastes restore the user's clipboard")

local saved = Clipboard.capture()
pasteboard.contents = "copied selection"
Clipboard.paste("file text", sendPaste, saved)
advance(Clipboard.RESTORE_DELAY)
expectEqual(pasteboard.contents, "USER", "caller snapshot wins over the current clipboard")

pasteboard.contents = nil
Clipboard.paste("x", sendPaste)
advance(Clipboard.RESTORE_DELAY)
expectEqual(pasteboard.contents, nil, "empty clipboard is restored as empty")

-- Time capture summary ------------------------------------------------------
local summary = Actions.timeCaptureSummary
expectEqual(summary(0, "CLOSE TIME-1\nNEW WORK-001 = CC1 (A) in the map\nADD 2026-09-26 19:20-OPEN OPEN P/R MEAL\nWROTE 1 row(s)\n\nHEALTH OK", ""),
  "✓ CLOSE TIME-1\n19:20-OPEN OPEN P/R MEAL", "success keeps stored rows, hides raw codes and health")
expectEqual(summary(2, "", "error: refusing to write\nAMBIGUITIES (1):\nAMBIGUOUS 2026-09-26 19:20 'x' — needs Context"),
  "✗ AMBIGUOUS 2026-09-26 19:20 'x' — needs Context", "ambiguity reports its reason")
expectEqual(summary(2, "", "error: conflict at 19:20"), "✗ error: conflict at 19:20", "error line reported")
expectEqual(summary(127, "", ""), "✗ t exited 127", "missing command reported")

-- Ask AI fallback --------------------------------------------------------------
local failure = Actions.askAiFailure
expectEqual(failure(0, "  Paris is the capital.\n", ""), nil, "a real answer is kept")
expectEqual(failure(0, "  \n", ""), "empty answer", "empty output falls through")
expectEqual(failure(1, "", "Loaded cached credentials.\nError: Quota exceeded for requests\n"),
  "Error: Quota exceeded for requests", "nonzero exit reports the last error line")
expectEqual(failure(1, "", ""), "exit 1", "silent failure reports the exit code")
expectEqual(failure(0, "You've hit your usage limit. Try again later.", ""),
  "You've hit your usage limit. Try again later.", "short limit message on exit 0 falls through")
expectEqual(failure(0, "Rate limits " .. string.rep("explained at length. ", 20), ""), nil,
  "a long answer that mentions limits is kept")

local parsed = Actions.askAiParseProviders("# order\nClaude claude -p\n\nTool tool run  # work\nbroken\n")
expectEqual(#parsed, 2, "config keeps provider lines, skips comments and one-word lines")
expectEqual(parsed[2].bin .. " " .. table.concat(parsed[2].args, " "), "tool run", "trailing comment dropped")
expectEqual(Actions.askAiParseProviders("# nothing\n"), nil, "config without providers falls back to defaults")

if failures > 0 then
  os.exit(1)
end
print("macos_logic_test: ok")

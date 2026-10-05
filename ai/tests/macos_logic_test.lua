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
expectEqual(normalize("iw3d", true), "/niw3d", "SAP hotstring keeps lowercase and adds /n")
expectEqual(normalize("se16n", true), "/nse16n", "hotstring preserves lowercase")
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
    {id = "sap-transaction-catalog", mode = "sap-command", contextLabel = "sap-gui-session",
      entries = {{trigger = "iw3d", value = "iw3d", immediate = false}}},
    {id = "ymt-commands", mode = "sap-command", contextLabel = "sap-gui-session",
      entries = {{trigger = "da", value = "=DA", immediate = true}}},
  }
)
expectEqual(#triggers, 6, "special hotstrings without behavior are skipped")

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

expectEqual(match("iw3d", inSap), nil, "SAP commands never fire immediately")
trigger, count, terminator = match("iw3d ", inSap)
expectEqual(trigger and trigger.run ~= nil, true, "SAP command runs on ending character")
local sapRunArgs
trigger.run({runSapTcode = function(...) sapRunArgs = {...} end})
expectEqual(sapRunArgs[1], "iw3d", "SAP hotstring forwards its transaction")
expectEqual(sapRunArgs[2], true, "SAP hotstring opts into case preservation")
expectEqual(count, 4, "SAP command erases its trigger")
trigger = select(1, match("da ", inSap))
local ymtRunArgs
trigger.run({runSapTcode = function(...) ymtRunArgs = {...} end})
expectEqual(ymtRunArgs[2], false, "non-tcode SAP command keeps default normalization")
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

-- Generated bindings stay wired to actions ----------------------------------
local generated = dofile(dir .. "generated/bindings.lua")
local summaryBinding
for _, binding in ipairs(generated) do
  if binding.type == "hotkey" and binding.tcode == "" then
    expectEqual(type(Actions[binding.id]), "function", "action registered for " .. binding.id)
  end
  if binding.id == "netnewswire_summary_current" then summaryBinding = binding end
end
expectEqual(summaryBinding and summaryBinding.contextLabel, "netnewswire",
  "summary binding is scoped to NetNewsWire")
mods, key = Dispatch.parseAhkKey(summaryBinding["key"])
table.sort(mods)
expectEqual(table.concat(mods, ","), "alt,cmd", "!#s is Option+Cmd")
expectEqual(key, "s", "!#s key is s")

-- NetNewsWire summary -------------------------------------------------------
expectEqual(Actions.escapeHtml([[<script>alert("x")</script> & more]]),
  "&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt; &amp; more", "HTML metacharacters are escaped")
expectEqual(Actions.escapeHtml("&lt;"), "&amp;lt;", "existing entities are not trusted")
local html = Actions.summaryHtml("a\n<img src=x onerror=alert(1)>")
expectEqual(html:find("<img", 1, true), nil, "summary text cannot inject markup")
expectEqual(html:find("<pre>a\n&lt;img", 1, true) ~= nil, true, "summary keeps line breaks inside <pre>")
expectEqual(
  Actions.summaryFailureMessage("status\nerror: No hay ningún artículo abierto en NetNewsWire.\nerror=1\n"),
  "No hay ningún artículo abierto en NetNewsWire.", "script error reason is shown")
expectEqual(Actions.summaryFailureMessage("zsh: command not found: python3"),
  "No se pudo generar el resumen.", "unknown failure gets the generic message")
expectEqual(Actions.summaryFailureMessage("error: " .. string.rep("x", 201)),
  "No se pudo generar el resumen.", "oversized error detail is not shown")
expectEqual(Actions.summaryFailureMessage(nil), "No se pudo generar el resumen.", "missing stderr is tolerated")

local alerts, tasks, windows, deleted = {}, {}, {}, 0
local settings, scriptExists = {}, true
local function fakeWindow()
  local window = {calls = {}}
  return setmetatable(window, {__index = function(_, name)
    return function(self, value)
      if name == "delete" then deleted = deleted + 1 end
      self.calls[name] = value == nil and true or value
      return self
    end
  end})
end
hs.printf = function() end
hs.alert = {show = function(text) alerts[#alerts + 1] = text end}
hs.settings = {get = function(name) return settings[name] end}
hs.fs = {attributes = function() return scriptExists and "file" or nil end}
hs.screen = {mainScreen = function()
  return {frame = function() return {x = 100, y = 50, w = 1600, h = 1000} end}
end}
hs.webview = {
  windowMasks = {titled = 1, closable = 2, resizable = 8},
  new = function(rect, preferences)
    local window = fakeWindow()
    window.rect, window.preferences = rect, preferences
    windows[#windows + 1] = window
    return window
  end,
}
hs.task = {new = function(path, callback, args)
  local task = {path = path, callback = callback, args = args}
  function task:start() tasks[#tasks + 1] = self; return self end
  return task
end}
local summarize = Actions.netnewswire_summary_current

scriptExists = false
summarize()
expectEqual(#tasks, 0, "missing script launches nothing")
expectEqual(alerts[#alerts], "No se encontró nnw_summary.py.", "missing script is reported")

scriptExists = true
summarize()
expectEqual(#tasks, 1, "summary starts one task")
expectEqual(alerts[#alerts], "Resumiendo…", "start feedback is shown")
expectEqual(tasks[1].path, "/bin/zsh", "summary runs through the login shell")
expectEqual(tasks[1].args[1], "-lc", "login shell supplies the provider PATH")
expectEqual(tasks[1].args[2]:find("nnw_summary", 1, true), nil, "script path is not part of the shell source")
expectEqual(tasks[1].args[4], os.getenv("HOME") .. "/gh/netnewswire-ai/tools/nnw_summary.py",
  "workspace default script is a positional argument")
summarize()
expectEqual(#tasks, 1, "a running summary is not duplicated")
expectEqual(alerts[#alerts], "El resumen sigue en curso…", "second press reports the running summary")

tasks[1].callback(1, "partial", "error: NetNewsWire no está abierto.\nerror=1\n")
expectEqual(#windows, 0, "failed summary opens no window")
expectEqual(alerts[#alerts], "NetNewsWire no está abierto.", "failure shows the script reason")

settings["keyflow.netnewswireSummaryScript"] = "/tmp/it's; $(x)/nnw_summary.py"
summarize()
expectEqual(#tasks, 2, "state is cleared after a failure")
expectEqual(tasks[2].args[4], "/tmp/it's; $(x)/nnw_summary.py", "local override wins and stays one argument")
tasks[2].callback(0, " \n", "")
expectEqual(#windows, 0, "empty output opens no window")
expectEqual(alerts[#alerts], "No se pudo generar el resumen.", "empty output is a failure")

summarize()
tasks[3].callback(0, "Título\n\n<b>Resumen</b>\n", "")
expectEqual(#windows, 1, "successful summary opens a window")
expectEqual(windows[1].rect.w, 760, "window width")
expectEqual(windows[1].rect.h, 580, "window height")
expectEqual(windows[1].rect.x, 520, "window is centered horizontally on the screen")
expectEqual(windows[1].rect.y, 260, "window is centered vertically on the screen")
expectEqual(windows[1].preferences.javaScriptEnabled, false, "summary window runs no JavaScript")
expectEqual(windows[1].calls.windowStyle, 11, "window is titled, closable and resizable")
expectEqual(windows[1].calls.html:find("&lt;b&gt;Resumen&lt;/b&gt;", 1, true) ~= nil, true,
  "window shows the escaped summary")
summarize()
tasks[4].callback(0, "otro", "")
expectEqual(deleted, 1, "previous summary window is closed")
windows[2].calls.windowCallback("closing")
summarize()
tasks[5].callback(0, "tercero", "")
expectEqual(deleted, 1, "a window the user closed is not deleted again")

if failures > 0 then
  os.exit(1)
end
print("macos_logic_test: ok")

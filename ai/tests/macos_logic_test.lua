-- Pure-logic tests for the Hammerspoon runtime. Run: lua ai/tests/macos_logic_test.lua
-- actions.lua only touches hs.* inside functions, so a stub is enough to load it.

hs = setmetatable({}, {__index = function() error("hs.* used at load time") end})

local root = arg[0]:match("^(.*)/ai/tests/") or "."
local Actions = dofile(root .. "/platforms/macos/hammerspoon/actions.lua")

local failures = 0
local function expectEqual(actual, expected, label)
  if actual ~= expected then
    failures = failures + 1
    io.stderr:write(string.format("FAIL %s: expected %q, got %q\n", label, expected, actual))
  end
end

local normalize = Actions.normalizeTcode
expectEqual(normalize("se16n"), "/nSE16N", "plain tcode gets /n")
expectEqual(normalize("  va03 "), "/nVA03", "whitespace trimmed")
expectEqual(normalize("/nse38"), "/nse38", "slash commands sent as-is")
expectEqual(normalize("/o"), "/o", "session command sent as-is")
expectEqual(normalize("=da"), "=DA", "OK-codes keep = and get no /n")

if failures > 0 then
  os.exit(1)
end
print("macos_logic_test: ok")

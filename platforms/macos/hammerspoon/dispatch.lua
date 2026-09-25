-- Pure key-binding helpers for init.lua; tested by ai/tests/macos_logic_test.lua.

local Dispatch = {}

local PREFIX_MODS = {["^"] = "ctrl", ["+"] = "shift", ["!"] = "alt", ["#"] = "cmd"}
local KEY_ALIASES = {enter = "return", esc = "escape"}

function Dispatch.parseAhkKey(ahkKey)
  local mods = {}
  local key = ahkKey:gsub("^~", "")
  while #key > 0 and PREFIX_MODS[key:sub(1, 1)] do
    table.insert(mods, PREFIX_MODS[key:sub(1, 1)])
    key = key:sub(2)
  end
  return mods, KEY_ALIASES[key:lower()] or key
end

local function matchesModifiers(flags, expectedMods)
  local expected = {}
  for _, mod in ipairs(expectedMods) do expected[mod] = true end
  for _, mod in ipairs({"cmd", "ctrl", "alt", "shift"}) do
    if (flags[mod] == true) ~= (expected[mod] == true) then return false end
  end
  return true
end

-- First binding for the key whose context is active. A match in an inactive
-- context must not hide a later one (nor swallow the key).
function Dispatch.find(bindings, keyCode, flags, contextIsActive)
  for _, binding in ipairs(bindings) do
    if keyCode == binding.keyCode
        and matchesModifiers(flags, binding.mods)
        and contextIsActive(binding.contextLabel) then
      return binding
    end
  end
  return nil
end

return Dispatch

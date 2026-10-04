-- Runs NeoHeal's tests outside the game:  lua spec/run.lua  from the addon folder,
-- or with the full path to this file from anywhere else.
-- Needs plain Lua 5.1 or newer. LuaUnit 3.5 is included as spec/luaunit.lua (BSD
-- licence in spec/luaunit-LICENSE.txt, https://github.com/bluebird75/luaunit). The game never loads these
-- files: they are not listed in NeoHeal.toc.
local root = (arg and arg[0] or ""):match("^(.*)[/\\]spec[/\\]run%.lua$") or "."
package.path = root .. "/spec/?.lua;" .. package.path
require("support").root = root

for _, file in ipairs({ "spells_test", "clickcast_test", "options_test", "tooltip_test", "modifiers_test", "clicktypes_test", "prediction_test" }) do
    dofile(root .. "/spec/" .. file .. ".lua")
end

os.exit(require("luaunit").LuaUnit.run())

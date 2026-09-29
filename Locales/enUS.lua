-- English strings. This file loads first, so a translation only has to override
-- the keys it translates; everything else stays English.
--
-- Adding a language later: create e.g. Locales\deDE.lua, list it in the .toc
-- after this file, and start it with:
--     if GetLocale() ~= "deDE" then return end
--     local L = select(2, ...).L
local _, NeoHeal = ...

local L = setmetatable({}, {
    -- A missing key shows its own name instead of raising an error.
    __index = function(_, key) return key end,
})
NeoHeal.L = L

L.ADDON_NAME = "NeoHeal"
L.LOADED = "loaded. Type /neoheal to open the options."
L.OPTIONS_TITLE = "NeoHeal Options"
L.OPEN_OPTIONS = "Open NeoHeal options"
L.APPLY_AFTER_COMBAT = "In combat: changes are applied when combat ends."

-- Option pages
L.PAGE_CLICK_CASTING = "Click Casting"
L.PAGE_LAYOUT = "Layout"

-- Click casting
L.CLICK_CASTING_HINT = "Pick a modifier, then choose what each mouse button or hover key does on a raid frame."
L.SET_HOVER_KEY = "Set key..."
L.HOVER_KEY = "Key: %s"
L.PRESS_A_KEY = "Press a key"
L.HOVER_KEY_TOOLTIP = "Hover key: press it while your mouse is over a raid frame.\nLeft click to set a key (Escape cancels), right click to clear it."
L.MODIFIER_NONE = "No modifier"
L.MODIFIER_SHIFT = "Shift"
L.MODIFIER_CTRL = "Ctrl"
L.MODIFIER_ALT = "Alt"
L.BUTTON_LEFT = "Left click"
L.BUTTON_RIGHT = "Right click"
L.BUTTON_MIDDLE = "Middle click"
L.BUTTON_4 = "Button 4"
L.BUTTON_5 = "Button 5"
L.COLUMN_ACTION = "Action"
L.COLUMN_TARGET = "Cast on"
L.COLUMN_ALSO_TARGET = "Also target"
L.ACTION_NONE = "None"
L.ACTION_TARGET = "Target"
L.ACTION_MENU = "Open unit menu"
L.ACTION_BUFF = "Cast missing buff"
L.BUFF_NOTHING_MISSING = "Nothing to buff"
L.BUFF_IN_COMBAT = "No buffing in combat: save your mana"
L.BUFF_READY_CHECK = "Ready check: save your mana for the pull"
L.HIGHEST_RANK = "Highest rank"
L.NOT_LEARNED = "not learned"
L.NO_SPELLS = "No spells found"
L.TARGET_UNIT = "Clicked unit"
L.TARGET_UNIT_TARGET = "Unit's target"
L.TARGET_UNIT_TARGETTARGET = "Target of target"
L.RESET_BINDINGS = "Reset to class defaults"

-- Layout
L.FRAME_STYLE = "Frame style"
L.FRAME_STYLE_FOREVER = "Forever"
L.FRAME_STYLE_CLASSIC = "Classic"
L.HEALTH_COLOR = "Health bar color"
L.HEALTH_COLOR_CLASS = "Class"
L.HEALTH_COLOR_HEALTH = "Health (green to red)"
L.SORT_ORDER = "Sort members"
L.SORT_INDEX = "Raid order"
L.SORT_NAME = "By name"
L.SORT_ROLE = "Tanks, healers, damage"
L.SORT_CLASS = "By class"
L.MAIN_TANK_POSITION = "Main tank group"
L.MAIN_TANKS_NONE = "None"
L.MAIN_TANKS_FIRST = "First (before group 1)"
L.MAIN_TANKS_LAST = "Last (after everything)"
L.HEALTH_TEXT = "Health text"
L.HEALTH_TEXT_PERCENT = "Percentage"
L.HEALTH_TEXT_DEFICIT = "Health missing"
L.HEALTH_TEXT_NONE = "Off"
L.POWER_BAR = "Resource bar"
L.POWER_BAR_ALL = "Everyone"
L.POWER_BAR_HEALERS = "Healers only"
L.POWER_BAR_NONE = "Off"
L.TEST_MODE = "Test mode"
L.TEST_MODE_OFF = "Off"
L.TEST_MODE_SIZE = "%d players"
L.BUTTON_WIDTH = "Button width"
L.BUTTON_HEIGHT = "Button height"
L.SPACING = "Spacing"
L.SCALE = "Scale"
L.MOVER_TEXT = "Drag to move"
L.MOVE_HINT = "Ctrl + drag to move"
L.SHOW_SOLO = "Show when solo"
L.SHOW_RAID_DEBUFFS = "Show raid debuffs"
L.SHOW_MISSING_BUFFS = "Show missing buffs"
L.SHOW_HOT_TIMERS = "Show HoT timers"
L.SHOW_INCOMING_HEALS = "Show incoming heals"
L.SHOW_AGGRO = "Show aggro"
L.SHOW_TOOLTIPS = "Show tooltips"
L.SHOW_PETS = "Show pets"
L.HIDE_BLIZZARD_FRAMES = "Hide Blizzard group frames"

-- Group titles above the frames (in a raid)
L.GROUP_NUMBER = "Group %d"
L.MAIN_TANKS = "Main tanks"
L.PETS = "Pets"

-- Unit status
L.DEAD = "Dead"
L.OFFLINE = "Offline"

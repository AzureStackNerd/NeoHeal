-- Click casting: what each mouse button (or hover key) + modifier does on a unit button.
--
-- Bindings are saved per character in NeoHealCharDB.bindings, keyed by modifier
-- prefix + button id, e.g. "1" (left click) or "shift-2" (shift + right click):
--     { action = "spell", spellID = 2061, highestRank = true, target = "unit", alsoTarget = false }
--     (with highestRank, rankOffset = 1 casts the rank below the highest; nil means 0)
--     { action = "target", target = "targettarget" }
--     { action = "menu" }
--     { action = "buff" }   -- casts your missing buff (MissingBuffs.lua), or does nothing
-- Each binding becomes secure button attributes, which is what lets the game cast
-- on click even in combat. "shift-2" casting on the unit's target becomes:
--     shift-type2 = "spell", shift-spell2 = 2061, shift-unitsuffix2 = "target"
-- With alsoTarget the click runs a small macro instead (see BuildTargetingMacro).
--
-- Hover keys: while the mouse is over a unit button, a keyboard key "clicks" it
-- with a virtual mouse button called "neokey1". The game turns that into the
-- attribute suffix "-neokey1", so it is bound exactly like a mouse button.
local _, NeoHeal = ...
local L = NeoHeal.L
local Spells = NeoHeal.Spells

local ClickCast = {}
NeoHeal.ClickCast = ClickCast

local NUM_HOVER_KEYS = 3

ClickCast.MODIFIERS = {
    { prefix = "",       label = L.MODIFIER_NONE,  keyPrefix = "" },
    { prefix = "shift-", label = L.MODIFIER_SHIFT, keyPrefix = "SHIFT-" },
    { prefix = "ctrl-",  label = L.MODIFIER_CTRL,  keyPrefix = "CTRL-" },
    { prefix = "alt-",   label = L.MODIFIER_ALT,   keyPrefix = "ALT-" },
}

ClickCast.BUTTONS = {
    { id = "1", label = L.BUTTON_LEFT },
    { id = "2", label = L.BUTTON_RIGHT },
    { id = "3", label = L.BUTTON_MIDDLE },
    { id = "4", label = L.BUTTON_4 },
    { id = "5", label = L.BUTTON_5 },
}
for slot = 1, NUM_HOVER_KEYS do
    table.insert(ClickCast.BUTTONS, { id = "-neokey" .. slot, hoverKey = slot, virtualButton = "neokey" .. slot })
end

-- "unitsuffix" values: the spell or target action goes to the clicked unit, its target
-- (e.g. the tank's target) or its target's target.
ClickCast.TARGETS = {
    { value = "unit",         label = L.TARGET_UNIT },
    { value = "target",       label = L.TARGET_UNIT_TARGET },
    { value = "targettarget", label = L.TARGET_UNIT_TARGETTARGET },
}

-- "neobuff" isn't a real action type: the click snippet (RES_SNIPPET) turns it into
-- the buff cast, or cancels the click.
local ACTION_TYPES = { spell = "spell", target = "target", menu = "togglemenu", buff = "neobuff" }

-- Every binding key ("shift-2", "-neokey1", ...) and the attribute slots it owns.
-- Slots without a binding are written as nil, which clears an old binding.
local SLOTS = {}                -- [bindingKey] = { prefix = "shift-", buttonId = "2" }
ClickCast.ATTRIBUTE_NAMES = {}
for _, modifier in ipairs(ClickCast.MODIFIERS) do
    for _, button in ipairs(ClickCast.BUTTONS) do
        SLOTS[modifier.prefix .. button.id] = { prefix = modifier.prefix, buttonId = button.id }
        for _, attribute in ipairs({ "type", "spell", "unitsuffix", "macrotext" }) do
            table.insert(ClickCast.ATTRIBUTE_NAMES, modifier.prefix .. attribute .. button.id)
        end
    end
end
---------------------------------------------------------------------------
-- Resurrecting: a click that would cast something on a dead friendly unit casts
-- your res spell instead ("Target" and "Open unit menu" keep working). A secure
-- snippet runs before each click and, for a dead unit, passes the click on as the
-- virtual button "neores", whose attributes cast the res spell with any modifier.
---------------------------------------------------------------------------
local RES_SPELLS = {
    PRIEST  = 2006,    -- Resurrection
    PALADIN = 7328,    -- Redemption
    SHAMAN  = 2008,    -- Ancestral Spirit
    DRUID   = 20484,   -- Rebirth (works in combat)
}

table.insert(ClickCast.ATTRIBUTE_NAMES, "*type-neores")
table.insert(ClickCast.ATTRIBUTE_NAMES, "*spell-neores")
-- Buffing (MissingBuffs.lua): the spell attribute is set per button, the type here.
table.insert(ClickCast.ATTRIBUTE_NAMES, "*type-neobuff")

-- Runs in the secure environment (no access to addon Lua) before every click.
-- Returning a button name makes the click use that button's attributes instead.
ClickCast.RES_SNIPPET = [[
    local unit = self:GetAttribute("unit")
    if not unit then return end

    -- Find out what this click would do.
    local prefix = (IsShiftKeyDown() and "shift-") or (IsControlKeyDown() and "ctrl-")
                or (IsAltKeyDown() and "alt-") or ""
    local suffix = (button == "LeftButton" and "1") or (button == "RightButton" and "2")
                or (button == "MiddleButton" and "3") or strmatch(button, "^Button(%d+)$")
                or ("-" .. button)
    local action = self:GetAttribute(prefix .. "type" .. suffix)

    -- "Cast missing buff": casts the buff MissingBuffs.lua put in "*spell-neobuff"
    -- (only set out of combat, without ready check). [nocombat] is checked here as
    -- well, so in combat it never buffs even if that attribute stayed. With
    -- nothing to buff the click is cancelled: it does nothing at all.
    if action == "neobuff" then
        if self:GetAttribute("*spell-neobuff") and SecureCmdOptionParse("[nocombat] buff") then
            return "neobuff"
        end
        return false
    end

    -- A cast on a dead friendly unit becomes the res.
    if not self:GetAttribute("*type-neores") then return end
    if not SecureCmdOptionParse("[@" .. unit .. ",dead,help] res") then return end
    if action == "spell" or action == "macro" then return "neores" end
]]

-- The frame that owns the res snippets (secure wrappers need a secure handler).
ClickCast.resHandler = CreateFrame("Frame", "NeoHealResHandler", UIParent, "SecureHandlerBaseTemplate")

function ClickCast:GetResSpell()
    local _, class = UnitClass("player")
    local spellID = RES_SPELLS[class]
    if spellID and IsPlayerSpell(spellID) then
        return Spells:GetHighestRank(spellID) or spellID
    end
end

-- Secure snippets that bind the hover keys while the mouse is over a button. The
-- secure environment may not set "_" attributes (that would let snippets install
-- snippets), so these are only ever set from Lua, out of combat - never copied
-- by the header's setup snippet like the attributes above.
ClickCast.SNIPPET_ATTRIBUTE_NAMES = { "_onenter", "_onleave", "_onhide" }

---------------------------------------------------------------------------
-- Class defaults: used on a character's first login and by "Reset to class
-- defaults". Spell IDs are rank 1; the bindings cast the highest known rank.
-- Spells the character hasn't learned yet are left out.
---------------------------------------------------------------------------
local function Spell(spellID)
    return { action = "spell", spellID = spellID, highestRank = true, target = "unit" }
end

local COMMON_DEFAULTS = {
    ["1"]      = { action = "target", target = "unit" },
    ["2"]      = { action = "menu" },
    ["ctrl-1"] = { action = "target", target = "unit" },
    ["ctrl-2"] = { action = "menu" },
}

local CLASS_DEFAULTS = {
    PRIEST = {
        ["1"] = Spell(2050),        -- Lesser Heal
        ["2"] = Spell(139),         -- Renew
        ["shift-1"] = Spell(2061),  -- Flash Heal
        ["shift-2"] = Spell(17),    -- Power Word: Shield
        ["3"] = Spell(527),         -- Dispel Magic
        ["shift-3"] = Spell(528),   -- Cure Disease
    },
    DRUID = {
        ["1"] = Spell(5185),        -- Healing Touch
        ["2"] = Spell(774),         -- Rejuvenation
        ["shift-1"] = Spell(8936),  -- Regrowth
        ["3"] = Spell(2782),        -- Remove Curse
        ["shift-3"] = Spell(8946),  -- Cure Poison
    },
    PALADIN = {
        ["1"] = Spell(635),         -- Holy Light
        ["shift-1"] = Spell(19750), -- Flash of Light
        ["3"] = Spell(4987),        -- Cleanse
        ["shift-3"] = Spell(1152),  -- Purify
    },
    SHAMAN = {
        ["1"] = Spell(331),         -- Healing Wave
        ["shift-1"] = Spell(8004),  -- Lesser Healing Wave
        ["3"] = Spell(526),         -- Cure Poison
        ["shift-3"] = Spell(2870),  -- Cure Disease
    },
    MAGE = {
        ["3"] = Spell(475),         -- Remove Lesser Curse
    },
}

function ClickCast:GetClassDefaults()
    local _, class = UnitClass("player")
    local bindings = CopyTable(COMMON_DEFAULTS)
    for key, binding in pairs(CLASS_DEFAULTS[class] or {}) do
        if IsPlayerSpell(binding.spellID) then
            bindings[key] = CopyTable(binding)
        end
    end
    return bindings
end

---------------------------------------------------------------------------
-- Reading and changing bindings
---------------------------------------------------------------------------
function ClickCast:Initialize()
    local charDB = NeoHeal.charDB
    charDB.bindings = charDB.bindings or self:GetClassDefaults()
    charDB.hoverKeys = charDB.hoverKeys or {}   -- [slot] = "Q", "1", ...
end

function ClickCast:Get(key)
    return NeoHeal.charDB.bindings[key]
end

function ClickCast:Set(key, binding)
    NeoHeal.charDB.bindings[key] = binding
    self:QueueApply()
end

function ClickCast:SetTarget(key, target)
    local binding = self:Get(key)
    if binding then
        binding.target = target
        self:QueueApply()
    end
end

function ClickCast:SetAlsoTarget(key, alsoTarget)
    local binding = self:Get(key)
    if binding then
        binding.alsoTarget = alsoTarget
        self:QueueApply()
    end
end

function ClickCast:GetHoverKey(slot)
    return NeoHeal.charDB.hoverKeys[slot]
end

-- key = "Q", "1", ... or nil to clear. A key can only belong to one slot.
function ClickCast:SetHoverKey(slot, key)
    local hoverKeys = NeoHeal.charDB.hoverKeys
    for otherSlot = 1, NUM_HOVER_KEYS do
        if key and hoverKeys[otherSlot] == key then hoverKeys[otherSlot] = nil end
    end
    hoverKeys[slot] = key
    self:QueueApply()
end

function ClickCast:ResetToDefaults()
    NeoHeal.charDB.bindings = self:GetClassDefaults()
    self:QueueApply()
end

-- True for a plain "Highest rank" binding: it names no rank, so the game casts the highest.
local function CastsHighestRank(binding)
    return binding.highestRank and (binding.rankOffset or 0) == 0
end

-- "Flash Heal", "Flash Heal (Rank 3)", "Flash Heal (Rank 6, highest -1)",
-- "Remove Curse (not learned)", "Target", ...
function ClickCast:Describe(binding)
    if not binding then return L.ACTION_NONE end
    if binding.action == "target" then return L.ACTION_TARGET end
    if binding.action == "menu" then return L.ACTION_MENU end
    if binding.action == "buff" then return L.ACTION_BUFF end

    local name = Spells.GetName(binding.spellID) or ("#" .. binding.spellID)
    if not IsPlayerSpell(binding.spellID) then
        return format("%s (%s)", name, L.NOT_LEARNED)
    end
    if CastsHighestRank(binding) then return name end
    local rank = Spells:GetRankText(self:GetSpellValue(binding))
    if binding.highestRank then
        local label = rank and format("%s, %s", rank, L.HIGHEST_RANK_MINUS_ONE_SHORT) or L.HIGHEST_RANK_MINUS_ONE_SHORT
        return format("%s (%s)", name, label)
    end
    return rank and format("%s (%s)", name, rank) or name
end

---------------------------------------------------------------------------
-- Turning bindings into secure attributes
---------------------------------------------------------------------------

-- What goes into the "spell" attribute. A spell ID casts exactly that rank.
-- "Highest rank" bindings resolve again whenever spells change (Core.lua).
function ClickCast:GetSpellValue(binding)
    if binding.highestRank then
        return Spells:GetHighestRank(binding.spellID, binding.rankOffset) or binding.spellID
    end
    return binding.spellID
end

-- A secure button can do only one thing per click, so "cast and also target" is a
-- two-line macro. Hovering a unit button makes its unit the "mouseover" unit, and
-- "mouseovertarget" / "mouseovertargettarget" follow the "cast on" choice:
--     /target mouseover
--     /cast [@mouseover] Flash Heal(Rank 3)
function ClickCast:BuildTargetingMacro(binding)
    local unit = "mouseover" .. (binding.target ~= "unit" and binding.target or "")
    local spellID = self:GetSpellValue(binding)
    local spell = Spells.GetName(spellID) or ""
    local rank = not CastsHighestRank(binding) and Spells:GetRankText(spellID)
    if rank then spell = format("%s(%s)", spell, rank) end
    return format("/target %s\n/cast [@%s] %s", unit, unit, spell)
end

-- The _onenter snippet: bind each hover key (with every modifier, since "SHIFT-Q"
-- is a different binding than "Q") to click this button with its virtual button.
function ClickCast:BuildHoverKeySnippet()
    local lines = {}
    for _, button in ipairs(self.BUTTONS) do
        local key = button.hoverKey and self:GetHoverKey(button.hoverKey)
        if key then
            for _, modifier in ipairs(self.MODIFIERS) do
                table.insert(lines, format("self:SetBindingClick(true, %q, self, %q)",
                    modifier.keyPrefix .. key, button.virtualButton))
            end
        end
    end
    return #lines > 0 and table.concat(lines, "\n") or nil
end

-- { [attributeName] = value } for the current bindings.
function ClickCast:BuildAttributes()
    local attributes = {}
    for key, binding in pairs(NeoHeal.charDB.bindings) do
        local slot = SLOTS[key]
        if slot then
            local prefix, buttonId = slot.prefix, slot.buttonId
            if binding.action == "spell" and binding.alsoTarget then
                attributes[prefix .. "type" .. buttonId] = "macro"
                attributes[prefix .. "macrotext" .. buttonId] = self:BuildTargetingMacro(binding)
            else
                attributes[prefix .. "type" .. buttonId] = ACTION_TYPES[binding.action]
                if binding.action == "spell" then
                    attributes[prefix .. "spell" .. buttonId] = self:GetSpellValue(binding)
                end
                if binding.action ~= "menu" and binding.action ~= "buff" and binding.target ~= "unit" then
                    attributes[prefix .. "unitsuffix" .. buttonId] = binding.target
                end
            end
        end
    end

    local resSpell = self:GetResSpell()
    if resSpell then
        attributes["*type-neores"] = "spell"
        attributes["*spell-neores"] = resSpell
    end
    attributes["*type-neobuff"] = "spell"

    local hoverSnippet = self:BuildHoverKeySnippet()
    if hoverSnippet then
        attributes._onenter = hoverSnippet
        attributes._onleave = "self:ClearBindings()"
        attributes._onhide = "self:ClearBindings()"
    end
    return attributes
end

-- Writes the bindings to every header (whose setup snippet copies them onto buttons
-- created later, see Layout.lua) and to every existing button.
function ClickCast:Apply()
    local attributes = self:BuildAttributes()
    for _, header in ipairs(NeoHeal.Layout:AllHeaders()) do
        -- A visible header re-runs its layout on every attribute change; hidden, it
        -- only does so once, when shown again.
        local wasShown = header:IsShown()
        header:Hide()
        header:SetAttribute("neoClickCount", #self.ATTRIBUTE_NAMES)
        for index, name in ipairs(self.ATTRIBUTE_NAMES) do
            header:SetAttribute("neoClickName" .. index, name)
            header:SetAttribute("neoClickValue" .. index, attributes[name])
        end
        header:SetShown(wasShown)
    end

    self.attributes = attributes
    for button in pairs(NeoHeal.UnitButton.buttons) do
        self:ApplyToButton(button)
    end
end

-- Writes the last applied bindings, hover-key snippets included, to one button.
-- Out of combat only; UnitButton calls it for buttons created in combat once
-- combat ends.
function ClickCast:ApplyToButton(button)
    local attributes = self.attributes
    if not attributes then return end
    for _, name in ipairs(self.ATTRIBUTE_NAMES) do
        button:SetAttribute(name, attributes[name])
    end
    for _, name in ipairs(self.SNIPPET_ATTRIBUTE_NAMES) do
        button:SetAttribute(name, attributes[name])
    end
end

function ClickCast:QueueApply()
    NeoHeal:RunOutOfCombat("applyBindings", function() self:Apply() end)
end

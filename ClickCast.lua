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

-- Blizzard's own click bindings (C_ClickBindings, see SecureUnitButton_OnClick)
-- drop a click of type "target", "menu" or "togglemenu" unless they hold an
-- Interaction binding for that button and modifiers. With Blizzard's default
-- bindings those are only plain left click (Target) and plain right click (Open
-- menu); this assumes those defaults. Everywhere else NeoHeal uses types of its
-- own: "neotarget", which the click snippet turns into a /target macro, and
-- "neomenu", which opens the menu from Lua (OpenUnitMenu).
local FALLBACK_TYPES = { target = "neotarget", menu = "neomenu" }

local function BlizzardLetsThrough(prefix, buttonId)
    return prefix == "" and (buttonId == "1" or buttonId == "2")
end

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

-- "neotarget": one virtual button per "Cast on" choice, each with its /target
-- macro; the click snippet picks the one the clicked binding needs.
local function TargetButton(target)
    return target == "unit" and "neotarget" or ("neotarget-" .. target)
end
for _, choice in ipairs(ClickCast.TARGETS) do
    table.insert(ClickCast.ATTRIBUTE_NAMES, "*type-" .. TargetButton(choice.value))
    table.insert(ClickCast.ATTRIBUTE_NAMES, "*macrotext-" .. TargetButton(choice.value))
end

-- Runs in the secure environment (no access to addon Lua) before every click.
-- Returning a button name makes the click use that button's attributes instead.
ClickCast.RES_SNIPPET = [[
    local unit = self:GetAttribute("unit")
    if not unit then return end

    -- Find out what this click would do, with the game's own prefix: every modifier
    -- held, as "alt-ctrl-shift-" (ClickCast.GetModifierPrefix, which can't be called
    -- from here). Two at once match no binding, so such a click does nothing.
    local prefix = (IsAltKeyDown() and "alt-" or "") .. (IsControlKeyDown() and "ctrl-" or "")
                .. (IsShiftKeyDown() and "shift-" or "")
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

    -- "Target" where Blizzard's click bindings would drop the click: the virtual
    -- button with the /target macro for its "Cast on" choice. Also on a dead unit.
    if action == "neotarget" then
        local target = self:GetAttribute(prefix .. "unitsuffix" .. suffix)
        return target and ("neotarget-" .. target) or "neotarget"
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

-- The game's held movement bindings: runOnUp="true" under the Movement header of
-- Blizzard's Bindings_Standard.xml, so they start on key down and stop on key up.
-- Toggles such as autorun aren't held and aren't here.
local HELD_MOVEMENT_BINDINGS = {
    MOVEANDSTEER = true, MOVEFORWARD = true, MOVEBACKWARD = true, TURNLEFT = true, TURNRIGHT = true,
    STRAFELEFT = true, STRAFERIGHT = true, JUMP = true, SITORSTAND = true, PITCHUP = true, PITCHDOWN = true,
}

-- Whether the key moves your character now, with any modifier the _onenter snippet
-- binds it with ("W" walks forward by default). The key capture (Options.lua)
-- refuses such a key: while the mouse is on a frame it would stop moving you, and
-- W kept the character walking (docs/forever-api.md section 6). A saved hover key
-- that moves you isn't bound (BuildHoverKeySnippet), and its button says so.
function ClickCast.MovesTheCharacter(key)
    for _, modifier in ipairs(ClickCast.MODIFIERS) do
        if HELD_MOVEMENT_BINDINGS[GetBindingAction(modifier.keyPrefix .. key)] then return true end
    end
    return false
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

-- Whether any modifier has an action on this hover key. A key without one is left
-- alone: binding it would only take the key away, and W as a hover key without an
-- action kept the character walking (docs/forever-api.md section 6).
local function HoverKeyHasAction(button)
    for _, modifier in ipairs(ClickCast.MODIFIERS) do
        if NeoHeal.charDB.bindings[modifier.prefix .. button.id] then return true end
    end
    return false
end

-- The _onenter snippet: bind each hover key that has an action and doesn't move
-- your character (with every modifier, since "SHIFT-Q" is a different binding than
-- "Q") to click this button with its virtual button. A key that moves you is
-- skipped even when saved: it was set before the key capture checked, or bound to
-- movement since.
function ClickCast:BuildHoverKeySnippet()
    local lines = {}
    for _, button in ipairs(self.BUTTONS) do
        local key = button.hoverKey and self:GetHoverKey(button.hoverKey)
        if key and HoverKeyHasAction(button) and not ClickCast.MovesTheCharacter(key) then
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
                local actionType = ACTION_TYPES[binding.action]
                if FALLBACK_TYPES[binding.action] and not BlizzardLetsThrough(prefix, buttonId) then
                    actionType = FALLBACK_TYPES[binding.action]
                end
                attributes[prefix .. "type" .. buttonId] = actionType
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
    for _, choice in ipairs(self.TARGETS) do
        local virtualButton = TargetButton(choice.value)
        attributes["*type-" .. virtualButton] = "macro"
        attributes["*macrotext-" .. virtualButton] = "/target mouseover" .. (choice.value ~= "unit" and choice.value or "")
    end

    -- Leaving and hiding clear the hover bindings even with no snippet: an action
    -- removed while the mouse is on a frame (applied when combat ends) would
    -- otherwise leave its key bound to that frame.
    attributes._onenter = self:BuildHoverKeySnippet()
    attributes._onleave = "self:ClearBindings()"
    attributes._onhide = "self:ClearBindings()"
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
    -- What the frames do now, for the tooltip: a binding changed in combat only
    -- takes effect when combat ends, and the tooltip waits for it too.
    self.appliedBindings = CopyTable(NeoHeal.charDB.bindings)
    self.appliedHoverKeys = CopyTable(NeoHeal.charDB.hoverKeys)
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
    button.neomenu = ClickCast.OpenUnitMenu   -- what a "neomenu" click calls
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

-- After a key binding changed (UPDATE_BINDINGS): a hover key may now move your
-- character, or no longer. Applies again only when that changes which keys the
-- frames take over. NeoHeal's own hover bindings may fire the same event on every
-- mouse-over (not checked); they never change this, because MovesTheCharacter
-- reads the bindings without those temporary ones.
function ClickCast:CheckHoverKeys()
    if not self.attributes then return end   -- not applied yet; Apply checks then
    if self:BuildHoverKeySnippet() ~= self.attributes._onenter then self:QueueApply() end
end

---------------------------------------------------------------------------
-- "Open unit menu" where Blizzard's click bindings would drop the click (type
-- "neomenu"): the game then calls the button's neomenu function, outside secure
-- code. It opens the menu Blizzard's togglemenu would open; an entry in it that
-- needs secure code, such as Set Focus, may be blocked from here.
---------------------------------------------------------------------------
local MENUS_BY_UNIT_TYPE = { player = "SELF", party = "PARTY", raid = "RAID_PLAYER", pet = "PET",
                             partypet = "OTHERPET", raidpet = "OTHERPET" }

-- The unit token "target" or "focus" says nothing about what is behind it: you,
-- a group member, a pet, someone outside your group or an NPC. So the menu is
-- read from the unit itself, as Blizzard's own frames do it. Taken from
-- TargetFrame_OpenMenu and FocusFrame_OpenMenu in
-- Blizzard_UnitFrame/Mainline/TargetFrame.lua (Gethe/wow-ui-source, branch
-- "live", read on 2026-11-15: lines 584-634 and 1096-1103). The focus frame
-- opens the focus menu whatever the focus is; the target frame picks one per
-- unit. Two of its answers are left out: a battle pet (Forever's content has no
-- pet battles [Likely], and a hunter's or warlock's pet is your pet or another
-- player's pet) and ENEMY_PLAYER (these frames show friendly units only).
-- Every answer here can be secret on maps where the game restricts addons
-- (forever-api.md section 2); IsTrue then reads it as false, which gives the
-- plain side of each choice. That FOCUS, TARGET, PLAYER and VEHICLE are the
-- names Forever's client registers is not checked in game (SELF, PARTY,
-- RAID_PLAYER, PET and OTHERPET are in use already).
local function DetectedMenu(unit)
    if unit == "focus" then return "FOCUS" end
    if NeoHeal.IsTrue(UnitIsUnit(unit, "player")) then return "SELF" end
    if NeoHeal.IsTrue(UnitIsUnit(unit, "vehicle")) then return "VEHICLE" end
    if NeoHeal.IsTrue(UnitIsUnit(unit, "pet")) then return "PET" end
    if NeoHeal.IsTrue(UnitIsOtherPlayersPet(unit)) then return "OTHERPET" end
    if NeoHeal.IsTrue(UnitIsPlayer(unit)) then
        if NeoHeal.IsTrue(UnitInRaid(unit)) then return "RAID_PLAYER" end
        if NeoHeal.IsTrue(UnitInParty(unit)) then return "PARTY" end
        return "PLAYER"
    end
    return "TARGET"   -- a friendly NPC
end

function ClickCast.OpenUnitMenu(frame, unit)
    -- Blizzard's menu click cancels a spell waiting for a target instead of opening
    -- the menu. SpellStopTargeting may be protected (not checked), so here the
    -- click just doesn't open the menu while a spell waits.
    if not unit or SpellIsTargeting() then return end
    unit = unit:lower()
    local unitType = unit:match("^([a-z]+)%d+$") or unit
    local which = MENUS_BY_UNIT_TYPE[unitType]
    -- In a raid you and your pet are raid units too. On maps where the game
    -- restricts addons the answer can be secret; then you get the raid member or
    -- other pet menu instead of an error.
    if unitType == "raid" and NeoHeal.IsTrue(UnitIsUnit(unit, "player")) then
        which = "SELF"
    elseif unitType == "raidpet" and NeoHeal.IsTrue(UnitIsUnit(unit, "pet")) then
        which = "PET"
    elseif unitType == "target" or unitType == "focus" then
        which = DetectedMenu(unitType)   -- the target and focus frames
    end
    if which then UnitPopup_OpenMenu(which, { ownerFrame = frame, unit = unit }) end
end

---------------------------------------------------------------------------
-- Tooltip: what each bound button does with the modifiers held right now,
-- added under the unit tooltip (UnitButton.lua).
---------------------------------------------------------------------------
local TOOLTIP_TITLE_COLOR = { 1, 0.82, 0 }   -- the game's gold
local TOOLTIP_LABEL_COLOR = { 0.7, 0.7, 0.7 }
local TOOLTIP_TEXT_COLOR = { 1, 1, 1 }

-- The prefix the game puts before a click's attribute names: every modifier held,
-- as "alt-ctrl-shift-" (SecureButton_GetModifierPrefix). With two or more held
-- it matches no binding here, so the click does nothing; RES_SNIPPET builds the
-- same prefix, so it doesn't redirect such a click to the res or a buff either.
function ClickCast.GetModifierPrefix()
    return (IsAltKeyDown() and "alt-" or "") .. (IsControlKeyDown() and "ctrl-" or "")
        .. (IsShiftKeyDown() and "shift-" or "")
end

local TARGET_LABELS = {}   -- [target value] = label
for _, choice in ipairs(ClickCast.TARGETS) do TARGET_LABELS[choice.value] = choice.label end

---------------------------------------------------------------------------
-- What a click casts, for the cancel cue (UnitButton.lua). The cast events carry
-- no target, so a cast is tied to the frame by the click that started it: the frame
-- tells whether a click was a spell binding on the member itself, and the cue finds
-- the spell from the attributes last applied to the frames (self.attributes), the
-- same source the tooltip and GetLeftClickSpell read. Never from the button's own
-- "spell" attribute: a "Cast and also target" binding is a macro with no spellID in
-- it. Not checked in game: whether a virtual-button click (a hover key) reaches the
-- button's PreClick hook at all.
---------------------------------------------------------------------------
-- Group heals, per class: a cast on one member says nothing about the others the
-- spell reaches, so no cue shows for them. Spell IDs turned into names at run time,
-- as Hots.lua does for its HoTs, so every language and every rank of the spell is
-- covered; the IDs are Classic-era's, not checked in game.
local GROUP_HEALS = {
    PRIEST = { 596 },          -- Prayer of Healing
    SHAMAN = { 1064 },         -- Chain Heal
}
local groupHealNames

local function GetGroupHealNames()
    if not groupHealNames then
        groupHealNames = {}
        local _, class = UnitClass("player")
        for _, spellID in ipairs(GROUP_HEALS[class] or {}) do
            local name = C_Spell.GetSpellName(spellID)
            if name then groupHealNames[name] = true end
        end
    end
    return groupHealNames
end

-- The binding key a click uses, from the mouse button the hook reports and the
-- modifiers held now: "shift-1" for shift + left click, and "shift--neokey1" for a
-- hover key, whose click arrives as the virtual button "neokey1" (the agent's name
-- for it, as PrintClick reads it) bound with every modifier prefix.
local function ClickBindingKey(prefix, mouseButton)
    local id = mouseButton == "LeftButton" and "1" or mouseButton == "RightButton" and "2"
        or mouseButton == "MiddleButton" and "3" or mouseButton:match("^Button(%d+)$")
    if id then return prefix .. id end
    local hoverSlot = mouseButton:match("^neokey(%d+)$")
    return hoverSlot and (prefix .. "-neokey" .. hoverSlot) or nil
end

-- The spell this click casts on the clicked member itself, or nil: another action
-- (menu, Target, missing buff), a spell sent to the member's target or their
-- target's target, or a spell whose name the game doesn't give. A group heal gets
-- nil too: the clicked member being full says nothing about the others it reaches.
-- Read from the bindings last applied to the frames, the same source the tooltip and
-- GetLeftClickSpell use, so the answer is what the frames do now.
function ClickCast.GetClickSpell(mouseButton)
    local bindings = ClickCast.appliedBindings or (NeoHeal.charDB and NeoHeal.charDB.bindings)
    local key = bindings and ClickBindingKey(ClickCast.GetModifierPrefix(), mouseButton)
    local binding = key and bindings[key]
    -- An instant or a cast-time spell both count here; whether a cast actually
    -- started is the cast event's answer, not this one.
    if not binding or binding.action ~= "spell" or binding.target ~= "unit" then return nil end
    local spellID = ClickCast:GetSpellValue(binding)
    local name = C_Spell.GetSpellName(spellID)
    if not name or GetGroupHealNames()[name] then return nil end
    return spellID, name
end

-- How much a spell heals or absorbs, read from its description, so the numbers of
-- exactly this rank: "Heals a friendly target for 237 to 280." gives "237-280";
-- "... absorbing 942 damage" an absorb of 942; a HoT gives its total ("Heals the
-- target for 32 over 12 sec."); Holy Shock its "204 to 220 healing". Healing
-- amounts only count when the sentence speaks of healing, so a damage spell gets
-- none. English descriptions only: any other text gives nil, and the tooltip shows
-- no number rather than a wrong one. A number may hold thousands commas, but never
-- ends in one ("332 to 381, then jumps").
local NUMBER = "([%d,]*%d)"
local AMOUNT_PATTERNS = {
    { pattern = "[Hh]eal[^.]-for " .. NUMBER .. " to " .. NUMBER, kind = "heal" },
    { pattern = NUMBER .. " to " .. NUMBER .. " healing", kind = "heal" },
    { pattern = "absorbing " .. NUMBER .. " damage", kind = "absorb" },
    { pattern = "[Hh]eal[^.]-" .. NUMBER .. " damage over", kind = "heal" },
    { pattern = "[Hh]eal[^.]-for " .. NUMBER .. " over", kind = "heal" },
}

-- The description's numbers: low and high as text (high nil for a single amount)
-- and "heal" or "absorb"; nil when there are none. The heal prediction asks in
-- combat too, so a description the game might hide then is left alone.
local function MatchAmount(spellID)
    local description = C_Spell.GetSpellDescription(spellID)
    if NeoHeal.IsSecret(description) or type(description) ~= "string" then return nil end
    for _, entry in ipairs(AMOUNT_PATTERNS) do
        local low, high = description:match(entry.pattern)
        if low then return low, high, entry.kind end
    end
end

-- The amount text ("237-280" or "942") and "heal" or "absorb", or nil.
function ClickCast.GetSpellAmount(spellID)
    local low, high, kind = MatchAmount(spellID)
    if low then return high and (low .. "-" .. high) or low, kind end
end

local function ToNumber(text)
    return tonumber((text:gsub(",", "")))
end

-- The spell an unmodified left click casts on the clicked unit, for the range check
-- on the target and focus frames (UnitButton.UpdateRange): those units can be
-- outside your group, where UnitInRange tells nothing (forever-api.md section 2).
-- Always the no-modifier binding, whatever is held now: a fade must not change
-- while you hold Shift. Read from the bindings last applied to the frames, like
-- the tooltip, so the fade matches what that click casts. Nil when that click
-- isn't a spell on the unit itself (a menu, a buff, a spell cast on the unit's
-- target): the frame then never fades, which is the safe side. "Cast and also
-- target" counts: that click casts on the unit too.
function ClickCast:GetLeftClickSpell()
    local bindings = self.appliedBindings or NeoHeal.charDB.bindings
    local binding = bindings["1"]
    if not binding or binding.action ~= "spell" or binding.target ~= "unit" then return nil end
    return self:GetSpellValue(binding)
end

-- The heal prediction on a hovered frame (UnitButton.lua): how much a left click
-- with the modifiers held now heals or shields that frame, as low and high numbers
-- (the same for a single amount), "heal" or "absorb", and the spell the click
-- casts. The shield rules tell one shield from another by that spell, so the bar
-- adds it here rather than the frames calling back for it. Nil when that click
-- doesn't heal or shield the frame: another action, a spell cast on another unit,
-- a spell not learned, or no readable amount.
function ClickCast:GetLeftClickAmount()
    local bindings = self.appliedBindings or NeoHeal.charDB.bindings
    local binding = bindings[ClickCast.GetModifierPrefix() .. "1"]
    if not binding or binding.action ~= "spell" or binding.target ~= "unit"
            or not IsPlayerSpell(binding.spellID) then
        return nil
    end
    local spellID = self:GetSpellValue(binding)
    local low, high, kind = MatchAmount(spellID)
    if not low then return nil end
    low = ToNumber(low)
    return low, high and ToNumber(high) or low, kind, spellID
end

local HEAL_AMOUNT = "|cff33ff33%s|r"     -- green
local ABSORB_AMOUNT = "|cff99ccff%s|r"   -- light blue, a little darker than the shield bar

-- "Flash Heal", or "Flash Heal (Unit's target)" when it doesn't go to the clicked
-- unit; a learned spell gets its amount after it: "Healing Wave 237-280".
local function DescribeForTooltip(binding)
    local text = ClickCast:Describe(binding)
    local target = binding.action ~= "menu" and binding.action ~= "buff" and binding.target
    if target and target ~= "unit" then
        text = format("%s (%s)", text, TARGET_LABELS[target] or target)
    end
    if binding.action == "spell" and IsPlayerSpell(binding.spellID) then
        local amount, kind = ClickCast.GetSpellAmount(ClickCast:GetSpellValue(binding))
        if kind == "absorb" then
            text = format("%s " .. ABSORB_AMOUNT, text, format(L.TOOLTIP_ABSORB, amount))
        elseif amount then
            text = format("%s " .. HEAL_AMOUNT, text, amount)
        end
    end
    return text
end

-- One line per bound button ("Left click    Flash Heal") for the modifiers held
-- now, under a "Shift" title while one is held; nothing when nothing is bound for
-- them. A hover key shows once it has a key: without one it can't be pressed.
-- Shows the bindings last applied to the frames (Apply), not edits still waiting
-- for combat to end.
function ClickCast:AddBindingsToTooltip(tooltip)
    local bindings = self.appliedBindings or NeoHeal.charDB.bindings
    local hoverKeys = self.appliedHoverKeys or NeoHeal.charDB.hoverKeys
    local prefix = ClickCast.GetModifierPrefix()
    local lines = {}
    for _, button in ipairs(self.BUTTONS) do
        local binding = bindings[prefix .. button.id]
        local label = button.label
        if button.hoverKey then
            -- A key that moves you isn't bound (BuildHoverKeySnippet): it does nothing.
            local key = hoverKeys[button.hoverKey]
            label = key and not ClickCast.MovesTheCharacter(key) and format(L.HOVER_KEY, key)
        end
        if binding and label then
            table.insert(lines, { label, DescribeForTooltip(binding) })
        end
    end
    if #lines == 0 then return end

    tooltip:AddLine(" ")
    for _, modifier in ipairs(self.MODIFIERS) do
        if prefix ~= "" and modifier.prefix == prefix then
            local color = TOOLTIP_TITLE_COLOR
            tooltip:AddLine(modifier.label, color[1], color[2], color[3])
        end
    end
    local labelColor, textColor = TOOLTIP_LABEL_COLOR, TOOLTIP_TEXT_COLOR
    for _, line in ipairs(lines) do
        tooltip:AddDoubleLine(line[1], line[2], labelColor[1], labelColor[2], labelColor[3],
            textColor[1], textColor[2], textColor[3])
    end
end

-- Test support: just enough of the WoW client API to load NeoHeal's files outside
-- the game, and a fake spellbook. Every Load() builds a fresh addon namespace and
-- reinstalls the globals in InstallGlobals. Globals a test sets itself (as
-- TestOptionsWindow does for the options window) stay set for later tests.
local Support = {
    root = ".",   -- the addon folder; set by run.lua
}

-- The fake spells. Flash Heal has seven ranks; Abolish Disease has one and no
-- rank text, like rankless spells in the game.
local FLASH_HEAL = { 2061, 9472, 9473, 9474, 10915, 10916, 10917 }   -- rank 1 to 7
local ABOLISH_DISEASE = 552
Support.FLASH_HEAL = FLASH_HEAL
Support.ABOLISH_DISEASE = ABOLISH_DISEASE

local CATALOGUE = {}   -- [spellID] = { name, subName }
for rank, spellID in ipairs(FLASH_HEAL) do
    CATALOGUE[spellID] = { name = "Flash Heal", subName = "Rank " .. rank }
end
CATALOGUE[ABOLISH_DISEASE] = { name = "Abolish Disease", subName = "" }

local state = {
    book = {},              -- spell IDs in the spellbook, in order
    known = {},             -- [spellID] = true
    subtextMissing = false, -- C_Spell.GetSpellSubtext returns "" for everything
    modifiers = {},         -- held modifier keys: { shift = true, ... }
    descriptions = {},      -- [spellID] = description text
}

local function Wipe(t)
    for key in pairs(t) do t[key] = nil end
    return t
end

local function CopyTableDeep(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and CopyTableDeep(value) or value
    end
    return copy
end

-- A frame that keeps its scripts and registered events in frame.stub
-- (frame.stub.scripts.OnEvent, frame.stub.events.SOME_EVENT). Like a real frame,
-- registering an event the client doesn't know raises an error, every other
-- method (a PascalCase name) does nothing, and any other field is nil until set.
-- All frames created since the last Load are in Support.frames.
local function NoOp() end

-- The real client errors when registering an unknown event; unregistering one is
-- assumed to fail the same way (not checked in the game), which is the safe side
-- for a test.
local function CheckEvent(action, event)
    if C_EventUtils and not C_EventUtils.IsEventValid(event) then
        error("Attempt to " .. action .. " unknown event \"" .. event .. "\"", 3)
    end
end

local function CreateFrameStub()
    local frame = { stub = { scripts = {}, events = {} } }
    function frame:SetScript(name, func) self.stub.scripts[name] = func end
    function frame:RegisterEvent(event) CheckEvent("register", event); self.stub.events[event] = true end
    function frame:UnregisterEvent(event) CheckEvent("unregister", event); self.stub.events[event] = nil end
    setmetatable(frame, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return NoOp end
    end })
    table.insert(Support.frames, frame)
    return frame
end

local function InstallGlobals()
    format = string.format
    wipe = Wipe
    CopyTable = CopyTableDeep
    Support.frames = {}
    CreateFrame = CreateFrameStub
    InCombatLockdown = function() return false end
    C_Timer = { After = function(_, func) func() end, NewTicker = function() end }   -- no waiting in tests
    C_EventUtils = { IsEventValid = function() return true end }
    SlashCmdList = {}
    Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 }, TooltipDataType = { Unit = 2 } }
    UnitClass = function() return "Priest", "PRIEST" end

    -- Modifier keys: none held until Support.SetModifiers.
    state.modifiers = {}
    IsShiftKeyDown = function() return state.modifiers.shift == true end
    IsControlKeyDown = function() return state.modifiers.ctrl == true end
    IsAltKeyDown = function() return state.modifiers.alt == true end

    -- Tooltip post-calls are kept in Support.tooltipPostCalls[dataType]; a fake
    -- tooltip's SetUnit runs the unit ones, as the game does.
    Support.tooltipPostCalls = {}
    TooltipDataProcessor = {
        AddTooltipPostCall = function(dataType, func)
            Support.tooltipPostCalls[dataType] = Support.tooltipPostCalls[dataType] or {}
            table.insert(Support.tooltipPostCalls[dataType], func)
        end,
    }
    GameTooltip_SetDefaultAnchor = function(tooltip, owner) tooltip:SetOwner(owner) end

    -- Unit menus opened are kept in Support.openedMenus: { which, contextData }.
    -- UnitIsUnit knows only a unit compared with itself until a test replaces it;
    -- no value is secret until a test sets issecretvalue.
    Support.openedMenus = {}
    UnitPopup_OpenMenu = function(which, contextData) table.insert(Support.openedMenus, { which, contextData }) end
    UnitIsUnit = function(a, b) return a == b end
    issecretvalue = nil
    SpellIsTargeting = function() return false end   -- no spell waiting for a target

    -- Messages at the top of the screen are kept in Support.errorMessages.
    Support.errorMessages = {}
    UIErrorsFrame = { AddMessage = function(_, message) table.insert(Support.errorMessages, message) end }

    C_Spell = {
        GetSpellName = function(spellID)
            local spell = CATALOGUE[spellID]
            return spell and spell.name
        end,
        GetSpellSubtext = function(spellID)
            local spell = CATALOGUE[spellID]
            if not spell or state.subtextMissing then return "" end
            return spell.subName
        end,
        -- No description until a test sets one (Support.SetDescription).
        GetSpellDescription = function(spellID) return state.descriptions[spellID] end,
    }
    state.descriptions = {}
    -- Strict like the game, which errors on a missing spell ID.
    IsPlayerSpell = function(spellID)
        assert(type(spellID) == "number", "IsPlayerSpell needs a spell ID")
        return state.known[spellID] == true
    end

    -- One skill line holding the spellbook.
    C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function()
            return { name = "Holy", itemIndexOffset = 0, numSpellBookItems = #state.book }
        end,
        GetSpellBookItemInfo = function(slot)
            local spellID = state.book[slot]
            local spell = CATALOGUE[spellID]
            return { itemType = Enum.SpellBookItemType.Spell, spellID = spellID, name = spell.name,
                     subName = spell.subName, iconID = 1, isPassive = false, isOffSpec = false }
        end,
    }
end

-- Which spells the character knows (and finds in the spellbook).
function Support.SetKnown(spellIDs)
    state.book = spellIDs
    Wipe(state.known)
    for _, spellID in ipairs(spellIDs) do state.known[spellID] = true end
end

-- The text C_Spell.GetSpellDescription returns for a spell ID.
function Support.SetDescription(spellID, text)
    state.descriptions[spellID] = text
end

-- Which modifier keys are held, e.g. { shift = true, ctrl = true }.
function Support.SetModifiers(held)
    state.modifiers = held
end

-- A tooltip that keeps what is shown on it, in tooltip.lines: { "unit", unit },
-- { "line", text } or { "double", left, right }; the colours of each line are in
-- tooltip.colors at the same index. SetUnit starts over, as the game's does, and
-- then runs the unit post-calls.
function Support.FakeTooltip(owner)
    local tooltip = { lines = {}, colors = {}, owner = owner, shown = false }
    function tooltip:GetOwner() return self.owner end
    function tooltip:SetOwner(newOwner) self.owner = newOwner end
    function tooltip:IsOwned(frame) return self.owner == frame end
    function tooltip:ClearLines() self.lines, self.colors = {}, {} end
    function tooltip:SetUnit(unit)
        self:ClearLines()
        table.insert(self.lines, { "unit", unit })
        table.insert(self.colors, {})
        for _, func in ipairs(Support.tooltipPostCalls[Enum.TooltipDataType.Unit] or {}) do func(self) end
    end
    function tooltip:AddLine(text, r, g, b)
        table.insert(self.lines, { "line", text })
        table.insert(self.colors, { r, g, b })
    end
    function tooltip:AddDoubleLine(left, right, lr, lg, lb, rr, rg, rb)
        table.insert(self.lines, { "double", left, right })
        table.insert(self.colors, { lr, lg, lb, rr, rg, rb })
    end
    function tooltip:Show() self.shown = true end
    function tooltip:Hide() self.shown = false; self.owner = nil end
    return tooltip
end

-- What the secure environment's SecureCmdOptionParse does with the option strings
-- the click snippet uses, "[@unit,dead,help] res" and "[nocombat] buff": the text
-- after the conditions when they all hold, else nil. `world` says which units are
-- dead or friendly and whether you are in combat.
local function OptionParser(world)
    return function(options)
        local conditions, result = options:match("^%[(.-)%]%s*(.*)$")
        local unit
        for condition in conditions:gmatch("[^,]+") do
            if condition:sub(1, 1) == "@" then
                unit = condition:sub(2)
            elseif condition == "dead" then
                if not (unit and world.dead[unit]) then return nil end
            elseif condition == "help" then
                if not (unit and world.friendly[unit]) then return nil end
            elseif condition == "nocombat" then
                if world.inCombat then return nil end
            else
                error("a condition this fake doesn't know: " .. condition)
            end
        end
        return result
    end
end

-- A world for RunSnippet: party1 and party2 friendly and alive, out of combat.
function Support.World(changes)
    local world = { dead = {}, friendly = { party1 = true, party2 = true }, inCombat = false }
    for key, value in pairs(changes or {}) do world[key] = value end
    return world
end

-- ClickCast.RES_SNIPPET runs in the game's secure environment before every click.
-- Here it runs as plain Lua, with fakes for what that environment offers. Returns
-- what the snippet returns: the virtual button the click turns into, false to
-- cancel the click, or nil to leave it alone.
function Support.RunSnippet(snippet, attributes, mouseButton, world)
    local env = {
        IsShiftKeyDown = IsShiftKeyDown, IsControlKeyDown = IsControlKeyDown, IsAltKeyDown = IsAltKeyDown,
        strmatch = string.match,
        SecureCmdOptionParse = OptionParser(world),
    }
    local frame = { GetAttribute = function(_, name) return attributes[name] end }
    local source = "local self, button = ...\n" .. snippet
    local chunk
    if setfenv then   -- Lua 5.1, as in the game
        chunk = assert(loadstring(source))
        setfenv(chunk, env)
    else
        chunk = assert(load(source, "RES_SNIPPET", "t", env))
    end
    return chunk(frame, mouseButton)
end

-- Makes C_Spell.GetSpellSubtext return "" (the scan still sees the spellbook's subName).
function Support.SetSubtextMissing(missing)
    state.subtextMissing = missing
end

-- Loads more addon files (paths relative to the addon folder) into `ns`.
function Support.LoadInto(ns, files)
    for _, file in ipairs(files) do
        local chunk = assert(loadfile(Support.root .. "/" .. file))
        chunk("NeoHeal", ns)
    end
    return ns
end

-- Loads addon files into a new namespace. `known` defaults to every fake spell.
function Support.Load(files, known)
    InstallGlobals()
    state.subtextMissing = false
    local all = { ABOLISH_DISEASE }
    for _, spellID in ipairs(FLASH_HEAL) do table.insert(all, spellID) end
    Support.SetKnown(known or all)
    return Support.LoadInto({}, files)
end

return Support

-- Test support: just enough of the WoW client API to load NeoHeal's files outside
-- the game, and a fake spellbook. Every Load() builds a fresh addon namespace and
-- reinstalls the globals in InstallGlobals. Globals a test sets itself (as
-- TestOptionsWindow does for the options window) stay set for later tests.
local Support = {
    root = ".",   -- the addon folder; set by run.lua
}

-- The fake spells. Flash Heal has seven ranks; Abolish Disease has one and no
-- rank text, like rankless spells in the game. Weakened Soul only has a name, for
-- matching auras. Power Word: Shield (ranks 1 and 10) and Ice Barrier (rank 1) are
-- in no spellbook unless a test passes them to Load or SetKnown. The ids of Power
-- Word: Shield rank 10 and Ice Barrier are Classic's as far as known, not checked in game.
local FLASH_HEAL = { 2061, 9472, 9473, 9474, 10915, 10916, 10917 }   -- rank 1 to 7
local ABOLISH_DISEASE = 552
local WEAKENED_SOUL = 6788
local POWER_WORD_SHIELD = 17
local POWER_WORD_SHIELD_10 = 10901
local ICE_BARRIER = 11426
Support.FLASH_HEAL = FLASH_HEAL
Support.ABOLISH_DISEASE = ABOLISH_DISEASE
Support.POWER_WORD_SHIELD = POWER_WORD_SHIELD
Support.POWER_WORD_SHIELD_10 = POWER_WORD_SHIELD_10
Support.ICE_BARRIER = ICE_BARRIER

local CATALOGUE = {}   -- [spellID] = { name, subName }
for rank, spellID in ipairs(FLASH_HEAL) do
    CATALOGUE[spellID] = { name = "Flash Heal", subName = "Rank " .. rank }
end
CATALOGUE[ABOLISH_DISEASE] = { name = "Abolish Disease", subName = "" }
CATALOGUE[WEAKENED_SOUL] = { name = "Weakened Soul", subName = "" }
CATALOGUE[POWER_WORD_SHIELD] = { name = "Power Word: Shield", subName = "Rank 1" }
CATALOGUE[POWER_WORD_SHIELD_10] = { name = "Power Word: Shield", subName = "Rank 10" }
CATALOGUE[ICE_BARRIER] = { name = "Ice Barrier", subName = "Rank 1" }

-- The spells of the cancel cue's tests (spec/castcue_test.lua), rank 1 each, in no
-- spellbook. Their ids are Classic's as far as known, not checked in game: Greater
-- Heal (a slow heal with a cast time), Prayer of Healing and Chain Heal (group heals
-- with a cast time), Resurrection, Renew (an instant), Health Funnel and Mind Flay
-- (channels).
Support.GREATER_HEAL = 2060
Support.PRAYER_OF_HEALING = 596
Support.CHAIN_HEAL = 1064
Support.RESURRECTION = 2006
Support.RENEW = 139
Support.HEALTH_FUNNEL = 755
Support.MIND_FLAY = 15407
CATALOGUE[Support.GREATER_HEAL] = { name = "Greater Heal", subName = "Rank 1" }
CATALOGUE[Support.PRAYER_OF_HEALING] = { name = "Prayer of Healing", subName = "Rank 1" }
CATALOGUE[Support.CHAIN_HEAL] = { name = "Chain Heal", subName = "Rank 1" }
CATALOGUE[Support.RESURRECTION] = { name = "Resurrection", subName = "Rank 1" }
CATALOGUE[Support.RENEW] = { name = "Renew", subName = "Rank 1" }
CATALOGUE[Support.HEALTH_FUNNEL] = { name = "Health Funnel", subName = "Rank 1" }
CATALOGUE[Support.MIND_FLAY] = { name = "Mind Flay", subName = "Rank 1" }

local state = {
    book = {},              -- spell IDs in the spellbook, in order
    known = {},             -- [spellID] = true
    subtextMissing = false, -- C_Spell.GetSpellSubtext returns "" for everything
    modifiers = {},         -- held modifier keys: { shift = true, ... }
    descriptions = {},      -- [spellID] = description text
    powerCosts = {},        -- [spellID] = what C_Spell.GetSpellPowerCost returns
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
-- (frame.stub.scripts.OnEvent, frame.stub.events.SOME_EVENT; an event registered
-- for some units only in frame.stub.unitEvents.SOME_EVENT = { units }). Like a real frame,
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
    local frame = { stub = { scripts = {}, events = {}, unitEvents = {} } }
    function frame:SetScript(name, func) self.stub.scripts[name] = func end
    function frame:RegisterEvent(event) CheckEvent("register", event); self.stub.events[event] = true end
    function frame:UnregisterEvent(event) CheckEvent("unregister", event); self.stub.events[event] = nil end
    function frame:RegisterUnitEvent(event, ...) CheckEvent("register", event); self.stub.unitEvents[event] = { ... } end
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
    -- A fake clock: GetTime gives Support.now (seconds), moved with Support.SetTime.
    -- C_Timer.After still runs at once (no waiting in tests). NewTicker keeps each
    -- ticker in Support.tickers ({ interval, func, cancelled }) and never runs it:
    -- a test calls the update it wants at the moment it chose.
    Support.now = 1000
    GetTime = function() return Support.now end
    Support.tickers = {}
    C_Timer = {
        After = function(_, func) func() end,
        NewTicker = function(interval, func)
            local ticker = { interval = interval, func = func, cancelled = false }
            function ticker:Cancel() self.cancelled = true end
            table.insert(Support.tickers, ticker)
            return ticker
        end,
    }
    C_EventUtils = { IsEventValid = function() return true end }
    SlashCmdList = {}
    Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 }, TooltipDataType = { Unit = 2 },
             PowerType = { Mana = 0, Rage = 1, Energy = 3 } }
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
    -- Set by single tests (spec/prediction_test.lua); gone again for the next.
    UnitGetIncomingHeals, UnitGetTotalAbsorbs, C_UnitAuras = nil, nil, nil
    SpellIsTargeting = function() return false end   -- no spell waiting for a target
    GetBindingAction = function() return "" end       -- no key bound until a test binds one

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
        -- nil, as the game gives for a spell without a resource cost, until a test
        -- sets one (Support.SetPowerCost); Support.COST_ERROR makes the call raise.
        GetSpellPowerCost = function(spellID)
            local cost = state.powerCosts[spellID]
            if cost == Support.COST_ERROR then error("GetSpellPowerCost failed for " .. tostring(spellID)) end
            return cost
        end,
    }
    state.descriptions = {}
    state.powerCosts = {}
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

-- The fake clock (GetTime), in seconds.
function Support.SetTime(now)
    Support.now = now
end

-- What C_Spell.GetSpellPowerCost returns for a spell ID: a list of cost entries
-- (Support.ManaCost), nil, a hidden value, or Support.COST_ERROR to make it raise.
Support.COST_ERROR = setmetatable({}, { __tostring = function() return "COST_ERROR" end })
function Support.SetPowerCost(spellID, cost)
    state.powerCosts[spellID] = cost
end

-- One cost entry list as the 12.x API describes SpellPowerCostInfo (type, name,
-- cost, requiredAuraID, hasRequiredAura; field names from Blizzard's API docs,
-- not checked in game). `changes` overrides fields, e.g. { cost = 0 } for a free
-- cast or { name = "RAGE", type = 1 } for another resource.
function Support.ManaCost(changes)
    local entry = { type = 0, name = "MANA", cost = 100, minCost = 100, costPercent = 0, costPerSec = 0,
                    requiredAuraID = 0, hasRequiredAura = false }
    for key, value in pairs(changes or {}) do entry[key] = value end
    return { entry }
end

-- A frame (a StatusBar too) that keeps what was done to it: shown (true until
-- hidden, as a new frame in the game), its range, value, alpha, every
-- SetAlphaFromBoolean argument as given (in alphaFromBoolean, never tested), and
-- each recorded call in order (calls: { method, ... }). Any other method (a
-- PascalCase name) records nothing and returns another Recorder, so chained calls
-- such as bar:GetStatusBarTexture():SetVertexColor() work.
function Support.Recorder(kind, name, parent)
    local frame = { kind = kind, name = name, parent = parent, shown = true, min = 0, max = 1, value = 0,
                    alpha = 1, alphaFromBoolean = {}, calls = {}, points = {} }
    local function Record(method, ...) table.insert(frame.calls, { method, ... }) end
    function frame:Show() Record("Show"); self.shown = true end
    function frame:Hide() Record("Hide"); self.shown = false end
    function frame:SetShown(shown) Record("SetShown", shown); self.shown = shown and true or false end
    function frame:IsShown() return self.shown end
    function frame:SetMinMaxValues(min, max) Record("SetMinMaxValues", min, max); self.min, self.max = min, max end
    function frame:GetMinMaxValues() return self.min, self.max end
    function frame:SetValue(value) Record("SetValue", value); self.value = value end
    function frame:GetValue() return self.value end
    function frame:SetAlpha(alpha) Record("SetAlpha", alpha); self.alpha = alpha end
    function frame:SetAlphaFromBoolean(value, alphaIfTrue, alphaIfFalse)
        Record("SetAlphaFromBoolean", value, alphaIfTrue, alphaIfFalse)
        table.insert(self.alphaFromBoolean, value)
    end
    function frame:GetParent() return self.parent end
    function frame:SetPoint(...) table.insert(self.points, { ... }) end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetHeight(height) self.height = height end
    function frame:SetStatusBarTexture(texture) self.texture = texture end
    function frame:SetStatusBarColor(...) self.barColor = { ... } end
    function frame:SetText(text) self.text = text end
    function frame:IsVisible() return self.shown end
    function frame:GetFrameLevel() return 1 end
    function frame:GetWidth() return 10 end
    function frame:GetName() return self.name or "NeoHealTestFrame" end
    function frame:SetAttribute(key, value) self.attributes = self.attributes or {}; self.attributes[key] = value end
    function frame:GetAttribute(key) return (self.attributes or {})[key] end
    function frame:SetScript(scriptName, func) self.scripts = self.scripts or {}; self.scripts[scriptName] = func end
    -- A second hook on the same script runs after the first, as in the game.
    function frame:HookScript(scriptName, func)
        self.hooks = self.hooks or {}
        local earlier = self.hooks[scriptName]
        self.hooks[scriptName] = earlier and function(...) earlier(...); func(...) end or func
    end
    -- The last colour given by either call, as { r, g, b, a } (a is 1 when not given).
    function frame:SetVertexColor(r, g, b, a) Record("SetVertexColor", r, g, b, a); self.color = { r, g, b, a or 1 } end
    function frame:SetColorTexture(r, g, b, a) Record("SetColorTexture", r, g, b, a); self.color = { r, g, b, a or 1 } end
    function frame:CreateFontString() return Support.Recorder("FontString", nil, frame) end
    function frame:CreateTexture() return Support.Recorder("Texture", nil, frame) end
    return setmetatable(frame, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then
            return function() return Support.Recorder("Object", nil, frame) end
        end
    end })
end

-- A value the game hides: any comparison, arithmetic or indexing raises an error,
-- as on a real secret value, and issecretvalue (as Support.LoadUnitButtons
-- installs it) says it is one.
Support.hidden = {}
Support.revealed = {}   -- [secret] = the value a test gave it (Support.Secret's `value`)

-- `value`, when given, is what the secret stands for: the addon can't read it, a
-- test can, with Support.Reveal.
function Support.Secret(name, value)
    local function refuse() error("used the secret " .. name, 2) end
    local secret = setmetatable({}, { __eq = refuse, __lt = refuse, __le = refuse, __add = refuse, __sub = refuse,
                                      __mul = refuse, __div = refuse, __unm = refuse, __concat = refuse,
                                      __len = refuse, __index = refuse, __call = refuse,
                                      __tostring = function() return "secret " .. name end })
    Support.hidden[secret] = true
    Support.revealed[secret] = value
    return secret
end

-- What a value stands for: a secret's own value, anything else as it is.
function Support.Reveal(value)
    if Support.hidden[value] then return Support.revealed[value] end
    return value
end

-- Core, the click casting and UnitButton.lua loaded for real unit buttons on
-- Recorder frames (Support.RealButton). The unit API answers as for a living,
-- connected player with a mana strip who is no leader, has no raid marker and
-- nobody's resurrection coming; a test changes an answer with `override(name,
-- value)`, its own file's Override, so it is put back after the test. The modules
-- a button only hands work to (HoT icons, missing buffs, aura icons, dispels) do
-- nothing here.
function Support.LoadUnitButtons(override)
    local ns = Support.Load({ "Locales/enUS.lua" })
    Support.hidden = {}
    issecretvalue = function(value) return value ~= nil and Support.hidden[value] == true end   -- Core reads it when it loads
    Support.LoadInto(ns, { "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua" })
    override("CreateFrame", function(kind, name, parent) return Support.Recorder(kind, name, parent) end)
    override("SecureHandlerWrapScript", NoOp)
    override("unpack", unpack or table.unpack)
    override("PowerBarColor", { MANA = { r = 0, g = 0, b = 1 } })
    override("UnitExists", function() return true end)
    override("UnitIsConnected", function() return true end)
    override("UnitIsDeadOrGhost", function() return false end)
    override("UnitPowerType", function() return 0, "MANA" end)
    override("UnitHealth", function() return 50 end)
    override("UnitInRange", function() return true, true end)
    override("UnitHealthMax", function() return 100 end)
    override("UnitHealthPercent", nil)
    override("UnitPower", function() return 50 end)
    override("UnitPowerMax", function() return 100 end)
    override("UnitPowerPercent", nil)
    override("C_CurveUtil", nil)
    for _, name in ipairs({ "UnitIsPlayer", "UnitName", "UnitIsGroupAssistant", "UnitIsGroupLeader", "GetRaidTargetIndex",
                            "UnitInRaid", "UnitHasIncomingResurrection", "UnitCanAttack" }) do
        override(name, NoOp)
    end
    local function Module() return setmetatable({}, { __index = function() return NoOp end }) end
    ns.Hots, ns.MissingBuffs, ns.AuraContainer = Module(), Module(), Module()
    ns.Dispel = { known = {}, COLORS = {}, CanDispelAnything = function() return false end }
    ns.ClickCast.ApplyToButton = NoOp
    ns.charDB = { bindings = {}, hoverKeys = {} }   -- no left click spell: target and focus frames stay bright
    ns.db = { layout = { showFiveSecond = true, powerBar = "all", healthColor = "class", healthText = "none" } }
    return ns
end

-- A real unit button (UnitButton.Init on a Recorder), given `unit` the way a group
-- header gives it one (the "unit" attribute), or no unit yet.
function Support.RealButton(ns, unit)
    local button = Support.Recorder("Button", "NeoHealTestButton")
    ns.UnitButton.Init(button)
    button.dispelContainer, button.raidDebuffContainer = {}, {}   -- so a new unit builds no aura icons
    if unit then button.hooks.OnAttributeChanged(button, "unit", unit) end
    return button
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

-- A StatusBar that keeps its range, value, whether it shows, and the bar whose
-- fill it is anchored to (bar.after; nil until anchored).
function Support.FakeBar()
    local bar = { min = 0, max = 1, value = 0, shown = false }
    bar.fill = { bar = bar }
    function bar:SetMinMaxValues(min, max) self.min, self.max = min, max end
    function bar:SetValue(value) self.value = value end
    function bar:SetShown(shown) self.shown = shown and true or false end
    function bar:Show() self.shown = true end
    function bar:Hide() self.shown = false end
    function bar:IsShown() return self.shown end
    function bar:GetStatusBarTexture() return self.fill end
    function bar:ClearAllPoints() self.after = nil end
    function bar:SetPoint(_, relativeTo) self.after = relativeTo.bar end
    return bar
end

-- A unit button with the bars of the health bar, as UnitButton.CreateVisuals makes them.
function Support.FakeButton(unit)
    local noop = function() end
    local button = { unit = unit, highlight = { Show = noop, Hide = noop } }
    for _, key in ipairs({ "health", "incoming", "prediction", "predictionRange", "predictionAbsorb", "absorb" }) do
        button[key] = Support.FakeBar()
    end
    button.health.shown = true
    return button
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

-- Sends `event` with its arguments to every frame made since the last Load that
-- registered it: for every unit (RegisterEvent), or for the unit in the first
-- argument (RegisterUnitEvent). A unit the game hides counts as "player", as only
-- your own events reach a frame registered for "player". Returns whether any frame
-- heard it, so a test can tell an event nobody registered from one that did nothing.
function Support.FireEvent(event, ...)
    local unit = ...
    if Support.hidden[unit] then unit = "player" end
    local heard = false
    for _, frame in ipairs(Support.frames) do
        local wants = frame.stub.events[event]
        for _, registered in ipairs(frame.stub.unitEvents[event] or {}) do
            if rawequal(registered, unit) then wants = true end
        end
        local handler = frame.stub.scripts.OnEvent
        if wants and handler then
            handler(frame, event, ...)
            heard = true
        end
    end
    return heard
end

-- A click on a Recorder button with `mouseButton` ("LeftButton", "RightButton",
-- "Button4", or a hover key's "neokey1"), with the modifiers Support.SetModifiers
-- set: its PreClick, OnClick and PostClick scripts and hooks, in the game's order.
-- What the click casts is not here: the test fires the cast events the game would.
function Support.Click(button, mouseButton)
    for _, name in ipairs({ "PreClick", "OnClick", "PostClick" }) do
        local script = button.scripts and button.scripts[name]
        if script then script(button, mouseButton, false) end
        local hook = button.hooks and button.hooks[name]
        if hook then hook(button, mouseButton, false) end
    end
end

-- The cancel cue's two looks (the look kept in game on 2026-11-17): running gold while
-- the heal is still needed, red once the member is above the line.
Support.CUE_RUNNING = { 1, 0.7, 0, 0.8 }
Support.CUE_FULL = { 1, 0, 0, 1 }

local function SameColor(color, expected)
    for index = 1, 4 do
        if math.abs(color[index] - expected[index]) > 1e-6 then return false end
    end
    return true
end

-- What a real button's cancel cue shows: "none" (hidden, alpha 0, or a colour with
-- alpha 0), "running", "full", or a text naming any other colour, so a failing
-- assertion says what it saw. A hidden colour (a curve's answer in combat) is read
-- through Support.Reveal.
function Support.CueLook(button)
    local cue = button.cancelCue
    if not cue then return "no cue texture" end
    if not cue.shown or cue.alpha == 0 then return "none" end
    if not cue.color then return "shown without a colour" end
    local color = {}
    for index = 1, 4 do color[index] = Support.Reveal(cue.color[index]) end
    if color[4] == 0 then return "none" end
    if SameColor(color, Support.CUE_RUNNING) then return "running" end
    if SameColor(color, Support.CUE_FULL) then return "full" end
    return string.format("colour %s, %s, %s, %s", tostring(color[1]), tostring(color[2]), tostring(color[3]),
        tostring(color[4]))
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

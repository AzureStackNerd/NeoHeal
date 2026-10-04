-- The heal prediction: ClickCast:GetLeftClickHeal (what the left click with the
-- modifiers held heals) and UnitButton drawing it on the frame under the mouse.
local lu = require("luaunit")
local Support = require("support")
local FLASH_HEAL = Support.FLASH_HEAL

local function Spell(spellID, highestRank, target)
    return { action = "spell", spellID = spellID, highestRank = highestRank, target = target or "unit" }
end

local RANK_7 = "Heals a friendly target for 1,887 to 2,193."
local RANK_3 = "Heals a friendly target for 327 to 394."
local HOT = "Heals the target of 45 damage over 15 sec."
local SHIELD = "Draws on the soul of the party member to shield them, absorbing 942 damage. Lasts 30 sec."

local function Describe()
    Support.SetDescription(FLASH_HEAL[7], RANK_7)
    Support.SetDescription(FLASH_HEAL[3], RANK_3)
end

TestLeftClickHeal = {}

function TestLeftClickHeal:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = {}, hoverKeys = {} }
    Describe()
    self.ClickCast, self.bindings = ns.ClickCast, ns.charDB.bindings
end

function TestLeftClickHeal:Heal()
    return { self.ClickCast:GetLeftClickHeal() }
end

-- "Highest rank" on rank 1: the numbers are those of rank 7, without the commas.
function TestLeftClickHeal:testTheRangeOfTheRankTheClickCasts()
    self.bindings["1"] = Spell(FLASH_HEAL[1], true)
    lu.assertEquals(self:Heal(), { 1887, 2193 })
end

function TestLeftClickHeal:testTheHeldModifierPicksTheBinding()
    self.bindings["1"] = Spell(FLASH_HEAL[7], true)
    self.bindings["shift-1"] = Spell(FLASH_HEAL[3], false)
    Support.SetModifiers({ shift = true })
    lu.assertEquals(self:Heal(), { 327, 394 })
end

-- Two modifiers held: the click does nothing, so it heals nothing either.
function TestLeftClickHeal:testTwoModifiersHealNothing()
    self.bindings["shift-1"] = Spell(FLASH_HEAL[3], false)
    self.bindings["ctrl-1"] = Spell(FLASH_HEAL[7], false)
    Support.SetModifiers({ shift = true, ctrl = true })
    lu.assertEquals(self:Heal(), {})
end

function TestLeftClickHeal:testOnlyTheLeftClickCounts()
    self.bindings["2"] = Spell(FLASH_HEAL[7], true)
    lu.assertEquals(self:Heal(), {})
end

function TestLeftClickHeal:testASingleAmountIsBothLowAndHigh()
    Support.SetDescription(FLASH_HEAL[7], HOT)
    self.bindings["1"] = Spell(FLASH_HEAL[7], false)
    lu.assertEquals(self:Heal(), { 45, 45 })
end

function TestLeftClickHeal:testNothingWhenTheClickDoesntHealTheClickedUnit()
    local cases = {
        target = { action = "target", target = "unit" },
        menu = { action = "menu" },
        buff = { action = "buff" },
        ["on the unit's target"] = Spell(FLASH_HEAL[7], false, "target"),
        ["on the target's target"] = Spell(FLASH_HEAL[7], false, "targettarget"),
    }
    for name, binding in pairs(cases) do
        self.bindings["1"] = binding
        lu.assertEquals(self:Heal(), {}, name)
    end
end

function TestLeftClickHeal:testNothingForASpellNotLearned()
    self.bindings["1"] = Spell(FLASH_HEAL[7], false)
    Support.SetKnown({ FLASH_HEAL[1] })
    lu.assertEquals(self:Heal(), {})
end

function TestLeftClickHeal:testNothingForAShieldOrWithoutANumber()
    self.bindings["1"] = Spell(FLASH_HEAL[7], false)
    for _, text in ipairs({ SHIELD, "Removes 1 disease from the target.", "" }) do
        Support.SetDescription(FLASH_HEAL[7], text)
        lu.assertEquals(self:Heal(), {}, text)
    end
    Support.SetDescription(FLASH_HEAL[7], nil)
    lu.assertEquals(self:Heal(), {}, "no description")
end

-- A binding changed in combat only works once combat ends; until then the
-- prediction follows the click that works now.
function TestLeftClickHeal:testTheBindingsInEffectNotTheEditedOnes()
    self.bindings["1"] = Spell(FLASH_HEAL[7], false)
    self.ClickCast.appliedBindings = { ["1"] = Spell(FLASH_HEAL[3], false) }
    lu.assertEquals(self:Heal(), { 327, 394 })
end

-- Should the game hide a description in combat, it is not read.
function TestLeftClickHeal:testASecretDescriptionGivesNothing()
    local ns = Support.Load({ "Locales/enUS.lua" })
    issecretvalue = function(value) return value == RANK_7 end
    Support.LoadInto(ns, { "Core.lua", "Spells.lua", "ClickCast.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = { ["1"] = Spell(FLASH_HEAL[7], false) }, hoverKeys = {} }
    Describe()
    lu.assertEquals({ ns.ClickCast:GetLeftClickHeal() }, {})
end

-- UnitButton.lua: the two bars on the hovered frame.

local MAX_HEALTH = 3000

TestHealPrediction = {}

function TestHealPrediction:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = { ["1"] = Spell(FLASH_HEAL[7], true), ["shift-1"] = Spell(FLASH_HEAL[3], false) },
                  hoverKeys = {} }
    ns.db = { layout = { showTooltips = false, showHealPrediction = true } }
    Describe()
    UnitHealthMax = function() return MAX_HEALTH end
    UnitIsConnected = function() return true end
    UnitIsDeadOrGhost = function() return false end
    GameTooltip = Support.FakeTooltip()
    local noop = function() end
    self.button = { unit = "party1", highlight = { Show = noop, Hide = noop },
                    prediction = Support.FakeBar(), predictionRange = Support.FakeBar() }
    self.ns, self.UnitButton = ns, ns.UnitButton
end

-- What the two bars show: the lowest amount and the rest of the range, or
-- "hidden". A shown bar is checked against the unit's maximum health.
function TestHealPrediction:Bars()
    local shows = {}
    for index, bar in ipairs({ self.button.prediction, self.button.predictionRange }) do
        if bar.shown then
            lu.assertEquals(bar.max, MAX_HEALTH)
            shows[index] = bar.value
        else
            lu.assertEquals(bar.value, 0)   -- emptied, so the shields start at its beginning
            shows[index] = "hidden"
        end
    end
    return shows
end

local HIDDEN = { "hidden", "hidden" }

local function ModifierWatchers()
    local watchers = {}
    for _, frame in ipairs(Support.frames) do
        if frame.stub.events.MODIFIER_STATE_CHANGED then table.insert(watchers, frame) end
    end
    return watchers
end

local function PressModifiers(held)
    Support.SetModifiers(held)
    for _, watcher in ipairs(ModifierWatchers()) do
        watcher.stub.scripts.OnEvent(watcher, "MODIFIER_STATE_CHANGED")
    end
end

function TestHealPrediction:testHoveringShowsTheLeftClickHeal()
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), { 1887, 2193 - 1887 })
end

-- Even with the tooltip off, a modifier switches to its left click.
function TestHealPrediction:testAModifierSwitchesToItsLeftClick()
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(#ModifierWatchers(), 1)
    PressModifiers({ shift = true })
    lu.assertEquals(self:Bars(), { 327, 394 - 327 })
    PressModifiers({ shift = true, alt = true })
    lu.assertEquals(self:Bars(), HIDDEN)
end

function TestHealPrediction:testLeavingHidesItAndStopsWatching()
    self.UnitButton.OnEnter(self.button)
    self.UnitButton.OnLeave(self.button)
    lu.assertEquals(self:Bars(), HIDDEN)
    lu.assertEquals(#ModifierWatchers(), 0)
end

-- Should the client send OnEnter for the next frame before OnLeave for this one,
-- this one still loses its prediction, and the next keeps its own.
function TestHealPrediction:testLeavingAfterTheNextFrameWasEntered()
    local first, noop = self.button, function() end
    local second = { unit = "party2", highlight = { Show = noop, Hide = noop },
                     prediction = Support.FakeBar(), predictionRange = Support.FakeBar() }
    self.UnitButton.OnEnter(first)
    self.UnitButton.OnEnter(second)
    self.UnitButton.OnLeave(first)
    lu.assertEquals(self:Bars(), HIDDEN)
    self.button = second
    lu.assertEquals(self:Bars(), { 1887, 2193 - 1887 })
    -- The next one is still the hovered one: a modifier still switches its prediction.
    PressModifiers({ shift = true })
    lu.assertEquals(self:Bars(), { 327, 394 - 327 })
end

function TestHealPrediction:testNothingWhenTheOptionIsOff()
    self.ns.db.layout.showHealPrediction = false
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), HIDDEN)
    lu.assertEquals(#ModifierWatchers(), 0)
end

-- A spell click on a dead member casts your res, and an offline one can't be healed.
function TestHealPrediction:testNothingOnADeadOrOfflineMember()
    UnitIsDeadOrGhost = function() return true end
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), HIDDEN)
    self.UnitButton.OnLeave(self.button)

    UnitIsDeadOrGhost = function() return false end
    UnitIsConnected = function() return false end
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), HIDDEN)
end

function TestHealPrediction:testASingleAmountHasNoRange()
    Support.SetDescription(FLASH_HEAL[7], HOT)
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), { 45, "hidden" })
end

function TestHealPrediction:testNothingWhenTheLeftClickDoesntHeal()
    self.ns.charDB.bindings["1"] = { action = "target", target = "unit" }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), HIDDEN)
end

-- With both on, one watcher redraws the prediction and rebuilds the tooltip.
function TestHealPrediction:testTheTooltipAndThePredictionShareTheWatcher()
    self.ns.db.layout.showTooltips = true
    self.UnitButton.buttons[self.button] = true
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(#ModifierWatchers(), 1)
    PressModifiers({ shift = true })
    lu.assertEquals(self:Bars(), { 327, 394 - 327 })
    lu.assertEquals(GameTooltip.lines[#GameTooltip.lines], { "double", "Left click", "Flash Heal (Rank 3) |cff33ff33327-394|r" })
end

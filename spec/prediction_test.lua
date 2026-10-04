-- The heal prediction: ClickCast:GetLeftClickAmount (what the left click with the
-- modifiers held heals or absorbs) and UnitButton drawing it on the frame under the mouse.
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
    return { self.ClickCast:GetLeftClickAmount() }
end

-- "Highest rank" on rank 1: the numbers are those of rank 7, without the commas.
function TestLeftClickHeal:testTheRangeOfTheRankTheClickCasts()
    self.bindings["1"] = Spell(FLASH_HEAL[1], true)
    lu.assertEquals(self:Heal(), { 1887, 2193, "heal" })
end

function TestLeftClickHeal:testTheHeldModifierPicksTheBinding()
    self.bindings["1"] = Spell(FLASH_HEAL[7], true)
    self.bindings["shift-1"] = Spell(FLASH_HEAL[3], false)
    Support.SetModifiers({ shift = true })
    lu.assertEquals(self:Heal(), { 327, 394, "heal" })
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
    lu.assertEquals(self:Heal(), { 45, 45, "heal" })
end

function TestLeftClickHeal:testAShieldGivesItsAbsorb()
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    self.bindings["1"] = Spell(FLASH_HEAL[7], false)
    lu.assertEquals(self:Heal(), { 942, 942, "absorb" })
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

function TestLeftClickHeal:testNothingWithoutANumber()
    self.bindings["1"] = Spell(FLASH_HEAL[7], false)
    for _, text in ipairs({ "Removes 1 disease from the target.", "" }) do
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
    lu.assertEquals(self:Heal(), { 327, 394, "heal" })
end

-- Should the game hide a description in combat, it is not read.
function TestLeftClickHeal:testASecretDescriptionGivesNothing()
    local ns = Support.Load({ "Locales/enUS.lua" })
    issecretvalue = function(value) return value == RANK_7 end
    Support.LoadInto(ns, { "Core.lua", "Spells.lua", "ClickCast.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = { ["1"] = Spell(FLASH_HEAL[7], false) }, hoverKeys = {} }
    Describe()
    lu.assertEquals({ ns.ClickCast:GetLeftClickAmount() }, {})
end

-- UnitButton.lua: the three bars on the hovered frame.

local MAX_HEALTH = 3000

TestHealPrediction = {}

-- `isSecret` (optional) stands in for the game's issecretvalue.
function TestHealPrediction:setUp(isSecret)
    local ns = Support.Load({ "Locales/enUS.lua" })
    issecretvalue = isSecret
    Support.LoadInto(ns, { "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = { ["1"] = Spell(FLASH_HEAL[7], true), ["shift-1"] = Spell(FLASH_HEAL[3], false) },
                  hoverKeys = {} }
    ns.db = { layout = { showTooltips = false, showHealPrediction = true } }
    Describe()
    UnitHealthMax = function() return MAX_HEALTH end
    UnitIsConnected = function() return true end
    UnitIsDeadOrGhost = function() return false end
    GameTooltip = Support.FakeTooltip()
    -- The unit's buffs and debuffs, as the game gives them out of combat.
    self.buffs, self.debuffs = {}, {}
    C_UnitAuras = {
        GetAuraDataByIndex = function(_, index, filter)
            if filter == "HELPFUL" then return self.buffs[index] end
            if filter == "HARMFUL" then return self.debuffs[index] end
        end,
    }
    self.button = Support.FakeButton("party1")
    self.ns, self.UnitButton = ns, ns.UnitButton
end

-- What a bar shows: its amount, or "hidden". A shown bar is checked against the
-- unit's maximum health.
local function Shows(bar)
    if bar.shown then
        lu.assertEquals(bar.max, MAX_HEALTH)
        return bar.value
    end
    lu.assertEquals(bar.value, 0)   -- emptied, as ShowAmountBar leaves every bar it hides
    return "hidden"
end

-- The heal bars: the lowest amount and the rest of the range.
function TestHealPrediction:Bars()
    return { Shows(self.button.prediction), Shows(self.button.predictionRange) }
end

-- The shield bar: the absorb of a shield on the left click.
function TestHealPrediction:Shield()
    return Shows(self.button.predictionAbsorb)
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
    local first, second = self.button, Support.FakeButton("party2")
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
    lu.assertEquals(self:Shield(), "hidden")
end

function TestHealPrediction:testAHealShowsNoShield()
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

-- A shield on the left click goes in the shield bar; the heal bars stay empty.
function TestHealPrediction:testALeftClickShieldShowsItsAbsorb()
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), HIDDEN)
    lu.assertEquals(self:Shield(), 942)
end

-- Weakened Soul, from anyone's shield, means the shield can't be cast.
function TestHealPrediction:testNoShieldOnWeakenedSoul()
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    self.debuffs = { { name = "Forbearance" }, { name = "Weakened Soul" } }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

function TestHealPrediction:testOtherAurasKeepTheShield()
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    self.buffs = { { name = "Renew" } }
    self.debuffs = { { name = "Forbearance" } }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), 942)
end

-- A shield still up (it outlasts Weakened Soul): a new one doesn't add to it.
function TestHealPrediction:testNoShieldOnAShieldStillUp()
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    self.buffs = { { name = "Renew" }, { name = "Power Word: Shield" } }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

-- Should the game not give the name of Weakened Soul or of Power Word: Shield,
-- that aura can't be ruled out.
function TestHealPrediction:testNoShieldWithoutASpellName()
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    local getName = C_Spell.GetSpellName
    for _, unnamed in ipairs({ 6788, 17 }) do
        C_Spell.GetSpellName = function(spellID)
            if spellID ~= unnamed then return getName(spellID) end
        end
        self.UnitButton.OnEnter(self.button)
        lu.assertEquals(self:Shield(), "hidden", "no name for spell " .. unnamed)
        self.UnitButton.OnLeave(self.button)
    end
end

-- In combat the game hides aura data, so Weakened Soul can't be ruled out: the
-- shield shows nothing rather than a shield that may not land. The game refuses
-- (an error) or hands out a secret aura.
function TestHealPrediction:testNoShieldWhenTheAurasAreRefused()
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    C_UnitAuras.GetAuraDataByIndex = function() error("Auras cannot be accessed when secret while tainted") end
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

function TestHealPrediction:testNoShieldWhenTheAurasAreSecret()
    local hidden = { name = "Something hidden" }
    self:setUp(function(value) return value == hidden end)
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    self.debuffs = { hidden }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

-- The aura readable, only its name secret.
function TestHealPrediction:testNoShieldWhenAnAuraNameIsSecret()
    self:setUp(function(value) return value == "Something hidden" end)
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    self.debuffs = { { name = "Something hidden" } }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

-- Where each bar starts: the shown bar before it, skipping hidden ones. In game a
-- hidden, emptied bar kept the width of what it last showed, so a bar after it
-- started that much too far to the right.
function TestHealPrediction:Anchors()
    local names, anchors = {}, {}
    for key, bar in pairs(self.button) do
        if type(bar) == "table" and bar.fill then names[bar] = key end
    end
    for _, key in ipairs(self.UnitButton.AMOUNT_BARS) do
        local bar = self.button[key]
        if bar.shown then anchors[key] = names[bar.after] or "nothing" end
    end
    return anchors
end

-- A shield up, and the left click heals: the shield starts after the heal prediction.
function TestHealPrediction:testTheShieldStartsAfterTheHealPrediction()
    self.button.absorb:Show()
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Anchors(),
        { prediction = "health", predictionRange = "prediction", absorb = "predictionRange" })
end

-- Leaving hides the prediction: the shield starts at the end of the health again.
function TestHealPrediction:testTheShieldSkipsTheHiddenPrediction()
    self.button.absorb:Show()
    self.UnitButton.OnEnter(self.button)
    self.UnitButton.OnLeave(self.button)
    lu.assertEquals(self:Anchors(), { absorb = "health" })
end

-- Incoming heals and shields come and go without a hover: each update anchors again.
function TestHealPrediction:testIncomingHealsAndShieldsAnchorWhenTheyChange()
    local incoming, absorbs = 0, 300
    UnitGetIncomingHeals = function() return incoming end
    UnitGetTotalAbsorbs = function() return absorbs end
    self.ns.db.layout.showIncomingHeals = true
    self.UnitButton.UpdateAbsorbs(self.button)
    lu.assertEquals(self:Anchors(), { absorb = "health" })
    incoming = 200
    self.UnitButton.UpdateIncomingHeals(self.button)
    lu.assertEquals(self:Anchors(), { incoming = "health", absorb = "incoming" })
    incoming = 0
    self.UnitButton.UpdateIncomingHeals(self.button)
    lu.assertEquals(self:Anchors(), { absorb = "health" })
    absorbs = 0
    self.UnitButton.UpdateAbsorbs(self.button)
    lu.assertEquals(self:Anchors(), {})
end

function TestHealPrediction:testAPredictedShieldStartsAfterTheIncomingHeals()
    Support.SetDescription(FLASH_HEAL[7], SHIELD)
    self.button.incoming:Show()
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Anchors(), { incoming = "health", predictionAbsorb = "incoming" })
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

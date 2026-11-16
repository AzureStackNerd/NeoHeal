-- The heal prediction: ClickCast:GetLeftClickAmount (what the left click with the
-- modifiers held heals or absorbs) and UnitButton drawing it on the frame under the mouse.
local lu = require("luaunit")
local Support = require("support")
local FLASH_HEAL = Support.FLASH_HEAL
local POWER_WORD_SHIELD, ICE_BARRIER = Support.POWER_WORD_SHIELD, Support.ICE_BARRIER

-- Every fake spell learned: Flash Heal, Abolish Disease and both shields.
local KNOWN = { Support.ABOLISH_DISEASE, POWER_WORD_SHIELD, Support.POWER_WORD_SHIELD_10, ICE_BARRIER }
for _, spellID in ipairs(FLASH_HEAL) do table.insert(KNOWN, spellID) end

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

-- Power Word: Shield's own id on the plain left click: the bar tells it from
-- another shield by the bound rank's name, not by the description.
local function BindShield(bindings)
    Support.SetDescription(POWER_WORD_SHIELD, SHIELD)
    bindings["1"] = Spell(POWER_WORD_SHIELD, false)
end

-- A shield that only goes on you. The fake's wording, not checked against the game's.
local ICE_BARRIER_TEXT = "Instantly shields you with a barrier of ice, absorbing 438 damage. Lasts 1 min."

local function BindIceBarrier(bindings, key)
    Support.SetDescription(ICE_BARRIER, ICE_BARRIER_TEXT)
    bindings[key or "1"] = Spell(ICE_BARRIER, false)
end

TestLeftClickHeal = {}

function TestLeftClickHeal:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" }, KNOWN)
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
    lu.assertEquals(self:Heal(), { 1887, 2193, "heal", FLASH_HEAL[7] })
end

function TestLeftClickHeal:testTheHeldModifierPicksTheBinding()
    self.bindings["1"] = Spell(FLASH_HEAL[7], true)
    self.bindings["shift-1"] = Spell(FLASH_HEAL[3], false)
    Support.SetModifiers({ shift = true })
    lu.assertEquals(self:Heal(), { 327, 394, "heal", FLASH_HEAL[3] })
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
    lu.assertEquals(self:Heal(), { 45, 45, "heal", FLASH_HEAL[7] })
end

function TestLeftClickHeal:testAShieldGivesItsAbsorb()
    BindShield(self.bindings)
    lu.assertEquals(self:Heal(), { 942, 942, "absorb", POWER_WORD_SHIELD })
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
    lu.assertEquals(self:Heal(), { 327, 394, "heal", FLASH_HEAL[3] })
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
    local ns = Support.Load({ "Locales/enUS.lua" }, KNOWN)
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
    BindShield(self.ns.charDB.bindings)
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), HIDDEN)
    lu.assertEquals(self:Shield(), 942)
end

-- Weakened Soul, from anyone's shield, means the shield can't be cast.
function TestHealPrediction:testNoShieldOnWeakenedSoul()
    BindShield(self.ns.charDB.bindings)
    self.debuffs = { { name = "Forbearance" }, { name = "Weakened Soul" } }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

function TestHealPrediction:testOtherAurasKeepTheShield()
    BindShield(self.ns.charDB.bindings)
    self.buffs = { { name = "Renew" } }
    self.debuffs = { { name = "Forbearance" } }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), 942)
end

-- A shield still up (it outlasts Weakened Soul): a new one doesn't add to it.
function TestHealPrediction:testNoShieldOnAShieldStillUp()
    BindShield(self.ns.charDB.bindings)
    self.buffs = { { name = "Renew" }, { name = "Power Word: Shield" } }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

-- Should the game not give the name of Weakened Soul or of Power Word: Shield,
-- that aura can't be ruled out.
function TestHealPrediction:testNoShieldWithoutASpellName()
    BindShield(self.ns.charDB.bindings)
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
    BindShield(self.ns.charDB.bindings)
    C_UnitAuras.GetAuraDataByIndex = function() error("Auras cannot be accessed when secret while tainted") end
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

function TestHealPrediction:testNoShieldWhenTheAurasAreSecret()
    local hidden = { name = "Something hidden" }
    self:setUp(function(value) return value == hidden end)
    BindShield(self.ns.charDB.bindings)
    self.debuffs = { hidden }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Shield(), "hidden")
end

-- The aura readable, only its name secret.
function TestHealPrediction:testNoShieldWhenAnAuraNameIsSecret()
    self:setUp(function(value) return value == "Something hidden" end)
    BindShield(self.ns.charDB.bindings)
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
    BindShield(self.ns.charDB.bindings)
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

-- Which shield rule applies (issue #12): Power Word: Shield's on any member's frame,
-- every other absorb only on a frame that shows you. Ice Barrier stands in for a
-- shield that only goes on you; Power Word: Shield absorbs 942, Ice Barrier 438.

-- Hovers a frame of this unit, reads its shield bar and leaves it again.
function TestHealPrediction:ShieldOn(unit)
    self.button = Support.FakeButton(unit)
    self.UnitButton.OnEnter(self.button)
    local shown = self:Shield()
    self.UnitButton.OnLeave(self.button)
    return shown
end

-- AC1, S6 to S8 and S10: UnitIsUnit tells which frames show you here: your raid
-- frame raid3, and the target frame while you target yourself.
function TestHealPrediction:testAShieldThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYou()
    BindIceBarrier(self.ns.charDB.bindings)
    UnitIsUnit = function(a, b) return a == b or ((a == "raid3" or a == "target") and b == "player") end
    self.debuffs = { { name = "Weakened Soul" } }   -- S6: whatever the unit's auras
    lu.assertEquals(self:ShieldOn("party1"), "hidden", "another member's frame")
    self.debuffs = {}
    lu.assertEquals(self:ShieldOn("partypet1"), "hidden", "a pet's frame")
    lu.assertEquals(self:ShieldOn("raid5"), "hidden", "another raid member's frame")
    lu.assertEquals(self:ShieldOn("focus"), "hidden", "the focus frame on someone else")
    lu.assertEquals(self:ShieldOn("player"), 438, "your own frame")
    lu.assertEquals(self:ShieldOn("raid3"), 438, "your own raid frame")
    lu.assertEquals(self:ShieldOn("target"), 438, "the target frame on you")
end

-- AC1, S9 (and S7): where the game hides whether a frame shows you, a raid, target
-- or focus frame shows nothing; your own frame is "player" and needs no answer.
function TestHealPrediction:testAShieldThatOnlyGoesOnYouShowsNothingWhereTheGameHidesWhoIsYou()
    local secret = {}
    self:setUp(function(value) return rawequal(value, secret) end)
    BindIceBarrier(self.ns.charDB.bindings)
    UnitIsUnit = function() return secret end
    lu.assertEquals(self:ShieldOn("raid3"), "hidden", "a raid frame")
    lu.assertEquals(self:ShieldOn("target"), "hidden", "the target frame")
    lu.assertEquals(self:ShieldOn("focus"), "hidden", "the focus frame")
    lu.assertEquals(self:ShieldOn("player"), 438, "your own frame")
end

-- AC1, S16: the shield on Shift + left click, Flash Heal on the plain left click.
function TestHealPrediction:testAShieldOnAModifierFollowsTheModifierAndTheFrame()
    BindIceBarrier(self.ns.charDB.bindings, "shift-1")
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    local own = Support.FakeButton("player")
    self.UnitButton.OnEnter(self.button)   -- party1
    lu.assertEquals({ self:Bars(), self:Shield() }, { { 1887, 2193 - 1887 }, "hidden" }, "party1")
    PressModifiers({ shift = true })
    lu.assertEquals({ self:Bars(), self:Shield() }, { HIDDEN, "hidden" }, "party1 with Shift")
    self.UnitButton.OnLeave(self.button)
    self.button = own
    self.UnitButton.OnEnter(own)
    lu.assertEquals({ self:Bars(), self:Shield() }, { HIDDEN, 438 }, "your own frame with Shift")
    PressModifiers({})
    lu.assertEquals({ self:Bars(), self:Shield() }, { { 1887, 2193 - 1887 }, "hidden" }, "Shift released")
end

-- AC2, S11: Weakened Soul and a Power Word: Shield on you only stop a new Power Word: Shield.
function TestHealPrediction:testPowerWordShieldsAurasLeaveAnotherShieldShowing()
    BindIceBarrier(self.ns.charDB.bindings)
    local cases = {
        ["Weakened Soul"] = { {}, { { name = "Weakened Soul" } } },
        ["a Power Word: Shield"] = { { { name = "Power Word: Shield" } }, {} },
        ["both"] = { { { name = "Power Word: Shield" } }, { { name = "Weakened Soul" } } },
    }
    for name, auras in pairs(cases) do
        self.buffs, self.debuffs = auras[1], auras[2]
        lu.assertEquals(self:ShieldOn("player"), 438, name)
    end
end

-- AC2, S12 and S13: nothing while its own aura is up, or while that can't be told.
function TestHealPrediction:testAnotherShieldShowsNothingWhileItsOwnIsUpOrTheAurasAreHidden()
    BindIceBarrier(self.ns.charDB.bindings)
    self.buffs = { { name = "Renew" }, { name = "Ice Barrier" } }
    lu.assertEquals(self:ShieldOn("player"), "hidden", "its own aura up")
    self.buffs = {}

    local getAuras = C_UnitAuras.GetAuraDataByIndex
    C_UnitAuras.GetAuraDataByIndex = function() error("Auras cannot be accessed when secret while tainted") end
    lu.assertEquals(self:ShieldOn("player"), "hidden", "auras refused in combat")
    C_UnitAuras.GetAuraDataByIndex = getAuras

    local getName = C_Spell.GetSpellName
    for _, unnamed in ipairs({ ICE_BARRIER, POWER_WORD_SHIELD }) do
        C_Spell.GetSpellName = function(spellID)
            if spellID ~= unnamed then return getName(spellID) end
        end
        lu.assertEquals(self:ShieldOn("player"), "hidden", "no name for spell " .. unnamed)
    end
    C_Spell.GetSpellName = getName
    lu.assertEquals(self:ShieldOn("player"), 438, "nothing in the way")
end

function TestHealPrediction:testAnotherShieldShowsNothingWhenTheAurasAreSecret()
    local hidden = { name = "Something hidden" }
    self:setUp(function(value) return value == hidden end)
    BindIceBarrier(self.ns.charDB.bindings)
    self.buffs = { hidden }
    lu.assertEquals(self:ShieldOn("player"), "hidden")
end

-- AC3, S1 and S2: Power Word: Shield on your own frames too, any rank (told by its
-- name), and another shield's aura up doesn't stop it.
function TestHealPrediction:testPowerWordShieldShowsOnYourOwnFrame()
    BindShield(self.ns.charDB.bindings)
    UnitIsUnit = function(a, b) return a == b or (a == "raid3" and b == "player") end
    lu.assertEquals(self:ShieldOn("player"), 942, "your own frame")
    lu.assertEquals(self:ShieldOn("raid3"), 942, "your own raid frame")
    self.buffs = { { name = "Ice Barrier" } }
    lu.assertEquals(self:ShieldOn("party1"), 942, "party1 with their own Ice Barrier up")
    self.buffs = {}

    Support.SetDescription(Support.POWER_WORD_SHIELD_10, SHIELD)
    self.ns.charDB.bindings["1"] = Spell(Support.POWER_WORD_SHIELD_10, false)
    lu.assertEquals(self:ShieldOn("party1"), 942, "rank 10 on party1")
    self.debuffs = { { name = "Weakened Soul" } }
    lu.assertEquals(self:ShieldOn("party1"), "hidden", "rank 10 on Weakened Soul")
end

-- AC4, S17: a heal shows its bars whatever the shield rules would say.
function TestHealPrediction:testAHealIgnoresTheShieldRules()
    local heal = { { 1887, 2193 - 1887 }, "hidden" }
    self.buffs, self.debuffs = { { name = "Power Word: Shield" } }, { { name = "Weakened Soul" } }
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals({ self:Bars(), self:Shield() }, heal, "Weakened Soul and a shield up")
    self.UnitButton.OnLeave(self.button)
    C_UnitAuras.GetAuraDataByIndex = function() error("Auras cannot be accessed when secret while tainted") end
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals({ self:Bars(), self:Shield() }, heal, "auras hidden in combat")
end

-- The redraws while the mouse stays on a frame (S14, S15, S18, S19), through the
-- real UnitButton chain: UpdateAll for a roster or target change, UpdateAuras for
-- an aura change. The button is wider than Support.FakeButton: every other part
-- of the frame is a stand-in that does nothing.
TestShieldRedraws = {}

local overridden = {}

-- Sets a global for this test; tearDown puts the old value back.
local function Override(name, value)
    if overridden[name] == nil then overridden[name] = { _G[name] } end
    _G[name] = value
end

local function Restore()
    for name, old in pairs(overridden) do _G[name] = old[1] end
    overridden = {}
end

-- Any PascalCase method does nothing; any other field is such an object too.
local function StandIn(object)
    return setmetatable(object or {}, { __index = function(self, key)
        if type(key) ~= "string" then return nil end
        if key:match("^%u") then return function() end end
        local part = StandIn()
        rawset(self, key, part)
        return part
    end })
end

local function WideButton(unit)
    local button = Support.FakeButton(unit)
    for _, value in pairs(button) do
        if type(value) == "table" and getmetatable(value) == nil then StandIn(value) end
    end
    button.health.SetPoint = function() end   -- ApplyStyle places it by numbers
    return StandIn(button)
end

function TestShieldRedraws:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua" }, KNOWN)
    ns.Spells:Scan()
    ns.charDB = { bindings = {}, hoverKeys = {} }
    BindIceBarrier(ns.charDB.bindings)
    ns.db = { layout = { showTooltips = false, showHealPrediction = true } }
    ns.Hots = { SetUnit = function() end, Update = function() end }
    ns.MissingBuffs = { Update = function() end }
    ns.AuraContainer = { SetUnit = function() end, SetShown = function() end }
    ns.Layout = { PresetChanged = function() return false end, Arrange = function() end }
    ns.Blizzard = { ApplyHiding = function() end }

    -- Who is you: changed by each test.
    self.you = { player = true }
    Override("UnitIsUnit", function(a, b)
        return a == b or (b == "player" and self.you[a] == true)
    end)
    self.buffs, self.debuffs = {}, {}
    C_UnitAuras = {
        GetAuraDataByIndex = function(_, index, filter)
            if filter == "HELPFUL" then return self.buffs[index] end
            if filter == "HARMFUL" then return self.debuffs[index] end
        end,
    }
    Override("UnitExists", function() return true end)
    Override("UnitIsConnected", function() return true end)
    Override("UnitIsDeadOrGhost", function() return false end)
    Override("UnitHealth", function() return 2000 end)
    Override("UnitHealthMax", function() return MAX_HEALTH end)
    Override("UnitPowerMax", function() return 0 end)
    Override("UnitName", function() return "Someone" end)
    Override("UnitIsPlayer", function() return false end)
    for _, name in ipairs({ "UnitIsGroupAssistant", "UnitIsGroupLeader", "UnitGroupRolesAssigned", "GetRaidTargetIndex",
                            "UnitHasIncomingResurrection", "UnitInRaid", "UnitPowerType", "UnitInRange",
                            "UnitGetTotalAbsorbs", "UnitCanAttack" }) do
        Override(name, function() end)
    end
    Override("unpack", unpack or table.unpack)
    Override("GameTooltip", Support.FakeTooltip())   -- OnLeave asks whether it owns the tooltip
    self.ns, self.UnitButton = ns, ns.UnitButton
end

function TestShieldRedraws:tearDown() Restore() end

function TestShieldRedraws:Hover(unit)
    self.button = WideButton(unit)
    self.UnitButton.buttons[self.button] = true
    self.UnitButton.OnEnter(self.button)
end

function TestShieldRedraws:Shield()
    return Shows(self.button.predictionAbsorb)
end

-- AC1, S15: the target and focus frames keep their unit while the person behind it changes.
function TestShieldRedraws:testTheShieldFollowsTheTargetOrFocusUnderTheMouse()
    for unit, event in pairs({ target = "PLAYER_TARGET_CHANGED", focus = "PLAYER_FOCUS_CHANGED" }) do
        self.you[unit] = true
        self:Hover(unit)
        lu.assertEquals(self:Shield(), 438, unit .. " on you")
        self.you[unit] = false
        self.ns[event](self.ns)
        lu.assertEquals(self:Shield(), "hidden", unit .. " changed to party1")
        self.you[unit] = true
        self.ns[event](self.ns)
        lu.assertEquals(self:Shield(), 438, unit .. " back on you")
        self.UnitButton.OnLeave(self.button)
    end
end

-- AC1, S18: the group puts another member behind your raid frame, and later you again.
function TestShieldRedraws:testTheShieldFollowsARosterChangeUnderTheMouse()
    self.you.raid3 = true
    self:Hover("raid3")
    lu.assertEquals(self:Shield(), 438, "your raid frame")
    self.you.raid3 = false
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Shield(), "hidden", "another member behind it")
    self.you.raid3 = true
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Shield(), 438, "you again")
end

-- AC2, S14 and S19: an aura change redraws through UpdateAuras, the redraw a
-- UNIT_AURA batch runs; UpdateAllAuras is its way in from here.
function TestShieldRedraws:testTheBarFollowsYourOwnShieldComingAndGoing()
    self:Hover("player")
    lu.assertEquals(self:Shield(), 438, "nothing up")
    self.buffs, self.debuffs = { { name = "Power Word: Shield" } }, { { name = "Weakened Soul" } }
    self.UnitButton:UpdateAllAuras()
    lu.assertEquals(self:Shield(), 438, "a Priest's shield landed")
    self.buffs = {}
    self.UnitButton:UpdateAllAuras()
    lu.assertEquals(self:Shield(), 438, "the shield faded, Weakened Soul still up")
    self.buffs, self.debuffs = { { name = "Ice Barrier" } }, {}
    self.UnitButton:UpdateAllAuras()
    lu.assertEquals(self:Shield(), "hidden", "your own Ice Barrier landed")
    self.buffs = {}
    self.UnitButton:UpdateAllAuras()
    lu.assertEquals(self:Shield(), 438, "your own Ice Barrier ended")
end

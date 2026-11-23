-- The heal prediction: ClickCast:GetLeftClickAmount (what the left click with the
-- modifiers held heals or absorbs) and UnitButton drawing it on the frame under the mouse.
local lu = require("luaunit")
local Support = require("support")
local FLASH_HEAL = Support.FLASH_HEAL
local POWER_WORD_SHIELD, ICE_BARRIER = Support.POWER_WORD_SHIELD, Support.ICE_BARRIER

-- Every fake spell learned: Flash Heal, Abolish Disease, both shields, Desperate
-- Prayer (its first id) and Prayer of Healing.
local DESPERATE_PRAYER, DESPERATE_PRAYER_2 = Support.DESPERATE_PRAYER, Support.DESPERATE_PRAYER_2
local KNOWN = { Support.ABOLISH_DISEASE, POWER_WORD_SHIELD, Support.POWER_WORD_SHIELD_10, ICE_BARRIER,
                DESPERATE_PRAYER, Support.PRAYER_OF_HEALING }
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

-- Which heal shows where (issue #20): a heal that only goes on you only on a frame
-- that shows you, every other heal on every frame. Desperate Prayer stands in for a
-- heal that only goes on you, Flash Heal for one on any friendly unit, Prayer of
-- Healing for a group heal you cast on yourself. The descriptions are the fake's
-- wording, not checked against the game's.
local DESPERATE_PRAYER_TEXT = "Instantly heals the caster for 134 to 170."
local PRAYER_OF_HEALING_TEXT = "A powerful prayer that heals party members within 30 yards for 312 to 333."
local PRAYER = { 134, 170 - 134 }
local FLASH = { 1887, 2193 - 1887 }

local function BindDesperatePrayer(bindings, key, spellID)
    spellID = spellID or DESPERATE_PRAYER
    Support.SetDescription(spellID, DESPERATE_PRAYER_TEXT)
    bindings[key or "1"] = Spell(spellID, false)
end

-- C_Spell.GetSpellName gives nothing for these spell ids, and the names in `renamed`
-- for others; every other id as before. Undone by the next setUp (Support.Load).
local function NameSpells(unnamed, renamed)
    local getName = C_Spell.GetSpellName
    C_Spell.GetSpellName = function(spellID)
        for _, id in ipairs(unnamed) do
            if spellID == id then return nil end
        end
        if renamed and renamed[spellID] then return renamed[spellID] end
        return getName(spellID)
    end
    return getName
end

-- Combat as the fake can give it: InCombatLockdown says so and the auras are
-- refused, as the game hides them in combat. No heal rule reads either; that the
-- game hides nothing else the rule needs in combat is not checked in game.
local function EnterCombat()
    InCombatLockdown = function() return true end
    C_UnitAuras.GetAuraDataByIndex = function() error("Auras cannot be accessed when secret while tainted") end
end

-- Hovers a frame of this unit, reads its heal bars and leaves it again.
function TestHealPrediction:HealOn(unit)
    self.button = Support.FakeButton(unit)
    self.UnitButton.OnEnter(self.button)
    local shown = self:Bars()
    self.UnitButton.OnLeave(self.button)
    return shown
end

-- UnitIsUnit as on a map where the game tells: your raid frame raid3 and the target
-- frame (you target yourself) show you, nothing else does.
local function YouAreRaid3AndTheTarget()
    UnitIsUnit = function(a, b) return a == b or ((a == "raid3" or a == "target") and b == "player") end
end

-- AC1, S1 to S5.
function TestHealPrediction:testAHealThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYou()
    BindDesperatePrayer(self.ns.charDB.bindings)
    YouAreRaid3AndTheTarget()
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "another member's frame")
    lu.assertEquals(self:HealOn("raid5"), HIDDEN, "another raid member's frame")
    lu.assertEquals(self:HealOn("partypet1"), HIDDEN, "a pet's frame")
    lu.assertEquals(self:HealOn("focus"), HIDDEN, "the focus frame on someone else")
    lu.assertEquals(self:HealOn("player"), PRAYER, "your own frame")
    lu.assertEquals(self:HealOn("raid3"), PRAYER, "your own raid frame")
    lu.assertEquals(self:HealOn("target"), PRAYER, "the target frame on you")
end

-- AC1, S6: where the game hides whether a frame shows you, in and out of combat.
function TestHealPrediction:testAHealThatOnlyGoesOnYouShowsNothingWhereTheGameHidesWhoIsYou()
    local secret = {}
    self:setUp(function(value) return rawequal(value, secret) end)
    BindDesperatePrayer(self.ns.charDB.bindings)
    UnitIsUnit = function() return secret end
    for _, combat in ipairs({ "out of combat", "in combat" }) do
        if combat == "in combat" then EnterCombat() end
        lu.assertEquals(self:HealOn("raid3"), HIDDEN, "your own raid frame, " .. combat)
        lu.assertEquals(self:HealOn("target"), HIDDEN, "the target frame, " .. combat)
        lu.assertEquals(self:HealOn("focus"), HIDDEN, "the focus frame, " .. combat)
        lu.assertEquals(self:HealOn("player"), PRAYER, "your own frame, " .. combat)
    end
end

-- AC1, S7: in combat, on a map where the game tells whether a frame is you.
function TestHealPrediction:testAHealThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYouInCombat()
    BindDesperatePrayer(self.ns.charDB.bindings)
    YouAreRaid3AndTheTarget()
    EnterCombat()
    lu.assertEquals(self:HealOn("player"), PRAYER, "your own frame")
    lu.assertEquals(self:HealOn("raid3"), PRAYER, "your own raid frame")
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "party1")
end

-- AC1, S8: Desperate Prayer on Shift + left click, Flash Heal on the plain left click.
function TestHealPrediction:testAHealThatOnlyGoesOnYouOnAModifierFollowsTheModifierAndTheFrame()
    BindDesperatePrayer(self.ns.charDB.bindings, "shift-1")
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    local own = Support.FakeButton("player")
    self.UnitButton.OnEnter(self.button)   -- party1
    lu.assertEquals(self:Bars(), FLASH, "party1")
    PressModifiers({ shift = true })
    lu.assertEquals(self:Bars(), HIDDEN, "party1 with Shift")
    self.UnitButton.OnLeave(self.button)
    self.button = own
    self.UnitButton.OnEnter(own)
    lu.assertEquals(self:Bars(), PRAYER, "your own frame with Shift")
    PressModifiers({})
    lu.assertEquals(self:Bars(), FLASH, "Shift released")
end

-- AC1, S16: no green bars on party1, and the incoming heals and the shield sit right
-- after each other, as with no prediction.
function TestHealPrediction:testAHiddenHealLeavesTheIncomingHealsAndShieldsInPlace()
    BindDesperatePrayer(self.ns.charDB.bindings)
    self.button.incoming:Show()
    self.button.absorb:Show()
    self.UnitButton.OnEnter(self.button)   -- party1
    lu.assertEquals(self:Bars(), HIDDEN)
    lu.assertEquals(self:Anchors(), { incoming = "health", absorb = "incoming" })
end

-- AC1, S17, first half: the game gives no name for the clicked spell. Flash Heal or
-- Desperate Prayer alike: bars on your own frame, none on party1.
function TestHealPrediction:testAHealThatCantBeToldApartShowsOnlyOnAFrameThatShowsYou()
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    NameSpells({ FLASH_HEAL[7] })
    lu.assertEquals(self:HealOn("player"), FLASH, "Flash Heal unnamed, your own frame")
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "Flash Heal unnamed, party1")

    self:setUp()
    BindDesperatePrayer(self.ns.charDB.bindings)
    NameSpells({ DESPERATE_PRAYER })
    lu.assertEquals(self:HealOn("player"), PRAYER, "Desperate Prayer unnamed, your own frame")
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "Desperate Prayer unnamed, party1")
end

-- AC1, S17, second half: every id of the listed heal gives no name, so a named Flash
-- Heal can't be told from it.
function TestHealPrediction:testAHealThatCantBeToldApartWhenTheListedHealHasNoName()
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    NameSpells({ DESPERATE_PRAYER, DESPERATE_PRAYER_2 })
    lu.assertEquals(self:HealOn("player"), FLASH, "your own frame")
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "party1")
end

-- The control for the row above: one id of the listed heal unnamed, the other named.
-- The named one still tells Desperate Prayer apart (bound by that id here), and
-- Flash Heal is not taken for it.
function TestHealPrediction:testOneUnnamedIdOfTheListedHealIsEnough()
    Support.SetKnown({ FLASH_HEAL[7], DESPERATE_PRAYER_2 })
    BindDesperatePrayer(self.ns.charDB.bindings, "1", DESPERATE_PRAYER_2)
    NameSpells({ DESPERATE_PRAYER })
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "Desperate Prayer on party1")
    lu.assertEquals(self:HealOn("player"), PRAYER, "Desperate Prayer on your own frame")
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    lu.assertEquals(self:HealOn("party1"), FLASH, "Flash Heal on party1")

    -- The other way round: 19236 unnamed, 13908 named.
    self:setUp()
    BindDesperatePrayer(self.ns.charDB.bindings)
    NameSpells({ DESPERATE_PRAYER_2 })
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "19236 unnamed, Desperate Prayer on party1")
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    lu.assertEquals(self:HealOn("party1"), FLASH, "19236 unnamed, Flash Heal on party1")
end

-- Should the game hide a spell name (its API docs mark none as hidden: not checked in
-- game), it counts as no name: the clicked spell's, or the listed heal's.
function TestHealPrediction:testAHiddenSpellNameCantBeToldApart()
    local secret = {}
    self:setUp(function(value) return rawequal(value, secret) end)
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    NameSpells({}, { [FLASH_HEAL[7]] = secret })
    lu.assertEquals(self:HealOn("player"), FLASH, "Flash Heal's name hidden, your own frame")
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "Flash Heal's name hidden, party1")

    self:setUp(function(value) return rawequal(value, secret) end)
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    NameSpells({}, { [DESPERATE_PRAYER] = secret, [DESPERATE_PRAYER_2] = secret })
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "Desperate Prayer's names hidden, Flash Heal on party1")
end

-- Every name a listed heal's ids give counts, not only the first: should the first id
-- name another spell, Desperate Prayer's own name still keeps it off party1.
function TestHealPrediction:testEveryNameOfTheListedHealCounts()
    Support.SetKnown({ FLASH_HEAL[7], DESPERATE_PRAYER_2 })
    BindDesperatePrayer(self.ns.charDB.bindings, "1", DESPERATE_PRAYER_2)
    NameSpells({}, { [DESPERATE_PRAYER] = "Renew" })
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "Desperate Prayer on party1")
    lu.assertEquals(self:HealOn("player"), PRAYER, "Desperate Prayer on your own frame")
end

-- A name the game gave nothing for on the first hover is asked again on the next:
-- a list kept from the first hover would count Desperate Prayer as a heal on any
-- friendly unit for the rest of the session. The first hover is Flash Heal, whose own
-- name is readable, so that draw does read the list; a clicked spell without a name
-- would stop before it.
function TestHealPrediction:testAListedHealNamedLaterStillCounts()
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    local getName = NameSpells({ DESPERATE_PRAYER, DESPERATE_PRAYER_2 })
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "no name yet, Flash Heal on party1")
    C_Spell.GetSpellName = getName
    lu.assertEquals(self:HealOn("party1"), FLASH, "named now, Flash Heal on party1")
    BindDesperatePrayer(self.ns.charDB.bindings)
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "named now")
    lu.assertEquals(self:HealOn("player"), PRAYER, "named now, your own frame")
end

-- A class with no heal that only goes on it in the list: its heals show everywhere.
function TestHealPrediction:testAClassWithoutSuchHealsShowsItsHealsOnEveryFrame()
    UnitClass = function() return "Shaman", "SHAMAN" end
    lu.assertEquals(self:HealOn("party1"), FLASH, "party1")
    lu.assertEquals(self:HealOn("player"), FLASH, "your own frame")
end

-- A class NeoHeal can't read (nothing, or a hidden value): every heal takes the safe
-- side, bars only on a frame that shows you.
function TestHealPrediction:testAClassThatCantBeReadShowsHealsOnlyOnAFrameThatShowsYou()
    UnitClass = function() return nil end
    lu.assertEquals(self:HealOn("player"), FLASH, "no class, your own frame")
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "no class, party1")

    local hidden = "PRIEST (hidden)"
    self:setUp(function(value) return value == hidden end)
    UnitClass = function() return "Priest", hidden end
    lu.assertEquals(self:HealOn("player"), FLASH, "a hidden class, your own frame")
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "a hidden class, party1")
end

-- AC2, S11 and S12: a heal on any friendly unit on every frame, in and out of combat,
-- also where the game hides whether a frame shows you.
function TestHealPrediction:testAHealOnAnyFriendlyUnitShowsOnEveryFrame()
    YouAreRaid3AndTheTarget()
    for _, unit in ipairs({ "player", "raid3", "party1", "raid5", "partypet1", "target", "focus" }) do
        lu.assertEquals(self:HealOn(unit), FLASH, unit)
    end
    EnterCombat()
    lu.assertEquals(self:HealOn("player"), FLASH, "your own frame in combat")
    lu.assertEquals(self:HealOn("party1"), FLASH, "party1 in combat")

    local secret = {}
    self:setUp(function(value) return rawequal(value, secret) end)
    UnitIsUnit = function() return secret end
    for _, unit in ipairs({ "raid3", "target", "focus" }) do
        lu.assertEquals(self:HealOn(unit), FLASH, unit .. " where the game hides who is you")
    end
end

-- Which frames a group heal cast around you shows on (issue #21): your own, a party
-- member's in a party, in a raid your own group's, and the target or focus frame on
-- one of them; none on a raid member outside your group, a pet, or anyone else.
-- Prayer of Healing stands in for that heal, Chain Heal for a group heal that lands on
-- the member you click. The descriptions and amounts are the fake's, not the game's;
-- that Prayer of Healing heals your party, in a raid your own group, is not checked
-- in game.
local PRAYER_OF_HEALING, CHAIN_HEAL = Support.PRAYER_OF_HEALING, Support.CHAIN_HEAL
local CHAIN_HEAL_TEXT = "Heals the friendly target for 320 to 368, then jumps to heal nearby targets."
local GROUP = { 312, 333 - 312 }
local CHAIN = { 320, 368 - 320 }

local function BindPrayerOfHealing(bindings, key)
    Support.SetDescription(PRAYER_OF_HEALING, PRAYER_OF_HEALING_TEXT)
    bindings[key or "1"] = Spell(PRAYER_OF_HEALING, false)
end

-- The game's issecretvalue for this file's group rows: a Support.Secret is hidden.
local function IsHidden(value) return value ~= nil and Support.hidden[value] == true end

-- Your group as the game gives it, read live, so a test changes `world` after the
-- call. `party`: how many others are in your party (GetNumSubgroupMembers). `raid`:
-- each unit's raid index (UnitInRaid), nil outside a raid; `groups`: each index's
-- group (GetRaidRosterInfo's third return), an index without one gives nothing.
-- `is`: whom a frame shows besides itself (UnitIsUnit), or `isHidden`, the hidden
-- answer UnitIsUnit then gives for everything. `players`: the units UnitIsPlayer says
-- yes for. Any answer may be a Support.Secret; GetRaidRosterInfo reads a hidden index
-- as the index it stands for, so only a check on the index keeps it out. Without an
-- index it raises, as IsPlayerSpell's fake does for a missing spell id; what the game's
-- GetRaidRosterInfo does without one is not checked in game.
local function Group(world)
    IsInRaid = function() return world.raid ~= nil end
    GetNumSubgroupMembers = function() return world.party or 0 end
    UnitInRaid = function(unit) return world.raid and world.raid[unit] end
    GetRaidRosterInfo = function(index)
        assert(type(Support.Reveal(index)) == "number", "GetRaidRosterInfo needs a raid index")
        local group = world.groups and world.groups[Support.Reveal(index)]
        if group == nil then return nil end
        return "Someone", 0, group
    end
    UnitIsUnit = function(a, b)
        if world.isHidden then return world.isHidden end
        return a == b or (world.is or {})[a] == b
    end
    UnitIsPlayer = function(unit) return (world.players or {})[unit] == true end
    return world
end

-- A raid: you are raid3; raid1, raid2 and raid3 are group 1, raid5 and raid12 group 2.
local function Raid()
    return { raid = { player = 3, raid1 = 1, raid2 = 2, raid3 = 3, raid5 = 5, raid12 = 12 },
             groups = { [1] = 1, [2] = 1, [3] = 1, [5] = 2, [12] = 2 },
             is = { raid3 = "player" },
             players = { player = true, raid1 = true, raid2 = true, raid3 = true, raid5 = true, raid12 = true } }
end

-- AC1, S1, S2, S3, S4, S6 and S7: solo, in a party and in a raid. The main tanks are a
-- group header's frames too, so they carry raidN tokens like the group frames (by the
-- header's group filter; not checked in game).
function TestHealPrediction:testAGroupHealAroundYouShowsOnlyOnTheFramesOfYourGroup()
    BindPrayerOfHealing(self.ns.charDB.bindings)
    local world = Group({ is = { target = "player" }, players = { player = true, target = true, focus = true } })
    lu.assertEquals(self:HealOn("player"), GROUP, "solo, your own frame")
    lu.assertEquals(self:HealOn("target"), GROUP, "solo, the target frame on you")
    lu.assertEquals(self:HealOn("focus"), HIDDEN, "solo, the focus frame on another player")
    world.players.focus = false
    lu.assertEquals(self:HealOn("focus"), HIDDEN, "solo, the focus frame on a friendly NPC")

    world = Group({ party = 2, is = { target = "party2", focus = "player" },
                    players = { player = true, party1 = true, party2 = true, target = true, focus = true } })
    lu.assertEquals(self:HealOn("player"), GROUP, "in a party, your own frame")
    lu.assertEquals(self:HealOn("party1"), GROUP, "in a party, party1")
    lu.assertEquals(self:HealOn("party2"), GROUP, "in a party, party2")
    lu.assertEquals(self:HealOn("target"), GROUP, "in a party, the target frame on party2")
    lu.assertEquals(self:HealOn("focus"), GROUP, "in a party, the focus frame on you")
    world.is.target = nil
    lu.assertEquals(self:HealOn("target"), HIDDEN, "in a party, the target frame on a player outside it")
    world.players.target = false
    lu.assertEquals(self:HealOn("target"), HIDDEN, "in a party, the target frame on a friendly NPC")

    world = Group(Raid())
    lu.assertEquals(self:HealOn("player"), GROUP, "in a raid, your own frame")
    lu.assertEquals(self:HealOn("raid3"), GROUP, "in a raid, your own raid frame")
    lu.assertEquals(self:HealOn("raid1"), GROUP, "in a raid, raid1 of your group")
    lu.assertEquals(self:HealOn("raid2"), GROUP, "in a raid, raid2 of your group")
    lu.assertEquals(self:HealOn("raid5"), HIDDEN, "in a raid, raid5 of another group")
    lu.assertEquals(self:HealOn("raid12"), HIDDEN, "in a raid, raid12 of another group")
    world.raid.target, world.players.target = 2, true
    lu.assertEquals(self:HealOn("target"), GROUP, "in a raid, the target frame on raid2 of your group")
    world.raid.focus, world.players.focus = 5, true
    lu.assertEquals(self:HealOn("focus"), HIDDEN, "in a raid, the focus frame on raid5 of another group")
    world.raid.target = nil
    lu.assertEquals(self:HealOn("target"), HIDDEN, "in a raid, the target frame on a player outside the raid")
    world.players.target = false
    lu.assertEquals(self:HealOn("target"), HIDDEN, "in a raid, the target frame on a friendly NPC")
end

-- AC1, S5: a pet's frame shows none. Every other answer puts each pet in your group,
-- so only its token (or, on the target or focus frame, UnitIsPlayer) keeps the bars
-- off: in a raid UnitInRaid gives a pet its owner's index, here one in your group
-- (that the game does so is not checked in game); in a party the fake's UnitIsUnit
-- says each pet shows party1. raid1 and party1 are the controls: the same world shows
-- their bars.
function TestHealPrediction:testAGroupHealAroundYouShowsNothingOnAPet()
    BindPrayerOfHealing(self.ns.charDB.bindings)
    local world = Raid()
    world.raid.pet, world.raid.raidpet1, world.raid.partypet1 = 3, 1, 2
    world.raid.target, world.raid.focus = 1, 3   -- on raid1's pet and on yours
    Group(world)
    lu.assertEquals(self:HealOn("raid1"), GROUP, "in a raid, raid1 (the control)")
    for _, unit in ipairs({ "pet", "raidpet1", "partypet1", "target", "focus" }) do
        lu.assertEquals(self:HealOn(unit), HIDDEN, "in a raid, " .. unit)
    end

    self:setUp()
    BindPrayerOfHealing(self.ns.charDB.bindings)
    Group({ party = 1, is = { pet = "party1", partypet1 = "party1" }, players = { player = true, party1 = true } })
    lu.assertEquals(self:HealOn("party1"), GROUP, "in a party, party1 (the control)")
    lu.assertEquals(self:HealOn("pet"), HIDDEN, "in a party, your pet")
    lu.assertEquals(self:HealOn("partypet1"), HIDDEN, "in a party, party1's pet")
end

-- AC1, S8: where the game hides who is in your group, or gives only part of it, the
-- frame shows none; where it hides only whether a frame shows you, a raid's group
-- numbers decide (the stakeholder's answer at gate 2). Each case hides or leaves out
-- one answer; raid1, the control, shows its bars where nothing is hidden.
function TestHealPrediction:testAGroupHealAroundYouShowsNothingWhereTheGameHidesYourGroup()
    local cases = {
        { "your raid index hidden", function(w) w.raid.player = Support.Secret("your raid index", 3) end },
        { "raid1's raid index hidden", function(w) w.raid.raid1 = Support.Secret("raid1's raid index", 1) end },
        { "your group hidden", function(w) w.groups[3] = Support.Secret("your group", 1) end },
        { "raid1's group hidden", function(w) w.groups[1] = Support.Secret("raid1's group", 1) end },
        { "no raid index for you", function(w) w.raid.player = nil end },
        { "no raid index for raid1", function(w) w.raid.raid1 = nil end },
        { "no group for you", function(w) w.groups[3] = nil end },
        { "no group for raid1", function(w) w.groups[1] = nil end },
        { "no group for either", function(w) w.groups[1], w.groups[3] = nil, nil end },
        -- One hidden value for both: Lua finds a value equal to itself without asking it,
        -- so only the checks on the hidden groups keep the bars off. With one group hidden
        -- the comparison gives no on its own, as the game's does: a hidden value equals
        -- nothing (docs/forever-api.md, section 2).
        { "both groups hidden", function(w)
            local hidden = Support.Secret("both groups", 1)
            w.groups[1], w.groups[3] = hidden, hidden
        end },
    }
    for _, combat in ipairs({ "out of combat", "in combat" }) do
        local function Fresh()
            self:setUp(IsHidden)
            BindPrayerOfHealing(self.ns.charDB.bindings)
            if combat == "in combat" then EnterCombat() end
            return Group(Raid())
        end
        Fresh()
        lu.assertEquals(self:HealOn("raid1"), GROUP, "nothing hidden, raid1, " .. combat)
        for _, case in ipairs(cases) do
            case[2](Fresh())
            local drawn, shown = pcall(self.HealOn, self, "raid1")
            lu.assertTrue(drawn, case[1] .. ", raid1, " .. combat .. ": the hover raised " .. tostring(shown))
            lu.assertEquals(shown, HIDDEN, case[1] .. ", raid1, " .. combat)
        end

        -- Only whether a frame shows you hidden, in a raid: the group numbers decide.
        local world = Fresh()
        world.isHidden = Support.Secret("is it you", true)
        world.raid.target, world.players.target = 3, true
        lu.assertEquals(self:HealOn("raid3"), GROUP, "'is it you' hidden, your own raid frame, " .. combat)
        lu.assertEquals(self:HealOn("target"), GROUP, "'is it you' hidden, the target frame on you, " .. combat)
        lu.assertEquals(self:HealOn("raid1"), GROUP, "'is it you' hidden, raid1, " .. combat)
        lu.assertEquals(self:HealOn("raid5"), HIDDEN, "'is it you' hidden, raid5, " .. combat)

        -- The same in a party: no group numbers, so a target on you shows none, while
        -- your own frame and party1's keep theirs.
        world = Fresh()
        world.raid, world.groups, world.party = nil, nil, 1
        world.isHidden = Support.Secret("is it you", true)
        world.players.target = true
        lu.assertEquals(self:HealOn("player"), GROUP, "in a party, 'is it you' hidden, your own frame, " .. combat)
        lu.assertEquals(self:HealOn("party1"), GROUP, "in a party, 'is it you' hidden, party1, " .. combat)
        lu.assertEquals(self:HealOn("target"), HIDDEN, "in a party, 'is it you' hidden, the target frame, " .. combat)

        -- Both hidden in a raid: your own raid frame shows none too.
        world = Fresh()
        world.isHidden = Support.Secret("is it you", true)
        world.raid.player = Support.Secret("your raid index", 3)
        lu.assertEquals(self:HealOn("raid3"), HIDDEN, "all hidden, your own raid frame, " .. combat)
        lu.assertEquals(self:HealOn("player"), GROUP, "all hidden, your own frame, " .. combat)
    end
end

-- AC1, S9, and #20's AC3 row it replaces ("a group heal you cast on yourself shows as
-- today"), whose raid12 outside your group now shows none: in and out of combat.
-- That the game hides none of these answers in combat is not checked in game.
function TestHealPrediction:testAGroupHealAroundYouShowsOnlyOnTheFramesOfYourGroupInCombat()
    for _, combat in ipairs({ "out of combat", "in combat" }) do
        self:setUp()
        BindPrayerOfHealing(self.ns.charDB.bindings)
        if combat == "in combat" then EnterCombat() end
        Group({ party = 1 })
        lu.assertEquals(self:HealOn("player"), GROUP, "in a party, your own frame, " .. combat)
        lu.assertEquals(self:HealOn("party1"), GROUP, "in a party, party1, " .. combat)
        Group(Raid())
        lu.assertEquals(self:HealOn("player"), GROUP, "in a raid, your own frame, " .. combat)
        lu.assertEquals(self:HealOn("raid1"), GROUP, "in a raid, raid1 of your group, " .. combat)
        lu.assertEquals(self:HealOn("raid12"), HIDDEN, "in a raid, raid12 of another group, " .. combat)
    end
end

-- AC2, S10: Prayer of Healing on Shift + left click, Flash Heal on the plain left click.
function TestHealPrediction:testAGroupHealOnAModifierFollowsTheModifierAndTheFrame()
    BindPrayerOfHealing(self.ns.charDB.bindings, "shift-1")
    self.ns.charDB.bindings["1"] = Spell(FLASH_HEAL[7], false)
    Group(Raid())
    self.button = Support.FakeButton("raid5")
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), FLASH, "raid5 of another group")
    PressModifiers({ shift = true })
    lu.assertEquals(self:Bars(), HIDDEN, "raid5 with Shift")
    self.UnitButton.OnLeave(self.button)
    self.button = Support.FakeButton("raid1")
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(self:Bars(), GROUP, "raid1 of your group with Shift")
    PressModifiers({})
    lu.assertEquals(self:Bars(), FLASH, "Shift released")
end

-- AC5, S16: Chain Heal lands on the member you click, so it shows on every frame of
-- S1 to S8, also where the game hides who is you and your raid index.
function TestHealPrediction:testAGroupHealCastOnTheClickedMemberShowsOnEveryFrame()
    for _, hidden in ipairs({ false, true }) do
        self:setUp(IsHidden)
        UnitClass = function() return "Shaman", "SHAMAN" end
        Support.SetKnown({ CHAIN_HEAL })
        Support.SetDescription(CHAIN_HEAL, CHAIN_HEAL_TEXT)
        self.ns.charDB.bindings["1"] = Spell(CHAIN_HEAL, false)
        local world = Raid()
        world.raid.pet, world.raid.raidpet1, world.raid.target = 3, 1, 1
        if hidden then
            world.isHidden = Support.Secret("is it you", true)
            world.raid.player = Support.Secret("your raid index", 3)
        end
        Group(world)
        local label = hidden and ", hidden" or ""
        for _, unit in ipairs({ "player", "raid3", "raid1", "raid5", "raid12", "pet", "raidpet1", "partypet1",
                                "target", "focus" }) do
            lu.assertEquals(self:HealOn(unit), CHAIN, unit .. label)
        end
        Group({ party = 1 })
        lu.assertEquals(self:HealOn("party1"), CHAIN, "in a party, party1" .. label)
    end
end

-- AC5, S18: a heal NeoHeal can't tell from a group heal shows only on a frame that
-- shows you: Flash Heal while Prayer of Healing gives no name; Prayer of Healing
-- without a name of its own, without a class, or while both of Desperate Prayer's
-- ids give no name (#20's order: an unnamed listed heal is "can't tell").
function TestHealPrediction:testAHealThatCantBeToldFromAGroupHealShowsOnlyOnAFrameThatShowsYou()
    Group({ party = 1 })
    NameSpells({ PRAYER_OF_HEALING })
    lu.assertEquals(self:HealOn("player"), FLASH, "Prayer of Healing unnamed, Flash Heal on your own frame")
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "Prayer of Healing unnamed, Flash Heal on party1")

    local cases = {
        { "Prayer of Healing unnamed", function() NameSpells({ PRAYER_OF_HEALING }) end },
        { "no class", function() UnitClass = function() return nil end end },
        { "Desperate Prayer unnamed", function() NameSpells({ DESPERATE_PRAYER, DESPERATE_PRAYER_2 }) end },
    }
    for _, case in ipairs(cases) do
        self:setUp()
        BindPrayerOfHealing(self.ns.charDB.bindings)
        Group({ party = 1 })
        case[2]()
        lu.assertEquals(self:HealOn("player"), GROUP, case[1] .. ", Prayer of Healing on your own frame")
        lu.assertEquals(self:HealOn("party1"), HIDDEN, case[1] .. ", Prayer of Healing on party1")
    end
end

-- AC5, S19: the answer follows the name the game gives now, never one it failed to
-- give at an earlier hover; Prayer of Healing itself too, after a draw that found no
-- name for it.
function TestHealPrediction:testAGroupHealsNameGivenLateCountsFromTheNextHover()
    Group({ party = 1 })
    local getName = NameSpells({ PRAYER_OF_HEALING })
    lu.assertEquals(self:HealOn("party1"), HIDDEN, "no name yet, Flash Heal on party1")
    C_Spell.GetSpellName = getName
    lu.assertEquals(self:HealOn("party1"), FLASH, "named now, Flash Heal on party1")
    BindPrayerOfHealing(self.ns.charDB.bindings)
    Group(Raid())
    lu.assertEquals(self:HealOn("raid5"), HIDDEN, "named now, Prayer of Healing on raid5 of another group")
    lu.assertEquals(self:HealOn("raid1"), GROUP, "named now, Prayer of Healing on raid1 of your group")
end

-- The heal bars of the hovered wide button.
function TestShieldRedraws:Bars()
    return { Shows(self.button.prediction), Shows(self.button.predictionRange) }
end

-- AC1, S9: Desperate Prayer while the target or focus changes under the mouse.
function TestShieldRedraws:testTheHealFollowsTheTargetOrFocusUnderTheMouse()
    BindDesperatePrayer(self.ns.charDB.bindings)
    for unit, event in pairs({ target = "PLAYER_TARGET_CHANGED", focus = "PLAYER_FOCUS_CHANGED" }) do
        self.you[unit] = true
        self:Hover(unit)
        lu.assertEquals(self:Bars(), PRAYER, unit .. " on you")
        self.you[unit] = false
        self.ns[event](self.ns)
        lu.assertEquals(self:Bars(), HIDDEN, unit .. " changed to party1")
        self.you[unit] = true
        self.ns[event](self.ns)
        lu.assertEquals(self:Bars(), PRAYER, unit .. " back on you")
        self.UnitButton.OnLeave(self.button)
    end
end

-- AC1, S10: the group puts another member behind your raid frame, and later you again.
function TestShieldRedraws:testTheHealFollowsARosterChangeUnderTheMouse()
    BindDesperatePrayer(self.ns.charDB.bindings)
    self.you.raid3 = true
    self:Hover("raid3")
    lu.assertEquals(self:Bars(), PRAYER, "your raid frame")
    self.you.raid3 = false
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), HIDDEN, "another member behind it")
    self.you.raid3 = true
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), PRAYER, "you again")
end

-- Prayer of Healing on the left click in a raid for the redraw rows: you are raid3;
-- raid1 to raid3 are group 1, raid5 group 2. Returns the raid index per unit and the
-- group per index, which a test changes; the fakes read them live. The target and
-- focus frames show players.
function TestShieldRedraws:Raid()
    local index = { player = 3, raid1 = 1, raid2 = 2, raid3 = 3, raid5 = 5 }
    local groups = { [1] = 1, [2] = 1, [3] = 1, [5] = 2 }
    Override("IsInRaid", function() return true end)
    Override("UnitInRaid", function(unit) return index[unit] end)
    Override("GetRaidRosterInfo", function(i)
        if groups[i] == nil then return nil end
        return "Someone", 0, groups[i]
    end)
    Override("UnitIsPlayer", function(unit) return unit == "target" or unit == "focus" end)
    -- A player's frame takes its class colour when it redraws.
    Override("RAID_CLASS_COLORS", setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end }))
    BindPrayerOfHealing(self.ns.charDB.bindings)
    return index, groups
end

-- AC2, S11: the target or focus frame changes from a member of your group to one of
-- another group and back, the mouse staying on it.
function TestShieldRedraws:testTheGroupHealFollowsTheTargetOrFocusUnderTheMouse()
    local index = self:Raid()
    for unit, event in pairs({ target = "PLAYER_TARGET_CHANGED", focus = "PLAYER_FOCUS_CHANGED" }) do
        index[unit] = 1
        self:Hover(unit)
        lu.assertEquals(self:Bars(), GROUP, unit .. " on raid1 of your group")
        index[unit] = 5
        self.ns[event](self.ns)
        lu.assertEquals(self:Bars(), HIDDEN, unit .. " changed to raid5 of another group")
        index[unit] = 1
        self.ns[event](self.ns)
        lu.assertEquals(self:Bars(), GROUP, unit .. " back on raid1")
        self.UnitButton.OnLeave(self.button)
    end
end

-- AC2, S12: the group puts a member of another group behind your raid frame (you are
-- raid4 now), and later a member of your group.
function TestShieldRedraws:testTheGroupHealFollowsARosterChangeUnderTheMouse()
    local index, groups = self:Raid()
    self.you.raid3 = true
    self:Hover("raid3")
    lu.assertEquals(self:Bars(), GROUP, "your raid frame")
    self.you.raid3, self.you.raid4 = false, true
    index.player, index.raid4, groups[3], groups[4] = 4, 4, 2, 1
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), HIDDEN, "a member of another group behind it")
    groups[3] = 1
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), GROUP, "a member of your group behind it")
end

-- AC2, S13: the member behind the frame moves to another group and back, then you do.
function TestShieldRedraws:testTheGroupHealFollowsAMoveToAnotherGroupUnderTheMouse()
    local _, groups = self:Raid()
    self:Hover("raid1")
    lu.assertEquals(self:Bars(), GROUP, "raid1 of your group")
    groups[1] = 2
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), HIDDEN, "raid1 moved to group 2")
    groups[1] = 1
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), GROUP, "raid1 back in your group")
    groups[3] = 2
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), HIDDEN, "you moved to group 2")
    groups[3] = 1
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), GROUP, "you back in raid1's group")
end

-- AC3, S14: a member of your group out of range keeps its bars, in a raid and in a
-- party; the range answer is read (the frame's fade), and the bars don't follow it.
function TestShieldRedraws:testAGroupHealShowsOnAMemberOfYourGroupOutOfItsReach()
    self:Raid()
    local asked = 0
    Override("UnitInRange", function() asked = asked + 1; return false, true end)
    self:Hover("raid1")
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), GROUP, "raid1 of your group, out of range")
    self.UnitButton.OnLeave(self.button)
    Override("IsInRaid", function() return false end)
    Override("GetNumSubgroupMembers", function() return 1 end)
    self:Hover("party1")
    self.ns:GROUP_ROSTER_UPDATE()
    lu.assertEquals(self:Bars(), GROUP, "party1, out of range")
    lu.assertTrue(asked > 0, "the range was asked")
end

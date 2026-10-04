-- The click bindings under the unit tooltip: ClickCast:AddBindingsToTooltip, and
-- UnitButton's post-call that adds them only to our own frames' tooltips.
local lu = require("luaunit")
local Support = require("support")
local FLASH_HEAL, ABOLISH_DISEASE = Support.FLASH_HEAL, Support.ABOLISH_DISEASE

local function Spell(spellID, highestRank, target)
    return { action = "spell", spellID = spellID, highestRank = highestRank, target = target or "unit" }
end

TestTooltip = {}

function TestTooltip:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = {}, hoverKeys = {} }
    self.ns, self.ClickCast, self.bindings = ns, ns.ClickCast, ns.charDB.bindings
end

function TestTooltip:Lines()
    local tooltip = Support.FakeTooltip()
    self.ClickCast:AddBindingsToTooltip(tooltip)
    return tooltip.lines
end

-- The game's own order and spelling: SecureButton_GetModifierPrefix.
function TestTooltip:testModifierPrefixMatchesTheGame()
    lu.assertEquals(self.ClickCast.GetModifierPrefix(), "")
    Support.SetModifiers({ shift = true })
    lu.assertEquals(self.ClickCast.GetModifierPrefix(), "shift-")
    Support.SetModifiers({ shift = true, ctrl = true, alt = true })
    lu.assertEquals(self.ClickCast.GetModifierPrefix(), "alt-ctrl-shift-")
end

function TestTooltip:testEveryBoundButtonInButtonOrder()
    self.bindings["3"] = Spell(ABOLISH_DISEASE, true)
    self.bindings["1"] = Spell(FLASH_HEAL[7], true)
    self.bindings["shift-2"] = Spell(FLASH_HEAL[3], false)   -- another modifier: not listed
    lu.assertEquals(self:Lines(), {
        { "line", " " },
        { "double", "Left click", "Flash Heal" },
        { "double", "Middle click", "Abolish Disease" },
    })
end

function TestTooltip:testAHeldModifierShowsItsBindingsUnderATitle()
    self.bindings["1"] = Spell(FLASH_HEAL[7], true)
    self.bindings["shift-1"] = Spell(FLASH_HEAL[3], false)
    self.bindings["shift-2"] = { action = "menu" }
    Support.SetModifiers({ shift = true })
    lu.assertEquals(self:Lines(), {
        { "line", " " },
        { "line", "Shift" },
        { "double", "Left click", "Flash Heal (Rank 3)" },
        { "double", "Right click", "Open unit menu" },
    })
end

-- Two modifiers at once match no binding, so a click does nothing: neither does the tooltip.
function TestTooltip:testTwoModifiersShowNothing()
    self.bindings["shift-1"] = Spell(FLASH_HEAL[7], true)
    self.bindings["ctrl-1"] = Spell(FLASH_HEAL[3], false)
    Support.SetModifiers({ shift = true, ctrl = true })
    lu.assertEquals(self:Lines(), {})
end

function TestTooltip:testNothingBoundAddsNothing()
    lu.assertEquals(self:Lines(), {})
end

function TestTooltip:testATargetOtherThanTheClickedUnitIsNamed()
    self.bindings["1"] = Spell(FLASH_HEAL[7], true, "target")
    self.bindings["2"] = { action = "target", target = "targettarget" }
    lu.assertEquals(self:Lines(), {
        { "line", " " },
        { "double", "Left click", "Flash Heal (Unit's target)" },
        { "double", "Right click", "Target (Target of target)" },
    })
end

-- The menu and the buff go to the clicked unit whatever a binding says.
function TestTooltip:testMenuAndBuffNeverNameATarget()
    self.bindings["1"] = { action = "menu", target = "target" }
    self.bindings["2"] = { action = "buff", target = "targettarget" }
    lu.assertEquals(self:Lines(), {
        { "line", " " },
        { "double", "Left click", "Open unit menu" },
        { "double", "Right click", "Cast missing buff" },
    })
end

function TestTooltip:testColours()
    self.bindings["shift-1"] = Spell(FLASH_HEAL[7], true)
    Support.SetModifiers({ shift = true })
    local tooltip = Support.FakeTooltip()
    self.ClickCast:AddBindingsToTooltip(tooltip)
    lu.assertEquals(tooltip.colors[2], { 1, 0.82, 0 })                  -- "Shift" in the game's gold
    lu.assertEquals(tooltip.colors[3], { 0.7, 0.7, 0.7, 1, 1, 1 })      -- grey button, white spell
end

function TestTooltip:testAHoverKeyShowsOnceItHasAKey()
    self.bindings["-neokey1"] = Spell(FLASH_HEAL[7], true)
    lu.assertEquals(self:Lines(), {})

    self.ns.charDB.hoverKeys[1] = "Q"
    lu.assertEquals(self:Lines(), {
        { "line", " " },
        { "double", "Key: Q", "Flash Heal" },
    })
end

-- The amount a spell binding heals or absorbs, after its name, from the spell's
-- description. REAL_HEAL is what the game returned for Healing Wave (in game,
-- 2026-10-04). CLASSIC holds the Classic texts from Wowhead's tooltips (fetched
-- 2026-10-04); its Healing Wave rank 1 matched the game's text exactly. The texts
-- marked "made up" test one rule each.
TestTooltipAmounts = {}

local REAL_HEAL = "Heals a friendly target for 237 to 280."
local CLASSIC = {
    chainHeal = "Heals the friendly target for 332 to 381, then jumps to heal additional nearby targets. "
        .. "If cast on a party member, the heal will only jump to other party members.",
    holyShock = "Blasts the target with Holy energy, causing 204 to 220 Holy damage to an enemy, "
        .. "or 204 to 220 healing to an ally.",
    renew = "Heals the target of 45 damage over 15 sec.",
    shield = "Draws on the soul of the party member to shield them, absorbing 942 damage. Lasts 30 sec.",
    rend = "Wounds the target causing them to bleed for 15 damage over 9 sec.",
    tranquility = "Regenerates all nearby group members for 98 every 2 seconds for 10 sec.",
}

function TestTooltipAmounts:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = {}, hoverKeys = {} }
    self.ClickCast, self.bindings = ns.ClickCast, ns.charDB.bindings
end

-- The text of the left click line for `binding`, with Flash Heal rank 7 described as `text`.
function TestTooltipAmounts:Line(binding, text)
    Support.SetDescription(FLASH_HEAL[7], text)
    self.bindings["1"] = binding
    local tooltip = Support.FakeTooltip()
    self.ClickCast:AddBindingsToTooltip(tooltip)
    return tooltip.lines[2][3]
end

function TestTooltipAmounts:testAHealShowsItsRange()
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[1], true), REAL_HEAL), "Flash Heal |cff33ff33237-280|r")
end

-- The numbers come from the rank the click casts, not the rank that was saved.
function TestTooltipAmounts:testTheRangeIsThatOfTheRankCast()
    Support.SetDescription(FLASH_HEAL[6], "Heals a friendly target for 190 to 230.")
    local minusOne = { action = "spell", spellID = FLASH_HEAL[4], highestRank = true, rankOffset = 1, target = "unit" }
    lu.assertEquals(self:Line(minusOne, REAL_HEAL), "Flash Heal (Rank 6, highest -1) |cff33ff33190-230|r")
end

function TestTooltipAmounts:testAShieldShowsWhatItAbsorbs()
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true), CLASSIC.shield), "Flash Heal |cff99ccff942 absorb|r")
end

function TestTooltipAmounts:testAHotShowsItsTotal()
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true), CLASSIC.renew), "Flash Heal |cff33ff3345|r")
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true), "Heals the target for 32 over 12 sec."),
        "Flash Heal |cff33ff3332|r")
end

-- A number never takes the comma after it along.
function TestTooltipAmounts:testChainHealShowsItsRangeWithoutTheComma()
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true), CLASSIC.chainHeal), "Flash Heal |cff33ff33332-381|r")
end

-- The real text has the same numbers for damage and healing; the made-up second
-- text has different ones, so only the healing range passes.
function TestTooltipAmounts:testHolyShockShowsItsHealing()
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true), CLASSIC.holyShock), "Flash Heal |cff33ff33204-220|r")
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true), "Blasts the target with Holy energy, causing 204 to "
        .. "220 Holy damage to an enemy, or 250 to 270 healing to an ally."), "Flash Heal |cff33ff33250-270|r")
end

-- Made up: a number with thousands commas keeps them.
function TestTooltipAmounts:testThousandsCommasStay()
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true), "Heals a friendly target for 1,966 to 2,195."),
        "Flash Heal |cff33ff331,966-2,195|r")
end

-- Regrowth: the direct heal; the HoT part after it is left out.
function TestTooltipAmounts:testAHealWithAHotShowsTheDirectHeal()
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true),
        "Heals a friendly target for 93 to 107 and another 98 over 21 sec."), "Flash Heal |cff33ff3393-107|r")
end

function TestTooltipAmounts:testTheTargetComesBeforeTheAmount()
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true, "target"), REAL_HEAL),
        "Flash Heal (Unit's target) |cff33ff33237-280|r")
end

-- No number rather than a wrong one.
function TestTooltipAmounts:testNoAmountForDamageCuresOrOtherText()
    local binding = Spell(FLASH_HEAL[7], true)
    lu.assertEquals(self:Line(binding, "Smite an enemy for 28 to 34 Holy damage."), "Flash Heal")
    lu.assertEquals(self:Line(binding,
        "Attempts to cure 1 disease effect on the target, and 1 more disease effect every 5 seconds for 20 sec."),
        "Flash Heal")
    lu.assertEquals(self:Line(binding, "Heilt ein freundliches Ziel um 237 bis 280."), "Flash Heal")
    lu.assertEquals(self:Line(binding, nil), "Flash Heal")
end

-- Damage over time is not healing; Tranquility's wording isn't recognised. The
-- third text is made up: "for N over" without a healing word.
function TestTooltipAmounts:testNoAmountForADotOrTranquility()
    local binding = Spell(FLASH_HEAL[7], true)
    lu.assertEquals(self:Line(binding, CLASSIC.rend), "Flash Heal")
    lu.assertEquals(self:Line(binding, CLASSIC.tranquility), "Flash Heal")
    lu.assertEquals(self:Line(binding, "Burns the target for 30 over 12 sec."), "Flash Heal")
end

-- Made up: the healing word and the numbers have to be in the same sentence, for
-- a range and for both HoT wordings.
function TestTooltipAmounts:testTheHealingWordCountsForItsOwnSentenceOnly()
    local binding = Spell(FLASH_HEAL[7], true)
    lu.assertEquals(self:Line(binding,
        "Summons a totem that heals. It strikes nearby enemies for 20 to 30 Nature damage."), "Flash Heal")
    lu.assertEquals(self:Line(binding, "Heals you. Burns the target for 30 damage over 12 sec."), "Flash Heal")
    lu.assertEquals(self:Line(binding, "Heals you. Burns the target for 30 over 12 sec."), "Flash Heal")
end

function TestTooltipAmounts:testNoAmountForASpellNotLearned()
    Support.SetKnown({})
    lu.assertEquals(self:Line(Spell(FLASH_HEAL[7], true), REAL_HEAL), "Flash Heal (not learned)")
end

function TestTooltipAmounts:testNoAmountForTargetMenuOrBuff()
    lu.assertEquals(self:Line({ action = "target", target = "unit" }, REAL_HEAL), "Target")
    lu.assertEquals(self:Line({ action = "menu" }, REAL_HEAL), "Open unit menu")
    lu.assertEquals(self:Line({ action = "buff" }, REAL_HEAL), "Cast missing buff")
end

-- A binding changed in combat takes effect when combat ends: until then the
-- tooltip shows what a click does now.

TestTooltipApplied = {}

function TestTooltipApplied:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = {}, hoverKeys = {} }
    local noop = function() end
    ns.Layout = { AllHeaders = function() return {} end }
    ns.UnitButton = { buttons = {}, UpdateAllAuras = noop }
    ns.MissingBuffs = {}
    self.ns, self.ClickCast = ns, ns.ClickCast
end

function TestTooltipApplied:Lines()
    local tooltip = Support.FakeTooltip()
    self.ClickCast:AddBindingsToTooltip(tooltip)
    return tooltip.lines
end

function TestTooltipApplied:testAChangeInCombatShowsWhenItIsApplied()
    self.ClickCast:Set("1", Spell(FLASH_HEAL[7], true))   -- out of combat: applied at once
    InCombatLockdown = function() return true end
    self.ClickCast:Set("1", Spell(FLASH_HEAL[3], false))
    lu.assertEquals(self:Lines()[2], { "double", "Left click", "Flash Heal" })

    InCombatLockdown = function() return false end
    self.ns:PLAYER_REGEN_ENABLED()   -- combat ends: the change is applied
    lu.assertEquals(self:Lines()[2], { "double", "Left click", "Flash Heal (Rank 3)" })
end

-- "Cast on" changes the binding itself rather than replacing it.
function TestTooltipApplied:testATargetChangedInCombatShowsWhenItIsApplied()
    self.ClickCast:Set("1", Spell(FLASH_HEAL[7], true))
    InCombatLockdown = function() return true end
    self.ClickCast:SetTarget("1", "target")
    lu.assertEquals(self:Lines()[2], { "double", "Left click", "Flash Heal" })
end

-- A hover key set in combat works only after combat, so it shows only then.
function TestTooltipApplied:testAHoverKeySetInCombatShowsWhenItIsApplied()
    self.ClickCast:Set("-neokey1", Spell(FLASH_HEAL[7], true))   -- bound, but no key yet
    InCombatLockdown = function() return true end
    self.ClickCast:SetHoverKey(1, "Q")
    lu.assertEquals(self:Lines(), {})

    InCombatLockdown = function() return false end
    self.ns:PLAYER_REGEN_ENABLED()
    lu.assertEquals(self:Lines(), { { "line", " " }, { "double", "Key: Q", "Flash Heal" } })
end

-- UnitButton.lua: hovering a frame, and the post-call that runs on every build of a
-- unit tooltip.

local function ModifierWatchers()
    local watchers = {}
    for _, frame in ipairs(Support.frames) do
        if frame.stub.events.MODIFIER_STATE_CHANGED then table.insert(watchers, frame) end
    end
    return watchers
end

-- Loads the files up to UnitButton.lua; `prepare` runs just before UnitButton.lua.
local function LoadHover(test, prepare)
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" })
    if prepare then prepare() end
    Support.LoadInto(ns, { "UnitButton.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = { ["1"] = Spell(FLASH_HEAL[7], true), ["shift-1"] = Spell(FLASH_HEAL[3], false) },
                  hoverKeys = {} }
    ns.db = { layout = { showTooltips = true } }
    test.button = Support.FakeButton("party1")
    ns.UnitButton.buttons[test.button] = true
    GameTooltip = Support.FakeTooltip()
    test.ns, test.UnitButton = ns, ns.UnitButton
end

local HOVER_LINES = { { "unit", "party1" }, { "line", " " }, { "double", "Left click", "Flash Heal" } }

TestTooltipHover = {}

function TestTooltipHover:setUp()
    LoadHover(self)
end

function TestTooltipHover:testShowsTheUnitWithTheBindingsBelowItOnce()
    self.UnitButton.OnEnter(self.button)
    lu.assertTrue(GameTooltip.shown)
    lu.assertEquals(GameTooltip.lines, HOVER_LINES)
end

function TestTooltipHover:testHoldingAModifierRebuildsTheTooltip()
    self.UnitButton.OnEnter(self.button)
    local watchers = ModifierWatchers()
    lu.assertEquals(#watchers, 1)

    Support.SetModifiers({ shift = true })
    watchers[1].stub.scripts.OnEvent(watchers[1], "MODIFIER_STATE_CHANGED")
    lu.assertEquals(GameTooltip.lines, {
        { "unit", "party1" }, { "line", " " }, { "line", "Shift" },
        { "double", "Left click", "Flash Heal (Rank 3)" },
    })
end

function TestTooltipHover:testLeavingHidesTheTooltipAndStopsWatching()
    self.UnitButton.OnEnter(self.button)
    local watcher = ModifierWatchers()[1]
    self.UnitButton.OnLeave(self.button)
    lu.assertFalse(GameTooltip.shown)
    lu.assertEquals(#ModifierWatchers(), 0)

    -- The real client sends no more events once OnLeave unregistered it; should one
    -- reach the watcher anyway, it changes nothing.
    Support.SetModifiers({ shift = true })
    watcher.stub.scripts.OnEvent(watcher, "MODIFIER_STATE_CHANGED")
    lu.assertFalse(GameTooltip.shown)
end

-- The frame lost its unit (a member left) while its tooltip shows: a modifier
-- change doesn't rebuild the tooltip for no unit.
function TestTooltipHover:testAFrameWithoutAUnitIsNotRebuilt()
    self.UnitButton.OnEnter(self.button)
    local watcher = ModifierWatchers()[1]
    self.button.unit = nil
    Support.SetModifiers({ shift = true })
    watcher.stub.scripts.OnEvent(watcher, "MODIFIER_STATE_CHANGED")
    lu.assertEquals(GameTooltip.lines, HOVER_LINES)
end

-- Something else took the tooltip while the mouse stayed on the frame: a modifier
-- change leaves that tooltip alone.
function TestTooltipHover:testAModifierChangeLeavesAnotherOwnersTooltipAlone()
    self.UnitButton.OnEnter(self.button)
    local watcher = ModifierWatchers()[1]
    local otherFrame = {}
    GameTooltip:SetOwner(otherFrame)
    GameTooltip:ClearLines()
    GameTooltip:AddLine("Something else")

    Support.SetModifiers({ shift = true })
    watcher.stub.scripts.OnEvent(watcher, "MODIFIER_STATE_CHANGED")
    lu.assertEquals(GameTooltip.lines, { { "line", "Something else" } })
    lu.assertTrue(GameTooltip:IsOwned(otherFrame))
end

function TestTooltipHover:testNothingWhenTooltipsAreOff()
    self.ns.db.layout.showTooltips = false
    self.UnitButton.OnEnter(self.button)
    lu.assertFalse(GameTooltip.shown)
    lu.assertEquals(#ModifierWatchers(), 0)
end

-- A client without TooltipDataProcessor: the lines are added straight after SetUnit.
TestTooltipHoverWithoutPostCalls = {}

function TestTooltipHoverWithoutPostCalls:testShowsTheBindingsOnce()
    LoadHover(self, function() TooltipDataProcessor = nil end)
    self.UnitButton.OnEnter(self.button)
    lu.assertEquals(GameTooltip.lines, HOVER_LINES)
end

-- A client that doesn't know MODIFIER_STATE_CHANGED: the tooltip still shows, and
-- the event is never registered or unregistered (both would raise an error).
TestTooltipUnknownModifierEvent = {}

function TestTooltipUnknownModifierEvent:testTheTooltipWorksWithoutTheEvent()
    LoadHover(self, function()
        C_EventUtils = { IsEventValid = function(event) return event ~= "MODIFIER_STATE_CHANGED" end }
    end)
    lu.assertTrue(pcall(self.UnitButton.OnEnter, self.button))
    lu.assertEquals(GameTooltip.lines, HOVER_LINES)
    lu.assertEquals(#ModifierWatchers(), 0)
    lu.assertTrue(pcall(self.UnitButton.OnLeave, self.button))
    lu.assertFalse(GameTooltip.shown)
end

-- The post-call on its own.

TestTooltipPostCall = {}

function TestTooltipPostCall:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = { ["1"] = Spell(FLASH_HEAL[7], true) }, hoverKeys = {} }
    self.ns = ns
    self.ourButton = {}
    ns.UnitButton.buttons[self.ourButton] = true
    local postCalls = Support.tooltipPostCalls[Enum.TooltipDataType.Unit]
    lu.assertEquals(#postCalls, 1)
    self.postCall = postCalls[1]
end

function TestTooltipPostCall:testAddsTheBindingsToOurFramesTooltip()
    GameTooltip = Support.FakeTooltip(self.ourButton)
    self.postCall(GameTooltip)
    lu.assertEquals(GameTooltip.lines, { { "line", " " }, { "double", "Left click", "Flash Heal" } })
end

function TestTooltipPostCall:testLeavesOtherTooltipsAlone()
    GameTooltip = Support.FakeTooltip({})   -- a unit tooltip owned by something else
    self.postCall(GameTooltip)
    lu.assertEquals(GameTooltip.lines, {})

    GameTooltip = Support.FakeTooltip(self.ourButton)
    local otherTooltip = Support.FakeTooltip(self.ourButton)   -- not GameTooltip
    self.postCall(otherTooltip)
    lu.assertEquals(otherTooltip.lines, {})
end

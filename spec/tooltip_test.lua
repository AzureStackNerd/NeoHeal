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
    local ns = Support.Load({ "Locales/enUS.lua", "Spells.lua", "ClickCast.lua" })
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
    local noop = function() end
    test.button = { unit = "party1", highlight = { Show = noop, Hide = noop } }
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

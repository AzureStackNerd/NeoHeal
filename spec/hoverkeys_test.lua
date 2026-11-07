-- Hover keys (ClickCast.lua): which keys the _onenter snippet takes over while the
-- mouse is on a frame, and which keys can't be a hover key at all. Seen in game: W
-- set as a hover key without an action kept the character walking
-- (docs/forever-api.md section 6).
local lu = require("luaunit")
local Support = require("support")

-- The held movement bindings in Blizzard's Bindings_Standard.xml (runOnUp="true"
-- under the Movement header), copied here so a binding dropped from the code fails.
local HELD_MOVEMENT = { "MOVEANDSTEER", "MOVEFORWARD", "MOVEBACKWARD", "TURNLEFT", "TURNRIGHT",
                        "STRAFELEFT", "STRAFERIGHT", "JUMP", "SITORSTAND", "PITCHUP", "PITCHDOWN" }

-- GetBindingAction for a few bound keys: { W = "MOVEFORWARD", ... }; "" for the rest.
local function BindKeys(actions)
    GetBindingAction = function(key) return actions[key] or "" end
end

TestHoverKeys = {}

function TestHoverKeys:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = {}, hoverKeys = {} }
    self.ClickCast, self.bindings, self.hoverKeys = ns.ClickCast, ns.charDB.bindings, ns.charDB.hoverKeys
end

-- A hover key with no action on any modifier must leave its key alone: binding it
-- would only take W away from walking.
function TestHoverKeys:testAHoverKeyWithoutAnActionLeavesItsKeyAlone()
    self.hoverKeys[1] = "W"
    lu.assertNil(self.ClickCast:BuildAttributes()._onenter)
end

function TestHoverKeys:testOnlyTheHoverKeysWithAnActionAreBound()
    self.hoverKeys[1] = "W"
    self.hoverKeys[2] = "Q"
    self.bindings["-neokey2"] = { action = "target", target = "unit" }
    local snippet = self.ClickCast:BuildAttributes()._onenter
    lu.assertStrContains(snippet, '"Q"')
    lu.assertNotStrContains(snippet, '"W"')
end

-- An action on one modifier is enough, and the key is then bound with every
-- modifier, as before ("SHIFT-Q" is a different binding than "Q").
function TestHoverKeys:testAnActionOnOneModifierBindsTheKeyWithEveryModifier()
    self.hoverKeys[1] = "Q"
    self.bindings["shift--neokey1"] = { action = "target", target = "unit" }
    local lines = {}
    local snippet = self.ClickCast:BuildAttributes()._onenter or ""   -- none fails below, not here
    for line in snippet:gmatch("[^\n]+") do table.insert(lines, line) end
    lu.assertEquals(lines, {
        'self:SetBindingClick(true, "Q", self, "neokey1")',
        'self:SetBindingClick(true, "SHIFT-Q", self, "neokey1")',
        'self:SetBindingClick(true, "CTRL-Q", self, "neokey1")',
        'self:SetBindingClick(true, "ALT-Q", self, "neokey1")',
    })
end

-- Leaving or hiding a frame always clears its hover bindings, also when there is
-- nothing left to bind: an action removed while the mouse was on a frame must not
-- leave its key taken.
function TestHoverKeys:testLeavingAlwaysClearsTheHoverBindings()
    local attributes = self.ClickCast:BuildAttributes()
    lu.assertNil(attributes._onenter)
    lu.assertEquals(attributes._onleave, "self:ClearBindings()")
    lu.assertEquals(attributes._onhide, "self:ClearBindings()")
end

-- Which keys move your character right now, read from the game's key bindings.
function TestHoverKeys:testAKeyBoundToMovementMovesTheCharacter()
    BindKeys({ W = "MOVEFORWARD" })
    lu.assertTrue(self.ClickCast.MovesTheCharacter("W"))
    lu.assertFalse(self.ClickCast.MovesTheCharacter("Q"))
end

function TestHoverKeys:testEveryHeldMovementBindingCounts()
    for _, action in ipairs(HELD_MOVEMENT) do
        BindKeys({ X = action })
        lu.assertTrue(self.ClickCast.MovesTheCharacter("X"), action)
    end
end

-- Autorun is a toggle, not held: nothing can get stuck, so it may be a hover key.
function TestHoverKeys:testAToggleIsNotMovement()
    BindKeys({ NUMLOCK = "TOGGLEAUTORUN" })
    lu.assertFalse(self.ClickCast.MovesTheCharacter("NUMLOCK"))
end

-- The snippet binds the key with every modifier, so each of those counts.
function TestHoverKeys:testTheKeyWithAModifierCountsToo()
    BindKeys({ ["ALT-X"] = "STRAFELEFT" })
    lu.assertTrue(self.ClickCast.MovesTheCharacter("X"))
end

-- A hover key saved before the key capture checked, or a key bound to movement
-- since: it keeps its action but isn't bound, so W keeps walking.
function TestHoverKeys:testAHoverKeyThatMovesYouIsNotBound()
    BindKeys({ W = "MOVEFORWARD" })
    self.hoverKeys[1] = "W"
    self.hoverKeys[2] = "Q"
    self.bindings["-neokey1"] = { action = "target", target = "unit" }
    self.bindings["-neokey2"] = { action = "target", target = "unit" }
    local snippet = self.ClickCast:BuildAttributes()._onenter or ""
    lu.assertStrContains(snippet, '"Q"')
    lu.assertNotStrContains(snippet, '"W"')
end

-- It does nothing, so the tooltip leaves it out.
function TestHoverKeys:testTheTooltipLeavesOutAHoverKeyThatMovesYou()
    BindKeys({ W = "MOVEFORWARD" })
    self.hoverKeys[1] = "W"
    self.hoverKeys[2] = "Q"
    self.bindings["-neokey1"] = { action = "target", target = "unit" }
    self.bindings["-neokey2"] = { action = "menu" }
    local tooltip = Support.FakeTooltip()
    self.ClickCast:AddBindingsToTooltip(tooltip)
    lu.assertEquals(tooltip.lines, { { "line", " " }, { "double", "Key: Q", "Open unit menu" } })
end

-- Changing a key binding in the game (UPDATE_BINDINGS) re-checks the hover keys,
-- and applies the bindings again only when that changes which keys are bound.
TestHoverKeysBindingChanges = {}

function TestHoverKeysBindingChanges:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" })
    ns.Spells:Scan()
    ns.db = {}   -- logged in
    ns.charDB = { bindings = { ["-neokey1"] = { action = "target", target = "unit" } }, hoverKeys = { "W" } }
    ns.Layout = { AllHeaders = function() return {} end }
    ns.UnitButton = { buttons = {} }
    self.pageRefreshes = 0
    ns.Options = { RefreshClickCastingPage = function() self.pageRefreshes = self.pageRefreshes + 1 end }
    local ClickCast = ns.ClickCast
    self.applies = 0
    local apply = ClickCast.Apply
    ClickCast.Apply = function(...) self.applies = self.applies + 1; return apply(...) end
    ClickCast:Apply()
    self.ns, self.ClickCast, self.applies = ns, ClickCast, 0
end

function TestHoverKeysBindingChanges:testTheEventIsRegistered()
    local registered = false
    for _, frame in ipairs(Support.frames) do
        if frame.stub.events.UPDATE_BINDINGS then registered = true end
    end
    lu.assertTrue(registered)
end

function TestHoverKeysBindingChanges:testBindingWToMovementUnbindsTheHoverKey()
    lu.assertStrContains(self.ClickCast.attributes._onenter or "", '"W"')
    BindKeys({ W = "MOVEFORWARD" })
    self.ns:UPDATE_BINDINGS()
    lu.assertEquals(self.applies, 1)
    lu.assertNil(self.ClickCast.attributes._onenter)
end

-- The event may come before the frames' first Apply (the order at login isn't
-- checked, and in combat at login Apply waits): nothing to compare with yet, so
-- nothing is applied.
function TestHoverKeysBindingChanges:testBeforeTheFirstApplyNothingHappens()
    self.ClickCast.attributes = nil
    BindKeys({ W = "MOVEFORWARD" })
    lu.assertTrue(pcall(self.ns.UPDATE_BINDINGS, self.ns))
    lu.assertEquals(self.applies, 0)
end

-- An open options page shows the change too: a hover-key button may now read
-- "W (moves you)", also when no frame changes (a hover key without an action).
function TestHoverKeysBindingChanges:testTheOptionsPageIsRefreshed()
    self.ns:UPDATE_BINDINGS()
    lu.assertEquals(self.pageRefreshes, 1)
end

-- Any other binding change, such as NeoHeal's own hover bindings on every
-- mouse-over if those fire the event too, applies nothing.
function TestHoverKeysBindingChanges:testAChangeThatKeepsTheHoverKeysAppliesNothing()
    BindKeys({ F = "TOGGLEAUTORUN" })
    self.ns:UPDATE_BINDINGS()
    lu.assertEquals(self.applies, 0)
end

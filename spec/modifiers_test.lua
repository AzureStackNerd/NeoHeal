-- Clicks with modifiers held use the game's own prefix, every modifier held as
-- "alt-ctrl-shift-": the res and buff snippet (ClickCast.RES_SNIPPET), the
-- explanation after a buff click (MissingBuffs.ExplainClick) and /neoheal clicks
-- (UnitButton.PrintClick). With two modifiers held none of them acts.
local lu = require("luaunit")
local Support = require("support")
local RunSnippet, World = Support.RunSnippet, Support.World

local COMBINATIONS = {
    {}, { shift = true }, { ctrl = true }, { alt = true },
    { shift = true, ctrl = true }, { shift = true, alt = true }, { ctrl = true, alt = true },
    { shift = true, ctrl = true, alt = true },
}

local function Count(held)
    local count = 0
    for _ in pairs(held) do count = count + 1 end
    return count
end

local function Describe(held)
    local names = {}
    for name in pairs(held) do table.insert(names, name) end
    table.sort(names)
    return #names > 0 and table.concat(names, "+") or "no modifier"
end

TestResSnippet = {}

function TestResSnippet:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Spells.lua", "ClickCast.lua" })
    self.snippet, self.ClickCast = ns.ClickCast.RES_SNIPPET, ns.ClickCast
    -- Shift + left click casts a spell, Shift + right click casts the missing buff.
    self.attributes = { unit = "party1", ["*type-neores"] = "spell", ["*spell-neobuff"] = 21562,
                        ["shift-type1"] = "spell", ["shift-type2"] = "neobuff" }
    self.deadParty1 = World({ dead = { party1 = true } })
    Support.SetModifiers({ shift = true })
end

-- The snippet builds its prefix itself (it can't call GetModifierPrefix): for every
-- combination it must find the binding under the game's prefix.
function TestResSnippet:testUsesTheGamesPrefixForEveryCombination()
    for _, held in ipairs(COMBINATIONS) do
        Support.SetModifiers(held)
        local prefix = self.ClickCast.GetModifierPrefix()
        local attributes = { unit = "party1", ["*type-neores"] = "spell", ["*spell-neobuff"] = 21562,
                             [prefix .. "type1"] = "spell", [prefix .. "type2"] = "neobuff" }
        lu.assertEquals(RunSnippet(self.snippet, attributes, "LeftButton", self.deadParty1), "neores", Describe(held))
        lu.assertEquals(RunSnippet(self.snippet, attributes, "RightButton", World()), "neobuff", Describe(held))
    end
end

-- NeoHeal binds no modifier or one: with two or more held, neither res nor buff.
function TestResSnippet:testTwoModifiersMatchNoBinding()
    local attributes = { unit = "party1", ["*type-neores"] = "spell", ["*spell-neobuff"] = 21562 }
    for _, modifier in ipairs({ "", "shift-", "ctrl-", "alt-" }) do
        attributes[modifier .. "type1"] = "spell"
        attributes[modifier .. "type2"] = "neobuff"
    end
    for _, held in ipairs(COMBINATIONS) do
        Support.SetModifiers(held)
        local acts = Count(held) <= 1
        lu.assertEquals(RunSnippet(self.snippet, attributes, "LeftButton", self.deadParty1),
            acts and "neores" or nil, Describe(held))
        lu.assertEquals(RunSnippet(self.snippet, attributes, "RightButton", World()),
            acts and "neobuff" or nil, Describe(held))
    end
end

function TestResSnippet:testALivingMemberGetsTheSpell()
    lu.assertNil(RunSnippet(self.snippet, self.attributes, "LeftButton", World()))
end

-- The res is for the clicked unit only, and only for a friend.
function TestResSnippet:testOnlyTheClickedFriendCounts()
    lu.assertNil(RunSnippet(self.snippet, self.attributes, "LeftButton", World({ dead = { party2 = true } })))
    self.attributes.unit = "party2"
    lu.assertEquals(RunSnippet(self.snippet, self.attributes, "LeftButton", World({ dead = { party2 = true } })), "neores")
    self.attributes.unit = "party1"
    lu.assertNil(RunSnippet(self.snippet, self.attributes, "LeftButton",
        World({ dead = { party1 = true }, friendly = {} })))
end

function TestResSnippet:testAMacroClickOnADeadMemberCastsTheRes()
    self.attributes["shift-type1"] = "macro"   -- "Also target" bindings are macros
    lu.assertEquals(RunSnippet(self.snippet, self.attributes, "LeftButton", self.deadParty1), "neores")
end

-- The game's own Target and Menu (plain left and right click) stay what they are.
function TestResSnippet:testTargetAndMenuStayOnADeadMember()
    Support.SetModifiers({})
    self.attributes["type1"] = "target"
    self.attributes["type2"] = "togglemenu"
    lu.assertNil(RunSnippet(self.snippet, self.attributes, "LeftButton", self.deadParty1))
    lu.assertNil(RunSnippet(self.snippet, self.attributes, "RightButton", self.deadParty1))
end

function TestResSnippet:testNoResSpellNoRes()
    self.attributes["*type-neores"] = nil
    lu.assertNil(RunSnippet(self.snippet, self.attributes, "LeftButton", self.deadParty1))
end

-- A buff click that can't buff is cancelled: false, so it does nothing at all.
function TestResSnippet:testNoBuffInCombatOrWithNothingToBuff()
    lu.assertEquals(RunSnippet(self.snippet, self.attributes, "RightButton", World({ inCombat = true })), false)
    self.attributes["*spell-neobuff"] = nil
    lu.assertEquals(RunSnippet(self.snippet, self.attributes, "RightButton", World()), false)
end

-- The red line after a "Cast missing buff" click that didn't buff.
TestExplainClick = {}

function TestExplainClick:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua", "MissingBuffs.lua" })
    ns.UnitButton = { readyCheckActive = false }
    local attributes = { ["shift-type1"] = "neobuff" }
    self.button = { GetAttribute = function(_, name) return attributes[name] end }   -- nothing to buff
    self.ns = ns
end

function TestExplainClick:testExplainsABuffClick()
    Support.SetModifiers({ shift = true })
    self.ns.MissingBuffs.ExplainClick(self.button, "LeftButton")
    lu.assertEquals(Support.errorMessages, { self.ns.L.BUFF_NOTHING_MISSING })
end

function TestExplainClick:testSaysNothingWithTwoModifiers()
    Support.SetModifiers({ shift = true, ctrl = true })
    self.ns.MissingBuffs.ExplainClick(self.button, "LeftButton")
    lu.assertEquals(Support.errorMessages, {})
end

-- /neoheal clicks prints what a click is bound to.
TestPrintClick = {}

function TestPrintClick:testPrintsTheBindingForTheModifiersHeld()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua" })
    local attributes = { ["shift-type1"] = "spell", ["shift-spell1"] = 2061 }
    local button = { unit = "party1", GetAttribute = function(_, name) return attributes[name] end }
    ns.UnitButton.debugClicks = true

    local printed, realPrint = {}, print
    print = function(text) table.insert(printed, text) end
    local ok, err = pcall(function()
        Support.SetModifiers({ shift = true })
        ns.UnitButton.PrintClick(button, "LeftButton")
        Support.SetModifiers({ shift = true, ctrl = true })
        ns.UnitButton.PrintClick(button, "LeftButton")
    end)
    print = realPrint   -- put back even when PrintClick failed
    assert(ok, err)

    lu.assertStrContains(printed[1], "type = spell, spell = 2061")
    lu.assertStrContains(printed[2], "type = nil, spell = nil")
end

-- "Target" and "Open unit menu" where Blizzard's click bindings would drop the click
-- (everything but plain left and right click): NeoHeal's own "neotarget", which the
-- click snippet turns into a /target macro, and "neomenu", which opens the menu
-- from Lua (ClickCast.OpenUnitMenu).
local lu = require("luaunit")
local Support = require("support")
local RunSnippet, World = Support.RunSnippet, Support.World

TestClickTypes = {}

function TestClickTypes:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" })
    ns.Spells:Scan()
    ns.charDB = { bindings = {}, hoverKeys = {} }
    self.ns, self.ClickCast, self.bindings = ns, ns.ClickCast, ns.charDB.bindings
end

-- Blizzard lets Target and Menu through on plain left and right click only.
function TestClickTypes:testTheGamesOwnTypesOnlyOnPlainLeftAndRightClick()
    self.bindings["1"] = { action = "target", target = "unit" }
    self.bindings["2"] = { action = "menu" }
    self.bindings["ctrl-1"] = { action = "target", target = "unit" }
    self.bindings["ctrl-2"] = { action = "menu" }
    self.bindings["3"] = { action = "target", target = "unit" }
    self.bindings["shift-5"] = { action = "menu" }
    self.bindings["-neokey1"] = { action = "target", target = "unit" }
    self.bindings["alt--neokey2"] = { action = "menu" }
    local attributes = self.ClickCast:BuildAttributes()
    lu.assertEquals(attributes["type1"], "target")
    lu.assertEquals(attributes["type2"], "togglemenu")
    lu.assertEquals(attributes["ctrl-type1"], "neotarget")
    lu.assertEquals(attributes["ctrl-type2"], "neomenu")
    lu.assertEquals(attributes["type3"], "neotarget")
    lu.assertEquals(attributes["shift-type5"], "neomenu")
    lu.assertEquals(attributes["type-neokey1"], "neotarget")
    lu.assertEquals(attributes["alt-type-neokey2"], "neomenu")
end

-- Plain left and right click keep the game's own Target and Menu for any action
-- on them, so a spell on the left button and Target on the right still work.
function TestClickTypes:testTargetOnPlainRightClickStaysTheGamesOwn()
    self.bindings["2"] = { action = "target", target = "unit" }
    lu.assertEquals(self.ClickCast:BuildAttributes()["type2"], "target")
end

function TestClickTypes:testATargetMacroForEveryCastOnChoice()
    local attributes = self.ClickCast:BuildAttributes()
    lu.assertEquals(attributes["*type-neotarget"], "macro")
    lu.assertEquals(attributes["*macrotext-neotarget"], "/target mouseover")
    lu.assertEquals(attributes["*type-neotarget-target"], "macro")
    lu.assertEquals(attributes["*macrotext-neotarget-target"], "/target mouseovertarget")
    lu.assertEquals(attributes["*type-neotarget-targettarget"], "macro")
    lu.assertEquals(attributes["*macrotext-neotarget-targettarget"], "/target mouseovertargettarget")
end

-- The header copies these onto new buttons, and old values are cleared: every
-- attribute BuildAttributes writes must be in ATTRIBUTE_NAMES.
function TestClickTypes:testTheTargetMacrosAreCopiedToNewButtons()
    local names = {}
    for _, name in ipairs(self.ClickCast.ATTRIBUTE_NAMES) do names[name] = true end
    for _, button in ipairs({ "neotarget", "neotarget-target", "neotarget-targettarget" }) do
        lu.assertTrue(names["*type-" .. button], button)
        lu.assertTrue(names["*macrotext-" .. button], button)
    end
end

-- The click snippet sends a "neotarget" click to the macro for its "Cast on"
-- choice, also on a dead member: Target never becomes the res.
function TestClickTypes:testTheSnippetPicksTheTargetMacro()
    local attributes = { unit = "party1", ["*type-neores"] = "spell",
                         ["ctrl-type1"] = "neotarget", ["ctrl-type2"] = "neotarget",
                         ["ctrl-unitsuffix2"] = "targettarget" }
    Support.SetModifiers({ ctrl = true })
    local snippet = self.ClickCast.RES_SNIPPET
    lu.assertEquals(RunSnippet(snippet, attributes, "LeftButton", World()), "neotarget")
    lu.assertEquals(RunSnippet(snippet, attributes, "RightButton", World()), "neotarget-targettarget")
    lu.assertEquals(RunSnippet(snippet, attributes, "LeftButton", World({ dead = { party1 = true } })), "neotarget")
end

-- A hover key "clicks" with its virtual button (neokey1, ...), whose attributes
-- end in "-neokey1": the snippet must find its Target binding there too.
function TestClickTypes:testTheSnippetPicksTheTargetMacroForAHoverKey()
    local attributes = { unit = "party1", ["type-neokey1"] = "neotarget", ["type-neokey2"] = "neotarget",
                         ["unitsuffix-neokey2"] = "target" }
    local snippet = self.ClickCast.RES_SNIPPET
    lu.assertEquals(RunSnippet(snippet, attributes, "neokey1", World()), "neotarget")
    lu.assertEquals(RunSnippet(snippet, attributes, "neokey2", World()), "neotarget-target")
end

-- The game's own Target and the NeoHeal menu are left alone by the snippet.
function TestClickTypes:testTheSnippetLeavesOtherTargetAndMenuClicksAlone()
    local attributes = { unit = "party1", ["*type-neores"] = "spell", ["type1"] = "target", ["ctrl-type2"] = "neomenu" }
    local snippet, dead = self.ClickCast.RES_SNIPPET, World({ dead = { party1 = true } })
    lu.assertNil(RunSnippet(snippet, attributes, "LeftButton", dead))
    Support.SetModifiers({ ctrl = true })
    lu.assertNil(RunSnippet(snippet, attributes, "RightButton", dead))
end

-- Every button gets the function a "neomenu" click calls.
function TestClickTypes:testEveryButtonGetsTheMenuFunction()
    self.bindings["ctrl-2"] = { action = "menu" }
    self.ClickCast.attributes = self.ClickCast:BuildAttributes()
    local set = {}
    local button = { SetAttribute = function(_, name, value) set[name] = value end }
    self.ClickCast:ApplyToButton(button)
    lu.assertEquals(button.neomenu, self.ClickCast.OpenUnitMenu)
    lu.assertEquals(set["ctrl-type2"], "neomenu")
end

-- The menu Blizzard's togglemenu would open, for the units NeoHeal's frames show.
TestOpenUnitMenu = {}

function TestOpenUnitMenu:setUp()
    self.ClickCast = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua" }).ClickCast
    self.frame = {}
end

function TestOpenUnitMenu:Opened(unit)
    Support.openedMenus = {}
    self.ClickCast.OpenUnitMenu(self.frame, unit)
    return Support.openedMenus[1]
end

function TestOpenUnitMenu:testMenusByUnit()
    lu.assertEquals(self:Opened("player")[1], "SELF")
    lu.assertEquals(self:Opened("party2")[1], "PARTY")
    lu.assertEquals(self:Opened("raid7")[1], "RAID_PLAYER")
    lu.assertEquals(self:Opened("pet")[1], "PET")
    lu.assertEquals(self:Opened("partypet1")[1], "OTHERPET")
    lu.assertEquals(self:Opened("raidpet3")[1], "OTHERPET")
end

-- In a raid you and your pet are raid units too.
function TestOpenUnitMenu:testYouAndYourPetInARaid()
    UnitIsUnit = function(a, b) return (a == "raid5" and b == "player") or (a == "raidpet5" and b == "pet") end
    lu.assertEquals(self:Opened("raid5")[1], "SELF")
    lu.assertEquals(self:Opened("raidpet5")[1], "PET")
    lu.assertEquals(self:Opened("raid6")[1], "RAID_PLAYER")
end

function TestOpenUnitMenu:testTheMenuBelongsToTheFrameAndUnit()
    lu.assertEquals(self:Opened("party2")[2], { ownerFrame = self.frame, unit = "party2" })
end

function TestOpenUnitMenu:testNoUnitNoMenu()
    lu.assertNil(self:Opened(nil))
end

-- A spell waiting for a target: the click opens no menu over it.
function TestOpenUnitMenu:testNoMenuWhileASpellWaitsForATarget()
    SpellIsTargeting = function() return true end
    lu.assertNil(self:Opened("party2"))
end

-- On maps where the game restricts addons, UnitIsUnit can be secret: that can't be
-- tested, so you get the raid member menu rather than an error.
TestOpenUnitMenuSecretAnswer = {}

function TestOpenUnitMenuSecretAnswer:testASecretAnswerGivesTheRaidMemberMenu()
    local ns = Support.Load({ "Locales/enUS.lua" })
    local SECRET = setmetatable({}, { __eq = function() error("compared a secret value") end })
    issecretvalue = function(value) return value == SECRET end   -- raw comparison: no __eq call
    Support.LoadInto(ns, { "Core.lua", "Spells.lua", "ClickCast.lua" })
    UnitIsUnit = function() return SECRET end
    ns.ClickCast.OpenUnitMenu({}, "raid5")
    lu.assertEquals(Support.openedMenus[1][1], "RAID_PLAYER")
end

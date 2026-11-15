-- MissingBuffs.lua: the grey icon in the third HoT slot shows on a member who
-- lacks your class's raid buff, and also on one whose buff is running out: 10% or
-- less of its full duration left (issue #2; Remco chose 10% on 2026-11-15). A
-- buff running out fires no event, so a button schedules its own re-check for the
-- moment its first buff starts running out. These tests drive one fake button
-- with fake auras, a clock they set themselves, and timers they fire by hand.
local lu = require("luaunit")
local Support = require("support")

local FORTITUDE, PRAYER = "Power Word: Fortitude", "Prayer of Fortitude"
local THIRTY_MINUTES, ONE_HOUR = 1800, 3600

-- A value the game hides: any comparison or arithmetic on it raises an error,
-- as a secret value does in the game.
local SECRET = setmetatable({}, {
    __eq = function() error("compared a secret value") end,
    __lt = function() error("compared a secret value") end,
    __le = function() error("compared a secret value") end,
    __sub = function() error("did arithmetic on a secret value") end,
    __mul = function() error("did arithmetic on a secret value") end,
})

local now, auras, timers, auraReads

-- An aura on the fake unit: `left` seconds of `duration` remaining.
local function Buff(name, duration, left)
    return { name = name, duration = duration, expirationTime = duration > 0 and now + left or 0 }
end

local function FakeIcon()
    local icon = { shown = false, texture = {} }
    function icon:Show() self.shown = true end
    function icon:Hide() self.shown = false end
    function icon:SetSize() end
    function icon:ClearAllPoints() end
    function icon:SetPoint() end
    function icon.texture:SetTexture(texture) self.texture = texture end
    return icon
end

local function FakeButton()
    local attributes = {}
    return {
        unit = "party1", health = {}, missingBuffIcon = FakeIcon(),
        GetAttribute = function(_, name) return attributes[name] end,
        SetAttribute = function(_, name, value) attributes[name] = value end,
    }
end

-- Fires every timer due by now, in the order they were scheduled.
local function FireDueTimers()
    local due = {}
    for index = #timers, 1, -1 do
        if timers[index].at <= now then table.insert(due, 1, table.remove(timers, index)) end
    end
    for _, timer in ipairs(due) do timer.func() end
end

TestMissingBuffs = {}

function TestMissingBuffs:setUp()
    local ns = Support.Load({ "Locales/enUS.lua" })
    issecretvalue = function(value) return rawequal(value, SECRET) end
    Support.LoadInto(ns, { "Core.lua", "Spells.lua", "MissingBuffs.lua" })
    now, auras, timers, auraReads = 1000, {}, {}, 0
    GetTime = function() return now end
    C_Timer = { After = function(delay, func) table.insert(timers, { at = now + delay, func = func }) end }
    -- Counts reads, so a test can tell whether an update ran at all.
    C_UnitAuras = { GetAuraDataByIndex = function(_, index) auraReads = auraReads + 1; return auras[index] end }
    UnitIsConnected = function() return true end
    UnitIsDeadOrGhost = function() return false end
    UnitIsPlayer = function() return true end
    IsInRaid = function() return false end
    ns.db = { layout = { showMissingBuffs = true } }
    ns.Hots = { GetIconSize = function() return 10 end }
    ns.UnitButton = { readyCheckActive = false }
    ns.MissingBuffs.known = {
        { names = { [FORTITUDE] = true, [PRAYER] = true }, spellID = 1243, icon = "fortitude-icon" },
    }
    ns.MissingBuffs.inCombat = false
    self.ns = ns
    self.button = FakeButton()
end

function TestMissingBuffs:Update()
    self.ns.MissingBuffs.Update(self.button)
end

-- A member without the buff gets the icon and the "Cast missing buff" click.
function TestMissingBuffs:testAMissingBuffShowsTheIcon()
    self:Update()
    lu.assertTrue(self.button.missingBuffIcon.shown, "no icon for a missing buff")
    lu.assertEquals(self.button:GetAttribute("*spell-neobuff"), 1243)
end

-- AC1: 3 minutes of a 30-minute buff is 10%: it is running out.
function TestMissingBuffs:testABuffWithTenPercentLeftShowsTheIcon()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 180) }
    self:Update()
    lu.assertTrue(self.button.missingBuffIcon.shown, "no icon for a buff with 10% left")
    lu.assertEquals(self.button:GetAttribute("*spell-neobuff"), 1243, "the click doesn't recast it")
end

-- 4 minutes of 30 is more than 10%: no icon yet, and the button checks again a
-- moment after the buff reaches 3 minutes left.
function TestMissingBuffs:testABuffWithMoreLeftShowsNoIconAndChecksAgainWhenItRunsOut()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 240) }
    self:Update()
    lu.assertFalse(self.button.missingBuffIcon.shown, "an icon for a buff with 13% left")
    lu.assertNil(self.button:GetAttribute("*spell-neobuff"))
    lu.assertEquals(#timers, 1, "no re-check scheduled")
    lu.assertAlmostEquals(timers[1].at, now + 60, 1, "the re-check isn't when the buff reaches 10%")
end

-- AC1 over time: the scheduled re-check finds the buff running out.
function TestMissingBuffs:testTheRecheckShowsTheIconOnceTheBuffRunsOut()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 240) }
    self:Update()
    now = now + 61
    FireDueTimers()
    lu.assertTrue(self.button.missingBuffIcon.shown, "the re-check didn't show the icon")
end

-- An update that finds the same moment keeps the pending re-check: the frequent
-- UNIT_AURA updates in a raid don't pile up timers.
function TestMissingBuffs:testTheSameMomentKeepsOneRecheck()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 240) }
    self:Update()
    self:Update()
    self:Update()
    lu.assertEquals(#timers, 1, "every update added a re-check")
end

-- An older re-check does nothing once a newer moment has replaced it (here the
-- member was rebuffed): it doesn't even read the auras.
function TestMissingBuffs:testAReplacedRecheckDoesNothing()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 240) }
    self:Update()
    local older = table.remove(timers, 1)
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, THIRTY_MINUTES) }
    self:Update()   -- a new moment: replaces the re-check
    now = now + 61
    auraReads = 0
    older.func()
    lu.assertEquals(auraReads, 0, "a replaced re-check updated the button")
end

-- A re-check that fires a moment early (timers aren't exact) schedules again for
-- the same moment, so the icon still comes.
function TestMissingBuffs:testAnEarlyRecheckSchedulesAgain()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 240) }
    self:Update()
    local first = table.remove(timers, 1)
    now = now + 59   -- one second before the buff reaches 10%
    first.func()
    lu.assertFalse(self.button.missingBuffIcon.shown)
    lu.assertEquals(#timers, 1, "an early re-check didn't schedule again")
    now = now + 2
    FireDueTimers()
    lu.assertTrue(self.button.missingBuffIcon.shown, "the icon never came after an early re-check")
end

-- A button that lost its unit while a re-check waited isn't updated.
function TestMissingBuffs:testARecheckSkipsAButtonWithoutUnit()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 240) }
    self:Update()
    self.button.unit = nil
    now = now + 61
    auraReads = 0
    FireDueTimers()
    lu.assertEquals(auraReads, 0, "a re-check updated a button without a unit")
end

-- The single version running out while the group version lasts: not running out.
function TestMissingBuffs:testTheLongestOfTheBuffsVersionsCounts()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 60), Buff(PRAYER, ONE_HOUR, 3000) }
    self:Update()
    lu.assertFalse(self.button.missingBuffIcon.shown, "the lasting group version was ignored")
end

-- Two auras with one name (two casters' Fortitude): the one that lasts counts.
function TestMissingBuffs:testOfTwoAurasWithOneNameTheLaterCounts()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 60), Buff(FORTITUDE, THIRTY_MINUTES, 1500) }
    self:Update()
    lu.assertFalse(self.button.missingBuffIcon.shown, "the lasting Fortitude was ignored")
end

-- Two buffs from your class (a priest with Divine Spirit): the second is found
-- missing while the first lasts, and with both lasting the re-check comes when
-- the first of them starts running out.
function TestMissingBuffs:testTwoBuffsFromYourClass()
    table.insert(self.ns.MissingBuffs.known, { names = { ["Divine Spirit"] = true }, spellID = 14752, icon = "spirit-icon" })
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 1500) }
    self:Update()
    lu.assertTrue(self.button.missingBuffIcon.shown, "a missing second buff showed no icon")
    lu.assertEquals(self.button.missingBuffIcon.texture.texture, "spirit-icon")
    lu.assertEquals(self.button:GetAttribute("*spell-neobuff"), 14752)

    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 1500), Buff("Divine Spirit", THIRTY_MINUTES, 400) }
    timers = {}
    self:Update()
    lu.assertFalse(self.button.missingBuffIcon.shown)
    lu.assertEquals(#timers, 1)
    lu.assertAlmostEquals(timers[1].at, now + 220, 1, "the re-check isn't when the first buff runs out")
end

-- With "Show missing buffs" off nothing shows, missing or running out.
function TestMissingBuffs:testTheOptionOffShowsNothing()
    self.ns.db.layout.showMissingBuffs = false
    self:Update()
    lu.assertFalse(self.button.missingBuffIcon.shown, "an icon with the option off")
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 60) }
    self:Update()
    lu.assertFalse(self.button.missingBuffIcon.shown, "an icon for a running-out buff with the option off")
end

-- A buff without a duration never runs out, so nothing needs checking again.
function TestMissingBuffs:testABuffWithoutDurationNeverRunsOut()
    auras = { Buff(FORTITUDE, 0, 0) }
    self:Update()
    lu.assertFalse(self.button.missingBuffIcon.shown, "an icon for a buff without duration")
    lu.assertEquals(#timers, 0, "a re-check for a buff that never runs out")
end

-- A duration the game hides counts as one that doesn't run out, and is never
-- compared or used in arithmetic.
function TestMissingBuffs:testAHiddenDurationCountsAsLasting()
    auras = { { name = FORTITUDE, duration = SECRET, expirationTime = SECRET } }
    self:Update()
    lu.assertFalse(self.button.missingBuffIcon.shown, "an icon for a buff whose duration is hidden")
    lu.assertEquals(#timers, 0)
end

-- AC3: in combat nothing shows, no re-check is scheduled, and one scheduled
-- before combat does nothing (leaving combat updates every button anyway).
function TestMissingBuffs:testInCombatNoRecheckRuns()
    auras = { Buff(FORTITUDE, THIRTY_MINUTES, 240) }
    self:Update()
    self.ns.MissingBuffs.inCombat = true
    self:Update()
    lu.assertFalse(self.button.missingBuffIcon.shown)
    lu.assertEquals(#timers, 1, "a re-check was scheduled in combat")
    now = now + 61
    self.ns.MissingBuffs.inCombat = false   -- out of combat again, so a stale re-check would read auras
    auraReads = 0
    FireDueTimers()
    lu.assertEquals(auraReads, 0, "the re-check from before combat still ran")
end

-- "Cast missing buff" in a raid: the group version (Prayer of Fortitude) for a
-- member of your party or raid, the single version for anyone else, such as the
-- target or focus frame on a player outside your group (issue #3). The group
-- version needs the spell and its reagent, both present here.
TestMissingBuffGroupVersion = {}

local SINGLE, GROUP, CANDLE = 1243, 21562, 17029
local GROUP_GLOBALS = { "UnitInRaid", "UnitInParty", "C_Item" }

function TestMissingBuffGroupVersion:setUp()
    self.saved = {}
    for _, name in ipairs(GROUP_GLOBALS) do self.saved[name] = _G[name] end
    local ns = Support.Load({ "Locales/enUS.lua" })
    issecretvalue = function(value) return rawequal(value, SECRET) end   -- Core reads it when it loads
    Support.LoadInto(ns, { "Core.lua", "Spells.lua", "MissingBuffs.lua" })
    Support.SetKnown({ SINGLE, GROUP })
    now, auras, timers = 1000, {}, {}
    GetTime = function() return now end
    C_Timer = { After = function() end }
    C_UnitAuras = { GetAuraDataByIndex = function() return nil end }   -- nobody has the buff
    C_Item = { GetItemCount = function(itemID) return itemID == CANDLE and 5 or 0 end }
    UnitIsConnected = function() return true end
    UnitIsDeadOrGhost = function() return false end
    UnitIsPlayer = function() return true end
    IsInRaid = function() return true end
    UnitInRaid = function() return nil end      -- in nobody's group until a test says so
    UnitInParty = function() return false end
    ns.db = { layout = { showMissingBuffs = true } }
    ns.Hots = { GetIconSize = function() return 10 end }
    ns.UnitButton = { readyCheckActive = false }
    ns.MissingBuffs.known = {
        { names = { [FORTITUDE] = true, [PRAYER] = true }, spellID = SINGLE, groupSpellID = GROUP,
          reagent = CANDLE, icon = "fortitude-icon" },
    }
    ns.MissingBuffs.inCombat = false
    self.ns = ns
end

function TestMissingBuffGroupVersion:tearDown()
    for _, name in ipairs(GROUP_GLOBALS) do _G[name] = self.saved[name] end
end

-- The spell the "Cast missing buff" click casts on a button for `unit`.
function TestMissingBuffGroupVersion:ClickSpell(unit)
    local button = FakeButton()
    button.unit = unit
    self.ns.MissingBuffs.Update(button)
    lu.assertTrue(button.missingBuffIcon.shown, unit .. ": no icon for a missing buff")
    return button:GetAttribute("*spell-neobuff")
end

function TestMissingBuffGroupVersion:testARaidMemberGetsTheGroupVersion()
    UnitInRaid = function(unit) return unit == "raid5" and 5 or nil end   -- the game returns a raid index
    lu.assertEquals(self:ClickSpell("raid5"), GROUP, "a raid member doesn't get the group version")
end

function TestMissingBuffGroupVersion:testAPartyMemberGetsTheGroupVersion()
    UnitInParty = function(unit) return unit == "party2" end
    lu.assertEquals(self:ClickSpell("party2"), GROUP, "a party member doesn't get the group version")
end

-- The target and focus frames on a player outside your group: the group version
-- would fail there, the single one works.
function TestMissingBuffGroupVersion:testTheTargetAndFocusOutsideYourGroupGetTheSingleVersion()
    lu.assertEquals(self:ClickSpell("target"), SINGLE, "the target frame on an outsider gets the group version")
    lu.assertEquals(self:ClickSpell("focus"), SINGLE, "the focus frame on an outsider gets the group version")
end

-- The target frame on a raid member is in your group: the group version, as on its own frame.
function TestMissingBuffGroupVersion:testTheTargetFrameOnARaidMemberGetsTheGroupVersion()
    UnitInRaid = function(unit) return unit == "target" and 5 or nil end
    lu.assertEquals(self:ClickSpell("target"), GROUP, "the target frame on a raid member doesn't get the group version")
end

-- On maps where the game restricts addons the group answers can be secret: never
-- tested, read as "not in your group", so the single version, which always works.
function TestMissingBuffGroupVersion:testASecretGroupAnswerGetsTheSingleVersion()
    UnitInRaid = function() return SECRET end
    UnitInParty = function() return SECRET end
    lu.assertEquals(self:ClickSpell("target"), SINGLE, "a secret group answer read as in your group")
end

-- The five-second rule (the story's acceptance criteria are quoted as AC1..AC8,
-- its scenario rows as S1..S40): the bar on the mana strip of every frame that
-- shows you, draining over the 5 seconds after a spell that cost mana
-- (UnitButton.lua), its events and default (Core.lua). Real unit buttons draw on
-- Recorder frames; the clock is fake, and the tests call the update at the moments
-- they choose instead of running the 0.1 s ticker. What these tests can't reach:
-- whether Forever fires the cast events, what C_Spell.GetSpellPowerCost answers
-- there, and whether SetAlphaFromBoolean places the bar on a frame whose "is this
-- you" answer the game hides. None of that is checked in game.
local lu = require("luaunit")
local Support = require("support")

-- Globals these tests set are put back afterwards (LuaUnit runs the classes in
-- name order, so later files' tests would see them).
local overridden = {}

local function Override(name, value)
    if overridden[name] == nil then overridden[name] = { _G[name] } end
    _G[name] = value
end

local function Restore()
    for name, old in pairs(overridden) do _G[name] = old[1] end
    overridden = {}
end

local T0 = 1000                            -- the fake clock at the first cast
local FLASH_HEAL = Support.FLASH_HEAL[1]   -- a cast time, costs mana
local RENEW = 139                          -- an instant, costs mana
local MIND_FLAY = 15407                    -- a channel of 3 seconds, costs mana
local TRANQUILITY = 740                    -- a channel of 10 seconds, costs mana
local SHOOT = 5019                         -- a wand: no resource cost
local CAT_FORM = 768                       -- a shapeshift that costs mana
local CLAW = 1082                          -- costs energy
local MAUL = 6807                          -- costs rage; lists a mana cost for caster form only
local HEROIC_STRIKE = 78                   -- costs rage
local CAT_FORM_AURA = 768

TestFiveSecond = {}

function TestFiveSecond:tearDown() Restore() end

-- You: a priest with a mana strip, alive, out of combat. self.you[unit] says which
-- other units are you, self.hiddenYou[unit] which answer the game hides, and
-- self.power[unit] a unit's power type (mana when not set).
function TestFiveSecond:setUp()
    local ns = Support.LoadUnitButtons(Override)
    self.ns, self.UnitButton = ns, ns.UnitButton
    self.you, self.hiddenYou, self.power = {}, {}, {}
    self.dead, self.inCombat = false, false
    self.guid = 0
    Override("UnitIsUnit", function(a, b)
        if b ~= "player" then return a == b end
        if self.hiddenYou[a] then return self.hiddenYou[a] end
        return a == "player" or self.you[a] == true
    end)
    Override("UnitPowerType", function(unit)
        local powerType = self.power[unit] or 0
        if Support.hidden[powerType] then return powerType end
        return powerType, ({ [0] = "MANA", [1] = "RAGE", [3] = "ENERGY" })[powerType]
    end)
    Override("UnitIsDeadOrGhost", function(unit) return unit == "player" and self.dead end)
    Override("InCombatLockdown", function() return self.inCombat end)
    for _, spellID in ipairs({ FLASH_HEAL, RENEW, MIND_FLAY, TRANQUILITY, CAT_FORM }) do
        Support.SetPowerCost(spellID, Support.ManaCost())
    end
    Support.SetPowerCost(SHOOT, nil)
    Support.SetPowerCost(CLAW, Support.ManaCost({ type = 3, name = "ENERGY", cost = 40 }))
    Support.SetPowerCost(HEROIC_STRIKE, Support.ManaCost({ type = 1, name = "RAGE", cost = 15 }))
    local maul = Support.ManaCost({ type = 1, name = "RAGE", cost = 15 })
    table.insert(maul, Support.ManaCost({ requiredAuraID = CAT_FORM_AURA, hasRequiredAura = false })[1])
    Support.SetPowerCost(MAUL, maul)
    Support.SetTime(T0)
    self.own = Support.RealButton(ns, "player")   -- your own party frame
end

function TestFiveSecond:Button(unit)
    return Support.RealButton(self.ns, unit)
end

-- Your spell `spellID` went off at `seconds` after T0 (UNIT_SPELLCAST_SUCCEEDED,
-- or a channel's start), each with its own castGUID unless one is given.
function TestFiveSecond:Cast(seconds, spellID, castGUID, unit)
    Support.SetTime(T0 + seconds)
    if not castGUID then
        self.guid = self.guid + 1
        castGUID = "Cast-" .. self.guid
    end
    self.UnitButton.OnPlayerCast(unit or "player", castGUID, spellID or FLASH_HEAL)
end

-- One tick of the bar at `seconds` after T0.
function TestFiveSecond:At(seconds)
    Support.SetTime(T0 + seconds)
    self.UnitButton.UpdateFiveSecond()
end

-- The bar of `button`: its value when it shows, or nil when it is hidden.
local function Bar(button)
    local bar = button.fiveSecond
    if not bar.shown or bar.alpha == 0 then return nil end
    return bar.value
end

local function AssertBar(button, expected, message)
    local value = Bar(button)
    lu.assertNotNil(value, message .. ": no bar")
    lu.assertAlmostEquals(value, expected, 1e-9, message)
end

-- AC1, S1, S2: when a spell that costs mana goes off, the bar appears full on your
-- frame, nothing before.
function TestFiveSecond:testAManaSpellStartsTheBarFull()
    lu.assertNil(Bar(self.own), "a bar before any cast")
    self:At(0)
    lu.assertNil(Bar(self.own), "a bar from a tick without a cast")
    self:Cast(0, FLASH_HEAL)
    AssertBar(self.own, 1, "Flash Heal's cast didn't start the bar full")
    self:Cast(10, RENEW)
    AssertBar(self.own, 1, "Renew didn't start the bar full")
end

-- AC1, S1, S10: it drains to empty over 5 seconds, then is gone.
function TestFiveSecond:testTheBarIsGoneAfterFiveSeconds()
    self:Cast(0)
    self:At(2.5)
    AssertBar(self.own, 0.5, "halfway")
    self:At(4.9)
    AssertBar(self.own, 0.02, "a tenth of a second before the end")
    self:At(5)
    lu.assertNil(Bar(self.own), "the bar is still there 5 seconds after the cast")
    self:At(5.1)
    lu.assertNil(Bar(self.own), "the bar came back after it ended")
end

-- AC1, S3, S4: a channel starts the bar when it starts; the same cast's own
-- success event later (same castGUID) doesn't restart it, so a 10 second channel's
-- bar is still gone 5 seconds after its start.
function TestFiveSecond:testAChannelCountsFromItsStart()
    self:Cast(0, TRANQUILITY, "Cast-Tranquility")
    AssertBar(self.own, 1, "the channel's start didn't start the bar")
    self:Cast(3, TRANQUILITY, "Cast-Tranquility")
    self:At(3)
    AssertBar(self.own, 0.4, "the same channel restarted the bar")
    self:At(5)
    lu.assertNil(Bar(self.own), "the bar outlasts 5 seconds after the channel started")
end

-- The cancel cue's AC2, S7 (docs/refinements/cancel-cue.md): a heal clicked on your
-- own frame and cancelled, interrupted or failed starts no bar, through the real
-- events; the same heal finished does.
function TestFiveSecond:testACancelledCastStartsNoBar()
    self.ns.db.layout.showCancelCue = true
    self.ns.charDB.bindings["1"] = { action = "spell", spellID = FLASH_HEAL, target = "unit", alsoTarget = false }
    self.ns.ClickCast.appliedBindings = CopyTable(self.ns.charDB.bindings)
    for index, ending in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        Support.SetTime(T0 + index * 10)
        Support.Click(self.own, "LeftButton")
        Support.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-" .. index, FLASH_HEAL)
        Support.FireEvent(ending, "player", "Cast-" .. index, FLASH_HEAL)
        self:At(index * 10 + 0.1)
        lu.assertNil(Bar(self.own), ending .. " started the bar")
    end
    Support.SetTime(T0 + 40)
    Support.Click(self.own, "LeftButton")
    Support.FireEvent("UNIT_SPELLCAST_START", "player", "Cast-9", FLASH_HEAL)
    Support.FireEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9", FLASH_HEAL)
    Support.FireEvent("UNIT_SPELLCAST_STOP", "player", "Cast-9", FLASH_HEAL)
    self:At(40.1)
    AssertBar(self.own, 0.98, "the finished heal didn't start the bar")
end

-- AC2, S9: a new spell with 2 seconds left fills the bar again for a full 5 seconds.
function TestFiveSecond:testANewManaSpellFillsTheBarAgain()
    self:Cast(0, FLASH_HEAL)
    self:Cast(3, RENEW)
    AssertBar(self.own, 1, "the new cast didn't fill the bar again")
    self:At(7.9)
    AssertBar(self.own, 0.02, "the bar ended on the first cast's clock")
    self:At(8)
    lu.assertNil(Bar(self.own), "the bar outlasts 5 seconds after the new cast")
end

-- AC2, S6: an action without a mana cost starts no bar and leaves a running one as
-- it is.
function TestFiveSecond:testNoManaSpentLeavesTheBarAsItIs()
    self:Cast(0, SHOOT)
    lu.assertNil(Bar(self.own), "a wand's Shoot started the bar")
    self:Cast(1, FLASH_HEAL)
    self:Cast(2, SHOOT)
    self:At(3.5)
    AssertBar(self.own, 0.5, "Shoot changed the running bar")
end

-- AC2, S7, S8: a free cast of a mana spell, and every cost NeoHeal can't read,
-- start the bar: a hidden spell, a hidden cost, a failing call, no such function.
function TestFiveSecond:testAFreeOrUnreadableCostStartsTheBar()
    local cases = {
        { "a free cast (Clearcasting)", function() Support.SetPowerCost(RENEW, Support.ManaCost({ cost = 0 })); return RENEW end },
        { "a hidden spell", function() return Support.Secret("spellID") end },
        { "a hidden cost", function() Support.SetPowerCost(RENEW, Support.Secret("cost")); return RENEW end },
        { "a hidden cost type", function()
            Support.SetPowerCost(RENEW, Support.ManaCost({ type = Support.Secret("type") })); return RENEW end },
        { "a failing cost call", function() Support.SetPowerCost(RENEW, Support.COST_ERROR); return RENEW end },
        { "no cost function", function() C_Spell.GetSpellPowerCost = nil; return RENEW end },
    }
    for index, case in ipairs(cases) do
        self:At(index * 10 - 1)   -- the bar before has ended
        lu.assertNil(Bar(self.own), "the bar before " .. case[1] .. " didn't end")
        local spellID = case[2]()
        self:Cast(index * 10, spellID)
        AssertBar(self.own, 1, case[1] .. " didn't start the bar")
    end
end

-- AC3, S22: another member's cast starts no bar anywhere and leaves yours as it is.
function TestFiveSecond:testOtherMembersCastsNeverStartIt()
    local party1 = self:Button("party1")
    self:Cast(0, FLASH_HEAL, nil, "party1")
    lu.assertNil(Bar(self.own), "another member's cast started your bar")
    lu.assertNil(Bar(party1), "another member's cast started their bar")
    self:Cast(1, FLASH_HEAL)
    self:Cast(2, FLASH_HEAL, nil, "party1")
    self:At(3.5)
    AssertBar(self.own, 0.5, "another member's cast restarted your bar")
    lu.assertNil(Bar(party1), "their frame shows a bar")
end

-- AC3, S18, S38: the events are registered for your own casts only, so a cast whose
-- unit the game hides is yours and starts the bar.
function TestFiveSecond:testACastWithAHiddenUnitIsYours()
    self.inCombat = true
    self:Cast(0, FLASH_HEAL, nil, Support.Secret("unit"))
    AssertBar(self.own, 1, "a cast with a hidden unit didn't start the bar")
end

-- AC3, S15, S17, S19, S20, S21, S23, S40: every frame that shows you carries the bar
-- with the same time left, your raid frame in the main tank group too; no other
-- frame does.
function TestFiveSecond:testOnlyFramesThatShowYouCarryTheBar()
    self.you.raid7, self.you.target, self.you.focus = true, true, false
    local yours = { self.own, self:Button("raid7"), self:Button("raid7"), self:Button("target") }
    local others = { self:Button("party1"), self:Button("raid2"), self:Button("focus"), self:Button("raidpet1"),
                     self:Button("partypet1") }
    self:Cast(0)
    self:At(1)
    for index, button in ipairs(yours) do
        AssertBar(button, 0.8, "frame " .. index .. " that shows you (" .. button.unit .. ")")
    end
    for _, button in ipairs(others) do
        lu.assertNil(Bar(button), button.unit .. " shows the bar")
    end
end

-- AC3, S18, S38: where the game hides which raid frame is you, its answer goes to
-- the bar's SetAlphaFromBoolean untouched; a client without that method keeps the
-- bar hidden.
function TestFiveSecond:testAHiddenAnswerGoesToTheGame()
    local answer = Support.Secret("is it you")
    self.hiddenYou.raid3 = answer
    self.inCombat = true
    local raid3 = self:Button("raid3")
    self:Cast(0)
    local bar = raid3.fiveSecond
    lu.assertIs(bar.alphaFromBoolean[#bar.alphaFromBoolean], answer, "the hidden answer didn't reach the bar")
    lu.assertTrue(bar.shown, "the bar is hidden, so the game's answer can't show it")
    lu.assertEquals(bar.value, 1, "the bar isn't full")

    local plain = self:Button("raid3")
    rawset(plain.fiveSecond, "SetAlphaFromBoolean", false)   -- false: the Recorder answers every other name
    self:At(1)
    lu.assertFalse(plain.fiveSecond.shown, "without SetAlphaFromBoolean a hidden answer shows the bar")
end

-- AC3, S18, S38: where the game hides who a raid frame is, it may hide that frame's
-- power type too; your own power type decides, so your raid frame still gets the
-- bar through SetAlphaFromBoolean. As a warrior, no frame gets it.
function TestFiveSecond:testAHiddenPowerTypeOnYourRaidFrameStillShowsTheBar()
    local answer = Support.Secret("is it you")
    self.hiddenYou.raid3 = answer
    self.power.raid3 = Support.Secret("raid3 power type")
    self.inCombat = true
    local raid3 = self:Button("raid3")
    self:Cast(0)
    self:At(1)
    local bar = raid3.fiveSecond
    lu.assertIs(bar.alphaFromBoolean[#bar.alphaFromBoolean], answer, "the hidden answer didn't reach the bar")
    lu.assertTrue(bar.shown, "the bar is hidden, so the game's answer can't show it")
    lu.assertAlmostEquals(bar.value, 0.8, 1e-9, "the bar's time left")

    self.power.player = 1   -- a warrior: your own strip shows rage
    local warriorRaid3 = self:Button("raid3")
    self:Cast(10, HEROIC_STRIKE)
    self:Cast(11, FLASH_HEAL)   -- even a cast that lists a mana cost
    self:At(12)
    lu.assertFalse(warriorRaid3.fiveSecond.shown, "a warrior's raid frame shows the bar")
end

-- AC4, S11, S14: anyone with a mana strip sees it, a mage too; a warrior never does.
function TestFiveSecond:testOnlySpendingYourManaCounts()
    Override("UnitClass", function() return "Mage", "MAGE" end)
    self:Cast(0, FLASH_HEAL)
    AssertBar(self.own, 1, "a mage")
    self:At(5)

    Override("UnitClass", function() return "Warrior", "WARRIOR" end)
    self.power.player = 1
    self:Cast(10, HEROIC_STRIKE)
    lu.assertNil(Bar(self.own), "a warrior's rage ability shows a bar")
    self:Cast(20, FLASH_HEAL)
    lu.assertNil(Bar(self.own), "a frame with a rage strip shows a bar")
    self.power.player = Support.Secret("power type")
    self:At(21)
    lu.assertNil(Bar(self.own), "a hidden power type shows a bar")
end

-- AC4, S12, S13, S37: a druid's shift costs mana but their strip shows energy: no
-- bar, and Claw or Maul don't restart the 5 seconds. Back in caster form 2 seconds
-- after the shift, the bar shows the 3 seconds left.
function TestFiveSecond:testADruidSeesTheTimeLeftBackInCasterForm()
    Override("UnitClass", function() return "Druid", "DRUID" end)
    self.power.player = 3
    self:Cast(0, CAT_FORM)
    lu.assertNil(Bar(self.own), "a bar on the energy strip")
    self:Cast(1, CLAW)
    self:Cast(1.5, MAUL)
    lu.assertNil(Bar(self.own), "a bar on the energy strip")
    self.power.player = 0
    self:At(2)
    AssertBar(self.own, 0.6, "back in caster form")
    self:At(5)
    lu.assertNil(Bar(self.own), "the shift's 5 seconds are over")
end

-- AC5, S26, S27, S39: off, no cast shows a bar; turned off during a countdown, also
-- in combat, the bar is gone at the next tick; on again, it waits for the next
-- spell.
function TestFiveSecond:testTheOptionTurnsTheBarOff()
    local layout = self.ns.db.layout
    layout.showFiveSecond = false
    self:Cast(0)
    self:At(0.1)
    lu.assertNil(Bar(self.own), "a bar with the option off")

    layout.showFiveSecond = true
    self:Cast(10)
    self.inCombat = true
    layout.showFiveSecond = false
    self:At(10.1)
    lu.assertNil(Bar(self.own), "turning it off in combat left the bar")
    layout.showFiveSecond = true
    self:At(11)
    lu.assertNil(Bar(self.own), "on again, the seconds that were left show")
    self:Cast(12)
    AssertBar(self.own, 1, "on again, the next spell starts no bar")
end

-- AC5, S25, S28, and the placement fix of 2026-11-16: the bar sits on the strip
-- (its child), 2 pixels on its bottom edge and as wide, so the 4 pixels of mana
-- above it stay visible; hidden on a new frame; hiding the strip hides it.
function TestFiveSecond:testTheBarSitsOnTheStrip()
    local button = Support.RealButton(self.ns)
    local bar = button.fiveSecond
    lu.assertNotNil(bar, "no five-second bar")
    lu.assertEquals(bar.kind, "StatusBar")
    lu.assertIs(bar.parent, button.power, "the bar isn't the strip's child")
    lu.assertEquals(bar.height, 2)
    lu.assertEquals({ bar.min, bar.max }, { 0, 1 })
    lu.assertFalse(bar.shown, "the bar shows on a new frame")
    local anchors = {}
    for _, point in ipairs(bar.points) do
        lu.assertIs(point[2], button.power, "anchored to something else than the strip")
        anchors[point[1]] = { point[3], point[4], point[5] }
    end
    lu.assertEquals(anchors, { BOTTOMLEFT = { "BOTTOMLEFT", 0, 0 }, BOTTOMRIGHT = { "BOTTOMRIGHT", 0, 0 } },
        "the bar isn't on the strip's bottom edge")
end

-- The placement fix of 2026-11-16: the resource strip is 6 pixels high on every
-- frame, so the 2-pixel bar on it leaves 4 pixels of mana visible.
function TestFiveSecond:testTheStripIsSixPixels()
    lu.assertEquals(Support.RealButton(self.ns).power.height, 6, "the resource strip isn't 6 pixels high")
    lu.assertEquals(self.own.power.height, 6, "your own frame's strip isn't 6 pixels high")
end

-- The placement fix of 2026-11-16: the health bar is what the strip leaves, so the
-- room below the name the raid debuffs get counts the 6-pixel strip and its
-- 1-pixel gap. A 36-pixel frame in the flat style (1 pixel inset on each side):
-- 36 - 2 - 6 - 1 = 27 of health, less the 14 above the debuffs and 1 below them
-- leaves 12, smaller than 1.5 times the HoT icon; without a strip, 19.
function TestFiveSecond:testTheDebuffRoomCountsTheSixPixelStrip()
    self.ns.Layout = { GetSize = function() return { buttonHeight = 36 } end }
    self.ns.Hots.GetIconSize = function() return 20 end
    self.ns.db.layout.frameStyle = "forever"
    lu.assertEquals(self.UnitButton.GetRaidDebuffSize(), 12, "the debuff room doesn't count a 6-pixel strip")
    self.ns.db.layout.powerBar = "none"
    lu.assertEquals(self.UnitButton.GetRaidDebuffSize(), 19, "without a strip the health bar has the room")
end

-- The colour fix of 2026-11-16: a mana strip is RGB 0, 115, 255 (0, 0.45, 1.0),
-- lighter than Blizzard's mana blue, which is too dark on a thin strip; a rage
-- strip keeps Blizzard's colour. The game's colours are faked as pure blue and red.
function TestFiveSecond:testAManaStripIsTheLighterBlue()
    Override("PowerBarColor", { MANA = { r = 0, g = 0, b = 1 }, RAGE = { r = 1, g = 0, b = 0 } })
    lu.assertEquals(self:Button("party1").power.barColor, { 0, 0.45, 1.0 }, "a mana strip isn't the lighter blue")
    self.power.party2 = 1
    lu.assertEquals(self:Button("party2").power.barColor, { 1, 0, 0 }, "a rage strip lost Blizzard's colour")
end

-- AC1: the bar takes the frame style's texture, like the other bars, and a colour
-- of its own.
function TestFiveSecond:testTheBarTakesTheStyle()
    local bar = self.own.fiveSecond
    lu.assertNotNil(self.own.health.texture, "the style gave the health bar no texture")
    lu.assertEquals(bar.texture, self.own.health.texture, "the bar has another texture than the style's")
    lu.assertNotNil(bar.barColor, "the bar has no colour of its own")
    lu.assertNotEquals(bar.barColor, self.own.power.barColor, "the bar has the strip's colour")
end

-- AC6, S30: the raid moves you to another frame during a countdown: the frame that
-- now shows you carries the bar with the time left, the one before none.
function TestFiveSecond:testTheBarFollowsAGroupChange()
    self.you.raid1 = true
    local before, after = self:Button("raid1"), self:Button("raid2")
    self:Cast(0)
    self:At(1)
    AssertBar(before, 0.8, "your raid frame before the change")
    Support.SetTime(T0 + 2)
    self.you.raid1, self.you.raid2 = false, true
    self.UnitButton:UpdateAllButtons()   -- what a roster update runs
    AssertBar(after, 0.6, "the frame that now shows you")
    lu.assertNil(Bar(before), "the frame that no longer shows you keeps the bar")
end

-- AC7, S32, S33, S34: dying ends the bar and a resurrection doesn't bring it back;
-- after a loading screen it shows the time left, never longer; a reload starts with
-- none.
function TestFiveSecond:testDeathAndReloadEndTheBar()
    self:Cast(0)
    self.dead = true
    self:At(1)
    lu.assertNil(Bar(self.own), "the bar shows while you are dead")
    self.dead = false
    self:At(2)
    lu.assertNil(Bar(self.own), "a resurrection brought the bar back")

    self:Cast(10)
    self:At(13)   -- the first tick after a loading screen
    AssertBar(self.own, 0.4, "after a loading screen")
    self:At(16)
    lu.assertNil(Bar(self.own), "a loading screen made the bar outlast the rule")

    self:Cast(20)
    self:setUp()   -- a reload: the addon loads again, mid-countdown
    Support.SetTime(T0 + 21)
    self.UnitButton.UpdateFiveSecond()
    lu.assertNil(Bar(self.own), "a reload shows the seconds that were left")
end

-- The ticker runs the update every 0.1 s; with no countdown it touches no bar.
function TestFiveSecond:testTheTickerRunsTheUpdate()
    local found
    for _, ticker in ipairs(Support.tickers) do
        if ticker.func == self.UnitButton.UpdateFiveSecond then found = ticker end
    end
    lu.assertNotNil(found, "no ticker runs UpdateFiveSecond")
    lu.assertEquals(found.interval, 0.1)
    local bar = self.own.fiveSecond
    bar.calls = {}
    self:At(1)
    lu.assertEquals(bar.calls, {}, "a tick without a countdown touched the bar")
end

-- AC3, AC6, S19, S20, S40: one countdown for every frame that shows you, kept in
-- UnitButton.lua: no global holds it, where another addon could change it or a
-- reload (S33) would keep it.
function TestFiveSecond:testTheCountdownIsTheModulesOwn()
    self:Cast(0, FLASH_HEAL, "Cast-Own")
    lu.assertNil(rawget(_G, "castAt"), "the countdown is a global")
    lu.assertNil(rawget(_G, "lastCastGUID"), "the last castGUID is a global")
end

-- AC1, AC2: Core passes your cast events on, both registered; nothing before login.
TestFiveSecondCore = {}

function TestFiveSecondCore:tearDown()
    NeoHealDB, NeoHealCharDB = nil, nil
    Restore()
end

function TestFiveSecondCore:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua" })
    self.casts = {}
    local noop = function() end
    ns.UnitButton = { OnPlayerCast = function(...) table.insert(self.casts, { ... }) end,
                      OnCastStart = noop, OnCastEnd = noop, ClearCancelCue = noop }   -- the cancel cue's handlers
    self.ns = ns
end

-- AC3, S22: both events are registered for your own casts only: the client marks
-- their unit argument as one it may hide (not checked in game), so the event
-- itself must say whose cast it is. The cancel cue (docs/refinements/cancel-cue.md,
-- AC2, S2, S7) registers a cast's start, stop, failure and interruption the same
-- way; none of them reaches the bar, as such a cast spent no mana.
function TestFiveSecondCore:testBothCastEventsAreRegistered()
    for _, event in ipairs({ "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_START",
                             "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED" }) do
        local units
        for _, frame in ipairs(Support.frames) do
            lu.assertNil(frame.stub.events[event], event .. " is registered for every unit")
            units = units or frame.stub.unitEvents[event]
        end
        lu.assertEquals(units, { "player" }, event .. " isn't registered for your own casts only")
    end
    -- S1, S5: a cast that starts, stops, fails or is interrupted spent no mana.
    self.ns.db = { layout = {} }
    for _, event in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
                             "UNIT_SPELLCAST_INTERRUPTED" }) do
        lu.assertTrue(Support.FireEvent(event, "player", "Cast-1", FLASH_HEAL), event .. " reaches no handler")
    end
    lu.assertEquals(self.casts, {}, "a cast that spent no mana reached the five-second bar")
end

-- A client that doesn't know the events still loads.
function TestFiveSecondCore:testUnknownEventsAreSkipped()
    Support.Load({ "Locales/enUS.lua" })
    C_EventUtils.IsEventValid = function(event) return not event:match("^UNIT_SPELLCAST") end
    lu.assertTrue(pcall(Support.LoadInto, {}, { "Core.lua" }), "Core.lua doesn't load without the cast events")
end

function TestFiveSecondCore:testTheEventsReachTheBar()
    self.ns:UNIT_SPELLCAST_SUCCEEDED("player", "Cast-1", FLASH_HEAL)
    self.ns:UNIT_SPELLCAST_CHANNEL_START("player", "Cast-2", MIND_FLAY)
    lu.assertEquals(self.casts, {})   -- before login
    self.ns.db = { layout = {} }
    self.ns:UNIT_SPELLCAST_SUCCEEDED("player", "Cast-1", FLASH_HEAL)
    self.ns:UNIT_SPELLCAST_CHANNEL_START("player", "Cast-2", MIND_FLAY)
    lu.assertEquals(self.casts, { { "player", "Cast-1", FLASH_HEAL }, { "player", "Cast-2", MIND_FLAY } })
end

-- AC5: on by default.
function TestFiveSecondCore:testOnByDefault()
    local noop = function() end
    local ns = self.ns
    ns.Spells, ns.Dispel, ns.MissingBuffs = { Scan = noop }, { UpdateKnownDispels = noop }, { UpdateKnownBuffs = noop }
    ns.ClickCast, ns.Layout = { Initialize = noop, Apply = noop }, { Create = noop }
    ns.Options, ns.Print = { RegisterSettingsCategory = noop }, noop
    NeoHealDB, NeoHealCharDB = nil, nil
    ns:PLAYER_LOGIN()
    lu.assertEquals(NeoHealDB.layout.showFiveSecond, true, "Show five-second rule isn't on by default")
end

-- The cancel cue (docs/refinements/cancel-cue.md, open point 3): on by default, as
-- the five-second bar.
function TestFiveSecondCore:testOnByDefaultForTheCue()
    local noop = function() end
    local ns = self.ns
    ns.Spells, ns.Dispel, ns.MissingBuffs = { Scan = noop }, { UpdateKnownDispels = noop }, { UpdateKnownBuffs = noop }
    ns.ClickCast, ns.Layout = { Initialize = noop, Apply = noop }, { Create = noop }
    ns.Options, ns.Print = { RegisterSettingsCategory = noop }, noop
    NeoHealDB, NeoHealCharDB = nil, nil
    ns:PLAYER_LOGIN()
    lu.assertEquals(NeoHealDB.layout.showCancelCue, true, "Show cancel cue isn't on by default")
end

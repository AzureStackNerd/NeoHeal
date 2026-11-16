-- Test mode (Preview.lua): the fake raid a healer looks at while setting up the
-- layout. A preview that differs from the real frames misleads that setup, so
-- these tests hold it to what the real headers do (Layout.lua) and to its own
-- comments: groups of five as columns, the sort orders of Layout.SORT_ORDERS,
-- main tanks and pets, and what each fake member draws. Low mana and the fake
-- target and focus member have their own tests (spec/lowmana_test.lua,
-- spec/targetfocus_test.lua). The real UnitButton.lua draws on fake frames that
-- keep what was done to them.
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

-- A frame, texture or font string that keeps what was done to it: points,
-- whether it shows, text, value, bar and vertex colours, texture, atlas and
-- raid marker. Any other method (a PascalCase name) returns another such object.
local function Recorder(kind)
    local frame = { kind = kind, points = {}, shown = true }
    function frame:SetPoint(...) table.insert(self.points, { ... }) end
    function frame:ClearAllPoints() self.points = {} end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(shown) self.shown = shown and true or false end
    function frame:IsShown() return self.shown end
    function frame:SetText(text) self.text = text end
    function frame:SetValue(value) self.value = value end
    function frame:SetStatusBarColor(r, g, b) self.barColor = { r, g, b } end
    function frame:SetVertexColor(r, g, b) self.vertexColor = { r, g, b } end
    function frame:SetTexture(file) self.texture = file end
    function frame:SetAtlas(atlas) self.atlas = atlas end
    function frame:GetFrameLevel() return 1 end
    function frame:GetWidth() return 10 end
    function frame:CreateFontString() return Recorder("FontString") end
    function frame:CreateTexture() return Recorder("Texture") end
    return setmetatable(frame, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return function() return Recorder() end end
    end })
end

local WIDTH, HEIGHT, SPACING = 80, 36, 2

-- One colour per class, so a frame's colour tells which class it was given.
local CLASS_COLORS = {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, PRIEST = { r = 1, g = 1, b = 1 },
    DRUID = { r = 1, g = 0.49, b = 0.04 }, PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    SHAMAN = { r = 0, g = 0.44, b = 0.87 }, ROGUE = { r = 1, g = 0.96, b = 0.41 },
    MAGE = { r = 0.41, g = 0.8, b = 0.94 }, WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
}

-- The fake raid's first members, by member number: classes rotate warrior,
-- priest, druid, paladin, shaman, rogue, mage, warlock, hunter (Preview.lua).
local GROUP_1 = { "Grimthorn", "Seraphine", "Thornwood", "Aurelion", "Stormhoof" }    -- members 1-5
local GROUP_2 = { "Shadeveil", "Frostwyn", "Morvoren", "Talonfeather", "Brakka" }     -- members 6-10
local PETS = { "Shadowmaw", "Fang", "Rattlecrest", "Zhaazar", "Grothak", "Xanrith" }

TestPreview = {}

function TestPreview:tearDown() Restore() end

function TestPreview:setUp()
    local ns = Support.Load({ "Locales/enUS.lua" })
    Support.LoadInto(ns, { "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua", "Layout.lua", "Preview.lua" })
    Override("unpack", unpack or table.unpack)
    Override("CreateFrame", function(kind) return Recorder(kind) end)
    Override("RAID_CLASS_COLORS", CLASS_COLORS)
    Override("PowerBarColor", setmetatable({}, { __index = function() return { r = 0, g = 0, b = 1 } end }))
    Override("SetRaidTargetIconTexture", function(texture, index) texture.marker = index end)
    local noop = function() end
    ns.Hots = { Attach = noop, ShowPreview = noop, GetIconSize = function() return 12 end }
    ns.MissingBuffs = { Attach = noop, ShowPreview = noop }
    ns.Dispel = { known = {}, COLORS = { Poison = { 0, 0.6, 0 }, Magic = { 0.2, 0.6, 1 },
                                         Curse = { 0.6, 0, 1 }, Disease = { 0.6, 0.4, 0 } } }
    ns.AuraContainer = { ApplyTimerSetting = noop }
    -- The real sort orders, on a container of our own.
    ns.Layout.container = Recorder("Frame")
    ns.Layout.GetSize = function() return { buttonWidth = WIDTH, buttonHeight = HEIGHT, spacing = SPACING } end
    ns.db = { layout = { healthColor = "class", healthText = "none", sortOrder = "index", powerBar = "all",
                         mainTankPosition = "none", showPets = false, showRaidDebuffs = false,
                         showHealPrediction = false, showLowMana = false, showAggro = false } }
    self.ns = ns
    self.Preview = ns.Preview
end

-- The shown fake frames in frame order: { name, column, row, frame }.
function TestPreview:Shown()
    local shown = {}
    for _, frame in ipairs(self.Preview.frames) do
        if frame.shown then
            local point = frame.points[#frame.points]
            table.insert(shown, { name = frame.nameText.text, column = point[2] / (WIDTH + SPACING),
                                  row = -point[3] / (HEIGHT + SPACING), frame = frame })
        end
    end
    return shown
end

-- The names in one screen column, top to bottom.
function TestPreview:Column(column)
    local names = {}
    for _, entry in ipairs(self:Shown()) do
        if entry.column == column then names[entry.row + 1] = entry.name end
    end
    return names
end

-- The shown frame drawing `name` (the first one, for a main tank shown twice).
function TestPreview:Frame(name)
    for _, entry in ipairs(self:Shown()) do
        if entry.name == name then return entry.frame end
    end
    lu.fail("no shown fake frame " .. name)
end

local function Labels(order)
    local labels = {}
    for _, group in ipairs(order) do table.insert(labels, group.label .. ":" .. group.count) end
    return labels
end

---------------------------------------------------------------------------
-- Layout: groups, columns, main tanks and pets
---------------------------------------------------------------------------

-- Ten members are two groups of five, each its own column, and so a raid.
function TestPreview:testTenMembersAreTwoColumnsOfFive()
    local order, isRaid = self.Preview:Show(10)
    lu.assertEquals(Labels(order), { "Group 1:5", "Group 2:5" })
    lu.assertTrue(isRaid, "two groups don't count as a raid")
    lu.assertEquals(self:Column(0), GROUP_1)
    lu.assertEquals(self:Column(1), GROUP_2)
end

-- Five members are one group: a party, which shows no main tank group even with
-- one chosen (like the real header, main tanks only show in a raid).
function TestPreview:testFiveMembersAreAPartyWithoutMainTanks()
    self.ns.db.layout.mainTankPosition = "first"
    local order, isRaid = self.Preview:Show(5)
    lu.assertEquals(Labels(order), { "Group 1:5" })
    lu.assertFalse(isRaid, "one group counts as a raid")
    lu.assertEquals(#self:Shown(), 5)
end

-- "Main tank group: First": the first two warriors (members 1 and 10) in a
-- column before the groups, which move one column right; they stay in their own
-- groups too.
function TestPreview:testMainTanksFirstComeBeforeTheGroups()
    self.ns.db.layout.mainTankPosition = "first"
    local order = self.Preview:Show(10)
    lu.assertEquals(Labels(order), { "Main tanks:2", "Group 1:5", "Group 2:5" })
    lu.assertEquals(self:Column(0), { "Grimthorn", "Brakka" })
    lu.assertEquals(self:Column(1), GROUP_1)
    lu.assertEquals(self:Column(2), GROUP_2)
end

-- "Main tank group: Last" puts them after the pets too; the six pets wrap into
-- a second column, so the main tanks start two columns after the last group.
function TestPreview:testMainTanksLastComeAfterThePets()
    local layout = self.ns.db.layout
    layout.mainTankPosition, layout.showPets = "last", true
    local order = self.Preview:Show(40)
    local labels = Labels(order)
    lu.assertEquals(#labels, 10)
    lu.assertEquals(labels[8], "Group 8:5")
    lu.assertEquals(labels[9], "Pets:6")
    lu.assertEquals(labels[10], "Main tanks:2")
    lu.assertEquals(self:Column(8), { "Shadowmaw", "Fang", "Rattlecrest", "Zhaazar", "Grothak" })
    lu.assertEquals(self:Column(9), { "Xanrith" })
    lu.assertEquals(self:Column(10), { "Grimthorn", "Brakka" })
end

-- "Main tank group: None" shows no main tank group in a raid either.
function TestPreview:testNoMainTankGroupWithNone()
    local order = self.Preview:Show(40)
    for _, label in ipairs(Labels(order)) do
        lu.assertNotEquals(label:match("^Main tanks"), "Main tanks", "a main tank group with None")
    end
    lu.assertEquals(#order, 8)
end

-- Pets show only with "Show pets" on and only at the 40 player test size.
function TestPreview:testPetsOnlyWithTheOptionAndFortyPlayers()
    local order = self.Preview:Show(40)
    lu.assertEquals(order[#order].label, "Group 8", "pets with Show pets off")
    self.ns.db.layout.showPets = true
    order = self.Preview:Show(25)
    lu.assertEquals(order[#order].label, "Group 5", "pets at 25 players")
    order = self.Preview:Show(40)
    lu.assertEquals(Labels(order)[9], "Pets:6")
end

-- Frames a smaller test size no longer uses are hidden; Hide hides them all.
function TestPreview:testUnusedFramesHideAndHideHidesAll()
    self.Preview:Show(40)
    self.Preview:Show(10)
    lu.assertEquals(#self:Shown(), 10, "frames from the 40 player preview still show")
    self.Preview:Hide()
    lu.assertEquals(#self:Shown(), 0, "Hide leaves fake frames showing")
end

---------------------------------------------------------------------------
-- Sorting: every group, main tanks included, like the real headers
---------------------------------------------------------------------------

-- "By name" sorts every group, and the main tank group, by name.
function TestPreview:testByNameSortsEveryGroupAndTheMainTanks()
    local layout = self.ns.db.layout
    layout.sortOrder, layout.mainTankPosition = "name", "first"
    self.Preview:Show(10)
    lu.assertEquals(self:Column(0), { "Brakka", "Grimthorn" })
    lu.assertEquals(self:Column(1), { "Aurelion", "Grimthorn", "Seraphine", "Stormhoof", "Thornwood" })
    lu.assertEquals(self:Column(2), { "Brakka", "Frostwyn", "Morvoren", "Shadeveil", "Talonfeather" })
end

-- "Tanks, healers, damage": the warrior (tank) first, then the healers (priest,
-- druid, paladin, shaman), then damage, each in raid order. Group 4 (members
-- 16-20: mage, warlock, hunter, warrior, priest) has all three.
function TestPreview:testByRolePutsTanksThenHealersThenDamage()
    self.ns.db.layout.sortOrder = "role"
    self.Preview:Show(20)
    lu.assertEquals(self:Column(1), { "Brakka", "Shadeveil", "Frostwyn", "Morvoren", "Talonfeather" })
    lu.assertEquals(self:Column(3), { "Thuldrin", "Lumara", "Arcanis", "Hexxus", "Wolfsbane" })
end

-- "By class": classes in Layout's grouping order (warrior, paladin, priest,
-- druid, shaman, ..., rogue, hunter, mage, warlock), by name within a class: the
-- two warrior main tanks come by name.
function TestPreview:testByClassFollowsTheClassOrderThenName()
    local layout = self.ns.db.layout
    layout.sortOrder, layout.mainTankPosition = "class", "first"
    self.Preview:Show(10)
    lu.assertEquals(self:Column(0), { "Brakka", "Grimthorn" })
    lu.assertEquals(self:Column(1), { "Grimthorn", "Aurelion", "Seraphine", "Thornwood", "Stormhoof" })
    lu.assertEquals(self:Column(2), { "Brakka", "Shadeveil", "Talonfeather", "Frostwyn", "Morvoren" })
end

---------------------------------------------------------------------------
-- Decorations: what each fake member draws
---------------------------------------------------------------------------

-- "Health bar color: Class": each member in its class colour, pets green.
function TestPreview:testClassColorsAndGreenPets()
    self.ns.db.layout.showPets = true
    self.Preview:Show(40)
    local brakka = CLASS_COLORS.WARRIOR
    lu.assertEquals(self:Frame("Brakka").health.barColor, { brakka.r, brakka.g, brakka.b })
    local seraphine = CLASS_COLORS.PRIEST
    lu.assertEquals(self:Frame("Seraphine").health.barColor, { seraphine.r, seraphine.g, seraphine.b })
    lu.assertEquals(self:Frame("Fang").health.barColor, { 0.2, 0.8, 0.2 })
end

-- "Health bar color: Health": the colour of the health each bar shows, pets too.
function TestPreview:testHealthColorFollowsTheHealthShown()
    local layout = self.ns.db.layout
    layout.healthColor, layout.showPets = "health", true
    self.Preview:Show(40)
    for _, name in ipairs({ "Grimthorn", "Morvoren", "Fang" }) do
        local health = self:Frame(name).health
        lu.assertEquals(health.barColor, { self.ns.UnitButton.HealthFractionColor(health.value) },
                        name .. "'s bar isn't coloured by its health")
    end
end

-- Member 1 leads, tanks and wears a skull: every top icon at once. Member 2
-- assists; member 4 wears a star; member 3 has no marker and doesn't lead.
function TestPreview:testStatusIcons()
    self.Preview:Show(10)
    local grimthorn = self:Frame("Grimthorn")
    lu.assertTrue(grimthorn.raidIcon.shown, "member 1 shows no raid marker")
    lu.assertEquals(grimthorn.raidIcon.marker, 8)
    lu.assertTrue(grimthorn.roleIcon.shown, "the warrior shows no tank icon")
    lu.assertEquals(grimthorn.roleIcon.atlas, "roleicon-tiny-tank")
    local seraphine = self:Frame("Seraphine")
    lu.assertTrue(seraphine.roleIcon.shown, "the priest shows no healer icon")
    lu.assertEquals(seraphine.roleIcon.atlas, "roleicon-tiny-healer")
    lu.assertTrue(grimthorn.leaderIcon.shown, "member 1 shows no leader icon")
    lu.assertEquals(grimthorn.leaderIcon.texture, "Interface\\GroupFrame\\UI-Group-LeaderIcon")
    lu.assertEquals(self:Frame("Seraphine").leaderIcon.texture, "Interface\\GroupFrame\\UI-Group-AssistantIcon")
    lu.assertTrue(self:Frame("Seraphine").leaderIcon.shown, "member 2 shows no assist icon")
    lu.assertEquals(self:Frame("Aurelion").raidIcon.marker, 1)
    local thornwood = self:Frame("Thornwood")
    lu.assertFalse(thornwood.raidIcon.shown, "member 3 shows a raid marker")
    lu.assertFalse(thornwood.leaderIcon.shown, "member 3 shows a leader icon")
    lu.assertFalse(self:Frame("Shadeveil").roleIcon.shown, "a rogue shows a role icon")
end

-- The fake debuffs that are shown on one holder: their count, or 0 when hidden.
local function DebuffCount(frame)
    local holder = frame.fakeDebuffs
    if not holder or not holder.shown then return 0 end
    local count = 0
    for _, icon in ipairs(holder.icons) do
        if icon.shown then count = count + 1 end
    end
    return count
end

-- "Show raid debuffs": members 4 and 9 (of every eleven) carry one and two boss
-- debuffs, no one else; off, no one does.
function TestPreview:testFakeDebuffsFollowTheOption()
    self.ns.db.layout.showRaidDebuffs = true
    self.Preview:Show(10)
    lu.assertEquals(DebuffCount(self:Frame("Aurelion")), 1, "member 4 doesn't carry one debuff")
    lu.assertEquals(DebuffCount(self:Frame("Talonfeather")), 2, "member 9 doesn't carry two debuffs")
    lu.assertEquals(DebuffCount(self:Frame("Grimthorn")), 0, "member 1 carries a debuff")
    self.ns.db.layout.showRaidDebuffs = false
    self.Preview:Show(10)
    for _, entry in ipairs(self:Shown()) do
        lu.assertEquals(DebuffCount(entry.frame), 0, entry.name .. " carries a debuff with raid debuffs off")
    end
end

-- The dispel strip on member 3 (of every six), in the colour of the first type
-- you can remove in the order poison, magic, curse, disease; none without a cure.
function TestPreview:testDispelStripInTheColourOfACurableType()
    self.ns.Dispel.known = { Disease = true, Magic = true }
    self.Preview:Show(10)
    local strip = self:Frame("Thornwood").dispelStrip
    lu.assertTrue(strip.shown, "member 3 shows no dispel strip")
    lu.assertEquals(strip.texture.vertexColor, { 0.2, 0.6, 1 }, "the strip isn't in the magic colour")
    lu.assertFalse(self:Frame("Grimthorn").dispelStrip.shown, "member 1 shows a dispel strip")
    self.ns.Dispel.known = {}
    self.Preview:Show(10)
    lu.assertFalse(self:Frame("Thornwood").dispelStrip.shown, "a dispel strip for a class without a cure")
end

-- "Show left-click heal prediction": member 5 shows it, as if under the mouse;
-- no one else, and no one with the option off.
function TestPreview:testHealPredictionOnMemberFiveOnly()
    local layout = self.ns.db.layout
    layout.showHealPrediction, layout.showPets = true, true
    self.Preview:Show(40)
    for _, entry in ipairs(self:Shown()) do
        local prediction, range = entry.frame.prediction, entry.frame.predictionRange
        if entry.name == "Stormhoof" then
            lu.assertTrue(prediction.shown and prediction.value > 0, "member 5 shows no heal prediction")
            lu.assertTrue(range.shown and range.value > 0, "member 5 shows no heal prediction range")
        else
            lu.assertFalse(prediction.shown, entry.name .. " shows a heal prediction")
            lu.assertFalse(range.shown, entry.name .. " shows a heal prediction range")
        end
    end
    layout.showHealPrediction = false
    self.Preview:Show(40)
    lu.assertFalse(self:Frame("Stormhoof").prediction.shown, "a heal prediction with the option off")
    lu.assertFalse(self:Frame("Stormhoof").predictionRange.shown, "a heal prediction range with the option off")
end

-- Pets: their own names, and none of a member's extras even with every option
-- on, also on frames a member drew before (test mode reuses its frames).
function TestPreview:testPetsDrawNoMemberExtras()
    local layout = self.ns.db.layout
    layout.showRaidDebuffs, layout.showHealPrediction, layout.mainTankPosition = true, true, "first"
    self.ns.Dispel.known = { Magic = true }
    self.Preview:Show(40)   -- with the main tanks first, the pets' frames draw members now
    layout.showPets, layout.mainTankPosition = true, "none"
    for _, frame in ipairs(self.Preview.frames) do
        frame.raidIcon:Show(); frame.roleIcon:Show(); frame.leaderIcon:Show(); frame.dispelStrip:Show()
        frame.absorb:Show()
    end
    self.Preview:Show(40)
    lu.assertEquals(self:Column(8), { "Shadowmaw", "Fang", "Rattlecrest", "Zhaazar", "Grothak" })
    lu.assertEquals(self:Column(9), { "Xanrith" })
    for _, name in ipairs(PETS) do
        local frame = self:Frame(name)
        lu.assertFalse(frame.raidIcon.shown or frame.roleIcon.shown or frame.leaderIcon.shown,
                       "the pet " .. name .. " shows a top icon")
        lu.assertEquals(DebuffCount(frame), 0, "the pet " .. name .. " carries a debuff")
        lu.assertFalse(frame.dispelStrip.shown, "the pet " .. name .. " shows a dispel strip")
        lu.assertFalse(frame.prediction.shown, "the pet " .. name .. " shows a heal prediction")
        lu.assertFalse(frame.absorb.shown, "the pet " .. name .. " shows a shield")
    end
end

-- AC8, S35, S36: with the option on, one fake healer (member 2, the priest who
-- also stands in for the target and focus frames) shows the five-second bar part
-- drained; no other member and no pet does, also on frames reused from before.
-- With the option off, no fake frame shows it.
function TestPreview:testFiveSecondBarOnOneFakeHealer()
    local layout = self.ns.db.layout
    layout.showFiveSecond, layout.showPets, layout.mainTankPosition = true, true, "first"
    self.Preview:Show(40)   -- with the main tanks first, the pets' frames draw members now
    layout.mainTankPosition = "none"
    for _, frame in ipairs(self.Preview.frames) do frame.fiveSecond:Show() end
    self.Preview:Show(40)
    for _, entry in ipairs(self:Shown()) do
        local bar = entry.frame.fiveSecond
        if entry.name == "Seraphine" then
            lu.assertTrue(bar.shown, "the fake healer shows no five-second bar")
            lu.assertTrue(bar.value > 0 and bar.value < 1, "the fake healer's bar isn't part drained")
        else
            lu.assertFalse(bar.shown, entry.name .. " shows a five-second bar")
        end
    end
    layout.showFiveSecond = false
    self.Preview:Show(40)
    for _, entry in ipairs(self:Shown()) do
        lu.assertFalse(entry.frame.fiveSecond.shown, entry.name .. " shows a five-second bar with the option off")
    end
end

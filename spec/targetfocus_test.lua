-- The target and focus frames (issue #3; the stories' acceptance criteria are
-- quoted as AC1..AC5): TargetFocusFrames.lua on fake frames, and what the other
-- files add for them: the reload on a target or focus change and the missing
-- target border (UnitButton.lua), the defaults and events (Core.lua), creating
-- and placing them (Layout.lua), the two checkboxes (Options.lua) and the fake
-- member in test mode (Preview.lua).
local lu = require("luaunit")
local Support = require("support")
local unpack = unpack or table.unpack

-- Globals these tests set are put back afterwards (LuaUnit runs the classes in
-- name order, so later files' tests would see them): Override sets one and
-- remembers the old value, Restore puts them all back.
local overridden = {}

local function Override(name, value)
    if overridden[name] == nil then overridden[name] = { _G[name] } end
    _G[name] = value
end

local function Restore()
    for name, old in pairs(overridden) do _G[name] = old[1] end
    overridden = {}
end

-- Any field is another such object, and calling it gives one too: stands in for
-- the parts of the game a test doesn't look at. Only string keys, so LuaUnit can
-- still print one in a failure message.
local function Universal()
    return setmetatable({}, {
        __index = function(self, key)
            if type(key) ~= "string" then return nil end
            local value = Universal()
            rawset(self, key, value)
            return value
        end,
        __call = function() return Universal() end,
        __tostring = function() return "Universal" end,
    })
end

-- A frame that keeps what was done to it: its attributes, size, points (each
-- SetPoint's arguments), parent and whether it shows. Any other method (a
-- PascalCase name) does nothing and returns a Universal.
local function FakeFrame(kind, name, parent, template)
    local frame = { kind = kind, name = name, parent = parent, template = template,
                    attributes = {}, points = {}, shown = true, scale = 1 }
    function frame:SetAttribute(key, value) self.attributes[key] = value end
    function frame:GetAttribute(key) return self.attributes[key] end
    function frame:GetName() return self.name end
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:SetHeight(height) self.height = height end
    function frame:GetHeight() return self.height end
    function frame:ClearAllPoints() self.points = {} end
    function frame:SetPoint(...) table.insert(self.points, { ... }) end
    function frame:SetParent(newParent) self.parent = newParent end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(shown) self.shown = shown and true or false end
    function frame:IsShown() return self.shown end
    function frame:GetScale() return self.scale end
    function frame:SetScale(scale) self.scale = scale end
    function frame:GetChildren() end
    return setmetatable(frame, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return function() return Universal() end end
    end })
end

-- The state driver the game would run for a frame: frame.drivers[state] = condition.
local function InstallStateDrivers()
    Override("RegisterStateDriver", function(frame, state, condition)
        frame.drivers = frame.drivers or {}
        frame.drivers[state] = condition
    end)
    Override("UnregisterStateDriver", function(frame, state)
        frame.drivers = frame.drivers or {}
        frame.drivers[state] = nil
    end)
end

local function Driver(frame)
    return (frame.drivers or {}).visibility
end

---------------------------------------------------------------------------
-- TargetFocusFrames.lua
---------------------------------------------------------------------------
TestTargetFocusFrames = {}

function TestTargetFocusFrames:tearDown() Restore() end

function TestTargetFocusFrames:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "TargetFocusFrames.lua" })
    Override("CreateFrame", FakeFrame)
    InstallStateDrivers()
    self.size = { buttonWidth = 80, buttonHeight = 36, spacing = 2 }
    self.container = FakeFrame("Frame", "NeoHealFrame")
    local titleBar = FakeFrame("Frame", nil, self.container)
    titleBar:SetHeight(16)
    ns.Layout = {
        container = self.container, titleBar = titleBar,
        GetSize = function() return self.size end,
        CreateTitleFrame = function()
            local label = FakeFrame("Frame", nil, self.container)
            label.text = { SetText = function(text, value) text.value = value end }
            return label
        end,
    }
    self.initialized = {}   -- [button] = its unit when UnitButton.Init ran
    ns.UnitButton = {
        Init = function(button) self.initialized[button] = button:GetAttribute("unit") end,
        CreateVisuals = function(frame) frame.visuals = true end,
    }
    ns.Preview = { Decorate = function(frame, member) frame.member = member end }
    ns.db = { layout = { showTargetFrame = false, showFocusFrame = false } }
    self.ns, self.frames = ns, ns.TargetFocusFrames
    self.frames:Create(self.container, "GROUP_BUTTON_TEMPLATE")
    self.target, self.focus = self.frames.buttons.target, self.frames.buttons.focus
end

function TestTargetFocusFrames:Refresh(settings)
    for key, value in pairs(settings or {}) do self.ns.db.layout[key] = value end
    self.frames:Refresh()
end

-- AC1/AC2: a NeoHeal unit button (same look and click casting as the group
-- frames) on the secure template of the group buttons, for its own unit.
function TestTargetFocusFrames:testEachFrameIsAUnitButtonForItsUnit()
    for _, unit in ipairs({ "target", "focus" }) do
        local button = self.frames.buttons[unit]
        lu.assertEquals(button.kind, "Button", unit)
        lu.assertEquals(button.template, "GROUP_BUTTON_TEMPLATE", unit .. ": not the group buttons' template")
        lu.assertIs(button.parent, self.container, unit)
        lu.assertEquals(button:GetAttribute("unit"), unit, unit .. ": wrong unit attribute")
        lu.assertEquals(self.initialized[button], unit, unit .. ": not made a NeoHeal unit button for its unit")
    end
end

-- AC1/AC2/AC3: with its option on, the game shows the frame while the unit is
-- friendly, in combat too; with it off, nothing shows it.
function TestTargetFocusFrames:testTheGameShowsTheFrameForAFriendlyUnit()
    self:Refresh({ showTargetFrame = true })
    lu.assertEquals(Driver(self.target), "[@target,help] show; hide")
    lu.assertNil(Driver(self.focus), "the focus frame is driven with its option off")
    lu.assertFalse(self.focus.shown, "the focus frame shows with its option off")
    self:Refresh({ showFocusFrame = true })
    lu.assertEquals(Driver(self.focus), "[@focus,help] show; hide")
end

-- Switching the option off stops the game showing it and hides it, also when it
-- was showing a friendly target.
function TestTargetFocusFrames:testTheOptionOffHidesTheFrame()
    self:Refresh({ showTargetFrame = true })
    self.target:Show()   -- the game showed it for a friendly target
    self:Refresh({ showTargetFrame = false })
    lu.assertNil(Driver(self.target), "the game still shows the frame with its option off")
    lu.assertFalse(self.target.shown, "the frame still shows with its option off")
end

-- AC5: the button size of the preset; above the frames, clear of the title bar
-- and group labels (2 pixels above the frames, 16 high); the focus right of the
-- target, one button and the spacing further, like the next group column.
function TestTargetFocusFrames:testSizeAndPlace()
    self:Refresh({ showTargetFrame = true, showFocusFrame = true })
    lu.assertEquals({ self.target.width, self.target.height }, { 80, 36 }, "the target frame isn't the preset's size")
    lu.assertEquals({ self.focus.width, self.focus.height }, { 80, 36 }, "the focus frame isn't the preset's size")
    local point, relativeTo, relativePoint, x, y = unpack(self.target.points[1])
    lu.assertIs(relativeTo, self.container, "the target frame doesn't move with the frames")
    lu.assertEquals({ point, relativePoint, x }, { "BOTTOMLEFT", "TOPLEFT", 0 })
    lu.assertTrue(y > 2 + 16, "the target frame overlaps the title bar or group labels")
    local focusPoint, focusRelativeTo, focusRelativePoint, focusX, focusY = unpack(self.focus.points[1])
    lu.assertIs(focusRelativeTo, self.container, "the focus frame doesn't move with the frames")
    lu.assertEquals({ focusPoint, focusRelativePoint, focusX, focusY }, { "BOTTOMLEFT", "TOPLEFT", 80 + 2, y },
        "the focus frame isn't right of the target frame")
end

-- AC5: a small label on top of each frame, which shows and hides with it.
function TestTargetFocusFrames:testEachFrameHasItsLabel()
    for unit, text in pairs({ target = "Target", focus = "Focus" }) do
        local button = self.frames.buttons[unit]
        lu.assertEquals(button.label.text.value, text, unit .. ": wrong label")
        lu.assertIs(button.label.parent, button, unit .. ": the label doesn't show and hide with its frame")
        local point, relativeTo, relativePoint = unpack(button.label.points[1])
        lu.assertIs(relativeTo, button, unit)
        lu.assertEquals({ point, relativePoint }, { "BOTTOMLEFT", "TOPLEFT" }, unit .. ": the label isn't on top of its frame")
    end
end

-- AC4: test mode shows a fake member where each frame goes, while its option
-- is on, and the real frames stay hidden.
function TestTargetFocusFrames:testTestModeShowsFakeMembersWhereTheFramesGo()
    self.ns.Layout.testSize = 5
    self:Refresh({ showTargetFrame = true, showFocusFrame = true })
    for _, unit in ipairs({ "target", "focus" }) do
        local button, fake = self.frames.buttons[unit], self.frames.previews[unit]
        lu.assertNil(Driver(button), unit .. ": the real frame is driven in test mode")
        lu.assertFalse(button.shown, unit .. ": the real frame shows in test mode")
        lu.assertNotNil(fake, unit .. ": no fake frame in test mode")
        lu.assertTrue(fake.shown, unit .. ": the fake frame doesn't show")
        lu.assertTrue(fake.visuals, unit .. ": the fake frame lacks the unit button look")
        lu.assertNotNil(fake.member, unit .. ": the fake frame shows no fake member")
        lu.assertEquals(fake.points, button.points, unit .. ": the fake frame isn't where the real one goes")
        lu.assertNotNil(fake.label, unit .. ": the fake frame lacks its label")
        lu.assertEquals(fake.label.text.value, button.label.text.value, unit .. ": the fake frame's label is wrong")
    end
end

function TestTargetFocusFrames:testTestModeShowsNoFakeFrameWithItsOptionOff()
    self.ns.Layout.testSize = 5
    self:Refresh({ showTargetFrame = true, showFocusFrame = false })
    local fake = self.frames.previews.focus
    lu.assertTrue(fake == nil or not fake.shown, "a fake focus frame with its option off")
end

-- Leaving test mode hides the fake frames, and the game shows the real ones again.
function TestTargetFocusFrames:testLeavingTestModeHidesTheFakeFrames()
    self.ns.Layout.testSize = 5
    self:Refresh({ showTargetFrame = true })
    self.ns.Layout.testSize = nil
    self:Refresh()
    lu.assertFalse(self.frames.previews.target.shown, "the fake target frame stays after test mode")
    lu.assertEquals(Driver(self.target), "[@target,help] show; hide", "the real frame doesn't come back")
end

---------------------------------------------------------------------------
-- UnitButton.lua: the reload on a new target or focus, and the target border
---------------------------------------------------------------------------
TestTargetFocusUnitButtons = {}

function TestTargetFocusUnitButtons:tearDown() Restore() end

local function Border()
    local border = { shown = false }
    function border:Show() self.shown = true end
    function border:Hide() self.shown = false end
    function border:SetShown(shown) self.shown = shown and true or false end
    function border:SetAlpha() end
    return border
end

-- A Blizzard-drawn aura container: counts its redraws.
local function Container()
    local container = { redraws = 0 }
    function container:IsShown() return true end
    function container:UpdateAllAuras() self.redraws = self.redraws + 1 end
    return container
end

-- A button with what UnitButton's SetUnit and UpdateTargetHighlight touch; its
-- events frame keeps which unit each event is registered for.
local function FakeUnitButton(name, unit)
    local events = { registered = {} }
    function events:UnregisterAllEvents() self.registered = {} end
    function events:RegisterUnitEvent(event, eventUnit) self.registered[event] = eventUnit end
    return {
        name = name, unit = unit, events = events, targetBorder = Border(), targetedBorder = Border(),
        dispelContainer = Container(), raidDebuffContainer = Container(), hotContainer = Container(),
        GetName = function(self) return self.name end,
    }
end

function TestTargetFocusUnitButtons:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua" })
    ns.db = { layout = {} }
    ns.Hots = { SetUnit = function() end }
    ns.AuraContainer = { SetUnit = function(container, unit) container.unit = unit end }
    Override("UnitExists", function() return false end)   -- UpdateAll stops: these tests look at what comes before
    Override("UnitCanAttack", function() return false end)
    self.UnitButton = ns.UnitButton
    self.target = FakeUnitButton("NeoHealTarget", "target")
    self.focus = FakeUnitButton("NeoHealFocus", "focus")
    self.party = FakeUnitButton("NeoHealGroup1UnitButton1", "party1")
    for _, button in ipairs({ self.target, self.focus, self.party }) do self.UnitButton.buttons[button] = true end
end

-- AC3: a new target reloads the target frame: its unit events, and the
-- Blizzard-drawn aura icons redraw. No other frame reloads.
function TestTargetFocusUnitButtons:testANewTargetReloadsTheTargetFrameOnly()
    self.UnitButton:ReloadUnitButtons("target")
    lu.assertEquals(self.target.events.registered.UNIT_HEALTH, "target", "the target frame didn't take up its new unit")
    for _, key in ipairs({ "dispelContainer", "raidDebuffContainer", "hotContainer" }) do
        lu.assertEquals(self.target[key].redraws, 1, key .. " didn't redraw for the new target")
    end
    lu.assertNil(self.focus.events.registered.UNIT_HEALTH, "the focus frame reloaded on a new target")
    lu.assertNil(self.party.events.registered.UNIT_HEALTH, "a group frame reloaded on a new target")
end

-- A frame without some aura icons (a class without HoTs) reloads too.
function TestTargetFocusUnitButtons:testAFrameWithoutHotIconsReloads()
    self.focus.hotContainer = nil
    lu.assertTrue(pcall(self.UnitButton.ReloadUnitButtons, self.UnitButton, "focus"), "reloading a frame without HoT icons errors")
    lu.assertEquals(self.focus.events.registered.UNIT_HEALTH, "focus")
end

-- The white "your target" border would always show on the target frame, so it
-- doesn't; the focus frame on your target keeps it.
function TestTargetFocusUnitButtons:testTheTargetFrameShowsNoTargetBorder()
    self.target.targetBorder:Show()
    Override("UnitIsUnit", function(a, b) return a == b or (a == "focus" and b == "target") end)
    self.UnitButton:UpdateTargetHighlights()
    lu.assertFalse(self.target.targetBorder.shown, "a 'your target' border on the target frame")
    lu.assertTrue(self.focus.targetBorder.shown, "the focus frame on your target lost its border")
end

---------------------------------------------------------------------------
-- Core.lua: defaults and events
---------------------------------------------------------------------------
TestTargetFocusCore = {}

function TestTargetFocusCore:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua" })
    self.reloads = {}
    ns.UnitButton = {
        UpdateTargetHighlights = function() end,
        ReloadUnitButtons = function(_, unit) table.insert(self.reloads, unit) end,
    }
    self.ns = ns
end

function TestTargetFocusCore:tearDown()
    NeoHealDB, NeoHealCharDB = nil, nil
    Restore()
end

-- AC1/AC2: both options start off.
function TestTargetFocusCore:testBothFramesStartOff()
    local noop = function() end
    local ns = self.ns
    ns.Spells, ns.Dispel, ns.MissingBuffs = { Scan = noop }, { UpdateKnownDispels = noop }, { UpdateKnownBuffs = noop }
    ns.ClickCast, ns.Layout = { Initialize = noop, Apply = noop }, { Create = noop }
    ns.Options, ns.Print = { RegisterSettingsCategory = noop }, noop
    NeoHealDB, NeoHealCharDB = nil, nil
    ns:PLAYER_LOGIN()
    lu.assertEquals(NeoHealDB.layout.showTargetFrame, false, "no default for Show target frame")
    lu.assertEquals(NeoHealDB.layout.showFocusFrame, false, "no default for Show focus frame")
end

function TestTargetFocusCore:testTheFocusEventIsRegistered()
    local registered = false
    for _, frame in ipairs(Support.frames) do
        if frame.stub.events.PLAYER_FOCUS_CHANGED then registered = true end
    end
    lu.assertTrue(registered, "PLAYER_FOCUS_CHANGED isn't registered")
end

-- AC3: a new target or focus reloads that frame.
function TestTargetFocusCore:testANewTargetReloadsTheTargetFrame()
    self.ns:PLAYER_TARGET_CHANGED()
    lu.assertEquals(self.reloads, { "target" })
end

function TestTargetFocusCore:testANewFocusReloadsTheFocusFrame()
    self.ns:PLAYER_FOCUS_CHANGED()
    lu.assertEquals(self.reloads, { "focus" })
end

---------------------------------------------------------------------------
-- Layout.lua: creating and placing them
---------------------------------------------------------------------------
TestTargetFocusLayout = {}

function TestTargetFocusLayout:tearDown() Restore() end

local function Preset()
    return { buttonWidth = 80, buttonHeight = 36, spacing = 2, scale = 1,
             position = { point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 100, y = 600 } }
end

function TestTargetFocusLayout:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Layout.lua" })
    Override("CreateFrame", FakeFrame)
    Override("UIParent", FakeFrame("Frame", "UIParent"))
    Override("IsInRaid", function() return false end)
    Override("IsInGroup", function() return false end)
    ns.db = { layout = { sizes = { party = Preset(), raid = Preset() }, showSolo = true, sortOrder = "index",
                         mainTankPosition = "none", showPets = false } }
    local noop = function() end
    ns.Hots = { RefreshSizes = noop }
    ns.UnitButton = { RefreshAuraContainers = noop, UpdateAllButtons = noop }
    ns.Blizzard = { ApplyHiding = noop }
    ns.Preview = { Show = function() return {}, false end }
    self.refreshes = 0
    ns.TargetFocusFrames = {
        Create = function(_, container, template) self.created = { container = container, template = template } end,
        Refresh = function() self.refreshes = self.refreshes + 1 end,
    }
    self.Layout = ns.Layout
end

-- AC1/AC2: the frames come with the group frames, as buttons like theirs.
function TestTargetFocusLayout:testCreateMakesTheFramesWithTheGroupButtonTemplate()
    self.Layout:Create()
    lu.assertNotNil(self.created, "no target and focus frames")
    lu.assertIs(self.created.container, self.Layout.container)
    lu.assertEquals(self.created.template, self.Layout.headers[1]:GetAttribute("template"),
        "not the template of the group buttons")
end

-- AC4/AC5: every layout refresh places them, in test mode too (where the real
-- frames hide and fake ones show).
function TestTargetFocusLayout:testRefreshPlacesThemAlsoInTestMode()
    self.Layout:Create()
    self.refreshes = 0
    self.Layout:Refresh()
    lu.assertEquals(self.refreshes, 1, "a layout refresh skips the target and focus frames")
    self.Layout.testSize = 5
    self.Layout:Refresh()
    lu.assertEquals(self.refreshes, 2, "test mode skips the target and focus frames")
end

---------------------------------------------------------------------------
-- Options.lua: the two checkboxes on the Layout page
---------------------------------------------------------------------------
TestTargetFocusOptions = {}

function TestTargetFocusOptions:tearDown() Restore() end

-- Fake frames for the options window that remember their scripts, the frame they
-- came from (a font string knows its checkbox) and every text set on them.
local texts

local function OptionsFrame(owner)
    local frame = { scripts = {}, owner = owner }
    return setmetatable(frame, { __index = function(_, key)
        if key == "SetScript" then return function(self, name, func) self.scripts[name] = func end end
        if key == "SetText" then
            return function(self, text)
                self.text = text
                table.insert(texts, self)
            end
        end
        if type(key) == "string" and key:match("^%u") and key ~= "TitleText" then
            return function(self) return OptionsFrame(self) end
        end
    end })
end

function TestTargetFocusOptions:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Spells.lua", "ClickCast.lua", "Options.lua" })
    texts = {}
    Override("CreateFrame", function(_, _, parent) return OptionsFrame(parent) end)
    Override("UIParent", OptionsFrame())
    Override("UISpecialFrames", {})
    Override("Round", function(value) return math.floor(value + 0.5) end)
    Override("MinimalSliderWithSteppersMixin", { Label = { Right = 1 }, Event = { OnValueChanged = 1 } })
    Override("CreateMinimalSliderFormatter", function() end)
    self.layoutRefreshes = 0
    ns.Layout = { GetSize = function() return {} end, Refresh = function() self.layoutRefreshes = self.layoutRefreshes + 1 end }
    ns.RunOutOfCombat = function(_, _, func) func() end
    ns.ClickCast.QueueApply = function() end
    ns.charDB = { bindings = {}, hoverKeys = {} }
    ns.db = { layout = {} }
    ns.Spells:Scan()
    ns.Options:Create()
    self.ns = ns
end

local function FindCheckbox(label)
    for _, frame in ipairs(texts) do
        if frame.text == label then return frame.owner end
    end
end

-- AC1/AC2: "Show target frame" and "Show focus frame" switch their setting and
-- apply the layout.
function TestTargetFocusOptions:testTheLayoutPageHasACheckboxPerFrame()
    for label, key in pairs({ ["Show target frame"] = "showTargetFrame", ["Show focus frame"] = "showFocusFrame" }) do
        local checkbox = FindCheckbox(label)
        lu.assertNotNil(checkbox, "no checkbox " .. label)
        rawset(checkbox, "GetChecked", function() return true end)
        checkbox.scripts.OnClick(checkbox)
        lu.assertTrue(self.ns.db.layout[key], label .. " doesn't switch " .. key)
    end
    lu.assertEquals(self.layoutRefreshes, 2)
end

---------------------------------------------------------------------------
-- Preview.lua: the fake member in the fake target and focus frames
---------------------------------------------------------------------------
TestTargetFocusPreview = {}

function TestTargetFocusPreview:tearDown() Restore() end

function TestTargetFocusPreview:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Preview.lua" })
    ns.db = { layout = { healthColor = "class", showHealPrediction = true, showRaidDebuffs = false, showAggro = true } }
    ns.UnitButton, ns.Hots, ns.MissingBuffs = Universal(), Universal(), Universal()
    ns.Dispel = { known = {}, COLORS = {} }
    Override("PowerBarColor", Universal())
    Override("RAID_CLASS_COLORS", Universal())
    self.ns = ns
end

-- AC4: test mode fills them with a fake member, as it does the group frames.
function TestTargetFocusPreview:testDecorateDrawsAFakeMember()
    local frame = Universal()
    frame.nameText = { SetText = function(text, value) text.value = value end }
    lu.assertNotNil(rawget(self.ns.Preview, "Decorate"), "test mode can't fill the target and focus frames")
    self.ns.Preview.Decorate(frame, 2)
    lu.assertEquals(frame.nameText.value, "Seraphine", "no fake member drawn")   -- member 2: the first priest
end

---------------------------------------------------------------------------
-- NeoHeal.toc: the game only loads the files the TOC lists, in its order
---------------------------------------------------------------------------
TestTargetFocusToc = {}

-- The files the TOC lists, in order (lines that are neither "##" metadata nor empty).
local function ReadTocFiles()
    local file = assert(io.open(Support.root .. "/NeoHeal.toc", "r"))
    local files = {}
    for line in file:lines() do
        line = line:gsub("%s+$", "")
        if line ~= "" and not line:match("^#") then table.insert(files, line) end
    end
    file:close()
    return files
end

local function IndexOf(list, value)
    for index, item in ipairs(list) do
        if item == value then return index end
    end
end

-- AC1/AC2: without its TOC line the module never loads. It reads its labels
-- from L when it loads, so it must come after the strings; everything else it
-- uses (UnitButton, Layout, Preview) it only calls once the game runs, so its
-- place among those doesn't matter.
function TestTargetFocusToc:testTheTocLoadsTheModuleAfterTheStrings()
    local files = ReadTocFiles()
    local module, strings = IndexOf(files, "TargetFocusFrames.lua"), IndexOf(files, "Locales\\enUS.lua")
    lu.assertNotNil(module, "NeoHeal.toc doesn't list TargetFocusFrames.lua")
    lu.assertTrue(module > strings, "TargetFocusFrames.lua loads before the strings it reads")
end

---------------------------------------------------------------------------
-- UnitButton.lua and ClickCast.lua: the range fade on the target and focus frames.
-- UnitInRange only answers for your party and raid, so these two frames judge
-- range by the spell an unmodified left click casts (C_Spell.IsSpellInRange).
-- The tests run the real range poll (the C_Timer.NewTicker callback).
---------------------------------------------------------------------------
TestTargetFocusRange = {}

local RANGE_SECRET = setmetatable({}, { __eq = function() error("compared a secret value") end })
local FADED = 0.4

function TestTargetFocusRange:tearDown() Restore() end

function TestTargetFocusRange:setUp()
    local ns = Support.Load({ "Locales/enUS.lua" })
    issecretvalue = function(value) return rawequal(value, RANGE_SECRET) end   -- Core reads it when it loads
    C_Timer = { After = function() end, NewTicker = function(_, func) self.poll = func end }
    Override("UnitExists", function() return true end)
    -- The game's answer for a unit outside your party or raid: not in range, not checked.
    Override("UnitInRange", function() return false, false end)
    Support.LoadInto(ns, { "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua" })
    ns.Spells:Scan()
    ns.db = { layout = {} }
    ns.charDB = { bindings = { ["1"] = { action = "spell", spellID = 2061, target = "unit" } }, hoverKeys = {} }
    ns.ClickCast.appliedBindings = ns.charDB.bindings
    self.asked = {}   -- every IsSpellInRange call: { spellID, unit }
    self.answer = false
    C_Spell.IsSpellInRange = function(spellID, unit)
        table.insert(self.asked, { spellID, unit })
        return self.answer
    end
    self.ns = ns
end

-- A button whose content keeps the alpha it was given, and what SetAlphaFromBoolean got.
function TestTargetFocusRange:Button(unit)
    local button = { unit = unit, IsVisible = function() return true end, GetName = function() return "Range" .. unit end }
    button.content = {
        SetAlpha = function(_, alpha) button.alpha = alpha end,
        SetAlphaFromBoolean = function(_, value, onTrue, onFalse) button.fromBoolean = { value, onTrue, onFalse } end,
    }
    self.ns.UnitButton.buttons[button] = true
    return button
end

-- The alpha one poll gives a frame for `unit`.
function TestTargetFocusRange:AlphaOf(unit)
    local button = self:Button(unit)
    self.poll()
    return button.alpha, button
end

function TestTargetFocusRange:testTheTargetFrameOutOfRangeFades()
    lu.assertEquals(self:AlphaOf("target"), FADED, "the target frame out of range doesn't fade")
    lu.assertEquals(self.asked[1], { 2061, "target" }, "not asked for the left-click spell on the target")
end

function TestTargetFocusRange:testTheFocusFrameOutOfRangeFades()
    lu.assertEquals(self:AlphaOf("focus"), FADED, "the focus frame out of range doesn't fade")
    lu.assertEquals(self.asked[1], { 2061, "focus" }, "not asked for the left-click spell on the focus")
end

function TestTargetFocusRange:testInRangeStaysBright()
    self.answer = true
    lu.assertEquals(self:AlphaOf("target"), 1, "the target frame in range fades")
end

-- nil: the check couldn't be made. That never fades a frame that may be in range.
function TestTargetFocusRange:testACheckThatCantBeMadeStaysBright()
    self.answer = nil
    lu.assertEquals(self:AlphaOf("target"), 1, "a check that can't be made faded the frame")
end

function TestTargetFocusRange:testWithoutTheRangeApiItStaysBright()
    C_Spell.IsSpellInRange = nil
    local button = self:Button("target")
    local ok, problem = pcall(self.poll)
    lu.assertTrue(ok, "the poll failed without C_Spell.IsSpellInRange: " .. tostring(problem))
    lu.assertEquals(button.alpha, 1, "the frame faded without C_Spell.IsSpellInRange")
end

function TestTargetFocusRange:testWithoutALeftClickSpellItStaysBrightAndAsksNothing()
    self.ns.charDB.bindings["1"] = { action = "menu" }
    lu.assertEquals(self:AlphaOf("target"), 1, "the frame faded without a left-click spell")
    lu.assertEquals(#self.asked, 0, "the range was asked without a left-click spell")
end

-- A hidden answer goes to the game untouched, never tested or compared.
function TestTargetFocusRange:testASecretAnswerGoesToTheGameUntouched()
    self.answer = RANGE_SECRET
    local alpha, button = self:AlphaOf("target")
    lu.assertNotNil(button.fromBoolean, "a secret answer didn't go to SetAlphaFromBoolean")
    lu.assertTrue(rawequal(button.fromBoolean[1], RANGE_SECRET), "SetAlphaFromBoolean didn't get the secret itself")
    lu.assertEquals({ button.fromBoolean[2], button.fromBoolean[3] }, { 1, FADED })
    lu.assertNil(alpha, "a secret answer was turned into an alpha here")
end

-- The target frame showing you: always in range, nothing asked.
function TestTargetFocusRange:testTheTargetFrameOnYouStaysBright()
    UnitIsUnit = function(a, b) return a == b or (a == "target" and b == "player") end
    lu.assertEquals(self:AlphaOf("target"), 1, "the target frame showing you faded")
    lu.assertEquals(#self.asked, 0, "the range of you was asked")
end

-- Only the target and focus frames take the spell check: group frames keep
-- UnitInRange, as before.
function TestTargetFocusRange:testGroupFramesStillUseUnitInRange()
    Override("UnitInRange", function(unit) return false, unit == "party1" or unit == "raid3" end)
    lu.assertEquals(self:AlphaOf("party1"), FADED, "a party frame out of range by UnitInRange doesn't fade")
    lu.assertEquals(self:AlphaOf("raid3"), FADED, "a raid frame out of range by UnitInRange doesn't fade")
    lu.assertEquals(#self.asked, 0, "a group frame asked the spell's range")
end

-- ClickCast:GetLeftClickSpell: the spell an unmodified left click casts on the unit.
function TestTargetFocusRange:testTheLeftClickSpellIsTheHighestRankWhenBoundSo()
    self.ns.charDB.bindings["1"] = { action = "spell", spellID = 2061, target = "unit", highestRank = true }
    lu.assertEquals(self.ns.ClickCast:GetLeftClickSpell(), Support.FLASH_HEAL[7], "not the rank the click casts")
end

-- The action decides, not a spell ID the binding may still carry: the menu and
-- buff bindings here keep one, so only the action can make them no spell.
function TestTargetFocusRange:testAMenuClickIsNoSpell()
    self.ns.charDB.bindings["1"] = { action = "menu", spellID = 2061, target = "unit" }
    lu.assertNil(self.ns.ClickCast:GetLeftClickSpell(), "a menu click gave a spell")
end

function TestTargetFocusRange:testABuffClickIsNoSpell()
    self.ns.charDB.bindings["1"] = { action = "buff", spellID = 2061, target = "unit" }
    lu.assertNil(self.ns.ClickCast:GetLeftClickSpell(), "a buff click gave a spell")
end

-- Cast on the unit's target: no range check on the unit itself.
function TestTargetFocusRange:testASpellOnTheUnitsTargetIsNoSpell()
    self.ns.charDB.bindings["1"] = { action = "spell", spellID = 2061, target = "target" }
    lu.assertNil(self.ns.ClickCast:GetLeftClickSpell(), "a spell cast on the unit's target gave a spell")
end

-- Holding Shift doesn't change which click is judged: the fade mustn't move with it.
function TestTargetFocusRange:testHoldingShiftKeepsTheUnmodifiedClick()
    self.ns.charDB.bindings["shift-1"] = { action = "spell", spellID = 552, target = "unit" }
    Support.SetModifiers({ shift = true })
    lu.assertEquals(self.ns.ClickCast:GetLeftClickSpell(), 2061, "Shift changed the spell the range is judged by")
end

-- The bindings last applied to the frames count, like the tooltip: they are what the click casts.
function TestTargetFocusRange:testTheAppliedBindingsCount()
    self.ns.ClickCast.appliedBindings = { ["1"] = { action = "spell", spellID = 552, target = "unit" } }
    lu.assertEquals(self.ns.ClickCast:GetLeftClickSpell(), 552, "not the spell of the bindings applied to the frames")
end

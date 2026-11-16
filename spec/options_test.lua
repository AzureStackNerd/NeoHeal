-- Options.lua and Core.lua: the click casting rows follow the spellbook, and the
-- action menu saves what you click. TestOptions uses a fake page;
-- TestOptionsWindow builds the real window on fake frames.
local lu = require("luaunit")
local Support = require("support")
local FLASH_HEAL = Support.FLASH_HEAL

local function FakePage(visible)
    local page = { refreshes = 0 }
    function page:IsVisible() return visible end
    function page:Refresh() self.refreshes = self.refreshes + 1 end
    return page
end

TestOptions = {}

function TestOptions:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua", "Options.lua" })
    -- What SPELLS_CHANGED calls besides the spellbook, cut down to nothing.
    local noop = function() end
    ns.Dispel = { UpdateKnownDispels = noop }
    ns.MissingBuffs = { UpdateKnownBuffs = noop }
    ns.UnitButton = { UpdateAllButtons = noop, RefreshAuraContainers = noop }
    ns.ClickCast.QueueApply = noop
    ns.db = {}   -- logged in
    self.ns = ns
end

function TestOptions:testRefreshBeforeTheWindowWasEverOpened()
    self.ns.Options:RefreshClickCastingPage()   -- must not error
end

function TestOptions:testRefreshOnlyWhileThePageShows()
    local hidden = FakePage(false)
    self.ns.Options.clickCastingPage = hidden
    self.ns.Options:RefreshClickCastingPage()
    lu.assertEquals(hidden.refreshes, 0)

    local shown = FakePage(true)
    self.ns.Options.clickCastingPage = shown
    self.ns.Options:RefreshClickCastingPage()
    lu.assertEquals(shown.refreshes, 1)
end

function TestOptions:testLearningASpellRefreshesTheRows()
    local page = FakePage(true)
    self.ns.Options.clickCastingPage = page
    self.ns:SPELLS_CHANGED()
    lu.assertEquals(page.refreshes, 1)
end

-- The real window on fake frames: every frame method returns another fake frame,
-- and each dropdown's menu builder is recorded so a test can click through it.
-- Each frame keeps its scripts and whether it takes keyboard input, and each frame
-- with an OnKeyDown script is recorded: those are the hover-key capture buttons,
-- slot 1 first. Setting OnKeyDown turns keyboard input on, as the client does
-- (docs/forever-api.md, section 7). TitleText is nil, as on a frame template without one.
-- A frame made by CreateFrame knows its type, its parent and its children, and is
-- shown until hidden. It is visible when it and every ancestor are shown; Show, Hide
-- and SetShown run OnShow or OnHide only when that changes, down to every shown
-- child, as the client does by its documentation (not checked in game). So the
-- build's ShowPage(1), under the still hidden window, runs nothing.
local menuBuilders, keyCaptureButtons

local function RunVisibilityScripts(frame, visible)
    local script = frame.scripts[visible and "OnShow" or "OnHide"]
    if script then script(frame) end
    for _, child in ipairs(frame.children) do
        if child.shown then RunVisibilityScripts(child, visible) end
    end
end

local function FakeFrame(frameType, _, parent)
    local frame = setmetatable({ scripts = {}, keyboardEnabled = false, frameType = frameType, parent = parent or false,
                                 children = {}, shown = true }, { __index = function(_, key)
        if key == "TitleText" then return nil end
        if key == "SetupMenu" then
            return function(frame, builder)
                frame.menuBuilder = builder
                table.insert(menuBuilders, builder)
            end
        end
        if key == "GetParent" then return function(frame) return frame.parent end end
        if key == "IsShown" then return function(frame) return frame.shown end end
        if key == "IsVisible" then
            return function(frame)
                return frame.shown and (not frame.parent or frame.parent:IsVisible())
            end
        end
        if key == "SetShown" or key == "Show" or key == "Hide" then
            return function(frame, shown)
                if key ~= "SetShown" then shown = key == "Show" end
                local wasVisible = frame:IsVisible()
                frame.shown = shown and true or false
                if frame:IsVisible() ~= wasVisible then RunVisibilityScripts(frame, not wasVisible) end
            end
        end
        if key == "SetScript" then
            return function(frame, name, func)
                frame.scripts[name] = func
                if name == "OnKeyDown" then
                    table.insert(keyCaptureButtons, frame)
                    frame.keyboardEnabled = true
                end
            end
        end
        if key == "EnableKeyboard" then
            return function(frame, enabled) frame.keyboardEnabled = enabled end
        end
        if key == "SetText" then
            return function(frame, text) frame.text = text end
        end
        return function() return FakeFrame() end
    end })
    if type(parent) == "table" and rawget(parent, "children") then table.insert(parent.children, frame) end
    return frame
end

-- A menu that keeps its buttons, so they can be found and clicked.
local function FakeMenu()
    local menu = { children = {} }
    function menu:CreateButton(text, onClick)
        local child = FakeMenu()
        child.text, child.onClick = text, onClick
        table.insert(self.children, child)
        return child
    end
    function menu:CreateRadio(text, _, setSelected)   -- choosing it runs its setter
        table.insert(self.children, { text = text, onClick = setSelected })
    end
    function menu:CreateDivider() end
    function menu:CreateTitle() end
    function menu:Find(text)
        for _, child in ipairs(self.children) do
            if child.text == text then return child end
        end
        error("no menu entry " .. tostring(text))
    end
    return menu
end

TestOptionsWindow = {}

function TestOptionsWindow:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Spells.lua", "ClickCast.lua", "Options.lua" })
    menuBuilders, keyCaptureButtons = {}, {}
    CreateFrame, UIParent, UISpecialFrames = FakeFrame, FakeFrame(), {}
    Round = function(value) return math.floor(value + 0.5) end
    MinimalSliderWithSteppersMixin = { Label = { Right = 1 }, Event = { OnValueChanged = 1 } }
    CreateMinimalSliderFormatter = function() end
    ns.Layout = { GetSize = function() return {} end }
    ns.ClickCast.QueueApply = function() end
    ns.charDB = { bindings = {}, hoverKeys = {} }
    ns.Spells:Scan()
    ns.Options:Create()
    self.ns = ns
end

-- The click casting page is built first; its first dropdown is the left click
-- row's action menu.
function TestOptionsWindow:testHighestRankMinusOneSavesTheRankBelowTheHighest()
    local root = FakeMenu()
    menuBuilders[1](nil, root)
    root:Find("Holy"):Find("Flash Heal"):Find(self.ns.L.HIGHEST_RANK_MINUS_ONE).onClick()
    local binding = self.ns.charDB.bindings["1"]
    lu.assertEquals(binding.spellID, FLASH_HEAL[6])
    lu.assertEquals(binding.rankOffset, 1)
    lu.assertTrue(binding.highestRank)
end

-- With the window open you walk normally: no hover-key button takes keys until
-- you click Set key on it. Seen in game 2026-11-15: the first open after a
-- /reload swallowed W and showed the "moves your character" warning.
function TestOptionsWindow:testNoKeyCaptureTakesKeysBeforeItsClick()
    lu.assertEquals(#keyCaptureButtons, 3)   -- hover keys 1 to 3
    for slot, capture in ipairs(keyCaptureButtons) do
        lu.assertFalse(capture.keyboardEnabled, "hover key " .. slot .. " takes keys before its click")
    end
end

-- A key that moves you can't be a hover key (W walks forward by default): the
-- capture says why at the top of the screen and keeps waiting for another key.
function TestOptionsWindow:testTheKeyCaptureRefusesAKeyThatMovesYou()
    GetBindingAction = function(key) return key == "W" and "MOVEFORWARD" or "" end
    local capture = keyCaptureButtons[1]   -- hover key 1
    capture.scripts.OnClick(capture, "LeftButton")   -- start capturing
    lu.assertTrue(capture.keyboardEnabled)
    capture.scripts.OnKeyDown(capture, "W")
    lu.assertNil(self.ns.charDB.hoverKeys[1])
    lu.assertEquals(Support.errorMessages, { format(self.ns.L.HOVER_KEY_MOVES, "W") })
    lu.assertTrue(capture.keyboardEnabled)   -- still waiting
    capture.scripts.OnKeyDown(capture, "Q")
    lu.assertEquals(self.ns.charDB.hoverKeys[1], "Q")
    lu.assertFalse(capture.keyboardEnabled)
end

-- A saved hover key that moves you isn't bound: its button says why.
function TestOptionsWindow:testAHoverKeyThatMovesYouIsMarked()
    GetBindingAction = function(key) return key == "W" and "MOVEFORWARD" or "" end
    local capture = keyCaptureButtons[1]
    self.ns.charDB.hoverKeys[1] = "W"
    capture:Refresh()
    lu.assertEquals(capture.text, format(self.ns.L.HOVER_KEY_MOVES_YOU, "W"))
    self.ns.charDB.hoverKeys[1] = "Q"
    capture:Refresh()
    lu.assertEquals(capture.text, "Key: Q")
end

function TestOptionsWindow:testTheBuiltPageRefreshesWhileItShows()
    local refreshes = 0
    self.ns.Options.RefreshBindingRows = function() refreshes = refreshes + 1 end
    self.ns.Options.clickCastingPage.IsVisible = function() return true end
    self.ns.Options:RefreshClickCastingPage()
    lu.assertEquals(refreshes, 1)
end

-- Issue #6: a hover-key button takes keys only while it reads "Press a key" (a
-- wait). Every test opens the window first, as the healer does, so a redraw of the
-- rows runs as it does in the game. The expected texts are the scenario rows' own
-- words (docs/refinements/6-key-capture-stops.md), not read from the code. What the
-- fake cannot show: that W then walks, which key the client sends where, and that
-- the client lets the keyboard go off as combat starts (not checked in game).
TestHoverKeyWait = {}

local SAVED_KEYS = {   -- hover key 1's key before the wait, and the text it returns to (S3)
    { name = "no key", text = "Set key..." },
    { name = "E", key = "E", text = "Key: E" },
    { name = "W, which moves you", key = "W", text = "W (moves you)" },
}

local function Click(button, mouseButton)
    button.scripts.OnClick(button, mouseButton or "LeftButton")
end

-- The client sends a key only to a button whose keyboard is on.
local function Press(button, key)
    lu.assertTrue(button.keyboardEnabled, "the client sends " .. key .. " to no button with its keyboard off")
    button.scripts.OnKeyDown(button, key)
end

-- AC3's rule, on all three buttons: a button takes keys exactly when it reads "Press a key".
local function AssertTextMatchesKeyboard(context)
    for slot, capture in ipairs(keyCaptureButtons) do
        lu.assertEquals(capture.keyboardEnabled, capture.text == "Press a key",
            format("%s: hover key %d reads %q but %s", context, slot, tostring(capture.text),
                capture.keyboardEnabled and "takes keys" or "takes none"))
    end
end

local function ChildrenOfType(frame, frameType)
    local found = {}
    for _, child in ipairs(frame.children) do
        if child.frameType == frameType then table.insert(found, child) end
    end
    return found
end

function TestHoverKeyWait:setUp()
    TestOptionsWindow.setUp(self)
    local ns = self.ns
    ns.db = { layout = {} }
    ns.Layout.SetMoveMode = function() end
    ns.Layout.SetTestMode = function() end
    ns.Layout.GetPresetName = function() return "party" end
    GetBindingAction = function(key) return key == "W" and "MOVEFORWARD" or "" end
end

-- Opens the window with these hover keys saved; hover key 1 has a spell, so the
-- "cast on" choice and "Also target" change something.
function TestHoverKeyWait:Open(hoverKeys)
    local ns = self.ns
    ns.charDB.hoverKeys = hoverKeys
    ns.charDB.bindings["-neokey1"] = { action = "spell", spellID = FLASH_HEAL[7], highestRank = true }
    ns.Options:Show()
    lu.assertTrue(ns.Options.frame:IsVisible())
    self.hoverKey1 = keyCaptureButtons[1]
end

-- The row of a hover key, its action and "cast on" dropdowns, and its "Also target" box.
function TestHoverKeyWait:HoverKeyRow(slot)
    for index, button in ipairs(self.ns.ClickCast.BUTTONS) do
        if button.hoverKey == slot then
            local row = self.ns.Options.bindingRows[index]
            local dropdowns = ChildrenOfType(row, "DropdownButton")
            return dropdowns[1], dropdowns[2], ChildrenOfType(row, "CheckButton")[1]
        end
    end
end

function TestHoverKeyWait:OpenMenu(dropdown)
    local root = FakeMenu()
    dropdown.menuBuilder(dropdown, root)
    return root
end

-- S10 (issue #6): the right click clears the key and the wait ends.
function TestHoverKeyWait:testRightClickDuringAWaitClearsTheKeyAndStopsTakingKeys()
    self:Open({ "E" })
    Click(self.hoverKey1)
    Click(self.hoverKey1, "RightButton")
    lu.assertNil(self.ns.charDB.hoverKeys[1])
    lu.assertEquals(self.hoverKey1.text, "Set key...")
    lu.assertFalse(self.hoverKey1.keyboardEnabled, "hover key 1 still takes keys")
    AssertTextMatchesKeyboard("after the right click")
end

-- S11: one wait at a time; the first shows its key again, Q goes to the second only.
function TestHoverKeyWait:testSetKeyOnASecondHoverKeyEndsTheFirstWait()
    self:Open({ "E" })
    local hoverKey2 = keyCaptureButtons[2]
    Click(self.hoverKey1)
    Click(hoverKey2)
    lu.assertEquals(self.hoverKey1.text, "Key: E")
    lu.assertFalse(self.hoverKey1.keyboardEnabled, "hover key 1 still takes keys")
    lu.assertEquals(hoverKey2.text, "Press a key")
    AssertTextMatchesKeyboard("after Set key on hover key 2")
    Press(hoverKey2, "Q")
    lu.assertEquals(self.ns.charDB.hoverKeys, { "E", "Q" })
    lu.assertEquals(hoverKey2.text, "Key: Q")
    AssertTextMatchesKeyboard("after Q")
end

-- AC3: what the healer or the game does during a wait, and whether it redraws the
-- rows (S12 to S18, S20). Each case runs on every saved key of hover key 1 (S3).
local WAIT_CASES = {
    { row = "S12, a right click on hover key 2", ends = true, run = function(test)
        Click(keyCaptureButtons[2], "RightButton")
        lu.assertNil(test.ns.charDB.hoverKeys[2])
        lu.assertEquals(keyCaptureButtons[2].text, "Set key...")
    end },
    { row = "S13, the Shift modifier button", ends = true, run = function(test)
        Click(test.ns.Options.modifierButtons[2])
        lu.assertEquals(test.ns.Options.selectedModifier, "shift-")
    end },
    { row = "S14, an action chosen in hover key 1's own menu", ends = true, run = function(test)
        local action = test:HoverKeyRow(1)
        test:OpenMenu(action):Find("Holy"):Find("Flash Heal"):Find(test.ns.L.HIGHEST_RANK_MINUS_ONE).onClick()
        lu.assertEquals(test.ns.charDB.bindings["-neokey1"].spellID, FLASH_HEAL[6])
    end },
    { row = "S15, Reset to class defaults", ends = true, run = function(test)
        local page = test.ns.Options.clickCastingPage
        for _, child in ipairs(page.children) do
            if child.text == "Reset to class defaults" then Click(child) end
        end
        lu.assertEquals(test.ns.charDB.bindings, test.ns.ClickCast:GetClassDefaults())
    end },
    { row = "S17, a spell learned", ends = true, run = function(test)
        test.ns.Options:RefreshClickCastingPage()   -- what SPELLS_CHANGED calls (TestOptions)
    end },
    { row = "S18, a key binding changed", ends = true, run = function(test)
        test.ns.Options:RefreshClickCastingPage()   -- what UPDATE_BINDINGS calls (spec/hoverkeys_test.lua)
    end },
    { row = "S16, a cast on choice and Also target", ends = false, run = function(test)
        local _, castOn, alsoTarget = test:HoverKeyRow(1)
        test:OpenMenu(castOn):Find(test.ns.L.TARGET_UNIT_TARGET).onClick()
        Click(alsoTarget)
        local binding = test.ns.charDB.bindings["-neokey1"]
        lu.assertEquals(binding.target, "target")
        lu.assertTrue(binding.alsoTarget and true or false)
    end },
    { row = "S20, a menu opened and closed without a choice", ends = false, run = function(test)
        local action, castOn = test:HoverKeyRow(1)
        test:OpenMenu(action)
        test:OpenMenu(castOn)
    end },
}

function TestHoverKeyWait:testARedrawOfTheRowsDuringAWaitNeverLeavesKeysTaken()
    local failures = {}
    for _, case in ipairs(WAIT_CASES) do
        for _, saved in ipairs(SAVED_KEYS) do
            local ok, err = pcall(function()
                self:setUp()
                self:Open({ saved.key, "R" })
                Click(self.hoverKey1)
                case.run(self)
                if case.ends then
                    lu.assertEquals(self.hoverKey1.text, saved.text)
                    lu.assertFalse(self.hoverKey1.keyboardEnabled, "hover key 1 still takes keys")
                    AssertTextMatchesKeyboard("after it")
                else
                    lu.assertEquals(self.hoverKey1.text, "Press a key")
                    AssertTextMatchesKeyboard("after it")
                    Press(self.hoverKey1, "Q")
                    lu.assertEquals(self.ns.charDB.hoverKeys[1], "Q")
                end
            end)
            if not ok then
                local message = type(err) == "table" and err.msg or tostring(err)
                table.insert(failures, case.row .. ", saved " .. saved.name .. ": " .. message)
            end
        end
    end
    lu.assertEquals(failures, {})
end

-- S19: the wait ends as combat starts, the window stays open.
function TestHoverKeyWait:testCombatStartEndsAWait()
    self:Open({ "E" })
    Click(self.hoverKey1)
    local frame = self.ns.Options.frame
    frame.scripts.OnEvent(frame, "PLAYER_REGEN_DISABLED")
    lu.assertTrue(frame:IsShown())
    lu.assertEquals(self.hoverKey1.text, "Key: E")
    lu.assertFalse(self.hoverKey1.keyboardEnabled, "hover key 1 still takes keys in combat")
    AssertTextMatchesKeyboard("after combat started")
end

-- S9: in combat a click on a hover-key button starts and clears nothing.
function TestHoverKeyWait:testAClickInCombatStartsNoWait()
    self:Open({ "E" })
    InCombatLockdown = function() return true end
    Click(self.hoverKey1)
    lu.assertEquals(self.hoverKey1.text, "Key: E")
    lu.assertFalse(self.hoverKey1.keyboardEnabled)
    Click(self.hoverKey1, "RightButton")
    lu.assertEquals(self.ns.charDB.hoverKeys[1], "E")
    AssertTextMatchesKeyboard("after clicks in combat")
end

-- S3: Escape ends the wait and keeps the key, whatever it was.
function TestHoverKeyWait:testEscapeCancelsAWaitAndKeepsTheKey()
    for _, saved in ipairs(SAVED_KEYS) do
        self:setUp()
        self:Open({ saved.key })
        Click(self.hoverKey1)
        Press(self.hoverKey1, "ESCAPE")
        lu.assertEquals(self.ns.charDB.hoverKeys[1], saved.key, "saved " .. saved.name)
        lu.assertEquals(self.hoverKey1.text, saved.text)
        lu.assertFalse(self.hoverKey1.keyboardEnabled, "saved " .. saved.name .. ": still takes keys")
        AssertTextMatchesKeyboard("after Escape, saved " .. saved.name)
    end
end

-- S5, S6: Shift alone is not a key, and a second click keeps the one wait.
function TestHoverKeyWait:testAModifierKeyOrASecondClickKeepsOneWait()
    self:Open({ "E" })
    Click(self.hoverKey1)
    Press(self.hoverKey1, "LSHIFT")
    lu.assertEquals(self.ns.charDB.hoverKeys[1], "E")
    lu.assertEquals(self.hoverKey1.text, "Press a key")
    Click(self.hoverKey1)
    lu.assertEquals(self.hoverKey1.text, "Press a key")
    AssertTextMatchesKeyboard("after Shift and a second click")
    Press(self.hoverKey1, "Q")
    lu.assertEquals(self.ns.charDB.hoverKeys[1], "Q")
    lu.assertEquals(self.hoverKey1.text, "Key: Q")
    AssertTextMatchesKeyboard("after Q")
end

-- S7, S8: the Layout tab or closing the window ends the wait; reopened, no button
-- takes keys. That the client hides the button with its page or window is not
-- checked in game.
function TestHoverKeyWait:testSwitchingPageOrClosingTheWindowEndsAWait()
    self:Open({ "E", "R" })
    local Options = self.ns.Options
    Click(self.hoverKey1)
    Click(Options.pageTabs[2])   -- Layout
    lu.assertFalse(self.hoverKey1.keyboardEnabled, "hover key 1 takes keys on the Layout page")
    Click(Options.pageTabs[1])   -- back on Click Casting
    lu.assertEquals(self.hoverKey1.text, "Key: E")
    AssertTextMatchesKeyboard("back on Click Casting")

    Click(self.hoverKey1)
    Options:Toggle()   -- closes it, as /neoheal does
    lu.assertFalse(Options.frame:IsShown())
    lu.assertFalse(self.hoverKey1.keyboardEnabled, "hover key 1 takes keys with the window closed")
    Options:Toggle()   -- reopened
    lu.assertEquals(self.hoverKey1.text, "Key: E")
    lu.assertEquals(keyCaptureButtons[2].text, "Key: R")
    AssertTextMatchesKeyboard("reopened")
end

-- The version in the title: the window title shows the version you run, read through the client
-- from the TOC's "## Version" line. The expected version is read from the real
-- NeoHeal.toc, so the test follows every release. Whether Forever's client has
-- C_AddOns.GetAddOnMetadata is not checked here, only in game.
local function TocVersion()
    local file = assert(io.open(Support.root .. "/NeoHeal.toc", "r"))
    local version
    for line in file:lines() do
        version = version or line:match("^##%s*Version%s*:%s*(.-)%s*$")
    end
    file:close()
    return version
end

-- Builds the window with the given C_AddOns and returns its title label: the
-- first font string made on the window frame, which has no TitleText.
local function BuildWindowTitle(addOns)
    local ns = Support.Load({ "Locales/enUS.lua", "Spells.lua", "ClickCast.lua", "Options.lua" })
    menuBuilders, keyCaptureButtons = {}, {}
    local titleLabel
    CreateFrame = function(_, name)
        local frame = FakeFrame()
        if name == "NeoHealOptionsFrame" then
            frame.CreateFontString = function()
                local label = FakeFrame()
                titleLabel = titleLabel or label
                return label
            end
        end
        return frame
    end
    UIParent, UISpecialFrames = FakeFrame(), {}
    Round = function(value) return math.floor(value + 0.5) end
    MinimalSliderWithSteppersMixin = { Label = { Right = 1 }, Event = { OnValueChanged = 1 } }
    CreateMinimalSliderFormatter = function() end
    ns.Layout = { GetSize = function() return {} end }
    ns.ClickCast.QueueApply = function() end
    ns.charDB = { bindings = {}, hoverKeys = {} }
    ns.Spells:Scan()
    C_AddOns = addOns
    ns.Options:Create()
    return titleLabel.text, ns.L
end

-- A client that knows NeoHeal's version only when asked for this addon by name.
local function AddOnsWithVersion(version)
    return { GetAddOnMetadata = function(addon, field)
        if addon == "NeoHeal" and field == "Version" then return version end
    end }
end

TestOptionsTitle = {}

function TestOptionsTitle:tearDown()
    C_AddOns = nil   -- the fake API has none; later spec files must not see this one
end

function TestOptionsTitle:testTheTitleShowsTheTocVersion()
    local version = TocVersion()
    lu.assertIsString(version, "NeoHeal.toc has no Version line")
    local title, L = BuildWindowTitle(AddOnsWithVersion(version))
    lu.assertEquals(title, L.OPTIONS_TITLE .. " (" .. version .. ")")
end

function TestOptionsTitle:testNoVersionKeepsThePlainTitle()
    local title, L = BuildWindowTitle(AddOnsWithVersion(nil))
    lu.assertEquals(title, L.OPTIONS_TITLE)
end

function TestOptionsTitle:testAnEmptyVersionKeepsThePlainTitle()
    local title, L = BuildWindowTitle(AddOnsWithVersion(""))
    lu.assertEquals(title, L.OPTIONS_TITLE)
end

function TestOptionsTitle:testAClientWithoutAddOnsKeepsThePlainTitle()
    local title, L = BuildWindowTitle(nil)
    lu.assertEquals(title, L.OPTIONS_TITLE)
end

---------------------------------------------------------------------------
-- The five-second rule's option on the Layout page (spec/fivesecond_test.lua has
-- what it does).
---------------------------------------------------------------------------
TestFiveSecondOption = {}

local FIVE_SECOND_GLOBALS = { "CreateFrame", "UIParent", "UISpecialFrames", "Round", "MinimalSliderWithSteppersMixin",
                              "CreateMinimalSliderFormatter" }

function TestFiveSecondOption:setUp()
    self.saved = {}
    for _, name in ipairs(FIVE_SECOND_GLOBALS) do self.saved[name] = { _G[name] } end
end

function TestFiveSecondOption:tearDown()
    for name, old in pairs(self.saved) do _G[name] = old[1] end
end

-- AC5, S26: a checkbox on the Layout page, labelled with the string, switches
-- showFiveSecond.
function TestFiveSecondOption:testTheFiveSecondOptionIsOnTheLayoutPage()
    local ns = Support.Load({ "Locales/enUS.lua", "Spells.lua", "ClickCast.lua", "Options.lua" })
    local texts = {}
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
    CreateFrame = function(_, _, parent) return OptionsFrame(parent) end
    UIParent, UISpecialFrames = OptionsFrame(), {}
    Round = function(value) return math.floor(value + 0.5) end
    MinimalSliderWithSteppersMixin = { Label = { Right = 1 }, Event = { OnValueChanged = 1 } }
    CreateMinimalSliderFormatter = function() end
    ns.Layout = { GetSize = function() return {} end, Refresh = function() end }
    ns.RunOutOfCombat = function(_, _, func) func() end
    ns.ClickCast.QueueApply = function() end
    ns.charDB = { bindings = {}, hoverKeys = {} }
    ns.db = { layout = { showFiveSecond = true } }
    ns.Spells:Scan()
    ns.Options:Create()
    -- A missing string would show its own key (Locales/enUS.lua), so look in the table itself.
    lu.assertNotNil(rawget(ns.L, "SHOW_FIVE_SECOND"), "no string for the option: the checkbox shows its key")
    local checkbox
    for _, frame in ipairs(texts) do
        if frame.text == ns.L.SHOW_FIVE_SECOND then checkbox = frame.owner end
    end
    lu.assertNotNil(checkbox, "no five-second checkbox on the Layout page")
    rawset(checkbox, "GetChecked", function() return false end)
    checkbox.scripts.OnClick(checkbox)
    lu.assertEquals(ns.db.layout.showFiveSecond, false, "the checkbox doesn't switch showFiveSecond")
end

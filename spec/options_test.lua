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
local menuBuilders, keyCaptureButtons

local function FakeFrame()
    return setmetatable({ scripts = {}, keyboardEnabled = false }, { __index = function(_, key)
        if key == "TitleText" then return nil end
        if key == "SetupMenu" then
            return function(_, builder) table.insert(menuBuilders, builder) end
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
    function menu:CreateRadio() end
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

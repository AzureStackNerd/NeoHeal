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
-- TitleText is nil, as on a frame template without one.
local menuBuilders

local function FakeFrame()
    return setmetatable({}, { __index = function(_, key)
        if key == "TitleText" then return nil end
        if key == "SetupMenu" then
            return function(_, builder) table.insert(menuBuilders, builder) end
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
    menuBuilders = {}
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

function TestOptionsWindow:testTheBuiltPageRefreshesWhileItShows()
    local refreshes = 0
    self.ns.Options.RefreshBindingRows = function() refreshes = refreshes + 1 end
    self.ns.Options.clickCastingPage.IsVisible = function() return true end
    self.ns.Options:RefreshClickCastingPage()
    lu.assertEquals(refreshes, 1)
end

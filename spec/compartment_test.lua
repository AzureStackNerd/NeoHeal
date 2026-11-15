-- NeoHeal.toc and Core.lua: Blizzard's addon compartment (the addon list beside
-- the minimap). It reads the TOC's Title, IconTexture and AddonCompartmentFunc,
-- and on a click calls _G[AddonCompartmentFunc](addonName, buttonName). These
-- tests read the real TOC and call the global the same way, then check the
-- options window opens and a second click closes it, as /neoheal does.
local lu = require("luaunit")
local Support = require("support")

-- The TOC's "## Key: value" metadata lines.
local function ReadTocMetadata()
    local file = assert(io.open(Support.root .. "/NeoHeal.toc", "r"))
    local metadata = {}
    for line in file:lines() do
        local key, value = line:match("^##%s*([%w_]+)%s*:%s*(.-)%s*$")
        if key then metadata[key] = value end
    end
    file:close()
    return metadata
end

-- Fake frames for the real options window, like spec/options_test.lua's, except
-- that each frame remembers whether it is shown, so Toggle can be checked.
local function FakeFrame()
    local frame = { shown = true }
    return setmetatable(frame, { __index = function(_, key)
        if key == "TitleText" then return nil end
        if key == "Show" then return function(self) self.shown = true end end
        if key == "Hide" then return function(self) self.shown = false end end
        if key == "IsShown" then return function(self) return self.shown end end
        return function() return FakeFrame() end
    end })
end

local function LoadAddonWithOptions(clickFunc)
    _G[clickFunc] = nil   -- left by an earlier spec file's Core.lua; this test must see its own
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua", "Spells.lua", "ClickCast.lua", "Options.lua" })
    CreateFrame, UIParent, UISpecialFrames = FakeFrame, FakeFrame(), {}
    Round = function(value) return math.floor(value + 0.5) end
    MinimalSliderWithSteppersMixin = { Label = { Right = 1 }, Event = { OnValueChanged = 1 } }
    CreateMinimalSliderFormatter = function() end
    ns.Layout = { GetSize = function() return {} end }
    ns.ClickCast.QueueApply = function() end
    ns.charDB = { bindings = {}, hoverKeys = {} }
    ns.db = {}
    ns.Spells:Scan()
    return ns
end

TestAddonCompartment = {}

-- AC1: the compartment finds NeoHeal: the TOC carries its name, its icon and the
-- name of a click function that exists as a global once the addon has loaded.
function TestAddonCompartment:testTheTocNamesAGlobalClickFunction()
    local metadata = ReadTocMetadata()
    lu.assertEquals(metadata.Title, "NeoHeal")
    lu.assertNotNil(metadata.IconTexture)
    local clickFunc = metadata.AddonCompartmentFunc
    lu.assertIsString(clickFunc, "NeoHeal.toc has no AddonCompartmentFunc line")
    LoadAddonWithOptions(clickFunc)
    lu.assertIsFunction(_G[clickFunc], "the TOC's AddonCompartmentFunc is not a global function")
end

-- AC2: a click there opens the options window and a second click closes it.
function TestAddonCompartment:testAClickOpensTheOptionsAndASecondClickClosesThem()
    local clickFunc = ReadTocMetadata().AddonCompartmentFunc
    lu.assertIsString(clickFunc, "NeoHeal.toc has no AddonCompartmentFunc line")
    local ns = LoadAddonWithOptions(clickFunc)
    lu.assertIsFunction(_G[clickFunc], "the TOC's AddonCompartmentFunc is not a global function")
    lu.assertNil(ns.Options.frame)   -- never opened yet

    _G[clickFunc]("NeoHeal", "LeftButton")
    lu.assertNotNil(ns.Options.frame, "the first click built no options window")
    lu.assertTrue(ns.Options.frame:IsShown(), "the first click did not show the options window")

    _G[clickFunc]("NeoHeal", "LeftButton")
    lu.assertFalse(ns.Options.frame:IsShown(), "the second click did not close the options window")
end

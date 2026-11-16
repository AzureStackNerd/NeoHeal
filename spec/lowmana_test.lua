-- Low mana on healers' frames (the story's acceptance criteria are
-- quoted as AC1..AC4): the healer rule shared with "Resource bar: Healers only"
-- and the "OOM" text (UnitButton.lua), its default (Core.lua), strings
-- (Locales/enUS.lua), checkbox (Options.lua) and the fake healer in test mode
-- (Preview.lua). The game's colour curve is played by a fake that interpolates
-- the points the addon gives it, so the 20% line is checked where the addon
-- draws it.
local lu = require("luaunit")
local Support = require("support")

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

-- A value the game hides: any comparison or arithmetic on it raises an error,
-- as on a real secret value.
local function Secret(name)
    local function refuse() error("used the secret " .. name) end
    return setmetatable({}, { __eq = refuse, __lt = refuse, __le = refuse, __add = refuse, __sub = refuse,
                              __mul = refuse, __div = refuse, __unm = refuse, __concat = refuse,
                              __tostring = function() return "secret " .. name end })
end

-- What issecretvalue says is hidden: [value] = true. Core reads issecretvalue
-- when it loads, so it gets this function, which looks in `hidden` at call time.
local hidden = {}
local function InstallSecrets()
    hidden = {}
    issecretvalue = function(value) return value ~= nil and hidden[value] == true end
end

-- A frame, texture or font string that keeps what was done to it: its scripts
-- and hooks, points, whether it shows, its text and every text colour (in
-- `colors`). Any other method (a PascalCase name) returns another such object.
local function Recorder(kind, template)
    local frame = { kind = kind, template = template, scripts = {}, hooks = {}, points = {}, colors = {},
                    attributes = {}, shown = true }
    function frame:SetScript(name, func) self.scripts[name] = func end
    function frame:HookScript(name, func) self.hooks[name] = func end
    function frame:SetPoint(...) table.insert(self.points, { ... }) end
    function frame:ClearAllPoints() self.points = {} end
    function frame:Show() self.shown = true end
    function frame:Hide() self.shown = false end
    function frame:SetShown(shown) self.shown = shown and true or false end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown end
    function frame:SetText(text) self.text = text end
    function frame:SetValue(value) self.value = value end
    function frame:SetTextColor(...) table.insert(self.colors, { ... }) end
    function frame:GetFrameLevel() return 1 end
    function frame:GetWidth() return 10 end
    function frame:GetAttribute(name) return self.attributes[name] end
    function frame:GetName() return "NeoHealTestButton" end
    function frame:CreateFontString(_, _, fontTemplate) return Recorder("FontString", fontTemplate) end
    function frame:CreateTexture() return Recorder("Texture") end
    return setmetatable(frame, { __index = function(_, key)
        if type(key) == "string" and key:match("^%u") then return function() return Recorder() end end
    end })
end

-- Whether the "OOM" text can be seen: shown, and the last colour it got (or the
-- one CreateVisuals gave it) not fully transparent.
local function Visible(text)
    if not text.shown then return false end
    local color = text.colors[#text.colors]
    if not color then return true end
    local alpha = color[4]
    if alpha == nil then return true end
    return alpha > 0
end

-- The game's colour curve: keeps its points and, like C_CurveUtil's, gives the
-- colour at a fraction by linear interpolation between them.
local function ColorCurve()
    local curve = { kind = "color", points = {} }
    function curve:SetType() end
    function curve:AddPoint(x, color) table.insert(self.points, { x, color }) end
    function curve:Evaluate(x)
        local points = self.points
        table.sort(points, function(a, b) return a[1] < b[1] end)
        if x <= points[1][1] then return points[1][2] end
        for index = 2, #points do
            local low, high = points[index - 1], points[index]
            if x <= high[1] then
                local t = (x - low[1]) / (high[1] - low[1])
                local result = {}
                for channel = 1, 4 do
                    result[channel] = low[2][channel] + t * (high[2][channel] - low[2][channel])
                end
                return result
            end
        end
        return points[#points][2]
    end
    return curve
end

local function Color(r, g, b, a)
    local color = { r, g, b, a }
    function color:GetRGBA() return self[1], self[2], self[3], self[4] end
    return color
end

-- The unit API for one member, from the fields of `member`: role, class, isPlayer,
-- dead, connected, mana (0..1) and rage (0..1). With `curves` the 12.x curve API is
-- there (as in the game); without it NeoHeal falls back to UnitPower/UnitPowerMax.
-- A colour curve passed to UnitPowerPercent is evaluated at the member's mana, or
-- when `member.secretColor` is set, that is what the colour's GetRGBA gives.
local function InstallUnitApi(member, curves)
    Override("unpack", unpack or table.unpack)
    Override("UnitGroupRolesAssigned", function() return member.role end)
    Override("UnitIsPlayer", function() return member.isPlayer end)
    Override("UnitClass", function() return "Someone", member.class end)
    Override("UnitIsConnected", function() return member.connected end)
    Override("UnitIsDeadOrGhost", function() return member.dead end)
    Override("UnitExists", function() return true end)
    local function Fraction(powerType)
        if powerType == 0 then return member.mana end
        return member.rage
    end
    Override("UnitPower", function(_, powerType) return Fraction(powerType) * 100 end)
    Override("UnitPowerMax", function() return 100 end)
    Override("UnitHealth", function() return 50 end)
    Override("UnitHealthMax", function() return 100 end)
    Override("UnitHealthPercent", nil)
    Override("UnitPowerType", function() return 0, "MANA" end)
    Override("PowerBarColor", { MANA = { r = 0, g = 0, b = 1 } })
    member.powerCalls = {}
    if curves then
        Override("CreateColor", Color)
        Override("C_CurveUtil", {
            CreateColorCurve = ColorCurve,
            CreateCurve = function()
                return { kind = "plain", SetType = function() end, AddPoint = function() end }
            end,
        })
        Override("UnitPowerPercent", function(unit, powerType, usePredicted, curve)
            table.insert(member.powerCalls, { unit, powerType, usePredicted, curve })
            if curve and curve.kind == "color" then
                if member.secretColor then
                    local r, g, b = 0.4, 0.75, 1
                    return { GetRGBA = function() return r, g, b, member.secretColor end }
                end
                return Color(table.unpack(curve:Evaluate(Fraction(powerType))))
            end
            return Fraction(powerType)
        end)
    else
        Override("C_CurveUtil", nil)
        Override("UnitPowerPercent", nil)
        Override("CreateColor", nil)
    end
    Enum.LuaCurveType = { Linear = 1 }
end

-- A healer with a role, alive, online, at 10% mana and full rage.
local function Healer(changes)
    local member = { role = "HEALER", class = "PRIEST", isPlayer = true, dead = false, connected = true,
                     mana = 0.1, rage = 1 }
    for key, value in pairs(changes or {}) do member[key] = value end
    return member
end

local function LoadUnitButton(extraFiles)
    local ns = Support.Load({ "Locales/enUS.lua" })
    InstallSecrets()
    local files = { "Core.lua", "Spells.lua", "ClickCast.lua", "UnitButton.lua" }
    for _, file in ipairs(extraFiles or {}) do table.insert(files, file) end
    Support.LoadInto(ns, files)
    ns.db = { layout = { showLowMana = true, powerBar = "all" } }
    return ns
end

---------------------------------------------------------------------------
-- UnitButton.IsHealer and ShowsPowerBar: one healer rule for both (AC2)
---------------------------------------------------------------------------
TestLowManaHealerRule = {}

function TestLowManaHealerRule:tearDown() Restore() end

function TestLowManaHealerRule:setUp()
    self.ns = LoadUnitButton()
    self.UnitButton = self.ns.UnitButton
end

function TestLowManaHealerRule:IsHealer(role, class)
    return self.UnitButton.IsHealer(role, class) and true or false
end

-- AC2: the assigned Healer role makes a healer, whatever the class.
function TestLowManaHealerRule:testTheHealerRoleMakesAHealer()
    lu.assertTrue(self:IsHealer("HEALER", "WARRIOR"), "a warrior with the Healer role isn't a healer")
end

-- AC2: an assigned role other than Healer wins over a healer class.
function TestLowManaHealerRule:testAnotherRoleBeatsTheClass()
    lu.assertFalse(self:IsHealer("DAMAGER", "PRIEST"), "a priest with the Damage role counts as a healer")
    lu.assertFalse(self:IsHealer("TANK", "DRUID"), "a druid with the Tank role counts as a healer")
end

-- AC2: without a role (none, or "NONE") Priest, Druid, Paladin and Shaman are healers.
function TestLowManaHealerRule:testWithoutARoleTheClassDecides()
    for _, role in ipairs({ "NONE", false }) do
        for _, class in ipairs({ "PRIEST", "DRUID", "PALADIN", "SHAMAN" }) do
            lu.assertTrue(self:IsHealer(role or nil, class), class .. " without a role isn't a healer")
        end
        for _, class in ipairs({ "WARRIOR", "MAGE", "ROGUE", "WARLOCK", "HUNTER" }) do
            lu.assertFalse(self:IsHealer(role or nil, class), class .. " without a role counts as a healer")
        end
        lu.assertFalse(self:IsHealer(role or nil, nil), "no role and no class (a pet) counts as a healer")
    end
end

-- AC2: "Resource bar: Healers only" uses the same rule; the other choices ignore it.
function TestLowManaHealerRule:testHealersOnlyUsesTheRule()
    self.ns.db.layout.powerBar = "healers"
    lu.assertTrue(self.UnitButton.ShowsPowerBar("NONE", "SHAMAN"), "healers only: no bar for a shaman without a role")
    lu.assertFalse(self.UnitButton.ShowsPowerBar("DAMAGER", "PRIEST"), "healers only: a bar for a damage priest")
    self.ns.db.layout.powerBar = "all"
    lu.assertTrue(self.UnitButton.ShowsPowerBar("DAMAGER", "WARRIOR"), "all: no bar for a warrior")
    self.ns.db.layout.powerBar = "none"
    lu.assertFalse(self.UnitButton.ShowsPowerBar("HEALER", "PRIEST"), "none: a bar for a healer")
end

---------------------------------------------------------------------------
-- UnitButton.UpdateLowMana: the "OOM" text on a real frame's font string
---------------------------------------------------------------------------
TestLowManaText = {}

function TestLowManaText:tearDown() Restore() end

-- `curves` false: a client without the curve API.
function TestLowManaText:setUp(curves)
    self.ns = LoadUnitButton()
    self.member = Healer()
    InstallUnitApi(self.member, curves ~= false)
    self.button = { unit = "raid1", lowManaText = Recorder("FontString") }
    self.button.lowManaText:Hide()
end

-- Updates the text for `changes` to the member, and says whether it can be seen.
function TestLowManaText:Shows(changes)
    for key, value in pairs(changes or {}) do self.member[key] = value end
    self.ns.UnitButton.UpdateLowMana(self.button)
    return Visible(self.button.lowManaText)
end

-- AC1: at 20% mana or less the text shows.
function TestLowManaText:testAHealerAt20PercentOrLessShowsIt()
    for _, mana in ipairs({ 0.2, 0.1, 0 }) do
        lu.assertTrue(self:Shows({ mana = mana }), "no OOM at " .. mana * 100 .. "% mana")
    end
end

-- AC1: above 20% it doesn't.
function TestLowManaText:testAbove20PercentItDoesNot()
    for _, mana in ipairs({ 0.21, 0.5, 1 }) do
        lu.assertFalse(self:Shows({ mana = mana }), "OOM at " .. mana * 100 .. "% mana")
    end
end

-- AC1: the text is blue.
function TestLowManaText:testTheTextIsBlue()
    lu.assertTrue(self:Shows())
    local r, g, b = table.unpack(self.button.lowManaText.colors[#self.button.lowManaText.colors])
    lu.assertTrue(b > r and b > g, "the OOM text isn't blue: " .. r .. ", " .. g .. ", " .. b)
end

-- The mana is read, not the bar the unit has now: a druid in bear form at 10%
-- mana and full rage shows it.
function TestLowManaText:testADruidInFormShowsTheirMana()
    lu.assertTrue(self:Shows({ class = "DRUID", role = "NONE", mana = 0.1, rage = 1 }), "a druid at 10% mana shows no OOM")
    lu.assertFalse(self:Shows({ mana = 0.9, rage = 0 }), "a druid at 90% mana and no rage shows OOM")
end

-- AC3: mana hidden in combat goes to the game's curve untouched, and the colour
-- the curve gives goes straight to the text.
function TestLowManaText:testSecretManaGoesThroughTheCurve()
    local mana, alpha = Secret("mana"), Secret("alpha")
    hidden[mana], hidden[alpha] = true, true
    self.member.mana, self.member.secretColor = mana, alpha
    local ok, problem = pcall(self.ns.UnitButton.UpdateLowMana, self.button)
    lu.assertTrue(ok, "secret mana was compared or computed with: " .. tostring(problem))
    local text = self.button.lowManaText
    lu.assertTrue(text.shown, "the text isn't shown for the curve's colour to show or hide it")
    lu.assertTrue(rawequal(text.colors[#text.colors][4], alpha), "the curve's colour didn't go to the text untouched")
    lu.assertEquals(self.member.powerCalls[#self.member.powerCalls][2], 0, "the curve wasn't asked for mana")
end

-- A client that refuses the secret colour: no text, rather than a wrong one.
function TestLowManaText:testARefusedColourShowsNothing()
    self.button.lowManaText:Show()
    function self.button.lowManaText:SetTextColor() error("refused") end
    lu.assertFalse(self:Shows({ mana = 0.9 }), "OOM shows while the colour that hides it was refused")
end

function TestLowManaText:testTheOptionOffHidesIt()
    self.ns.db.layout.showLowMana = false
    lu.assertFalse(self:Shows(), "OOM with Show low mana off")
end

-- AC3: dead or offline: no text.
function TestLowManaText:testADeadHealerShowsNothing()
    lu.assertFalse(self:Shows({ dead = true }), "OOM on a dead healer")
end

function TestLowManaText:testAnOfflineHealerShowsNothing()
    lu.assertFalse(self:Shows({ connected = false }), "OOM on an offline healer")
end

function TestLowManaText:testAButtonWithoutAUnitShowsNothing()
    self.button.unit = nil
    self.button.lowManaText:Show()
    local ok, problem = pcall(self.ns.UnitButton.UpdateLowMana, self.button)
    lu.assertTrue(ok, "a button without a unit errors: " .. tostring(problem))
    lu.assertFalse(Visible(self.button.lowManaText), "OOM on a button without a unit")
end

-- AC2: healers only, by role, else by class.
function TestLowManaText:testOnlyHealersShowIt()
    lu.assertFalse(self:Shows({ role = "NONE", class = "MAGE" }), "OOM on a mage")
    lu.assertFalse(self:Shows({ role = "DAMAGER", class = "PRIEST" }), "OOM on a priest with the Damage role")
    self.button.healerUnit = nil
    lu.assertTrue(self:Shows({ role = "NONE", class = "DRUID" }), "no OOM on a druid without a role")
end

-- Pets have no class; a pet never shows it.
function TestLowManaText:testAPetShowsNothing()
    lu.assertFalse(self:Shows({ role = "NONE", class = "PRIEST", isPlayer = false }), "OOM on a pet")
end

-- AC2: the resource-bar setting doesn't decide who is a healer.
function TestLowManaText:testTheResourceBarSettingDoesntMatter()
    self.ns.db.layout.powerBar = "none"
    lu.assertTrue(self:Shows(), "no OOM on a healer with the resource bar off")
    self.ns.db.layout.powerBar = "all"
    lu.assertFalse(self:Shows({ role = "NONE", class = "MAGE" }), "OOM on a mage with resource bars for all")
end

-- AC2/AC3: a role hidden in combat keeps what was known: a priest with the
-- Damage role doesn't turn into a healer by class for the length of the fight.
function TestLowManaText:testAHiddenRoleKeepsWhatWasKnown()
    lu.assertFalse(self:Shows({ role = "DAMAGER", class = "PRIEST" }))
    local role = Secret("role")
    hidden[role] = true
    lu.assertFalse(self:Shows({ role = role }), "a damage priest shows OOM once their role is hidden")
end

-- A role hidden before anything was known: the class decides.
function TestLowManaText:testAHiddenRoleWithNothingKnownFallsBackToTheClass()
    local role = Secret("role")
    hidden[role] = true
    lu.assertTrue(self:Shows({ role = role, class = "PRIEST" }), "a priest with a hidden role shows no OOM")
end

-- A new unit on the button (the group changed) reads the role again.
function TestLowManaText:testANewUnitReadsTheRoleAgain()
    lu.assertTrue(self:Shows({ role = "HEALER", class = "PRIEST" }))
    local role = Secret("role")
    hidden[role] = true
    self.button.unit = "raid2"
    lu.assertFalse(self:Shows({ role = role, class = "MAGE" }), "the last unit's healer role stuck to the new unit")
end

-- A hidden class is no class: without a role, no healer.
function TestLowManaText:testAHiddenClassIsNoClass()
    hidden.PRIEST = true
    lu.assertFalse(self:Shows({ role = "NONE", class = "PRIEST" }), "a hidden class counted as a healer class")
end

-- Without the curve API the readable fraction decides, on the same line.
function TestLowManaText:testWithoutCurvesTheFractionDecides()
    self:setUp(false)
    lu.assertTrue(self:Shows({ mana = 0.2 }), "no OOM at 20% mana without curves")
    lu.assertFalse(self:Shows({ mana = 0.21 }), "OOM at 21% mana without curves")
end

-- A new member behind the target (or focus) frame keeps the unit token, so the
-- healer answer kept for a hidden role must go with the old member.
function TestLowManaText:testANewTargetDoesntInheritTheHealerAnswer()
    local noop = function() end
    local button = self.button
    button.unit = "target"
    button.events = { UnregisterAllEvents = noop, RegisterUnitEvent = noop }
    button.GetName = function() return "NeoHealTarget" end
    local container = { UpdateAllAuras = noop }
    button.dispelContainer, button.raidDebuffContainer = container, container
    self.ns.Hots = { SetUnit = noop }
    self.ns.AuraContainer = { SetUnit = noop }
    self.ns.UnitButton.buttons[button] = true
    lu.assertTrue(self:Shows({ role = "HEALER", class = "PRIEST" }))
    Override("UnitExists", function() return false end)   -- SetUnit stops before UpdateAll: the next event updates
    local role = Secret("role")
    hidden[role] = true
    self.member.role, self.member.class = role, "MAGE"
    self.ns.UnitButton:ReloadUnitButtons("target")
    lu.assertFalse(self:Shows(), "a new target inherited the old target's healer answer")
end

-- UnitButton.ShowLowMana, which test mode uses: shown at 20% or less.
function TestLowManaText:testShowLowManaForAReadableFraction()
    local frame = { lowManaText = Recorder("FontString") }
    self.ns.UnitButton.ShowLowMana(frame, 0.2)
    lu.assertTrue(frame.lowManaText.shown, "ShowLowMana hides it at 20%")
    self.ns.UnitButton.ShowLowMana(frame, 0.201)
    lu.assertFalse(frame.lowManaText.shown, "ShowLowMana shows it above 20%")
end

---------------------------------------------------------------------------
-- A real unit button on recording frames: CreateVisuals, and the unit events
-- that update the text
---------------------------------------------------------------------------
TestLowManaButton = {}

function TestLowManaButton:tearDown() Restore() end

function TestLowManaButton:setUp()
    local ns = LoadUnitButton()
    self.member = Healer({ mana = 0.5 })
    InstallUnitApi(self.member, true)
    Override("CreateFrame", function(kind, _, _, template) return Recorder(kind, template) end)
    Override("SecureHandlerWrapScript", function() end)
    local noop = function() end
    ns.Hots = { Attach = noop, SetUnit = noop }
    ns.MissingBuffs = { Attach = noop, ExplainClick = noop }
    ns.ClickCast.ApplyToButton = noop
    ns.db.layout.healthColor = "class"
    ns.db.layout.healthText = "none"
    self.button = Recorder("Button")
    ns.UnitButton.Init(self.button)   -- no unit yet: nothing is read
    self.button.unit = "raid1"
    self.ns = ns
end

-- Sends a unit event to the button, as the game does to its events frame.
function TestLowManaButton:Event(event, changes)
    for key, value in pairs(changes or {}) do self.member[key] = value end
    local events = self.button.events
    events.scripts.OnEvent(events, event)
    return Visible(self.button.lowManaText)
end

-- AC1: "OOM" over the middle of the health bar, small, hidden at first.
function TestLowManaButton:testTheTextSitsOverTheMiddleOfTheHealthBar()
    local text = self.button.lowManaText
    lu.assertNotNil(text, "the frame has no low mana text")
    lu.assertEquals(text.kind, "FontString")
    lu.assertEquals(text.text, "OOM")
    lu.assertEquals(text.template, "GameFontNormalSmall")
    lu.assertEquals(#text.points, 1)
    lu.assertEquals(text.points[1][1], "CENTER")
    lu.assertIs(text.points[1][2], self.button.health, "not placed on the health bar")
    lu.assertEquals(text.points[1][3], "CENTER")
    lu.assertFalse(text.shown, "OOM shows on a new frame")
end

-- AC1: a change of mana updates the text.
function TestLowManaButton:testAManaChangeUpdatesTheText()
    lu.assertTrue(self:Event("UNIT_POWER_UPDATE", { mana = 0.1 }), "the mana event didn't show OOM")
    lu.assertFalse(self:Event("UNIT_POWER_UPDATE", { mana = 0.5 }), "the mana event didn't hide OOM")
end

-- AC2: also with the resource bar off for this member.
function TestLowManaButton:testAManaChangeUpdatesTheTextWithoutAResourceBar()
    self.ns.db.layout.powerBar = "none"
    lu.assertTrue(self:Event("UNIT_POWER_UPDATE", { mana = 0.1 }), "with the resource bar off, OOM never shows")
end

-- AC3: dying hides it, coming back shows it again: the health event updates it.
function TestLowManaButton:testDyingAndComingBackUpdateTheText()
    lu.assertTrue(self:Event("UNIT_POWER_UPDATE", { mana = 0.1 }))
    lu.assertFalse(self:Event("UNIT_HEALTH", { dead = true }), "OOM stayed on a healer who died")
    lu.assertTrue(self:Event("UNIT_HEALTH", { dead = false }), "OOM didn't come back with the healer")
end

-- AC2: "Resource bar: Healers only" on a real frame follows the healer rule.
function TestLowManaButton:testHealersOnlyResourceBarFollowsTheRule()
    self.ns.db.layout.powerBar = "healers"
    self:Event("UNIT_POWER_UPDATE", { role = "NONE", class = "MAGE" })
    lu.assertFalse(self.button.powerBarShown, "healers only: a mage got a resource bar")
    self.button.unit = "raid2"
    self:Event("UNIT_POWER_UPDATE", { role = "NONE", class = "SHAMAN" })
    lu.assertTrue(self.button.powerBarShown, "healers only: a shaman got no resource bar")
    self.ns.db.layout.powerBar = "all"
    self.button.unit = "raid3"
    self:Event("UNIT_POWER_UPDATE", { role = "NONE", class = "MAGE" })
    lu.assertTrue(self.button.powerBarShown, "all: a mage got no resource bar")
end

-- A role hidden in combat keeps the resource bar as it was.
function TestLowManaButton:testAHiddenRoleKeepsTheResourceBar()
    self.ns.db.layout.powerBar = "healers"
    self:Event("UNIT_POWER_UPDATE", { role = "DAMAGER", class = "PRIEST" })
    lu.assertFalse(self.button.powerBarShown)
    local role = Secret("role")
    hidden[role] = true
    self:Event("UNIT_POWER_UPDATE", { role = role })
    lu.assertFalse(self.button.powerBarShown, "a damage priest got a resource bar once their role was hidden")
end

---------------------------------------------------------------------------
-- Core.lua, Locales/enUS.lua, Options.lua: the setting (AC4)
---------------------------------------------------------------------------
TestLowManaSetting = {}

function TestLowManaSetting:tearDown()
    NeoHealDB, NeoHealCharDB = nil, nil
    Restore()
end

-- AC4: on by default.
function TestLowManaSetting:testOnByDefault()
    local ns = Support.Load({ "Locales/enUS.lua", "Core.lua" })
    local noop = function() end
    ns.Spells, ns.Dispel, ns.MissingBuffs = { Scan = noop }, { UpdateKnownDispels = noop }, { UpdateKnownBuffs = noop }
    ns.ClickCast, ns.Layout = { Initialize = noop, Apply = noop }, { Create = noop }
    ns.Options, ns.Print = { RegisterSettingsCategory = noop }, noop
    NeoHealDB, NeoHealCharDB = nil, nil
    ns:PLAYER_LOGIN()
    lu.assertEquals(NeoHealDB.layout.showLowMana, true, "Show low mana isn't on by default")
end

-- AC1/AC4: the strings.
function TestLowManaSetting:testTheStrings()
    local ns = Support.Load({ "Locales/enUS.lua" })
    lu.assertEquals(ns.L.SHOW_LOW_MANA, "Show low mana")
    lu.assertEquals(ns.L.LOW_MANA_TEXT, "OOM")
end

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

-- AC4: a "Show low mana" checkbox on the Layout page switches the setting.
function TestLowManaSetting:testTheLayoutPageHasTheCheckbox()
    local ns = Support.Load({ "Locales/enUS.lua", "Spells.lua", "ClickCast.lua", "Options.lua" })
    texts = {}
    Override("CreateFrame", function(_, _, parent) return OptionsFrame(parent) end)
    Override("UIParent", OptionsFrame())
    Override("UISpecialFrames", {})
    Override("Round", function(value) return math.floor(value + 0.5) end)
    Override("MinimalSliderWithSteppersMixin", { Label = { Right = 1 }, Event = { OnValueChanged = 1 } })
    Override("CreateMinimalSliderFormatter", function() end)
    ns.Layout = { GetSize = function() return {} end, Refresh = function() end }
    ns.RunOutOfCombat = function(_, _, func) func() end
    ns.ClickCast.QueueApply = function() end
    ns.charDB = { bindings = {}, hoverKeys = {} }
    ns.db = { layout = { showLowMana = true } }
    ns.Spells:Scan()
    ns.Options:Create()
    local checkbox
    for _, frame in ipairs(texts) do
        if frame.text == "Show low mana" then checkbox = frame.owner end
    end
    lu.assertNotNil(checkbox, "no Show low mana checkbox")
    rawset(checkbox, "GetChecked", function() return false end)
    checkbox.scripts.OnClick(checkbox)
    lu.assertEquals(ns.db.layout.showLowMana, false, "the checkbox doesn't switch showLowMana")
end

---------------------------------------------------------------------------
-- Preview.lua: test mode shows it on one fake healer (AC4)
---------------------------------------------------------------------------
TestLowManaPreview = {}

function TestLowManaPreview:tearDown() Restore() end

function TestLowManaPreview:setUp()
    local ns = LoadUnitButton({ "Preview.lua" })
    Override("unpack", unpack or table.unpack)
    Override("CreateFrame", function(kind, _, _, template) return Recorder(kind, template) end)
    Override("RAID_CLASS_COLORS", setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end }))
    Override("PowerBarColor", setmetatable({}, { __index = function() return { r = 0, g = 0, b = 1 } end }))
    local noop = function() end
    ns.Hots = { Attach = noop, ShowPreview = noop }
    ns.MissingBuffs = { Attach = noop, ShowPreview = noop }
    ns.Dispel = { known = {}, COLORS = {} }
    ns.AuraContainer = { ApplyTimerSetting = noop }
    ns.Layout = { container = Recorder("Frame"), SORT_ORDERS = { index = { sortMethod = "INDEX" } },
                  GetSize = function() return { buttonWidth = 80, buttonHeight = 36, spacing = 2 } end }
    local layout = ns.db.layout
    layout.healthColor, layout.healthText, layout.sortOrder = "class", "none", "index"
    layout.mainTankPosition, layout.showPets = "none", true
    self.ns = ns
end

-- The names of the shown fake frames that show "OOM". Every frame starts this
-- round with the text on, as a frame reused from an earlier round may have it.
function TestLowManaPreview:ShowingOom()
    local Preview = self.ns.Preview
    Preview:Show(40)
    for _, frame in ipairs(Preview.frames) do frame.lowManaText:Show() end
    Preview:Show(40)
    local names = {}
    for _, frame in ipairs(Preview.frames) do
        if frame.shown and Visible(frame.lowManaText) then table.insert(names, frame.nameText.text) end
    end
    return names
end

-- AC4: one fake healer (member 2, the first priest) shows it; no one else, pets
-- neither.
function TestLowManaPreview:testOneFakeHealerShowsIt()
    lu.assertEquals(self:ShowingOom(), { "Seraphine" })
end

-- The fake healer's resource bar shows the same low mana as the text.
function TestLowManaPreview:testTheFakeHealersBarAgreesWithTheText()
    self:ShowingOom()
    for _, frame in ipairs(self.ns.Preview.frames) do
        if frame.nameText.text == "Seraphine" then
            lu.assertTrue(frame.power.value <= 0.2, "the fake healer shows OOM with a bar at " .. frame.power.value)
            return
        end
    end
    lu.fail("no fake healer Seraphine")
end

function TestLowManaPreview:testNoPetShowsIt()
    local names = self:ShowingOom()
    for _, pet in ipairs({ "Shadowmaw", "Fang", "Rattlecrest", "Zhaazar", "Grothak", "Xanrith" }) do
        for _, name in ipairs(names) do
            lu.assertNotEquals(name, pet, "the fake pet " .. pet .. " shows OOM")
        end
    end
end

function TestLowManaPreview:testNotWithTheOptionOff()
    self.ns.db.layout.showLowMana = false
    lu.assertEquals(self:ShowingOom(), {}, "test mode shows OOM with Show low mana off")
end

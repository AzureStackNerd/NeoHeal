-- The cancel cue (the story's acceptance criteria are quoted as AC1..AC7, its
-- scenario rows as S1..S51, docs/refinements/cancel-cue.md): a band on the health
-- bar of the frame you clicked to start a heal, gold while the member still needs
-- it and red once they are above 90% health, gone when the cast ends. Real unit
-- buttons draw on Recorder frames, clicked through their scripts and hooks
-- (Support.Click); your cast events go through Core's event frame
-- (Support.FireEvent), so a test also fails when an event is not registered. The
-- test plays the game: it decides which cast a click starts and which events
-- follow, from the rows, never from NeoHeal's code.
--
-- Health runs three ways, as the code can meet it: readable without the curve API,
-- readable with it, and hidden in combat, where only a colour curve can turn it
-- into the cue's look; a hidden colour is read back through Support.Reveal.
--
-- What these tests can't reach: whether Forever sends your cast events, in which
-- order around a click, whether a hover key's virtual click runs PreClick, and the
-- client's spell queue. None of that is checked in game.
local lu = require("luaunit")
local Support = require("support")
local unpack = unpack or table.unpack

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

local T0 = 1000
local GREATER_HEAL = Support.GREATER_HEAL
local FLASH_HEAL = Support.FLASH_HEAL[1]
local PRAYER_OF_HEALING = Support.PRAYER_OF_HEALING
local CHAIN_HEAL = Support.CHAIN_HEAL
local RESURRECTION = Support.RESURRECTION
local RENEW = Support.RENEW
local HEALTH_FUNNEL = Support.HEALTH_FUNNEL
local MIND_FLAY = Support.MIND_FLAY

-- The option's key in NeoHealDB.layout (the Developer's name).
local OPTION = "showCancelCue"

-- Health the three ways: "readable" (no curve API, out of combat), "curves" (the
-- curve API, out of combat), "combat" (the curve API, health hidden).
local MODES = { "readable", "curves", "combat" }

---------------------------------------------------------------------------
-- The curve API as the 12.x client describes it, evaluated linearly
---------------------------------------------------------------------------
local function Color(r, g, b, a)
    local color = { r, g, b, a or 1 }
    function color:GetRGB() return self[1], self[2], self[3] end
    function color:GetRGBA() return self[1], self[2], self[3], self[4] end
    return color
end

local function Curve(kind)
    local curve = { kind = kind, points = {} }
    function curve:SetType() end
    function curve:AddPoint(x, y)
        table.insert(self.points, { x, y })
        table.sort(self.points, function(p, q) return p[1] < q[1] end)
    end
    function curve:Evaluate(x)
        local points = self.points
        local function At(point)
            if self.kind == "plain" then return point[2] end
            return { point[2][1], point[2][2], point[2][3], point[2][4] }
        end
        if x <= points[1][1] then return At(points[1]) end
        for index = 2, #points do
            local p, q = points[index - 1], points[index]
            if x <= q[1] then
                local t = (x - p[1]) / (q[1] - p[1])
                if self.kind == "plain" then return p[2] + (q[2] - p[2]) * t end
                local color = {}
                for channel = 1, 4 do color[channel] = p[2][channel] + (q[2][channel] - p[2][channel]) * t end
                return color
            end
        end
        return At(points[#points])
    end
    return curve
end

---------------------------------------------------------------------------
-- The world: health per unit, death, offline, combat, the clock
---------------------------------------------------------------------------
TestCastCue = {}

function TestCastCue:tearDown()
    Support.SetModifiers({})
    Restore()
end

function TestCastCue:setUp()
    self:Fresh("readable")
end

-- A fresh addon (as at a reload) with health read `mode`'s way. Every member is at
-- 50%, alive, online; you are a priest; one heal on left click, Greater Heal on the
-- clicked member.
function TestCastCue:Fresh(mode)
    local ns = Support.LoadUnitButtons(Override)
    self.ns, self.UnitButton, self.mode = ns, ns.UnitButton, mode
    ns.db.layout[OPTION] = true
    self.health, self.dead, self.offline, self.guids = {}, {}, {}, {}
    self.inCombat = mode == "combat"
    self.guid = 0
    Support.SetTime(T0)
    local world = self
    local function Fraction(unit)
        local fraction = world.health[unit] or 0.5
        if world.dead[unit] then fraction = 0 end
        return fraction
    end
    local function Hide(name, value)
        if world.inCombat then return Support.Secret(name, value) end
        return value
    end
    Override("InCombatLockdown", function() return world.inCombat end)
    Override("UnitIsDeadOrGhost", function(unit) return world.dead[unit] == true end)
    Override("UnitIsConnected", function(unit) return not world.offline[unit] end)
    Override("UnitHealth", function(unit) return Hide("health", Fraction(unit) * 100) end)
    Override("UnitHealthMax", function() return 100 end)
    Override("UnitGUID", function(unit) return world.guids[unit] or ("Player-" .. tostring(unit)) end)
    Override("GameTooltip", { IsOwned = function() return false end, Hide = function() end })   -- OnLeave asks it
    if mode == "readable" then
        Override("UnitHealthPercent", nil)
        Override("C_CurveUtil", nil)
        Override("CreateColor", nil)
    else
        Override("CreateColor", Color)
        Override("C_CurveUtil", {
            CreateCurve = function() return Curve("plain") end,
            CreateColorCurve = function() return Curve("color") end,
        })
        Enum.LuaCurveType = { Linear = 1, Step = 2 }
        Override("UnitHealthPercent", function(unit, _, curve)
            local fraction = Fraction(unit)
            if not curve then return Hide("health fraction", fraction) end
            if curve.kind == "plain" then return Hide("health percent", curve:Evaluate(fraction)) end
            local rgba = curve:Evaluate(fraction)
            return Color(Hide("r", rgba[1]), Hide("g", rgba[2]), Hide("b", rgba[3]), Hide("a", rgba[4]))
        end)
    end
    self:Bind("1", { spellID = GREATER_HEAL })
end

-- Sets binding `key` ("1", "shift-2", "-neokey1") as the options would save it and
-- applies it: a spell on the clicked member unless `changes` says otherwise.
function TestCastCue:Bind(key, changes)
    local binding = { action = "spell", spellID = GREATER_HEAL, target = "unit", alsoTarget = false }
    for field, value in pairs(changes or {}) do binding[field] = value end
    if binding.action ~= "spell" then binding.spellID, binding.alsoTarget = nil, nil end
    local bindings = self.ns.charDB.bindings
    bindings[key] = binding
    self.ns.ClickCast.appliedBindings = CopyTable(bindings)
end

function TestCastCue:Button(unit)
    return Support.RealButton(self.ns, unit)
end

function TestCastCue:At(seconds)
    Support.SetTime(T0 + seconds)
end

function TestCastCue:Later(seconds)
    Support.SetTime(Support.now + seconds)
end

-- A click with `mouseButton` while `modifiers` are held.
function TestCastCue:Click(button, mouseButton, modifiers)
    Support.SetModifiers(modifiers or {})
    Support.Click(button, mouseButton or "LeftButton")
    Support.SetModifiers({})
end

function TestCastCue:NewGUID()
    self.guid = self.guid + 1
    return "Cast-" .. self.guid
end

function TestCastCue:Event(event, ...)
    Support.FireEvent(event, ...)
end

-- The game starts your cast of `spellID`: a spell with a cast time sends START; an
-- instant only its success; a channel its channel start and its success.
function TestCastCue:GameStarts(spellID, kind, guid)
    if kind == "cast" then
        self:Event("UNIT_SPELLCAST_START", "player", guid, spellID)
    elseif kind == "instant" then
        self:Event("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spellID)
    elseif kind == "channel" then
        self:Event("UNIT_SPELLCAST_CHANNEL_START", "player", guid, spellID)
        self:Event("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spellID)
    end
end

-- A cast with a cast time that finishes: its success, then its stop.
function TestCastCue:Finish(guid, spellID)
    self:Event("UNIT_SPELLCAST_SUCCEEDED", "player", guid, spellID)
    self:Event("UNIT_SPELLCAST_STOP", "player", guid, spellID)
end

-- The common case: a left click on `button`, and the game starts Greater Heal.
function TestCastCue:ClickAndCast(button, spellID)
    self:Click(button)
    self:Later(0.05)
    local guid = self:NewGUID()
    self:GameStarts(spellID or GREATER_HEAL, "cast", guid)
    return guid
end

-- Health changes to `fraction`: UNIT_HEALTH on every frame of `unit`.
function TestCastCue:Health(unit, fraction)
    self.health[unit] = fraction
    self:UnitEvent(unit, "UNIT_HEALTH")
end

function TestCastCue:UnitEvent(unit, event)
    for button in pairs(self.UnitButton.buttons) do
        if button.unit == unit then button.events.scripts.OnEvent(button.events, event, unit) end
    end
end

local Look = Support.CueLook

-- Every button's look but those in `expected` ({ [button] = look }) is "none".
function TestCastCue:AssertLooks(expected, message)
    for button in pairs(self.UnitButton.buttons) do
        local want = expected[button] or "none"
        lu.assertEquals(Look(button), want, message .. " (" .. tostring(button.unit) .. ", " .. self.mode .. ")")
    end
end

---------------------------------------------------------------------------
-- How the cast starts x the spell x how it ends: 10 x 5 x 9 = 450 cells
---------------------------------------------------------------------------

-- How the cast starts. `counts`: AC4 says this start shows the cue for a heal on
-- one member with a cast time. `refused`: the click starts nothing, and the spell
-- comes from elsewhere `delay` seconds later.
local STARTS = {
    { name = "an unmodified left click", counts = true, key = "1", mouse = "LeftButton" },
    { name = "shift + right click", counts = true, key = "shift-2", mouse = "RightButton", modifiers = { shift = true } },
    { name = "a hover key", counts = true, key = "-neokey1", mouse = "neokey1" },
    { name = "Cast and also target", counts = true, key = "1", mouse = "LeftButton", binding = { alsoTarget = true } },
    { name = "a click on a dead member, which casts your res", counts = false, key = "1", mouse = "LeftButton",
      dead = true },
    { name = "a heal bound to the member's target", counts = false, key = "1", mouse = "LeftButton",
      binding = { target = "target" }, notOnMember = true },
    { name = "a click that starts no cast, the spell elsewhere a second later", counts = false, key = "1",
      mouse = "LeftButton", refused = true, delay = 1 },
    { name = "a Target click, the spell elsewhere at once", counts = false, key = "1", mouse = "LeftButton",
      binding = { action = "target" }, notOnMember = true },
    { name = "a cast from outside NeoHeal", counts = false, noClick = true },
    { name = "a heal started while you channel", counts = true, key = "1", mouse = "LeftButton", channel = true },
}

-- The spell. `eligible`: AC4 says a cue shows for it.
local SPELLS = {
    { name = "a heal with a cast time", id = GREATER_HEAL, kind = "cast", eligible = true },
    { name = "a group heal with a cast time", id = PRAYER_OF_HEALING, kind = "cast", eligible = false },
    { name = "a res", id = RESURRECTION, kind = "cast", eligible = false },
    { name = "an instant", id = RENEW, kind = "instant", eligible = false },
    { name = "a channel", id = HEALTH_FUNNEL, kind = "channel", eligible = false },
}

local ENDS = {
    "it finishes", "only its success is reported", "you cancel it (its stop alone)", "it is interrupted",
    "it fails at its end", "it is pushed back first", "a second click is refused", "a second click is queued",
    "the queued cast's start comes before this cast's end",
}

-- Starts `start` with `spell` on `button`. Returns the spell the game casts and its
-- kind, or nil when nothing starts. `beforeStart` runs between the click and the
-- cast's start (a queued click waits for the cast before it).
function TestCastCue:Begin(start, spell, button, guid, beforeStart, noChannel)
    if start.dead then
        self.dead[button.unit] = true
        self:UnitEvent(button.unit, "UNIT_HEALTH")
    end
    local channelGUID = "Channel-" .. guid
    if start.channel and not noChannel then
        self:Event("UNIT_SPELLCAST_CHANNEL_START", "player", channelGUID, MIND_FLAY)
    end
    if not start.noClick then
        local changes = { spellID = spell.id }
        for field, value in pairs(start.binding or {}) do changes[field] = value end
        self:Bind(start.key, changes)
        self:Click(button, start.mouse, start.modifiers)
    end
    if beforeStart then beforeStart() end
    self:Later(start.delay or 0.05)
    local castSpell, kind = spell.id, spell.kind
    if start.dead then
        castSpell, kind = RESURRECTION, "cast"   -- the click snippet's res swap
    elseif spell.id == RESURRECTION and not (start.refused or start.noClick) then
        castSpell = nil   -- the game refuses a res on someone alive
    end
    if castSpell then self:GameStarts(castSpell, kind, guid) end
    if start.channel and not noChannel then
        self:Event("UNIT_SPELLCAST_CHANNEL_STOP", "player", channelGUID, MIND_FLAY)
    end
    return castSpell, kind
end

-- How a cast of `kind` ends, the "how it ends" values that need no second click.
function TestCastCue:End(endName, castSpell, kind, guid)
    if not castSpell or kind == "instant" then return end
    if kind == "channel" then
        self:Event("UNIT_SPELLCAST_CHANNEL_STOP", "player", guid, castSpell)
        return
    end
    if endName == "it finishes" or endName == "it is pushed back first" then
        self:Finish(guid, castSpell)
    elseif endName == "only its success is reported" then
        self:Event("UNIT_SPELLCAST_SUCCEEDED", "player", guid, castSpell)
    elseif endName == "you cancel it (its stop alone)" then
        self:Event("UNIT_SPELLCAST_STOP", "player", guid, castSpell)
    elseif endName == "it is interrupted" then
        self:Event("UNIT_SPELLCAST_INTERRUPTED", "player", guid, castSpell)
    elseif endName == "it fails at its end" then
        self:Event("UNIT_SPELLCAST_FAILED", "player", guid, castSpell)
    else
        self:Finish(guid, castSpell)
    end
end

-- One cell. The expected looks come from AC1, AC2 and AC4: a cue shows only when
-- both the start and the spell count, "running" at 50% health, only on the clicked
-- frame, and no frame shows one once the cast has ended.
function TestCastCue:RunCell(start, spell, endName)
    self:Fresh("readable")
    local first, second = self:Button("party1"), self:Button("party2")
    local cell = start.name .. " / " .. spell.name .. " / " .. endName
    local expected = start.counts and spell.eligible and "running" or "none"

    local guid1 = self:NewGUID()
    local castSpell, kind = self:Begin(start, spell, first, guid1)
    self:AssertLooks({ [first] = expected }, cell .. ": while it casts")

    if endName == "it is pushed back first" then
        self:Event("UNIT_SPELLCAST_DELAYED", "player", guid1, castSpell)
        self:Later(3)   -- past the cast's planned end
        self:AssertLooks({ [first] = expected }, cell .. ": after the pushback")
        self:End(endName, castSpell, kind, guid1)
    elseif endName == "a second click is refused" then
        if not start.noClick then
            self:Later(0.5)
            self:Click(second, start.mouse, start.modifiers)   -- "another action is in progress"
        end
        self:Later(0.2)
        self:AssertLooks({ [first] = expected }, cell .. ": after the refused click")
        self:End("it finishes", castSpell, kind, guid1)
    elseif endName == "a second click is queued" then
        local guid2 = self:NewGUID()
        local castSpell2, kind2 = self:Begin(start, spell, second, guid2, function()
            self:Later(0.2)
            self:End("it finishes", castSpell, kind, guid1)
            self:AssertLooks({}, cell .. ": between the first cast's end and the queued start")
        end, true)
        self:AssertLooks({ [second] = expected }, cell .. ": the queued cast")
        self:End("it finishes", castSpell2, kind2, guid2)
    elseif endName == "the queued cast's start comes before this cast's end" then
        local guid2 = self:NewGUID()
        local castSpell2, kind2 = self:Begin(start, spell, second, guid2, nil, true)
        self:AssertLooks({ [second] = expected }, cell .. ": the queued cast started")
        self:End("it finishes", castSpell, kind, guid1)
        self:AssertLooks({ [second] = expected }, cell .. ": after the first cast's end")
        self:End("it finishes", castSpell2, kind2, guid2)
    else
        self:End(endName, castSpell, kind, guid1)
    end
    self:AssertLooks({}, cell .. ": after the cast")
end

-- AC1, AC2, AC4 over every cell of how the cast starts x the spell x how it ends.
function TestCastCue:testEveryStartSpellAndEnd()
    local cells = 0
    for _, start in ipairs(STARTS) do
        for _, spell in ipairs(SPELLS) do
            for _, endName in ipairs(ENDS) do
                self:RunCell(start, spell, endName)
                cells = cells + 1
            end
        end
    end
    lu.assertEquals(cells, 450, "not every cell ran")
end

---------------------------------------------------------------------------
-- AC1: the two looks follow the member's health
---------------------------------------------------------------------------

-- AC1, S1, S3, S4, S6, S13: "running" from the cast's start below the line, "full"
-- the moment health is above 90%; exactly 90% is "running"; above the line at the
-- start is "full" from the start. In and out of combat, with health read every way.
function TestCastCue:testTheCueTurnsFullAboveTheLine()
    for _, mode in ipairs(MODES) do
        self:Fresh(mode)
        local party1, party2 = self:Button("party1"), self:Button("party2")
        local guid = self:ClickAndCast(party1)
        self:AssertLooks({ [party1] = "running" }, "S1: at 50%")
        self:Health("party1", 0.95)
        self:AssertLooks({ [party1] = "full" }, "S3: above the line")
        self:Health("party1", 0.9)
        self:AssertLooks({ [party1] = "running" }, "S6: exactly 90%")
        self:Health("party1", 0.91)
        self:AssertLooks({ [party1] = "full" }, "S3: at 91%")
        self:Finish(guid, GREATER_HEAL)

        self.health.party2 = 0.95
        self:Later(1)
        guid = self:ClickAndCast(party2)
        self:AssertLooks({ [party2] = "full" }, "S4: above the line at the start")
        self:Finish(guid, GREATER_HEAL)
        self.health.party1 = 0.9
        self:Later(4)
        guid = self:ClickAndCast(party1)
        self:AssertLooks({ [party1] = "running" }, "S6: exactly 90% at the start")
        self:Finish(guid, GREATER_HEAL)
    end
end

-- AC1, S5, S13: above the line, then the damage lands: back to "running" at once.
function TestCastCue:testTheCueTurnsBackBelowTheLine()
    for _, mode in ipairs(MODES) do
        self:Fresh(mode)
        local party1 = self:Button("party1")
        self.health.party1 = 0.97
        self:ClickAndCast(party1)
        self:AssertLooks({ [party1] = "full" }, "S5: before the damage")
        self:Health("party1", 0.6)
        self:AssertLooks({ [party1] = "running" }, "S5: after the damage")
        self:Health("party1", 0.99)
        self:AssertLooks({ [party1] = "full" }, "S13: up again")
    end
end

-- AC1, S41, S42, S51: a 3-pixel band on the bottom edge of the health bar, on the
-- bar itself (so it never draws past it), in both frame styles; its two looks are
-- two colours of their own, whatever colour the health bar or the low-health tint
-- has, and on the bottom edge it can't be taken for the aggro line (top) or the
-- dispel strip (left).
function TestCastCue:testTheCueIsABandOnTheHealthBarsBottomEdge()
    for _, style in ipairs({ "forever", "classic" }) do
        for _, healthColor in ipairs({ "class", "health" }) do
            self:Fresh("curves")
            local layout = self.ns.db.layout
            layout.frameStyle, layout.healthColor = style, healthColor
            local party1 = self:Button("party1")
            local cue = party1.cancelCue
            local where = style .. ", health colour " .. healthColor
            lu.assertNotNil(cue, "no cue texture")
            lu.assertEquals(cue.height, 3, where .. ": the band isn't 3 pixels")
            local anchors = {}
            for _, point in ipairs(cue.points) do anchors[point[1]] = true end
            lu.assertEquals(anchors, { BOTTOMLEFT = true, BOTTOMRIGHT = true },
                where .. ": the band isn't on the bottom edge")
            local onTheBar, parent = false, cue.parent
            while parent do
                if parent == party1.health then onTheBar = true end
                parent = parent.parent
            end
            lu.assertTrue(onTheBar, where .. ": the band isn't on the health bar")
            lu.assertFalse(cue.shown, where .. ": the band shows without a cast")

            self:Health("party1", 0.2)   -- the low-health tint shows
            self:ClickAndCast(party1)
            lu.assertEquals(Look(party1), "running", where .. ": at 20% health")
            self:Health("party1", 0.95)
            lu.assertEquals(Look(party1), "full", where .. ": at 95% health")
        end
    end
end

---------------------------------------------------------------------------
-- AC2: the cue ends with the cast, however it ends
---------------------------------------------------------------------------

-- AC2, S2, S7, S8, S9, S10, S44: each end event alone ends it, in "full" too; a
-- pushed-back cast keeps it, following the health, until the cast really ends.
function TestCastCue:testTheCueEndsWithTheCast()
    local ends = {
        { "S2: it finishes", function(self, guid) self:Finish(guid, GREATER_HEAL) end },
        { "S7: you cancel it", function(self, guid) self:Event("UNIT_SPELLCAST_STOP", "player", guid, GREATER_HEAL) end },
        { "S8: it is interrupted", function(self, guid)
            self:Event("UNIT_SPELLCAST_INTERRUPTED", "player", guid, GREATER_HEAL) end },
        { "S9: it fails", function(self, guid) self:Event("UNIT_SPELLCAST_FAILED", "player", guid, GREATER_HEAL) end },
        { "S44: only its success", function(self, guid)
            self:Event("UNIT_SPELLCAST_SUCCEEDED", "player", guid, GREATER_HEAL) end },
    }
    for _, mode in ipairs(MODES) do
        for _, case in ipairs(ends) do
            self:Fresh(mode)
            local party1 = self:Button("party1")
            local guid = self:ClickAndCast(party1)
            self:Health("party1", 0.95)
            self:AssertLooks({ [party1] = "full" }, case[1] .. ": before the end")
            case[2](self, guid)
            self:AssertLooks({}, case[1])
        end

        self:Fresh(mode)
        local party1 = self:Button("party1")
        local guid = self:ClickAndCast(party1)
        self:Event("UNIT_SPELLCAST_DELAYED", "player", guid, GREATER_HEAL)
        self:Later(4)
        self:AssertLooks({ [party1] = "running" }, "S10: pushed back past its planned end")
        self:Health("party1", 0.95)
        self:AssertLooks({ [party1] = "full" }, "S10: following the health meanwhile")
        self:Finish(guid, GREATER_HEAL)
        self:AssertLooks({}, "S10: after the pushed-back cast")
    end
end

-- AC2, S11, S12, S47: a member who dies or goes offline during the cast (offline
-- at 95%, the last health the game knew) never shows "full", and the cast's end
-- leaves nothing; a res, also once someone else brought the member back, shows none.
function TestCastCue:testADeadOrOfflineMemberNeverShowsFull()
    for _, mode in ipairs(MODES) do
        self:Fresh(mode)
        local party1, party2 = self:Button("party1"), self:Button("party2")
        local guid = self:ClickAndCast(party1)
        self.dead.party1 = true
        self:UnitEvent("party1", "UNIT_HEALTH")
        lu.assertEquals(party1.statusText.text, self.ns.L.DEAD, "S11: the frame doesn't show Dead")
        lu.assertNotEquals(Look(party1), "full", "S11: dead and full (" .. mode .. ")")
        self:Finish(guid, GREATER_HEAL)
        self:AssertLooks({}, "S11: after the cast")

        self.health.party2 = 0.95
        guid = self:ClickAndCast(party2)
        self.offline.party2 = true
        self:UnitEvent("party2", "UNIT_CONNECTION")
        lu.assertEquals(party2.statusText.text, self.ns.L.OFFLINE, "S12: the frame doesn't show Offline")
        lu.assertNotEquals(Look(party2), "full", "S12: offline and full (" .. mode .. ")")
        self:Event("UNIT_SPELLCAST_STOP", "player", guid, GREATER_HEAL)
        self:AssertLooks({}, "S12: after the cast")

        self:Fresh(mode)
        local party3 = self:Button("party3")
        self.dead.party3 = true
        self:UnitEvent("party3", "UNIT_HEALTH")
        guid = self:ClickAndCast(party3, RESURRECTION)   -- the click snippet's res swap
        self:AssertLooks({}, "S33: your res")
        self.dead.party3 = false
        self:Health("party3", 0.95)
        self:AssertLooks({}, "S47: brought back by someone else during your res")
        self:Finish(guid, RESURRECTION)
    end
end

---------------------------------------------------------------------------
-- AC3: on whichever frame you cast on, and only there
---------------------------------------------------------------------------

-- AC3, S14 to S20, S16: your own, a party, raid, main tank group, pet, target and
-- focus frame, in combat (and your own and the target frame out of combat too):
-- "running", "full" above the line, "running" below it, gone at the end. A main
-- tank shown twice gets it on the clicked frame only.
function TestCastCue:testTheCueShowsOnEveryKindOfFrame()
    local cases = {
        { "S15: your own frame", "player", { "combat", "readable" } },
        { "S1: a party member's frame", "party1", { "combat" } },
        { "S14: a raid member's frame", "raid7", { "combat" } },
        { "S16: a main tank group frame", "raid3", { "combat" }, twice = true },
        { "S17: a pet's frame", "raidpet1", { "combat" } },
        { "S17: a party pet's frame", "partypet1", { "combat" } },
        { "S18, S20: the target frame", "target", { "combat", "readable" } },
        { "S19: the focus frame", "focus", { "combat" } },
    }
    for _, case in ipairs(cases) do
        for _, mode in ipairs(case[3]) do
            self:Fresh(mode)
            local clicked = self:Button(case[2])
            local other = case.twice and self:Button(case[2]) or self:Button("party4")
            local guid = self:ClickAndCast(clicked)
            self:AssertLooks({ [clicked] = "running" }, case[1] .. ": at the start")
            self:Health(case[2], 0.95)
            self:AssertLooks({ [clicked] = "full" }, case[1] .. ": above the line")
            self:Health(case[2], 0.4)
            self:AssertLooks({ [clicked] = "running" }, case[1] .. ": below it again")
            self:Finish(guid, GREATER_HEAL)
            self:AssertLooks({}, case[1] .. ": after the cast")
            lu.assertNotNil(other, "no second frame")
        end
    end
end

-- AC3, S22, S49: a roster change that gives the clicked frame another member, or
-- leaves it with none, or keeps its token for someone else (another GUID, or one
-- the game hides): no frame shows the cue for someone the heal isn't going to, the
-- member's new frame shows none, and a frame given a member later shows none.
function TestCastCue:testAFrameGivenAnotherMemberDropsTheCue()
    for _, mode in ipairs({ "readable", "combat" }) do
        self:Fresh(mode)
        local clicked, moved = self:Button("party1"), self:Button("party2")
        local guid = self:ClickAndCast(clicked)
        clicked.hooks.OnAttributeChanged(clicked, "unit", "party2")
        moved.hooks.OnAttributeChanged(moved, "unit", "party1")
        self:AssertLooks({}, "S22: the frames swapped members")
        self:Health("party1", 0.95)
        self:AssertLooks({}, "S22: the member's new frame")
        self:Finish(guid, GREATER_HEAL)

        guid = self:ClickAndCast(clicked)
        clicked.hooks.OnAttributeChanged(clicked, "unit", nil)
        self:AssertLooks({}, "S49: the frame left with no member")
        clicked.hooks.OnAttributeChanged(clicked, "unit", "party3")
        self:AssertLooks({}, "S49: a member given to it later")
        self:Finish(guid, GREATER_HEAL)

        for _, newGUID in ipairs({ "Player-someone-else", Support.Secret("guid") }) do
            local raid3 = self:Button("raid3")
            guid = self:ClickAndCast(raid3)
            self.guids.raid3 = newGUID
            self.UnitButton:UpdateAllButtons()   -- what a roster update runs
            self:AssertLooks({}, "S22: the same token for another member (" .. tostring(newGUID) .. ")")
            self:Finish(guid, GREATER_HEAL)
            self.guids.raid3 = nil
        end
    end
end

-- AC3, S22's control (fix round 1): a roster update that leaves every frame its
-- member (GROUP_ROSTER_UPDATE, a role change, SPELLS_CHANGED and Layout:Refresh all
-- run UpdateAllButtons) keeps the cue on a party, a raid and a pet frame.
function TestCastCue:testARosterUpdateKeepsTheCueForTheSameMember()
    for _, mode in ipairs({ "readable", "combat" }) do
        for _, unit in ipairs({ "party1", "raid3", "raidpet1" }) do
            self:Fresh(mode)
            local clicked = self:Button(unit)
            local guid = self:ClickAndCast(clicked)
            self.UnitButton:UpdateAllButtons()
            self:AssertLooks({ [clicked] = "running" }, "S22 control: a roster update, " .. unit .. " unchanged")
            self:Finish(guid, GREATER_HEAL)
        end
    end
end

-- AC3, S22 (fix round 1): a member whose GUID the game hides when the cast starts
-- can't be told from someone else later, so a roster update takes the cue away.
function TestCastCue:testAHiddenGUIDAtTheCastsStartDropsTheCueOnARosterUpdate()
    local party1 = self:Button("party1")
    self.guids.party1 = Support.Secret("guid")
    local guid = self:ClickAndCast(party1)
    self.guids.party1 = nil   -- readable again, the same member
    self.UnitButton:UpdateAllButtons()
    self:AssertLooks({}, "S22: a GUID hidden at the cast's start")
    self:Finish(guid, GREATER_HEAL)
end

-- AC3, S15 with S22's control (fix round 1): a roster update keeps the cue on your
-- own frame.
function TestCastCue:testARosterUpdateKeepsTheCueOnYourOwnFrame()
    for _, mode in ipairs({ "readable", "combat" }) do
        self:Fresh(mode)
        local own = self:Button("player")
        local guid = self:ClickAndCast(own)
        self.UnitButton:UpdateAllButtons()
        self:AssertLooks({ [own] = "running" }, "S22 control: a roster update, your own frame")
        self:Finish(guid, GREATER_HEAL)
    end
end

-- AC3, S22's control (fix round 1): a group header that sets the "unit" attribute
-- again to the token the frame already has (not checked in game) keeps the cue.
function TestCastCue:testTheSameUnitSetAgainKeepsTheCue()
    for _, unit in ipairs({ "party1", "raid3", "player" }) do
        self:Fresh("readable")
        local clicked = self:Button(unit)
        local guid = self:ClickAndCast(clicked)
        clicked.hooks.OnAttributeChanged(clicked, "unit", unit)
        self:AssertLooks({ [clicked] = "running" }, "the unit attribute set again to " .. unit)
        self:Finish(guid, GREATER_HEAL)
    end
end

-- AC3, S23: the clicked frame hides during the cast: the cue is gone, and shown
-- again it shows none; a frame hidden and shown again in one go keeps it.
function TestCastCue:testAHiddenFrameDropsTheCue()
    local party1 = self:Button("party1")
    local guid = self:ClickAndCast(party1)
    party1.hooks.OnHide(party1)   -- hidden and back before the next frame (Layout:Refresh)
    self:AssertLooks({ [party1] = "running" }, "S23: hidden and shown again in one go")
    party1:Hide()
    party1.hooks.OnHide(party1)
    party1:Show()
    self:AssertLooks({}, "S23: shown again after it hid")
    self:Finish(guid, GREATER_HEAL)
end

---------------------------------------------------------------------------
-- AC4: which ways of casting show it
---------------------------------------------------------------------------

-- AC4, S26 to S34, S43, S45, S31 and its known limit: only a heal with a cast time
-- on the clicked member, started from the frame, shows the cue.
function TestCastCue:testOnlyACastOnTheClickedMemberShowsTheCue()
    -- S26, S27, S28: every button, modifier and hover key, and "Cast and also target".
    local ways = {
        { "S26: shift + right click", "shift-2", "RightButton", { shift = true } },
        { "S26: ctrl + middle click", "ctrl-3", "MiddleButton", { ctrl = true } },
        { "S26: alt + button 4", "alt-4", "Button4", { alt = true } },
        { "S26: button 5", "5", "Button5" },
        { "S27: a hover key", "-neokey1", "neokey1" },
        { "S27: shift + the third hover key", "shift--neokey3", "neokey3", { shift = true } },
        { "S28: Cast and also target", "1", "LeftButton", nil, { alsoTarget = true } },
    }
    for _, way in ipairs(ways) do
        self:Fresh("readable")
        local party1 = self:Button("party1")
        self:Bind(way[2], way[5])
        self:Click(party1, way[3], way[4])
        self:Later(0.05)
        local guid = self:NewGUID()
        self:GameStarts(GREATER_HEAL, "cast", guid)
        self:AssertLooks({ [party1] = "running" }, way[1])
        self:Finish(guid, GREATER_HEAL)
    end

    -- No cue: the cast goes elsewhere, has no cast time, or isn't a heal on one member.
    local none = {
        { "S29: a heal on the member's target", { target = "target" }, GREATER_HEAL, "cast" },
        { "S29: a heal on the member's target's target", { target = "targettarget" }, GREATER_HEAL, "cast" },
        { "S30: an instant", { spellID = RENEW }, RENEW, "instant" },
        { "S34: Prayer of Healing", { spellID = PRAYER_OF_HEALING }, PRAYER_OF_HEALING, "cast" },
        { "S34: Chain Heal, as a shaman", { spellID = CHAIN_HEAL }, CHAIN_HEAL, "cast", "SHAMAN" },
        { "S43: a channel", { spellID = HEALTH_FUNNEL }, HEALTH_FUNNEL, "channel" },
    }
    for _, case in ipairs(none) do
        self:Fresh("readable")
        if case[5] then Override("UnitClass", function() return case[5], case[5] end) end
        local party1 = self:Button("party1")
        self:Bind("1", case[2])
        self:Click(party1)
        self:Later(0.05)
        local guid = self:NewGUID()
        self:GameStarts(case[3], case[4], guid)
        self:AssertLooks({}, case[1])
        self:Finish(guid, case[3])
    end

    -- S33: a dead member, whose click becomes your res.
    self:Fresh("readable")
    local party1 = self:Button("party1")
    self.dead.party1 = true
    self:UnitEvent("party1", "UNIT_HEALTH")
    local guid = self:ClickAndCast(party1, RESURRECTION)
    self:AssertLooks({}, "S33: your res")
    self:Finish(guid, RESURRECTION)

    -- S32: a cast from outside NeoHeal.
    self:Fresh("readable")
    party1 = self:Button("party1")
    guid = self:NewGUID()
    self:GameStarts(GREATER_HEAL, "cast", guid)
    self:AssertLooks({}, "S32: an action bar cast")
    self:Finish(guid, GREATER_HEAL)

    -- S31: a click that starts nothing, then a cast elsewhere: no cue for another
    -- spell, nor for the same spell more than half a second later; the known limit,
    -- the same spell within half a second (or any spell whose details the game
    -- hides), shows it on the clicked frame until that cast ends.
    local refused = {
        { "S31: the same spell 0.55 s later", 0.55, GREATER_HEAL, "none" },
        { "S31: another spell at once", 0.05, FLASH_HEAL, "none" },
        { "S31, known limit: the same spell 0.45 s later", 0.45, GREATER_HEAL, "running" },
        { "S31, known limit: a hidden spell 0.45 s later", 0.45, "hidden", "running" },
    }
    for _, case in ipairs(refused) do
        self:Fresh("readable")
        party1 = self:Button("party1")
        self:Click(party1)
        self:Later(case[2])
        guid = self:NewGUID()
        local spellID = case[3] == "hidden" and Support.Secret("spellID") or case[3]
        self:GameStarts(spellID, "cast", guid)
        self:AssertLooks(case[4] == "none" and {} or { [party1] = case[4] }, case[1])
        self:Finish(guid, spellID)
        self:AssertLooks({}, case[1] .. ": after that cast")
    end

    -- S31: a Target, Menu or missing-buff click, then the heal from an action bar.
    for _, action in ipairs({ "target", "menu", "buff" }) do
        self:Fresh("readable")
        party1 = self:Button("party1")
        self:Bind("1", { action = action })
        self:Click(party1)
        self:Later(0.05)
        guid = self:NewGUID()
        self:GameStarts(GREATER_HEAL, "cast", guid)
        self:AssertLooks({}, "S31: a " .. action .. " click")
        self:Finish(guid, GREATER_HEAL)
    end

    -- S45: a heal started while you channel; the channel's end, before or after the
    -- heal's start, leaves the cue.
    for _, stopFirst in ipairs({ false, true }) do
        self:Fresh("readable")
        party1 = self:Button("party1")
        self:Event("UNIT_SPELLCAST_CHANNEL_START", "player", "Channel-1", MIND_FLAY)
        self:Event("UNIT_SPELLCAST_SUCCEEDED", "player", "Channel-1", MIND_FLAY)
        self:Click(party1)
        self:Later(0.05)
        if stopFirst then self:Event("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Channel-1", MIND_FLAY) end
        guid = self:NewGUID()
        self:GameStarts(GREATER_HEAL, "cast", guid)
        if not stopFirst then self:Event("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Channel-1", MIND_FLAY) end
        self:AssertLooks({ [party1] = "running" }, "S45: the channel's end " .. (stopFirst and "before" or "after"))
        self:Finish(guid, GREATER_HEAL)
    end
end

-- AC4, S24, S25, S46: a refused second click leaves the cue on the first frame; a
-- queued one moves it when its cast starts, whichever end comes first.
function TestCastCue:testASecondClickLeavesTheCueOnTheFirstFrame()
    for _, mode in ipairs({ "readable", "combat" }) do
        self:Fresh(mode)
        local party1, party2 = self:Button("party1"), self:Button("party2")
        local guid1 = self:ClickAndCast(party1)
        self:Later(1)
        self:Click(party2)   -- refused: another action is in progress
        self:Later(0.3)
        self:AssertLooks({ [party1] = "running" }, "S24: after the refused click")
        self:Health("party1", 0.95)
        self:AssertLooks({ [party1] = "full" }, "S24: the first frame still follows its member")
        self:Finish(guid1, GREATER_HEAL)
        self:AssertLooks({}, "S24: after the first cast")

        -- S25: queued near the end; the first cast ends, then the queued one starts.
        self.health.party1 = 0.5
        guid1 = self:ClickAndCast(party1)
        self:Later(2.2)
        self:Click(party2)
        self:Later(0.3)
        self:Finish(guid1, GREATER_HEAL)
        self:AssertLooks({}, "S25: the first cast ended")
        self:Later(0.05)
        local guid2 = self:NewGUID()
        self:GameStarts(GREATER_HEAL, "cast", guid2)
        self:AssertLooks({ [party2] = "running" }, "S25: the queued cast started")
        self:Finish(guid2, GREATER_HEAL)

        -- S46: the queued cast's start comes before the first cast's end.
        guid1 = self:ClickAndCast(party1)
        self:Later(2.2)
        self:Click(party2)
        self:Later(0.3)
        guid2 = self:NewGUID()
        self:GameStarts(GREATER_HEAL, "cast", guid2)
        self:Finish(guid1, GREATER_HEAL)
        self:AssertLooks({ [party2] = "running" }, "S46: after the first cast's late end")
        self:Finish(guid2, GREATER_HEAL)
        self:AssertLooks({}, "S46: after the queued cast")
    end
end

---------------------------------------------------------------------------
-- AC5: the option
---------------------------------------------------------------------------

-- Turns the option on or off the way its checkbox does: the setting, and turned
-- off, UnitButton.ClearCancelCue at once (spec/options_test.lua
-- "testTheCancelCueOptionIsOnTheLayoutPage" proves the checkbox makes that call).
function TestCastCue:SetOption(on)
    self.ns.db.layout[OPTION] = on
    if not on then self.UnitButton.ClearCancelCue() end
end

-- AC5, S35, S36, S37: off, no cue; turned off during a cast, in combat, gone at
-- once; turned on during a cast, none for that cast, the next one shows it.
function TestCastCue:testTheOptionTurnsTheCueOff()
    for _, mode in ipairs({ "readable", "combat" }) do
        self:Fresh(mode)
        local party1 = self:Button("party1")
        self:SetOption(false)
        local guid = self:ClickAndCast(party1)
        self:AssertLooks({}, "S35: the option off")
        self:SetOption(true)
        self:AssertLooks({}, "S37: turned on during that cast")
        self:Health("party1", 0.95)
        self:AssertLooks({}, "S37: turned on during that cast, health changed")
        self:Finish(guid, GREATER_HEAL)
        self:Later(1)
        guid = self:ClickAndCast(party1)
        self:AssertLooks({ [party1] = "full" }, "S37: the next cast")

        self:SetOption(false)   -- in combat in the "combat" mode
        self:AssertLooks({}, "S36: turned off during the cast")
        self:Health("party1", 0.5)
        self:AssertLooks({}, "S36: turned off, health changed")
        self:Finish(guid, GREATER_HEAL)
    end
end

---------------------------------------------------------------------------
-- AC6: never outlasts the cast, never for a cast it didn't see start
---------------------------------------------------------------------------

-- AC6, S38: the game hides your cast's details (castGUID and spell): the cue shows
-- while it runs, follows the health, and is gone when it ends, whichever end event.
function TestCastCue:testTheCueEndsWhenTheGameHidesTheCast()
    for _, mode in ipairs({ "readable", "combat" }) do
        for _, endEvent in ipairs({ "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_FAILED",
                                    "UNIT_SPELLCAST_INTERRUPTED" }) do
            self:Fresh(mode)
            local party1 = self:Button("party1")
            self:Click(party1)
            self:Later(0.05)
            self:Event("UNIT_SPELLCAST_START", "player", Support.Secret("castGUID"), Support.Secret("spellID"))
            self:AssertLooks({ [party1] = "running" }, "S38: a hidden cast")
            self:Health("party1", 0.95)
            self:AssertLooks({ [party1] = "full" }, "S38: a hidden cast, above the line")
            self:Health("party1", 0.5)
            self:AssertLooks({ [party1] = "running" }, "S38: a hidden cast, below it again")
            self:Event(endEvent, "player", Support.Secret("castGUID"), Support.Secret("spellID"))
            self:AssertLooks({}, "S38: " .. endEvent .. " with hidden details")

            -- The start readable, its end hidden (the details hidden from mid-cast on).
            local guid = self:ClickAndCast(party1)
            self:AssertLooks({ [party1] = "running" }, "S38: a readable start")
            self:Event(endEvent, "player", Support.Secret("castGUID", guid), Support.Secret("spellID"))
            self:AssertLooks({}, "S38: " .. endEvent .. " hidden after a readable start")
        end
    end
end

-- AC6, S39: a reload or a login during a cast: no cue until a new cast starts from
-- a frame; the old cast's events and a cast started from elsewhere show none.
function TestCastCue:testNoCueAfterAReload()
    local party1 = self:Button("party1")
    self:ClickAndCast(party1)
    self:AssertLooks({ [party1] = "running" }, "before the login")
    self:Event("PLAYER_ENTERING_WORLD", true, false)
    self:AssertLooks({}, "S39: after a login or a loading screen")

    self:ClickAndCast(party1)
    self:Fresh("readable")   -- a reload, mid-cast
    party1 = self:Button("party1")
    self:Health("party1", 0.95)
    self:Event("UNIT_SPELLCAST_DELAYED", "player", "Cast-1", GREATER_HEAL)
    self:AssertLooks({}, "S39: after a reload")
    self:Later(1)
    local guid = self:NewGUID()
    self:GameStarts(GREATER_HEAL, "cast", guid)
    self:AssertLooks({}, "S39: a cast not started from a frame")
    self:Finish(guid, GREATER_HEAL)
    self:Later(1)
    self:ClickAndCast(party1)
    self:AssertLooks({ [party1] = "full" }, "S39: a new cast from a frame")
end

-- The look and live updates of one unit button: health bar with incoming heals,
-- resource bar, name, status text, range fading, dispel highlight, aggro, raid
-- target icon and tooltip. The secure button itself is created by a group header
-- (see Layout.lua); this module decorates it and keeps it current.
local _, NeoHeal = ...
local L = NeoHeal.L
local IsSecret, IsTrue, IsFalse = NeoHeal.IsSecret, NeoHeal.IsTrue, NeoHeal.IsFalse

local UnitButton = {
    buttons = {},   -- [button] = true for every decorated button
}
NeoHeal.UnitButton = UnitButton

local OUT_OF_RANGE_ALPHA = 0.4
local RANGE_CHECK_INTERVAL = 1   -- seconds; backup for UNIT_IN_RANGE_UPDATE
local WHITE_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local PET_BAR_COLOR = { r = 0.2, g = 0.8, b = 0.2 }
local FALLBACK_POWER_COLOR = { r = 0.0, g = 0.5, b = 1.0 }   -- mana blue
local POWER_BAR_HEIGHT = 4
local AGGRO_THREAT_STATUS = 2    -- UnitThreatSituation: 2 and 3 mean "has aggro"
local AURA_BATCH_DELAY = 0.1     -- seconds; UNIT_AURA bursts on one unit cost one scan

---------------------------------------------------------------------------
-- Health and power values. The 12.x API's Unit*Percent functions work even
-- while the values are secret: the result is secret too, but StatusBars and
-- FontStrings accept it. A curve maps the 0..1 fraction onto the range we want.
---------------------------------------------------------------------------
local curves = {}   -- [maxValue] = curve mapping 0..1 onto 0..maxValue

local function GetCurve(maxValue)
    if not curves[maxValue] then
        local curve = C_CurveUtil.CreateCurve()
        curve:SetType(Enum.LuaCurveType.Linear)
        curve:AddPoint(0, 0)
        curve:AddPoint(1, maxValue)
        curves[maxValue] = curve
    end
    return curves[maxValue]
end

local function GetHealthFraction(unit)   -- 0..1
    if UnitHealthPercent then
        return UnitHealthPercent(unit, true)
    end
    local maxHealth = UnitHealthMax(unit)
    return maxHealth > 0 and UnitHealth(unit) / maxHealth or 0
end

local function GetHealthPercent(unit)    -- 0..100
    if UnitHealthPercent and C_CurveUtil then
        return UnitHealthPercent(unit, true, GetCurve(100))
    end
    return GetHealthFraction(unit) * 100
end

local function GetPowerFraction(unit, powerType)   -- 0..1
    if UnitPowerPercent and C_CurveUtil then
        return UnitPowerPercent(unit, powerType, true, GetCurve(1))
    end
    local maxPower = UnitPowerMax(unit, powerType)
    return maxPower > 0 and UnitPower(unit, powerType) / maxPower or 0
end

local function IsDeadOrOffline(unit)
    return IsFalse(UnitIsConnected(unit)) or IsTrue(UnitIsDeadOrGhost(unit))
end

-- "Health bar color: Health": red at 0%, yellow at 50%, green at 100%.
local HEALTH_COLOR_STOPS = { { 0, 1, 0, 0 }, { 0.5, 1, 1, 0 }, { 1, 0, 1, 0 } }   -- { fraction, r, g, b }
local healthColorCurve

-- The colour for a readable fraction (also used by the test mode preview).
function UnitButton.HealthFractionColor(fraction)
    local low, high = HEALTH_COLOR_STOPS[1], HEALTH_COLOR_STOPS[2]
    if fraction > high[1] then low, high = HEALTH_COLOR_STOPS[2], HEALTH_COLOR_STOPS[3] end
    local t = math.max(0, math.min(1, (fraction - low[1]) / (high[1] - low[1])))
    return low[2] + (high[2] - low[2]) * t, low[3] + (high[3] - low[3]) * t, low[4] + (high[4] - low[4]) * t
end

-- The colour for a unit. On the 12.x API a colour curve gives it even while health
-- is secret (the colour is secret too, which SetStatusBarColor accepts).
local function GetHealthColor(unit)
    if UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateColorCurve then
        if not healthColorCurve then
            healthColorCurve = C_CurveUtil.CreateColorCurve()
            healthColorCurve:SetType(Enum.LuaCurveType.Linear)
            for _, stop in ipairs(HEALTH_COLOR_STOPS) do
                healthColorCurve:AddPoint(stop[1], CreateColor(stop[2], stop[3], stop[4]))
            end
        end
        return UnitHealthPercent(unit, true, healthColorCurve):GetRGB()
    end
    return UnitButton.HealthFractionColor(GetHealthFraction(unit))
end

local function ColorByHealth()
    return NeoHeal.db.layout.healthColor == "health"
end

---------------------------------------------------------------------------
-- Updates, one per aspect of the button
---------------------------------------------------------------------------
local function UpdateIdentity(button)
    local unit = button.unit
    local name = UnitName(unit)
    button.nameText:SetText(name)
    if ColorByHealth() then return end   -- UpdateHealth colours the bar then

    -- Players in their class colour; pets in green.
    local color = PET_BAR_COLOR
    if IsTrue(UnitIsPlayer(unit)) then
        local _, class = UnitClass(unit)
        color = not IsSecret(class) and RAID_CLASS_COLORS[class] or PET_BAR_COLOR
    end
    button.health:SetStatusBarColor(color.r, color.g, color.b)
end

-- Shows `amount` (health points, possibly secret) on one of the bars after the
-- health fill; nil or 0 hides it. A hidden bar is also emptied: the absorb bar is
-- anchored to the end of the incoming heals, which must then be the end of the health.
local function ShowAmountBar(bar, unit, amount)
    if not IsSecret(amount) and (not amount or amount <= 0) then
        bar:SetValue(0)
        bar:Hide()
        return
    end
    -- Secret values can be shown by a StatusBar; pcall in case this client disagrees.
    local ok = pcall(bar.SetMinMaxValues, bar, 0, UnitHealthMax(unit)) and pcall(bar.SetValue, bar, amount)
    if not ok then bar:SetValue(0) end
    bar:SetShown(ok)
end

-- The part of the bar that heals on their way (yours and other healers') will fill.
-- It sits right after the health fill and is clipped at the end of the bar.
local function UpdateIncomingHeals(button)
    local unit = button.unit
    local show = NeoHeal.db.layout.showIncomingHeals and not IsDeadOrOffline(unit)
    ShowAmountBar(button.incoming, unit, show and UnitGetIncomingHeals(unit))
end

-- Shields (Power Word: Shield, ...): right after the incoming heals.
local function UpdateAbsorbs(button)
    local unit = button.unit
    local show = UnitGetTotalAbsorbs and not IsDeadOrOffline(unit)
    ShowAmountBar(button.absorb, unit, show and UnitGetTotalAbsorbs(unit))
end

-- Low health: the empty part of the health bar turns red below this fraction.
-- In combat health can be secret, so a colour curve gives the tint (its alpha
-- jumps from visible to 0 just above the threshold); the result is secret too,
-- which SetVertexColor accepts.
local LOW_HEALTH_THRESHOLD = 0.35
local LOW_HEALTH_COLOR = { 0.8, 0, 0, 0.45 }
local lowHealthCurve

-- For a readable fraction (also used by the test mode preview).
function UnitButton.ShowLowHealth(frame, fraction)
    local r, g, b, a = unpack(LOW_HEALTH_COLOR)
    frame.lowHealth:SetVertexColor(r, g, b, fraction <= LOW_HEALTH_THRESHOLD and a or 0)
    frame.lowHealth:Show()
end

local function UpdateLowHealth(button, isDeadOrOffline)
    local tint, unit = button.lowHealth, button.unit
    if isDeadOrOffline then
        tint:Hide()
        return
    end
    if not (UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateColorCurve) then
        UnitButton.ShowLowHealth(button, GetHealthFraction(unit))
        return
    end

    if not lowHealthCurve then
        local r, g, b, a = unpack(LOW_HEALTH_COLOR)
        lowHealthCurve = C_CurveUtil.CreateColorCurve()
        lowHealthCurve:SetType(Enum.LuaCurveType.Linear)
        lowHealthCurve:AddPoint(0, CreateColor(r, g, b, a))
        lowHealthCurve:AddPoint(LOW_HEALTH_THRESHOLD, CreateColor(r, g, b, a))
        lowHealthCurve:AddPoint(LOW_HEALTH_THRESHOLD + 0.001, CreateColor(r, g, b, 0))
        lowHealthCurve:AddPoint(1, CreateColor(r, g, b, 0))
    end
    local ok = pcall(function()
        tint:SetVertexColor(UnitHealthPercent(unit, true, lowHealthCurve):GetRGBA())
    end)
    tint:SetShown(ok)
end

local function UpdateHealth(button)
    local unit = button.unit
    local status
    if IsFalse(UnitIsConnected(unit)) then
        status = L.OFFLINE
    elseif IsTrue(UnitIsDeadOrGhost(unit)) then
        status = L.DEAD
    end

    if status then
        button.health:SetValue(0)
        button.statusText:SetText(status)
    else
        button.health:SetValue(GetHealthFraction(unit))
        if ColorByHealth() then
            button.health:SetStatusBarColor(GetHealthColor(unit))
        end
        if NeoHeal.db.layout.showHealthText then
            button.statusText:SetText(format("%d%%", GetHealthPercent(unit)))
        else
            button.statusText:SetText("")
        end
    end
    UpdateLowHealth(button, status ~= nil)
    UpdateIncomingHeals(button)
    UpdateAbsorbs(button)
end

-- The looks a frame can have (Layout > Frame style): background, border and bar
-- texture. `inset` is the room the border takes; the bars start inside it.
local FRAME_STYLES = {
    classic = {   -- the stone dialog background with the tooltip border
        backdrop = {
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 16,
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
            insets = { left = 2, right = 2, top = 2, bottom = 2 },
        },
        backgroundColor = { 1, 1, 1, 1 },
        borderColor = { 0.7, 0.7, 0.7, 1 },
        barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
        inset = 3,
    },
    forever = {   -- flat and dark with a thin black line, like the modern raid frames
        backdrop = { bgFile = WHITE_TEXTURE, edgeFile = WHITE_TEXTURE, edgeSize = 1 },
        backgroundColor = { 0.05, 0.05, 0.05, 0.75 },
        borderColor = { 0, 0, 0, 1 },
        barTexture = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
        inset = 1,
    },
}
local INCOMING_HEAL_COLOR = { 0.3, 1, 0.3, 0.5 }
local ABSORB_COLOR = { 0.8, 0.9, 1, 0.6 }

-- "Resource bar: Healers only". Classic players rarely pick a role, so without
-- one the class decides.
local HEALER_CLASSES = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }

-- Whether a member with this role and class gets a resource bar (the preview uses it too).
function UnitButton.ShowsPowerBar(role, class)
    local setting = NeoHeal.db.layout.powerBar
    if setting == "healers" then
        if role and role ~= "NONE" then return role == "HEALER" end
        return HEALER_CLASSES[class] or false
    end
    return setting ~= "none"
end

local function ShowsPowerBarForButton(button)
    local unit = button.unit
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    local class = IsTrue(UnitIsPlayer(unit)) and select(2, UnitClass(unit)) or nil   -- pets: no class
    if IsSecret(role) then
        -- Should the role be hidden in combat, keep the bar as it is (roles don't
        -- change in combat) rather than fall back to the class: a shadow priest
        -- would get a bar for the length of the fight.
        if button.powerBarShown ~= nil then return button.powerBarShown end
        role = nil
    end
    if IsSecret(class) then class = nil end
    return UnitButton.ShowsPowerBar(role, class)
end

-- Places the health bar above the resource bar, or over the full height without
-- one. Only does work when that changed.
local function LayoutBars(button, showPower)
    if button.powerBarShown == showPower then return end
    button.powerBarShown = showPower

    local health, power, inset = button.health, button.power, button.style.inset
    power:SetShown(showPower)
    if showPower then
        health:SetPoint("BOTTOMLEFT", power, "TOPLEFT", 0, 1)
        health:SetPoint("BOTTOMRIGHT", power, "TOPRIGHT", 0, 1)
    else
        health:SetPoint("BOTTOMLEFT", button.content, "BOTTOMLEFT", inset, inset)
        health:SetPoint("BOTTOMRIGHT", button.content, "BOTTOMRIGHT", -inset, inset)
    end
end

UnitButton.LayoutBars = LayoutBars   -- the preview uses it too

-- Places `bar` right after the end of `previous`'s fill.
local function AnchorAfter(bar, previous)
    local fill = previous:GetStatusBarTexture()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", fill, "TOPRIGHT")
    bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
end

-- Applies the frame style. Only does work when the setting changed; LayoutBars
-- must follow, as the bar anchors depend on the style's inset.
local function ApplyStyle(button)
    local style = FRAME_STYLES[NeoHeal.db.layout.frameStyle] or FRAME_STYLES.forever
    if button.style == style then return end
    button.style = style
    local background = button.background
    background:SetBackdrop(style.backdrop)
    background:SetBackdropColor(unpack(style.backgroundColor))
    background:SetBackdropBorderColor(unpack(style.borderColor))

    local health, power, incoming, absorb, inset = button.health, button.power, button.incoming, button.absorb, style.inset
    for _, bar in ipairs({ health, power, incoming, absorb }) do
        bar:SetStatusBarTexture(style.barTexture)
    end
    incoming:SetStatusBarColor(unpack(INCOMING_HEAL_COLOR))
    absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
    -- Health, then incoming heals, then shields.
    AnchorAfter(incoming, health)
    AnchorAfter(absorb, incoming)

    power:SetPoint("BOTTOMLEFT", inset, inset)
    power:SetPoint("BOTTOMRIGHT", -inset, inset)
    health:SetPoint("TOPLEFT", inset, -inset)
    health:SetPoint("TOPRIGHT", -inset, -inset)
    button.powerBarShown = nil   -- the bottom anchors need the new inset too
end
UnitButton.ApplyStyle = ApplyStyle   -- the preview uses it too

-- Mana, rage, energy, ... in the game's own colours. The type can change, e.g.
-- when a druid shifts into bear form.
local function UpdatePower(button)
    local unit = button.unit
    LayoutBars(button, ShowsPowerBarForButton(button))
    if not button.powerBarShown then return end

    local powerType, powerToken = UnitPowerType(unit)
    if IsSecret(powerType) then powerType, powerToken = nil, nil end
    local color = (powerToken and PowerBarColor[powerToken]) or FALLBACK_POWER_COLOR
    button.power:SetStatusBarColor(color.r, color.g, color.b)

    if IsDeadOrOffline(unit) then
        button.power:SetValue(0)
    else
        button.power:SetValue(GetPowerFraction(unit, powerType))
    end
end

local function UpdateRange(button)
    local unit = button.unit
    if IsTrue(UnitIsUnit(unit, "player")) then
        button.content:SetAlpha(1)
        return
    end

    local inRange, checked = UnitInRange(unit)
    if IsSecret(inRange) or IsSecret(checked) then
        -- The answer is hidden from us, but the game can apply it to the alpha itself.
        if button.content.SetAlphaFromBoolean then
            button.content:SetAlphaFromBoolean(inRange, 1, OUT_OF_RANGE_ALPHA)
        end
        return
    end
    button.content:SetAlpha((checked and not inRange) and OUT_OF_RANGE_ALPHA or 1)
end

-- Out of combat: a border in the debuff type's colour. In combat the game hides
-- the debuffs from addons, so Blizzard draws the icon of a debuff you can dispel
-- (bottom centre) instead; its type colour can't be known then.
local function UpdateDispel(button)
    local debuffType, hidden = NeoHeal.Dispel:FindDispellable(button.unit)
    if debuffType then
        local color = NeoHeal.Dispel.COLORS[debuffType]
        button.dispelBorder:SetBackdropBorderColor(color[1], color[2], color[3])
        button.dispelBorder:Show()
    else
        button.dispelBorder:Hide()
    end
    NeoHeal.AuraContainer.SetShown(button.dispelContainer, hidden, button.unit)
end

-- Out of combat only. Also rebuilds after a size change (containers can't resize).
local function BuildDispelContainer(button)
    if not button.unit or not NeoHeal.Dispel:CanDispelAnything() then return end
    local size = NeoHeal.Hots.GetIconSize()
    if button.dispelContainer then
        if button.dispelContainer.neoSize == size then return end
        button.dispelContainer:Hide()
    end
    button.dispelContainer = NeoHeal.AuraContainer.Create(button.health, button.unit, {
        filter = NeoHeal.Dispel.COMBAT_FILTER, corner = "BOTTOM", maxIcons = 1, size = size,
    })
end

local function UpdateAuras(button)
    UpdateDispel(button)
    NeoHeal.Hots.Update(button)
end

-- UNIT_AURA fires very often in raids, several times in a row for one unit. So an
-- event only marks the button; shortly after, every marked button is scanned once.
local aurasPending = {}   -- [button] = true
local auraFlushScheduled = false

local function FlushPendingAuras()
    auraFlushScheduled = false
    for button in pairs(aurasPending) do
        aurasPending[button] = nil
        if button.unit then UpdateAuras(button) end
    end
end

local function QueueAuraUpdate(button)
    aurasPending[button] = true
    if not auraFlushScheduled then
        auraFlushScheduled = true
        C_Timer.After(AURA_BATCH_DELAY, FlushPendingAuras)
    end
end

-- A red strip along the top while the unit has aggro.
local function UpdateAggro(button)
    local hasAggro = false
    if NeoHeal.db.layout.showAggro then
        local status = UnitThreatSituation(button.unit)
        hasAggro = status ~= nil and not IsSecret(status) and status >= AGGRO_THREAT_STATUS
    end
    button.aggro:SetShown(hasAggro)
end

-- Raid target markers. Forever hides the marker index from addons, even out of
-- combat: it is secret when marked and nil when not. We can't test, compare or
-- compute with it, nor put it in a texture path or a curve (all tested), but
-- Blizzard's own SetRaidTargetIconTexture accepts it (tested on Forever). Should
-- that ever fail, a star shows "marked" without which marker.
local RAID_MARKER_SHEET = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"
local STAR_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"

-- Shows the exact marker; returns true if the game accepted the index.
local function ShowExactMarker(texture, index)
    return pcall(function()
        texture:SetTexture(RAID_MARKER_SHEET)
        SetRaidTargetIconTexture(texture, index)
    end)
end
UnitButton.ShowExactMarker = ShowExactMarker   -- for /neoheal debug

local function UpdateRaidTarget(button)
    local icon = button.raidIcon
    local index = GetRaidTargetIndex(button.unit)
    if not IsSecret(index) and not index then   -- never test a secret value itself
        icon:Hide()
        return
    end
    if not ShowExactMarker(icon, index) then
        icon:SetTexture(STAR_TEXTURE)
        icon:SetTexCoord(0, 1, 0, 1)
    end
    icon:Show()
end

-- A white border around the frame of your current target.
local function UpdateTargetHighlight(button)
    button.targetBorder:SetShown(IsTrue(UnitIsUnit(button.unit, "target")))
end

-- A crown for the group leader, a flag for raid assistants, left of the name.
local LEADER_ICON = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local ASSIST_ICON = "Interface\\GroupFrame\\UI-Group-AssistantIcon"

local function UpdateLeader(button)
    local unit = button.unit
    local texture
    if IsTrue(UnitIsGroupLeader(unit)) then
        texture = LEADER_ICON
    elseif IsTrue(UnitIsGroupAssistant(unit)) then
        texture = ASSIST_ICON
    end
    if texture then button.leaderIcon:SetTexture(texture) end
    button.leaderIcon:SetShown(texture ~= nil)
    button.nameText:SetPoint("TOPLEFT", texture and 14 or 3, -3)   -- make room for the icon
end

-- One icon in the centre, most important first: ready check answer (while a
-- ready check runs), being resurrected, being summoned.
local READY_CHECK_ICONS = {
    ready    = "Interface\\RaidFrame\\ReadyCheck-Ready",
    notready = "Interface\\RaidFrame\\ReadyCheck-NotReady",
    waiting  = "Interface\\RaidFrame\\ReadyCheck-Waiting",
}
local RESURRECT_ICON = "Interface\\RaidFrame\\Raid-Icon-Rez"
local SUMMON_ATLAS = "Raid-Icon-SummonPending"
UnitButton.readyCheckActive = false   -- set by Core.lua's ready check events

local function HasIncomingSummon(unit)
    return C_IncomingSummon and C_IncomingSummon.HasIncomingSummon
        and IsTrue(C_IncomingSummon.HasIncomingSummon(unit))
end

local function UpdateStatusIcon(button)
    local unit, icon = button.unit, button.statusIcon
    local readyStatus = UnitButton.readyCheckActive and GetReadyCheckStatus(unit)
    if readyStatus and not IsSecret(readyStatus) and READY_CHECK_ICONS[readyStatus] then
        icon:SetTexture(READY_CHECK_ICONS[readyStatus])
    elseif IsTrue(UnitHasIncomingResurrection(unit)) then
        icon:SetTexture(RESURRECT_ICON)
    elseif HasIncomingSummon(unit) then
        icon:SetAtlas(SUMMON_ATLAS)
    else
        icon:Hide()
        return
    end
    icon:Show()
end

local function UpdateAll(button)
    if not button.unit or not UnitExists(button.unit) then return end
    ApplyStyle(button)
    UpdateIdentity(button)
    UpdateHealth(button)
    UpdatePower(button)
    UpdateRange(button)
    UpdateAuras(button)
    UpdateAggro(button)
    UpdateRaidTarget(button)
    UpdateTargetHighlight(button)
    UpdateLeader(button)
    UpdateStatusIcon(button)
end

---------------------------------------------------------------------------
-- Unit events. Each button listens only to events for its own unit.
---------------------------------------------------------------------------
local EVENT_UPDATES = {
    UNIT_HEALTH = UpdateHealth,
    UNIT_MAXHEALTH = UpdateHealth,
    UNIT_CONNECTION = UpdateHealth,
    UNIT_HEAL_PREDICTION = UpdateIncomingHeals,
    UNIT_ABSORB_AMOUNT_CHANGED = UpdateAbsorbs,
    UNIT_POWER_UPDATE = UpdatePower,
    UNIT_MAXPOWER = UpdatePower,
    UNIT_DISPLAYPOWER = UpdatePower,
    UNIT_NAME_UPDATE = UpdateIdentity,
    UNIT_AURA = QueueAuraUpdate,
    UNIT_IN_RANGE_UPDATE = UpdateRange,
    UNIT_THREAT_SITUATION_UPDATE = UpdateAggro,
    INCOMING_RESURRECT_CHANGED = UpdateStatusIcon,
    INCOMING_SUMMON_CHANGED = UpdateStatusIcon,
}

local UNIT_EVENTS = {}
for event in pairs(EVENT_UPDATES) do
    if not C_EventUtils or C_EventUtils.IsEventValid(event) then
        table.insert(UNIT_EVENTS, event)
    end
end

local function OnUnitEvent(eventFrame, event)
    EVENT_UPDATES[event](eventFrame.button)
end

-- Called whenever the header gives the button a (new) unit, or takes it away.
local function SetUnit(button, unit)
    button.unit = unit
    local events = button.events
    events:UnregisterAllEvents()
    NeoHeal.Hots.SetUnit(button, unit)
    if button.dispelContainer then
        NeoHeal.AuraContainer.SetUnit(button.dispelContainer, unit)
    elseif unit then
        NeoHeal:RunOutOfCombat("dispelContainer" .. button:GetName(), function() BuildDispelContainer(button) end)
    end
    if not unit then return end

    for _, event in ipairs(UNIT_EVENTS) do
        events:RegisterUnitEvent(event, unit)
    end
    UpdateAll(button)
end

---------------------------------------------------------------------------
-- Building a button's look. Also used for the test-mode preview (Preview.lua).
-- Frame levels, bottom to top: background, health bar, incoming heals and shields, HoT icons, text
-- overlay (name, icons), target border, dispel border.
---------------------------------------------------------------------------
function UnitButton.CreateVisuals(frame)
    -- Background and border, drawn by ApplyStyle in the chosen frame style.
    local background = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    background:SetAllPoints()
    background:SetFrameLevel(frame:GetFrameLevel())
    frame.background = background

    -- Everything that fades with range lives in `content`: a plain frame, so its
    -- alpha may change in combat (the secure button's may not).
    local content = CreateFrame("Frame", nil, frame)
    content:SetAllPoints()
    frame.content = content

    -- A thin resource bar along the bottom; the health bar fills the rest. Their
    -- anchors, textures and the anchors of the bars after the health fill are set
    -- by ApplyStyle and LayoutBars.
    local power = CreateFrame("StatusBar", nil, content)
    power:SetHeight(POWER_BAR_HEIGHT)
    power:SetMinMaxValues(0, 1)
    frame.power = power

    local health = CreateFrame("StatusBar", nil, content)
    health:SetMinMaxValues(0, 1)
    health:SetClipsChildren(true)   -- incoming heals and shields never draw past the end of the bar
    frame.health = health

    -- Low health tint (UpdateLowHealth): behind the health bar, so only its empty part shows it.
    local lowHealth = content:CreateTexture(nil, "ARTWORK")
    lowHealth:SetAllPoints(health)
    lowHealth:SetTexture(WHITE_TEXTURE)
    lowHealth:Hide()
    frame.lowHealth = lowHealth

    -- Incoming heals, then shields, each as wide as the health bar and starting
    -- where the one before it ends.
    local function CreateAmountBar()
        local bar = CreateFrame("StatusBar", nil, health)
        bar:SetFrameLevel(health:GetFrameLevel() + 1)
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        bar:Hide()
        health:HookScript("OnSizeChanged", function(_, width) bar:SetWidth(width) end)
        return bar
    end
    frame.incoming = CreateAmountBar()
    frame.absorb = CreateAmountBar()
    ApplyStyle(frame)
    LayoutBars(frame, true)

    NeoHeal.Hots.Attach(frame)   -- HoT icons at health level + 2

    local overlay = CreateFrame("Frame", nil, health)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(health:GetFrameLevel() + 3)

    local nameText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("TOPLEFT", 3, -3)
    nameText:SetPoint("TOPRIGHT", -16, -3)   -- leaves room for the raid target icon
    nameText:SetWordWrap(false)
    frame.nameText = nameText

    -- Bottom-left, because the bottom-right corner holds the HoT icons.
    local statusText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", 3, 3)
    statusText:SetTextColor(0.85, 0.85, 0.85)
    frame.statusText = statusText

    local raidIcon = overlay:CreateTexture(nil, "OVERLAY")
    raidIcon:SetSize(12, 12)
    raidIcon:SetPoint("TOPRIGHT", -2, -2)
    raidIcon:Hide()   -- its texture is set per marker (UpdateRaidTarget)
    frame.raidIcon = raidIcon

    local leaderIcon = overlay:CreateTexture(nil, "OVERLAY")
    leaderIcon:SetSize(10, 10)
    leaderIcon:SetPoint("TOPLEFT", 2, -3)
    leaderIcon:Hide()
    frame.leaderIcon = leaderIcon

    -- Ready check answer, incoming resurrection or summon (UpdateStatusIcon).
    local statusIcon = overlay:CreateTexture(nil, "OVERLAY")
    statusIcon:SetSize(16, 16)
    statusIcon:SetPoint("CENTER", 0, 2)
    statusIcon:Hide()
    frame.statusIcon = statusIcon

    local aggro = overlay:CreateTexture(nil, "OVERLAY")
    aggro:SetPoint("TOPLEFT")
    aggro:SetPoint("TOPRIGHT")
    aggro:SetHeight(3)
    aggro:SetColorTexture(1, 0, 0, 0.9)
    aggro:Hide()
    frame.aggro = aggro

    local highlight = overlay:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.15)
    highlight:Hide()
    frame.highlight = highlight

    local targetBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    targetBorder:SetAllPoints()
    targetBorder:SetFrameLevel(health:GetFrameLevel() + 4)
    targetBorder:SetBackdrop({ edgeFile = WHITE_TEXTURE, edgeSize = 1 })
    targetBorder:SetBackdropBorderColor(1, 1, 1, 0.9)
    targetBorder:Hide()
    frame.targetBorder = targetBorder

    -- Above the target border: a dispellable debuff matters more.
    local dispelBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    dispelBorder:SetAllPoints()
    dispelBorder:SetFrameLevel(health:GetFrameLevel() + 5)
    dispelBorder:SetBackdrop({ edgeFile = WHITE_TEXTURE, edgeSize = 2 })
    dispelBorder:Hide()
    frame.dispelBorder = dispelBorder
end

---------------------------------------------------------------------------
-- Decorating a new secure button
---------------------------------------------------------------------------
local function OnEnter(button)
    button.highlight:Show()
    if NeoHeal.db.layout.showTooltips and button.unit then
        GameTooltip_SetDefaultAnchor(GameTooltip, button)
        GameTooltip:SetUnit(button.unit)
        GameTooltip:Show()
    end
end

local function OnLeave(button)
    button.highlight:Hide()
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

function UnitButton.Init(button)
    UnitButton.CreateVisuals(button)
    button:HookScript("OnEnter", OnEnter)
    button:HookScript("OnLeave", OnLeave)

    -- Unit events go to a plain child frame, so no protected frame is touched in combat.
    local events = CreateFrame("Frame", nil, button)
    events.button = button
    events:SetScript("OnEvent", OnUnitEvent)
    button.events = events

    button:HookScript("OnAttributeChanged", function(self, name, value)
        if name == "unit" then SetUnit(self, value) end
    end)
    -- Protected setup; for a button created in combat it waits until combat ends.
    NeoHeal:RunOutOfCombat("setupButton" .. button:GetName(), function()
        button:RegisterForClicks("AnyUp")
        NeoHeal.ClickCast:ApplyToButton(button)   -- adds the hover-key snippets
        -- Before every click: on a dead unit, cast your res spell instead.
        SecureHandlerWrapScript(button, "OnClick", NeoHeal.ClickCast.resHandler, NeoHeal.ClickCast.RES_SNIPPET)
    end)

    UnitButton.buttons[button] = true
    SetUnit(button, button:GetAttribute("unit"))
end

function UnitButton:UpdateAllButtons()
    for button in pairs(self.buttons) do
        UpdateAll(button)
    end
end

-- Leaving combat makes aura data readable again, but fires no UNIT_AURA. Without
-- this, the Blizzard-drawn icons would stay until the next aura change.
function UnitButton:UpdateAllAuras()
    for button in pairs(self.buttons) do
        if button.unit then UpdateAuras(button) end
    end
end

-- Out of combat, after a size change or learning a first dispel spell.
function UnitButton:RefreshDispelContainers()
    for button in pairs(self.buttons) do
        BuildDispelContainer(button)
    end
end

function UnitButton:UpdateRaidTargets()
    for button in pairs(self.buttons) do
        if button.unit then UpdateRaidTarget(button) end
    end
end

function UnitButton:UpdateTargetHighlights()
    for button in pairs(self.buttons) do
        if button.unit then UpdateTargetHighlight(button) end
    end
end

function UnitButton:UpdateLeaders()
    for button in pairs(self.buttons) do
        if button.unit then UpdateLeader(button) end
    end
end

function UnitButton:UpdateStatusIcons()
    for button in pairs(self.buttons) do
        if button.unit then UpdateStatusIcon(button) end
    end
end

C_Timer.NewTicker(RANGE_CHECK_INTERVAL, function()
    for button in pairs(UnitButton.buttons) do
        if button.unit and button:IsVisible() then
            UpdateRange(button)
        end
    end
end)

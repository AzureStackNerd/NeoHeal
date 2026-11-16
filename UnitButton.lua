-- The look and live updates of one unit button: health bar with incoming heals,
-- resource bar, name, status text, range fading, dispel highlight, aggro, raid
-- target icon and tooltip. The secure button itself is created by a group header
-- (see Layout.lua), or for the target and focus frames by TargetFocusFrames.lua;
-- this module decorates it and keeps it current.
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
local FIVE_SECOND_SECONDS = 5    -- how long your mana regeneration stays off after a cast
local FIVE_SECOND_TICK = 0.1     -- seconds; how often the five-second bar moves
local FIVE_SECOND_HEIGHT = 2     -- pixels on the strip's top edge, so the mana below stays visible
local FIVE_SECOND_COLOR = { 0.55, 0.85, 1, 0.9 }   -- pale blue, brighter than the mana under it
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

-- The bars after the health fill, in the order they are drawn (CreateVisuals).
local AMOUNT_BARS = { "incoming", "prediction", "predictionRange", "predictionAbsorb", "absorb" }

-- Places `bar` right after the end of `previous`'s fill.
local function AnchorAfter(bar, previous)
    local fill = previous:GetStatusBarTexture()
    bar:ClearAllPoints()
    bar:SetPoint("TOPLEFT", fill, "TOPRIGHT")
    bar:SetPoint("BOTTOMLEFT", fill, "BOTTOMRIGHT")
end

-- Starts each shown bar where the shown one before it ends, or at the end of the
-- health. Hidden bars are skipped: in game a hidden, emptied bar kept the width of
-- what it last showed (seen on 2026-10-04), which pushed the bars after it to the
-- right and a shield past the end of the frame. Runs after every change to which
-- bars show.
local function AnchorAmountBars(button)
    local previous = button.health
    for _, key in ipairs(AMOUNT_BARS) do
        local bar = button[key]
        if bar:IsShown() then
            AnchorAfter(bar, previous)
            previous = bar
        end
    end
end

UnitButton.AnchorAmountBars = AnchorAmountBars   -- the preview uses it too
UnitButton.AMOUNT_BARS = AMOUNT_BARS             -- the tests use it

-- Shows `amount` (health points, possibly secret) on one of the bars after the
-- health fill; nil or 0 hides it. A hidden bar is also emptied. AnchorAmountBars
-- must follow.
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
    AnchorAmountBars(button)
end

-- The button under the mouse (OnEnter, OnLeave): the only one with a heal prediction.
local hoveredButton

-- Weakened Soul, left by anyone's Power Word: Shield, keeps a new shield off the
-- unit for 15 sec. The shield itself lasts up to 30 sec, and a new one cast on it
-- doesn't add to it. Both matched by name, like the HoTs. Not checked in game.
local WEAKENED_SOUL = 6788
local POWER_WORD_SHIELD = 17

-- Whether the unit has an aura of this name: true or false, or nil when the game
-- hides the unit's auras, as it does in combat (docs/forever-api.md, section 3).
local function HasAura(unit, name, filter)
    for index = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if not ok or IsSecret(aura) or (aura and IsSecret(aura.name)) then return nil end
        if not aura then return false end
        if aura.name == name then return true end
    end
    return false
end

-- Whether a Power Word: Shield cast now would land and add to what the unit has:
-- no Weakened Soul and no Power Word: Shield on it. False when that can't be told
-- (hidden auras, or a name the game doesn't give): a shield that may not land is
-- not predicted.
local function CanTakePowerWordShield(unit)
    local weakenedSoul, shield = C_Spell.GetSpellName(WEAKENED_SOUL), C_Spell.GetSpellName(POWER_WORD_SHIELD)
    if not weakenedSoul or not shield then return false end
    return HasAura(unit, weakenedSoul, "HARMFUL") == false and HasAura(unit, shield, "HELPFUL") == false
end

-- Whether the frame shows you. "player" is the plain string the game calls your
-- own frame, so no lookup is needed there; every other unit (your "raidN" in a
-- raid, the target and focus frames) is compared with the game, whose answer the
-- game may hide on maps where it restricts addons (docs/forever-api.md, section 2)
-- -- and a hidden answer shows nothing, as a shield that may not land there isn't
-- predicted. So your own frame keeps its bar on such a map and a raid frame
-- doesn't. Not checked in game.
local function ShowsThePlayer(unit)
    return unit == "player" or IsTrue(UnitIsUnit(unit, "player"))
end

-- Whether a shield that only goes on you would land and add to what the unit has:
-- one aura of its own name keeps it off, of any rank (the name is the same for
-- every rank, as Spells.lua groups a spell by name), and the spell has no such
-- aura on you. Weakened Soul and Power Word: Shield are not asked: they stop only
-- a new Power Word: Shield. False when that can't be told (hidden auras, or the
-- game gives no name for the spell): a shield that may not land is not predicted.
local function CanTakeOwnShield(unit, name)
    if not ShowsThePlayer(unit) then return false end
    return HasAura(unit, name, "HELPFUL") == false
end

-- Whether a shield cast with this spell would land and add to what the unit has.
-- Power Word: Shield is the one shield with the rules above; told apart by name,
-- never by its description, because a description is English-only text that the
-- game may word in a way no test here can foresee. Every other absorb takes the
-- rule for a shield that only goes on you: that this covers them all is an
-- assumption about the game's content, not checked in game, and it errs to a bar
-- missing where it could show, never a bar on a frame the shield never reaches.
-- False when the game gives no name for either spell.
local function CanTakeShield(unit, spellID)
    local name, powerWordShield = C_Spell.GetSpellName(spellID), C_Spell.GetSpellName(POWER_WORD_SHIELD)
    if not name or not powerWordShield then return false end
    if name == powerWordShield then return CanTakePowerWordShield(unit) end
    return CanTakeOwnShield(unit, name)
end

-- Heal prediction: what your left click, with the modifiers held now, would heal
-- the frame under the mouse (ClickCast:GetLeftClickAmount), right after the
-- incoming heals. The lowest amount, which the heal always reaches, is drawn
-- lighter than incoming heals; the rest of the range up to the highest amount,
-- which it may reach, in the same green but fainter. A shield on the left click
-- shows its absorb instead, in the blue of the tooltip, where that shield would
-- land (CanTakeShield). The amounts are plain numbers, so heals show in combat too
-- (seen in game on 2026-10-04): the StatusBar places them against the secret
-- maximum.
local function UpdateHealPrediction(button)
    local unit = button.unit
    local low, high, kind, spellID
    if button == hoveredButton and NeoHeal.db.layout.showHealPrediction and unit and not IsDeadOrOffline(unit) then
        low, high, kind, spellID = NeoHeal.ClickCast:GetLeftClickAmount()
    end
    local heal = kind == "heal" and low
    local absorb = kind == "absorb" and CanTakeShield(unit, spellID) and low
    ShowAmountBar(button.prediction, unit, heal)
    ShowAmountBar(button.predictionRange, unit, heal and high - low)
    ShowAmountBar(button.predictionAbsorb, unit, absorb)
    AnchorAmountBars(button)
end

-- Shields (Power Word: Shield, ...): right after the incoming heals and the heal prediction.
local function UpdateAbsorbs(button)
    local unit = button.unit
    local show = UnitGetTotalAbsorbs and not IsDeadOrOffline(unit)
    ShowAmountBar(button.absorb, unit, show and UnitGetTotalAbsorbs(unit))
    AnchorAmountBars(button)
end
UnitButton.UpdateIncomingHeals, UnitButton.UpdateAbsorbs = UpdateIncomingHeals, UpdateAbsorbs   -- the tests use them

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

-- "Health text": the percentage, or the deficit (health missing, e.g. "-2340"),
-- which is what Classic healers pick a spell rank by. Nothing shows at full
-- health; in combat the deficit is secret and can't be compared with 0, so a
-- colour curve fades the text out at 100% instead.
local HEALTH_TEXT_COLOR = { 0.85, 0.85, 0.85 }
local deficitCurve

-- For readable values (also used by the test mode preview).
function UnitButton.ShowHealthText(frame, fraction, maxHealth)
    local text, mode = frame.statusText, NeoHeal.db.layout.healthText
    text:SetTextColor(unpack(HEALTH_TEXT_COLOR))
    if mode == "percent" then
        text:SetText(format("%d%%", fraction * 100))
    elseif mode == "deficit" and fraction < 1 then
        text:SetText(format("-%d", (1 - fraction) * maxHealth))
    else
        text:SetText("")
    end
end

local function UpdateHealthText(button)
    local text, unit, mode = button.statusText, button.unit, NeoHeal.db.layout.healthText
    text:SetTextColor(unpack(HEALTH_TEXT_COLOR))
    if mode == "percent" then
        text:SetText(format("%d%%", GetHealthPercent(unit)))
        return
    elseif mode ~= "deficit" then
        text:SetText("")
        return
    end

    local missing = UnitHealthMissing and UnitHealthMissing(unit, true)
    if not UnitHealthMissing or not IsSecret(missing) then
        missing = missing or (UnitHealthMax(unit) - UnitHealth(unit))
        text:SetText(missing > 0 and format("-%d", missing) or "")
        return
    end
    text:SetText(format("-%d", missing))
    if C_CurveUtil and C_CurveUtil.CreateColorCurve then
        if not deficitCurve then
            local r, g, b = unpack(HEALTH_TEXT_COLOR)
            deficitCurve = C_CurveUtil.CreateColorCurve()
            deficitCurve:SetType(Enum.LuaCurveType.Linear)
            deficitCurve:AddPoint(0, CreateColor(r, g, b, 1))
            deficitCurve:AddPoint(0.999, CreateColor(r, g, b, 1))
            deficitCurve:AddPoint(1, CreateColor(r, g, b, 0))
        end
        -- Should this client refuse, "-0" shows at full health: harmless.
        pcall(function()
            text:SetTextColor(UnitHealthPercent(unit, true, deficitCurve):GetRGBA())
        end)
    end
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

-- Who counts as a healer, for "Resource bar: Healers only" and the low-mana text.
-- Classic players rarely pick a role, so without one the class decides.
local HEALER_CLASSES = { PRIEST = true, DRUID = true, PALADIN = true, SHAMAN = true }

-- Whether a role and class make a healer (the preview uses it too).
function UnitButton.IsHealer(role, class)
    if role and role ~= "NONE" then return role == "HEALER" end
    return HEALER_CLASSES[class] or false
end

-- Whether the button's unit counts as a healer. In combat the game may hide the
-- role and the class. Should the role be hidden, keep what was last known (roles
-- don't change in combat) rather than fall back to the class: a shadow priest
-- would count for the length of the fight.
local function IsHealerButton(button)
    local unit = button.unit
    if button.healerUnit ~= unit then button.healerUnit, button.healerShown = unit, nil end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    local class = IsTrue(UnitIsPlayer(unit)) and select(2, UnitClass(unit)) or nil   -- pets: no class
    if IsSecret(role) then
        if button.healerShown ~= nil then return button.healerShown end
        role = nil
    end
    if IsSecret(class) then class = nil end
    button.healerShown = UnitButton.IsHealer(role, class)
    return button.healerShown
end

-- Low mana: a healer at 20% mana or less shows "OOM" over the middle of the health
-- bar, so the raid's healers can cover for them or call a break. In combat mana can
-- be secret, so a colour curve gives the text its alpha (visible up to the
-- threshold, hidden above it); the result is secret too, and is handed straight to
-- SetTextColor. That this client accepts a secret colour there isn't checked in
-- game; the pcall below keeps the text hidden if it doesn't.
local LOW_MANA_THRESHOLD = 0.2
local LOW_MANA_COLOR = { 0.4, 0.75, 1 }
-- Enum.PowerType.Mana: the bar to read. That a shapeshifted druid's own mana is
-- readable under it isn't checked in game.
local MANA = 0
local lowManaCurve

-- For a readable fraction (also used by the test mode preview).
function UnitButton.ShowLowMana(frame, fraction)
    frame.lowManaText:SetShown(fraction <= LOW_MANA_THRESHOLD)
end

local function UpdateLowMana(button)
    local text, unit = button.lowManaText, button.unit
    if not unit or not NeoHeal.db.layout.showLowMana or IsDeadOrOffline(unit) or not IsHealerButton(button) then
        text:Hide()
        return
    end
    if not (UnitPowerPercent and C_CurveUtil and C_CurveUtil.CreateColorCurve) then
        UnitButton.ShowLowMana(button, GetPowerFraction(unit, MANA))
        return
    end

    if not lowManaCurve then
        local r, g, b = unpack(LOW_MANA_COLOR)
        lowManaCurve = C_CurveUtil.CreateColorCurve()
        lowManaCurve:SetType(Enum.LuaCurveType.Linear)
        lowManaCurve:AddPoint(0, CreateColor(r, g, b, 1))
        lowManaCurve:AddPoint(LOW_MANA_THRESHOLD, CreateColor(r, g, b, 1))
        lowManaCurve:AddPoint(LOW_MANA_THRESHOLD + 0.001, CreateColor(r, g, b, 0))
        lowManaCurve:AddPoint(1, CreateColor(r, g, b, 0))
    end
    -- Should this client refuse the secret colour, no text shows at all: a wrong
    -- "OOM" on a healer with mana is worse than none.
    local ok = pcall(function()
        text:SetTextColor(UnitPowerPercent(unit, MANA, true, lowManaCurve):GetRGBA())
    end)
    text:SetShown(ok)
end
UnitButton.UpdateLowMana = UpdateLowMana   -- the tests use it

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
        button.statusText:SetTextColor(unpack(HEALTH_TEXT_COLOR))
        button.statusText:SetText(status)
    else
        button.health:SetValue(GetHealthFraction(unit))
        if ColorByHealth() then
            button.health:SetStatusBarColor(GetHealthColor(unit))
        end
        UpdateHealthText(button)
    end
    UpdateLowHealth(button, status ~= nil)
    UpdateLowMana(button)   -- also for coming back from dead or offline
    UpdateIncomingHeals(button)
    UpdateHealPrediction(button)
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
local PREDICTION_COLOR = { 0.6, 1, 0.6, 0.6 }          -- the lowest amount of your left click
local PREDICTION_RANGE_COLOR = { 0.6, 1, 0.6, 0.3 }     -- the rest of its range: what it may heal, so fainter
local PREDICTION_ABSORB_COLOR = { 0.6, 0.8, 1, 0.6 }    -- a shield on your left click, the blue of its tooltip amount
local ABSORB_COLOR = { 0.8, 0.9, 1, 0.6 }

-- "Resource bar: Healers only". The healer rule itself is `UnitButton.IsHealer`,
-- shared with the low-mana text.
function UnitButton.ShowsPowerBar(role, class)
    local setting = NeoHeal.db.layout.powerBar
    if setting == "healers" then return UnitButton.IsHealer(role, class) end
    return setting ~= "none"
end

local function ShowsPowerBarForButton(button)
    local setting = NeoHeal.db.layout.powerBar
    if setting == "healers" then return IsHealerButton(button) end
    return setting ~= "none"
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
    local prediction, predictionRange, predictionAbsorb = button.prediction, button.predictionRange, button.predictionAbsorb
    local fiveSecond = button.fiveSecond
    for _, bar in ipairs({ health, power, incoming, prediction, predictionRange, predictionAbsorb, absorb, fiveSecond }) do
        bar:SetStatusBarTexture(style.barTexture)
    end
    incoming:SetStatusBarColor(unpack(INCOMING_HEAL_COLOR))
    prediction:SetStatusBarColor(unpack(PREDICTION_COLOR))
    predictionRange:SetStatusBarColor(unpack(PREDICTION_RANGE_COLOR))
    predictionAbsorb:SetStatusBarColor(unpack(PREDICTION_ABSORB_COLOR))
    absorb:SetStatusBarColor(unpack(ABSORB_COLOR))
    fiveSecond:SetStatusBarColor(unpack(FIVE_SECOND_COLOR))
    AnchorAmountBars(button)   -- to the fills of the new textures

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
    UpdateLowMana(button)   -- independent of the resource-bar setting
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

-- The units no group header owns (TargetFocusFrames.lua). Their unit can be anyone,
-- including someone outside your group, so they can't use UnitInRange: that answers
-- only for your party and raid (forever-api.md section 2).
local OWN_UNITS = { target = true, focus = true }

-- Range by the spell an unmodified left click casts on the unit, which judges any
-- unit: C_Spell.IsSpellInRange takes the unit as its target and is AllowedWhenTainted
-- (Blizzard_APIDocumentationGenerated/SpellDocumentation.lua, Gethe/wow-ui-source
-- branch "live", read on 2026-11-15). It gives true, false, or nil when the check
-- can't be made (unknown spell, invalid unit); nil keeps the frame at full alpha, so
-- a check that doesn't work never fades a frame that is in range.
-- Whether Forever's client hides its answer in combat isn't documented either way.
-- A secret answer goes to the game through SetAlphaFromBoolean, as for the group
-- frames, so it is never tested or compared here. A secret nil can't be told from a
-- secret false, and what the game makes of a secret nil isn't checked in game: if it
-- reads it as false, that frame fades while it isn't out of range. That needs a
-- hidden answer and a check that can't be made at the same moment, and the frame
-- stays at full alpha whenever the answer is readable.
local function UpdateOwnUnitRange(button)
    local spellID = NeoHeal.ClickCast:GetLeftClickSpell()
    if not spellID or not C_Spell.IsSpellInRange then
        button.content:SetAlpha(1)
        return
    end
    local inRange = C_Spell.IsSpellInRange(spellID, button.unit)
    if IsSecret(inRange) then
        if button.content.SetAlphaFromBoolean then
            button.content:SetAlphaFromBoolean(inRange, 1, OUT_OF_RANGE_ALPHA)
        end
        return
    end
    button.content:SetAlpha((inRange == false) and OUT_OF_RANGE_ALPHA or 1)
end

local function UpdateRange(button)
    local unit = button.unit
    if IsTrue(UnitIsUnit(unit, "player")) then
        button.content:SetAlpha(1)
        return
    end
    if OWN_UNITS[unit] then
        UpdateOwnUnitRange(button)
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

-- A debuff you can dispel: a strip along the left edge in its type's colour (Magic
-- blue, Curse purple, Disease brown, Poison green). Drawn by the game, so also in
-- combat. A strip rather than a border, so it never hides the target border.
local DISPEL_STRIP_WIDTH = 5

local function UpdateDispel(button)
    NeoHeal.AuraContainer.SetShown(button.dispelContainer, true, button.unit)
end

-- Out of combat only. After learning a cure spell, an existing border follows the
-- new dispel types.
local function BuildDispelContainer(button)
    local Dispel = NeoHeal.Dispel
    if not button.unit or not Dispel:CanDispelAnything() then return end
    if button.dispelContainer then
        NeoHeal.AuraContainer.SetDispelFilters(button.dispelContainer, Dispel:GetBorderFilters())
        return
    end
    -- Above the target border: a dispellable debuff matters more.
    button.dispelContainer = NeoHeal.AuraContainer.CreateDispelStrip(button, button.unit,
        button.health:GetFrameLevel() + 5, Dispel:GetBorderFilters(), Dispel:GetColorCurve(), DISPEL_STRIP_WIDTH)
end

-- Raid debuffs: debuffs that matter to a healer, such as boss debuffs. Up to two,
-- in the centre and larger than the HoT icons. Always Blizzard-drawn, so they look
-- the same in and out of combat. The filter keeps out (a "!" negates a part):
--   RAID    debuffs you can dispel: HARMFUL|RAID means exactly that, and the
--           dispel border already shows those;
--   PLAYER  debuffs you caused yourself, such as Weakened Soul from your shields.
-- Boss debuffs can't be picked out: isBossAura has no filter token.
local RAID_DEBUFF_FILTER = "HARMFUL|!RAID|!PLAYER"
local RAID_DEBUFF_MAX_ICONS = 2
local RAID_DEBUFF_SCALE = 1.5   -- Blizzard draws boss debuffs 1.5 times as large too
UnitButton.RAID_DEBUFF_TOP = 14 -- pixels from the top of the health bar: just below the name

-- 1.5 times the HoT icons, but never larger than the room below the name. That
-- room is counted with a resource bar, so the size is the same on every button.
function UnitButton.GetRaidDebuffSize()
    local settings = NeoHeal.db.layout
    local style = FRAME_STYLES[settings.frameStyle] or FRAME_STYLES.forever
    local healthHeight = NeoHeal.Layout:GetSize().buttonHeight - 2 * style.inset
    if settings.powerBar ~= "none" then healthHeight = healthHeight - POWER_BAR_HEIGHT - 1 end
    local room = healthHeight - UnitButton.RAID_DEBUFF_TOP - 1
    return math.max(8, math.min(math.floor(NeoHeal.Hots.GetIconSize() * RAID_DEBUFF_SCALE), room))
end

-- Out of combat only. Also rebuilds after a size change (containers can't resize).
local function BuildRaidDebuffContainer(button)
    if not button.unit then return end
    local size = UnitButton.GetRaidDebuffSize()
    if button.raidDebuffContainer then
        if button.raidDebuffContainer.neoSize == size then return end
        button.raidDebuffContainer:Hide()
    end
    button.raidDebuffContainer = NeoHeal.AuraContainer.Create(button.health, button.unit, {
        filter = RAID_DEBUFF_FILTER, corner = "TOP", offsetY = -UnitButton.RAID_DEBUFF_TOP,
        maxIcons = RAID_DEBUFF_MAX_ICONS, size = size,
    })
end

local function UpdateAuras(button)
    NeoHeal.AuraContainer.SetShown(button.raidDebuffContainer, NeoHeal.db.layout.showRaidDebuffs, button.unit)
    UpdateDispel(button)
    NeoHeal.Hots.Update(button)
    NeoHeal.MissingBuffs.Update(button)
    UpdateHealPrediction(button)   -- Weakened Soul coming or going changes the shield prediction
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

local LayoutTopIcons   -- defined below, with the other top icons

local function UpdateRaidTarget(button)
    local icon = button.raidIcon
    local index = GetRaidTargetIndex(button.unit)
    if not IsSecret(index) and not index then   -- never test a secret value itself
        icon:Hide()
    else
        if not ShowExactMarker(icon, index) then
            icon:SetTexture(STAR_TEXTURE)
            icon:SetTexCoord(0, 1, 0, 1)
        end
        icon:Show()
    end
    LayoutTopIcons(button)
end

-- A white border around the frame of your current target.
-- A red border on whoever your hostile target is targeting: who the boss is about
-- to hit, before any aggro shows. It shares the spot with the white border without
-- clashing: while you target an enemy, no raid member is your target.
--
-- Both use UnitIsUnit, which the game may hide (secret) on maps where it restricts
-- addons, there always for "targettarget". A secret answer can't be tested, but
-- SetAlphaFromBoolean lets the game apply it to the border.
local function ShowIfSameUnit(border, unit, otherUnit)
    local same = UnitIsUnit(unit, otherUnit)
    if IsSecret(same) and border.SetAlphaFromBoolean then
        border:Show()
        border:SetAlphaFromBoolean(same, 1, 0)
    else
        border:SetAlpha(1)
        border:SetShown(IsTrue(same))
    end
end

local function UpdateTargetHighlight(button)
    local unit = button.unit
    -- The target frame (TargetFocusFrames.lua) always shows your target: a white
    -- border there would say nothing. A plain string compare, never a secret.
    if unit == "target" then
        button.targetBorder:Hide()
    else
        ShowIfSameUnit(button.targetBorder, unit, "target")
    end
    -- UnitCanAttack isn't secret. Only an enemy's target counts: a friendly
    -- target's target would be anyone.
    if IsTrue(UnitCanAttack("player", "target")) then
        ShowIfSameUnit(button.targetedBorder, unit, "targettarget")
    else
        button.targetedBorder:Hide()
    end
end

---------------------------------------------------------------------------
-- The five-second rule: mana regeneration stays off for 5 seconds after a spell
-- that costs mana, so your frame(s) show a thin bar on the mana strip that drains
-- over those 5 seconds and is gone when regeneration is back.
--
-- One countdown for the whole addon, not one per frame: every frame that shows you
-- draws the same time left, so a frame that starts or stops showing you (a target
-- switch, a roster change) needs nothing dropped. The value is read from the clock
-- on every update, never stepped down per tick, so a jump in time (a loading screen,
-- a return to caster form) shows the right time left at once.
---------------------------------------------------------------------------
local castAt         -- GetTime of the last spell that spent mana; nil while no countdown runs
local lastCastGUID   -- that cast's GUID, kept only while the game gives it readable

-- Enum.PowerType.Mana: your strip must show mana, so a warrior or a rogue and a
-- druid in a form fall out by themselves. Your own power type is read, never the
-- frame's: every frame the bar may show on is you (ShowIfSameUnit decides), and on a
-- map that restricts addons a raid frame's power type can be hidden where yours is
-- not, which would keep the bar off your own raid frame (S18, S38). A hidden power
-- type shows no bar: a bar that may say the wrong thing is worse.
local function ShowsManaStrip()
    local powerType = UnitPowerType("player")
    if IsSecret(powerType) then return false end
    return powerType == MANA
end

-- The fraction of the 5 seconds still to run, or nil when no bar should show:
-- no countdown, the option off, you are dead, or the 5 seconds are over.
local function FiveSecondLeft()
    if not NeoHeal.db or not NeoHeal.db.layout.showFiveSecond then return nil end
    if castAt == nil or IsTrue(UnitIsDeadOrGhost("player")) then return nil end
    local left = (castAt + FIVE_SECOND_SECONDS - GetTime()) / FIVE_SECOND_SECONDS
    if left <= 0 then return nil end
    return left
end

-- One frame's bar, from the shared countdown. Also called from UpdateAll, so a
-- target switching away from you or a roster change is right at once.
local function UpdateFiveSecondFor(button)
    local bar = button.fiveSecond
    if not bar then return end
    local left = FiveSecondLeft()
    if left == nil or not button.unit or not ShowsManaStrip() then
        bar:Hide()
        return
    end
    bar:SetValue(left)
    -- Your own frame is "player"; every other frame is compared with the game, whose
    -- answer it may hide on maps where it restricts addons. A hidden answer goes to
    -- SetAlphaFromBoolean, and a client without that method keeps the bar hidden --
    -- never a bar on a frame that is not you. Not checked in game.
    ShowIfSameUnit(bar, button.unit, "player")
end
UnitButton.UpdateFiveSecondFor = UpdateFiveSecondFor   -- the tests use it

-- Ends the countdown for good: every bar hidden once, then nothing runs until the
-- next spell. Five seconds passing, the option turned off and your death all end it
-- this way, which is what makes "off, then on again" (S27) and a resurrection (S32)
-- wait for the next spell instead of showing the seconds that were left.
local function EndCountdown()
    castAt = nil
    lastCastGUID = nil
    for button in pairs(UnitButton.buttons) do
        if button.fiveSecond then button.fiveSecond:Hide() end
    end
end

-- The tick: one update of every bar. It returns at once while no countdown runs, so
-- it costs nothing between casts.
function UnitButton.UpdateFiveSecond()
    if castAt == nil then return end
    if FiveSecondLeft() == nil then
        EndCountdown()
        return
    end
    for button in pairs(UnitButton.buttons) do
        UpdateFiveSecondFor(button)
    end
end

-- One cost entry of C_Spell.GetSpellPowerCost: does it need mana that you have? The
-- required aura is what the client says the cost applies under (a form, a spec); an
-- ability that lists a mana cost for another form must not start the bar (S13).
-- A field NeoHeal can't read, or one the client leaves out, counts as mana.
local function EntryCostsMana(cost)
    local kind = cost.type
    if IsSecret(kind) then return true end
    if kind ~= MANA then return false end
    local requiredAura = cost.requiredAuraID
    if requiredAura == nil or IsSecret(requiredAura) or requiredAura == 0 then return true end
    local hasAura = cost.hasRequiredAura
    if IsSecret(hasAura) then return true end
    return IsTrue(hasAura)
end

-- Whether a spell's cost says it spends mana. A spell the game says has no resource
-- cost starts no bar (a wand's Shoot, a melee swing, Life Tap: S6); only a cost
-- NeoHeal cannot read -- a missing function, a hidden value, an error -- counts as
-- mana, as nearly every spell a mana user casts costs some and a bar that may be
-- wrong that way is the safe one (S8, open point 5).
local function CostsMana(spellID)
    if IsSecret(spellID) then return true end
    if not C_Spell or not C_Spell.GetSpellPowerCost then return true end
    -- The whole read is in the pcall: the client can refuse the call or hand back a
    -- table whose insides can't be read, and either is a cost NeoHeal could not read.
    local ok, spends = pcall(function()
        local costs = C_Spell.GetSpellPowerCost(spellID)
        if IsSecret(costs) then return true end
        if not costs then return false end   -- the docs: nil when the spell has no resource cost
        for _, cost in ipairs(costs) do
            if EntryCostsMana(cost) then return true end
        end
        return false
    end)
    if not ok then return true end
    return spends
end

-- A spell of yours went off, or a channel of yours started (Core.lua's events).
-- Both events can carry hidden values: the client marks them SecretWhenUnitSpellCast
-- Restricted, so a castGUID is compared only while it is readable, and a hidden
-- spellID starts the bar without asking for its cost. That Forever fires these events
-- for your own casts, also in combat, is not checked in game.
function UnitButton.OnPlayerCast(unit, castGUID, spellID)
    if not NeoHeal.db or not NeoHeal.db.layout.showFiveSecond then return end
    -- Both events are registered for "player", so a cast that arrives is yours; the
    -- unit is checked because the client's docs mark the payload secret, and a hidden
    -- one is no proof that this is someone else's (compared with a constant it is
    -- simply unequal, which would drop your own cast).
    if not IsSecret(unit) and unit ~= "player" then return end
    if not IsSecret(castGUID) then
        if castGUID == lastCastGUID then return end   -- a channel's own end does not restart the bar
        lastCastGUID = castGUID
    else
        lastCastGUID = nil
    end
    if not CostsMana(spellID) then return end
    castAt = GetTime()
    UnitButton.UpdateFiveSecond()
end

-- The top line: the name on the left, always at the same spot so names line up
-- down a column, and the status icons on the right. From the right: raid target
-- marker, role icon, then a crown for the group leader or a flag for raid
-- assistants. A name that doesn't fit is cut off at the icons.
-- The role icon shows only for tanks and healers, as Blizzard's raid frames do: a
-- main tank or main assist set in the raid window first (Classic raids use those
-- more than chosen roles), else the chosen role.
local LEADER_ICON = "Interface\\GroupFrame\\UI-Group-LeaderIcon"
local ASSIST_ICON = "Interface\\GroupFrame\\UI-Group-AssistantIcon"
-- Blizzard's own icons, the bare symbol without a circle where the client has it;
-- per role the first atlas this client knows is used.
local ROLE_ATLASES = {
    MAINTANK   = { "RaidFrame-Icon-MainTank" },
    MAINASSIST = { "RaidFrame-Icon-MainAssist" },
    TANK       = { "roleicon-tiny-tank", "UI-LFG-RoleIcon-Tank-Micro-GroupFinder" },
    HEALER     = { "roleicon-tiny-healer", "UI-LFG-RoleIcon-Healer-Micro-GroupFinder" },
}

local function FindRoleAtlas(role)
    for _, atlas in ipairs(role and ROLE_ATLASES[role] or {}) do
        if not (C_Texture and C_Texture.GetAtlasInfo) or C_Texture.GetAtlasInfo(atlas) then
            return atlas
        end
    end
end
local TEXT_LEFT = DISPEL_STRIP_WIDTH + 2   -- name and health text start right of the dispel strip
local NAME_HEIGHT = 12                     -- the name's line, with room for GameFontHighlightSmall
local ICON_GAP = 2

-- Places the visible top icons right to left and ends the name before them.
-- Called whenever one of them is shown or hidden.
function LayoutTopIcons(frame)   -- the local declared above UpdateRaidTarget
    local x = -ICON_GAP
    for _, icon in ipairs({ frame.raidIcon, frame.roleIcon, frame.leaderIcon }) do
        if icon:IsShown() then
            icon:ClearAllPoints()
            icon:SetPoint("TOPRIGHT", x, icon == frame.raidIcon and -2 or -3)
            x = x - icon:GetWidth() - ICON_GAP
        end
    end
    frame.nameClip:SetPoint("TOPRIGHT", x - 1, -2)
end

-- `role` is a key of ROLE_ATLASES or anything else (no icon); `leaderTexture` may be nil.
-- Also used by the test mode preview.
function UnitButton.SetStatusIcons(frame, role, leaderTexture)
    local atlas = FindRoleAtlas(role)
    if atlas then frame.roleIcon:SetAtlas(atlas) end
    frame.roleIcon:SetShown(atlas ~= nil)
    if leaderTexture then frame.leaderIcon:SetTexture(leaderTexture) end
    frame.leaderIcon:SetShown(leaderTexture ~= nil)
    LayoutTopIcons(frame)
end

local function GetDisplayRole(unit)
    local raidIndex = UnitInRaid(unit)
    if raidIndex and not IsSecret(raidIndex) then
        local raidRole = select(10, GetRaidRosterInfo(raidIndex))
        if raidRole == "MAINTANK" or raidRole == "MAINASSIST" then return raidRole end   -- a secret never equals
    end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit)
    return not IsSecret(role) and role or nil
end

local function UpdateLeader(button)
    local unit = button.unit
    local texture
    if IsTrue(UnitIsGroupLeader(unit)) then
        texture = LEADER_ICON
    elseif IsTrue(UnitIsGroupAssistant(unit)) then
        texture = ASSIST_ICON
    end
    UnitButton.SetStatusIcons(button, GetDisplayRole(unit), texture)
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
    UpdateFiveSecondFor(button)   -- a new unit on this button reads its strip and whether it is you
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
    if button.raidDebuffContainer then
        NeoHeal.AuraContainer.SetUnit(button.raidDebuffContainer, unit)
    elseif unit then
        NeoHeal:RunOutOfCombat("raidDebuffContainer" .. button:GetName(), function()
            BuildRaidDebuffContainer(button)
            if button.unit then UpdateAuras(button) end   -- show it straight away
        end)
    end
    if not unit then return end

    for _, event in ipairs(UNIT_EVENTS) do
        events:RegisterUnitEvent(event, unit)
    end
    UpdateAll(button)
end

---------------------------------------------------------------------------
-- Building a button's look. Also used for the test-mode preview (Preview.lua).
-- Frame levels, bottom to top: background, health bar, the bars after its fill (incoming
-- heals, heal prediction, shields), HoT icons, text overlay (name, icons), target border,
-- dispel border.
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
    -- anchors and textures are set by ApplyStyle and LayoutBars, the anchors of the
    -- bars after the health fill by AnchorAmountBars.
    local power = CreateFrame("StatusBar", nil, content)
    power:SetHeight(POWER_BAR_HEIGHT)
    power:SetMinMaxValues(0, 1)
    frame.power = power

    -- The five-second bar (UpdateFiveSecond): a child of the strip, so hiding the
    -- strip hides it too, and 2 pixels on its top edge leave the mana below visible.
    -- It takes its texture and colour from ApplyStyle, like every other bar.
    local fiveSecond = CreateFrame("StatusBar", nil, power)
    fiveSecond:SetHeight(FIVE_SECOND_HEIGHT)
    fiveSecond:SetPoint("TOPLEFT", power, "TOPLEFT", 0, 0)
    fiveSecond:SetPoint("TOPRIGHT", power, "TOPRIGHT", 0, 0)
    fiveSecond:SetMinMaxValues(0, 1)
    fiveSecond:Hide()
    frame.fiveSecond = fiveSecond

    local health = CreateFrame("StatusBar", nil, content)
    health:SetMinMaxValues(0, 1)
    health:SetClipsChildren(true)   -- incoming heals, prediction and shields never draw past the end of the bar
    frame.health = health

    -- Low health tint (UpdateLowHealth): behind the health bar, so only its empty part shows it.
    local lowHealth = content:CreateTexture(nil, "ARTWORK")
    lowHealth:SetAllPoints(health)
    lowHealth:SetTexture(WHITE_TEXTURE)
    lowHealth:Hide()
    frame.lowHealth = lowHealth

    -- Incoming heals, the heal prediction (its lowest amount, then the rest of its
    -- range), the shield prediction and shields, each as wide as the health bar and
    -- starting where the last shown one before it ends.
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
    frame.prediction = CreateAmountBar()
    frame.predictionRange = CreateAmountBar()
    frame.predictionAbsorb = CreateAmountBar()
    frame.absorb = CreateAmountBar()
    ApplyStyle(frame)
    LayoutBars(frame, true)

    NeoHeal.Hots.Attach(frame)   -- HoT icons at health level + 2
    NeoHeal.MissingBuffs.Attach(frame)   -- in the third HoT slot

    local overlay = CreateFrame("Frame", nil, health)
    overlay:SetAllPoints()
    overlay:SetFrameLevel(health:GetFrameLevel() + 3)

    -- A name too long is cut off at the end by this clipping frame, without "...":
    -- the dots took the room of three letters. Clipping also works on a secret
    -- name, which Lua couldn't shorten. Its right edge is set by LayoutTopIcons.
    local nameClip = CreateFrame("Frame", nil, overlay)
    nameClip:SetPoint("TOPLEFT", TEXT_LEFT, -2)
    nameClip:SetPoint("TOPRIGHT", -3, -2)
    nameClip:SetHeight(NAME_HEIGHT)
    nameClip:SetClipsChildren(true)
    frame.nameClip = nameClip

    local nameText = nameClip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT")   -- no right edge: the full name is drawn, the frame cuts it
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    frame.nameText = nameText

    -- Bottom-left, because the bottom-right corner holds the HoT icons.
    local statusText = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("BOTTOMLEFT", TEXT_LEFT, 3)   -- lined up with the name
    statusText:SetTextColor(unpack(HEALTH_TEXT_COLOR))
    frame.statusText = statusText

    -- "OOM" over the middle of the health bar (UpdateLowMana). Its colour carries
    -- the showing and hiding, as the mana behind it may be secret in combat.
    local lowManaText = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lowManaText:SetPoint("CENTER", health, "CENTER")
    lowManaText:SetTextColor(unpack(LOW_MANA_COLOR))
    lowManaText:SetText(L.LOW_MANA_TEXT)
    lowManaText:Hide()
    frame.lowManaText = lowManaText

    local raidIcon = overlay:CreateTexture(nil, "OVERLAY")
    raidIcon:SetSize(12, 12)
    raidIcon:Hide()   -- its texture is set per marker (UpdateRaidTarget), placed by LayoutTopIcons
    frame.raidIcon = raidIcon

    -- Placed by LayoutTopIcons.
    local roleIcon = overlay:CreateTexture(nil, "OVERLAY")
    roleIcon:SetSize(10, 10)
    roleIcon:Hide()
    frame.roleIcon = roleIcon

    local leaderIcon = overlay:CreateTexture(nil, "OVERLAY")
    leaderIcon:SetSize(10, 10)
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

    -- Targeted by your hostile target (UpdateTargetHighlight).
    local targetedBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    targetedBorder:SetAllPoints()
    targetedBorder:SetFrameLevel(health:GetFrameLevel() + 4)
    targetedBorder:SetBackdrop({ edgeFile = WHITE_TEXTURE, edgeSize = 2 })
    targetedBorder:SetBackdropBorderColor(1, 0.1, 0.1, 1)
    targetedBorder:Hide()
    frame.targetedBorder = targetedBorder

    -- Test mode only: the real buttons get a game-drawn dispel strip
    -- (BuildDispelContainer), the preview frames this look-alike.
    local dispelStrip = CreateFrame("Frame", nil, frame)
    dispelStrip:SetPoint("TOPLEFT")
    dispelStrip:SetPoint("BOTTOMLEFT")
    dispelStrip:SetWidth(DISPEL_STRIP_WIDTH)
    dispelStrip:SetFrameLevel(health:GetFrameLevel() + 5)
    dispelStrip.texture = dispelStrip:CreateTexture(nil, "OVERLAY")
    dispelStrip.texture:SetAllPoints()
    dispelStrip.texture:SetTexture(WHITE_TEXTURE)
    dispelStrip:Hide()
    frame.dispelStrip = dispelStrip
end

---------------------------------------------------------------------------
-- Decorating a new secure button
---------------------------------------------------------------------------
-- The tooltip: the game's unit tooltip, with the click bindings for the modifiers
-- held right now below it (ClickCast:AddBindingsToTooltip). The game rebuilds a
-- unit tooltip by itself when the unit's data changes, which drops lines added
-- once, so where it can, a post-call adds them to every build of a tooltip owned
-- by one of our buttons.
local bindingsByPostCall = TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
    and Enum.TooltipDataType and true or false

if bindingsByPostCall then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
        if tooltip == GameTooltip and UnitButton.buttons[tooltip:GetOwner()] then
            NeoHeal.ClickCast:AddBindingsToTooltip(tooltip)
        end
    end)
end

local function ShowTooltip(button)
    GameTooltip_SetDefaultAnchor(GameTooltip, button)
    GameTooltip:SetUnit(button.unit)
    if not bindingsByPostCall then NeoHeal.ClickCast:AddBindingsToTooltip(GameTooltip) end
    GameTooltip:Show()
end

-- Pressing or releasing a modifier over a button rebuilds its tooltip, so it shows
-- that modifier's bindings, and redraws its heal prediction for that modifier's
-- left click. Listens only while the mouse is over a button that shows either.
local MODIFIER_EVENT = "MODIFIER_STATE_CHANGED"
local canWatchModifiers = not C_EventUtils or C_EventUtils.IsEventValid(MODIFIER_EVENT)
local modifierWatcher = CreateFrame("Frame")
modifierWatcher:SetScript("OnEvent", function(self)
    local button = self.button
    if not button or not button.unit then return end
    UpdateHealPrediction(button)
    if GameTooltip:IsOwned(button) then ShowTooltip(button) end
end)

local function OnEnter(button)
    button.highlight:Show()
    if not button.unit then return end
    hoveredButton = button
    UpdateHealPrediction(button)
    local layout = NeoHeal.db.layout
    if layout.showTooltips then ShowTooltip(button) end
    if layout.showTooltips or layout.showHealPrediction then
        modifierWatcher.button = button
        if canWatchModifiers then modifierWatcher:RegisterEvent(MODIFIER_EVENT) end
    end
end

local function OnLeave(button)
    button.highlight:Hide()
    -- Redrawn even when another button already took the hover (its OnEnter came
    -- first), so this one never keeps a prediction.
    if hoveredButton == button then hoveredButton = nil end
    UpdateHealPrediction(button)
    if modifierWatcher.button == button then
        if canWatchModifiers then modifierWatcher:UnregisterEvent(MODIFIER_EVENT) end
        modifierWatcher.button = nil
    end
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end
UnitButton.OnEnter, UnitButton.OnLeave = OnEnter, OnLeave   -- the tests use them

-- /neoheal clicks: prints every click on a unit button (which mouse button arrived
-- and what that button is bound to), to find out why a binding doesn't fire.
UnitButton.debugClicks = false

local CLICK_SUFFIXES = { LeftButton = "1", RightButton = "2", MiddleButton = "3" }

function UnitButton.PrintClick(button, mouseButton)
    if not UnitButton.debugClicks then return end
    local prefix = NeoHeal.ClickCast.GetModifierPrefix()
    local suffix = CLICK_SUFFIXES[mouseButton] or mouseButton:match("^Button(%d+)$") or ("-" .. mouseButton)
    local actionType = button:GetAttribute(prefix .. "type" .. suffix)
    NeoHeal:Print(format("click: %s%s on %s -> type = %s, spell = %s", prefix, tostring(mouseButton),
        tostring(button.unit), tostring(actionType), tostring(button:GetAttribute(prefix .. "spell" .. suffix))))
    if actionType == "neobuff" then
        local buff = button.missingBuff
        print(format("  buff to cast: %s, missing buff: %s, icon shown: %s", tostring(button:GetAttribute("*spell-neobuff")),
            buff and C_Spell.GetSpellName(buff.spellID) or "none", tostring(button.missingBuffIcon:IsShown())))
    end
end

function UnitButton.Init(button)
    UnitButton.CreateVisuals(button)
    button:HookScript("OnEnter", OnEnter)
    button:HookScript("OnClick", UnitButton.PrintClick)   -- after the click; only prints with /neoheal clicks
    -- PostClick also runs when the click snippet cancelled the click.
    button:HookScript("PostClick", NeoHeal.MissingBuffs.ExplainClick)
    button:HookScript("OnLeave", OnLeave)
    -- A member leaving hides their button, maybe under the mouse. Should the client
    -- not send OnLeave then, this keeps a later unit on that button from showing a
    -- prediction (the hover-key snippet clears on _onhide for the same reason). It
    -- waits a frame: Layout:Refresh and ClickCast:Apply hide and re-show every
    -- header in one go, and a button that is back by then keeps its hover.
    button:HookScript("OnHide", function(self)
        C_Timer.After(0, function()
            if not self:IsVisible() then OnLeave(self) end
        end)
    end)

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

-- Out of combat, after a layout change or learning a first dispel spell: builds
-- missing containers and rebuilds those of the wrong size.
function UnitButton:RefreshAuraContainers()
    for button in pairs(self.buttons) do
        BuildDispelContainer(button)
        BuildRaidDebuffContainer(button)
        if button.unit then UpdateAuras(button) end   -- follows "Show raid debuffs"
    end
end

-- The target and focus frames (TargetFocusFrames.lua) keep their unit token while
-- the unit behind it changes, which no header reports. Core.lua calls this on
-- PLAYER_TARGET_CHANGED and PLAYER_FOCUS_CHANGED, maybe in combat: it runs what a
-- new unit runs (SetUnit touches no secure attribute) and asks its Blizzard-drawn
-- aura icons to redraw, as whether they follow the switch by themselves isn't
-- checked in game. Group buttons never have these units.
local RELOADED_CONTAINERS = { "dispelContainer", "raidDebuffContainer", "hotContainer" }

function UnitButton:ReloadUnitButtons(unit)
    for button in pairs(self.buttons) do
        if button.unit == unit then
            -- The token stays the same while the member behind it changes, so the
            -- healer answer kept for a hidden role belonged to the previous one:
            -- drop it, or a new target in combat inherits the old one's answer.
            button.healerUnit = nil
            SetUnit(button, unit)
            for _, key in ipairs(RELOADED_CONTAINERS) do
                local container = button[key]   -- nil without HoTs or cure spells
                if container then pcall(container.UpdateAllAuras, container) end
            end
        end
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
        if button.unit then
            UpdateStatusIcon(button)
            NeoHeal.MissingBuffs.UpdateClick(button)   -- no buffing by click while ready check icons show
        end
    end
end

-- The five-second bar's clock. It returns at once while no countdown runs, so it
-- costs nothing between casts. Whether a ticker keeps running in combat is not
-- checked in game; the bar is a plain frame's, so nothing here touches a secure one.
C_Timer.NewTicker(FIVE_SECOND_TICK, UnitButton.UpdateFiveSecond)

C_Timer.NewTicker(RANGE_CHECK_INTERVAL, function()
    for button in pairs(UnitButton.buttons) do
        if button.unit and button:IsVisible() then
            UpdateRange(button)
        end
    end
end)

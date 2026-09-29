-- HoT icons: your own HoTs (per class, see HOT_SPELLS) in the bottom-right corner
-- of a unit button. Other healers' HoTs are never shown. Each icon has a cooldown
-- swipe; with "Show HoT timers" on, also countdown numbers (in and out of combat).
--
-- Two ways to draw them, because WoW: Forever hides all aura data from addons
-- in combat:
--   * Out of combat (data readable): our own icons.
--   * In combat (data hidden): Blizzard-drawn icons (AuraContainer.lua), which
--     can't filter by spell name (see MAX_DURATION).
-- Both use the same small countdown (AuraContainer.AddTimedCooldown).
local _, NeoHeal = ...
local IsSecret = NeoHeal.IsSecret
local AuraContainer = NeoHeal.AuraContainer

local Hots = {}
NeoHeal.Hots = Hots

-- The HoTs (and shields) each class tracks (rank 1 IDs; matched by name, so every
-- rank counts).
local HOT_SPELLS = {
    PRIEST = { 139, 17 },     -- Renew, Power Word: Shield
    DRUID  = { 774, 8936 },   -- Rejuvenation, Regrowth
}

local FILTER = "HELPFUL|PLAYER"   -- only buffs you cast
-- Blizzard's container (in combat) can't filter by spell name, only by filter and
-- duration. 30s keeps everything above (Power Word: Shield is the longest, 30s)
-- and drops long buffs such as Thorns and Fortitude. Personal procs of the same
-- length as a HoT (Spirit Tap: 15s, like Renew) can't be told apart, so in combat
-- they show on your own frame. On Forever neither "RAID" nor "RAID_IN_COMBAT"
-- drops them (tested); accepted as a known limitation.
local MAX_DURATION = 30
local MAX_ICONS = 3

local hotNames   -- [spellName] = true for the player's class; built on first use

local function GetHotNames()
    if not hotNames then
        hotNames = {}
        local _, class = UnitClass("player")
        for _, spellID in ipairs(HOT_SPELLS[class] or {}) do
            local name = C_Spell.GetSpellName(spellID)
            if name then hotNames[name] = true end
        end
    end
    return hotNames
end

local function ClassHasHots()
    return next(GetHotNames()) ~= nil
end

function Hots.GetIconSize()
    return math.max(10, math.min(20, math.floor(NeoHeal.db.layout.buttonHeight * 0.4)))
end

---------------------------------------------------------------------------
-- Out of combat: our own icons
---------------------------------------------------------------------------
local function CreateIcon(button)
    local icon = CreateFrame("Frame", nil, button.health)
    icon:SetFrameLevel(button.health:GetFrameLevel() + 2)

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- trim the icon border

    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints()
    icon.cooldown:SetReverse(true)
    icon.cooldown:SetDrawEdge(false)
    NeoHeal.AuraContainer.AddTimedCooldown(icon.cooldown)   -- same countdown as in combat

    icon:Hide()
    return icon
end

-- Lays the icons out from the bottom-right corner, growing to the left.
local function LayoutIcons(button)
    local size = Hots.GetIconSize()
    if button.hotIconSize == size then return end
    button.hotIconSize = size
    for index, icon in ipairs(button.hotIcons) do
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        if index == 1 then
            icon:SetPoint("BOTTOMRIGHT", button.health, "BOTTOMRIGHT", -1, 1)
        else
            icon:SetPoint("RIGHT", button.hotIcons[index - 1], "LEFT", -1, 0)
        end
    end
end

local function ShowIcon(icon, aura)
    icon.texture:SetTexture(aura.icon)
    icon.cooldown:SetCooldown(aura.expirationTime - aura.duration, aura.duration)
    icon:Show()
end

local function HideIcon(icon)
    icon:Hide()
end

-- Collects up to MAX_ICONS of your class HoTs into `found`. Returns true if the
-- game is hiding aura data right now (then `found` is meaningless).
local function ReadHots(unit, found)
    wipe(found)
    local names = GetHotNames()
    for index = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, FILTER)
        if not ok or IsSecret(aura) then return true end
        if not aura then return false end
        if IsSecret(aura.name) or IsSecret(aura.duration) or IsSecret(aura.expirationTime) or IsSecret(aura.icon) then
            return true
        end
        if names[aura.name] and aura.duration > 0 then
            table.insert(found, aura)
            if #found == MAX_ICONS then return false end
        end
    end
    return false
end

---------------------------------------------------------------------------
-- In combat: Blizzard-drawn icons in the same corner
---------------------------------------------------------------------------
local function BuildContainer(button)
    if button.hotContainer or not button.unit or not ClassHasHots() then return end
    button.hotContainer = AuraContainer.Create(button.health, button.unit, {
        filter = FILTER, corner = "BOTTOMRIGHT", maxIcons = MAX_ICONS,
        size = Hots.GetIconSize(), maxDuration = MAX_DURATION, timed = true,
    })
end

---------------------------------------------------------------------------
-- Used by UnitButton
---------------------------------------------------------------------------
function Hots.Attach(button)
    button.hotIcons = {}
    for index = 1, MAX_ICONS do
        button.hotIcons[index] = CreateIcon(button)
    end
    LayoutIcons(button)
end

-- The button got a new unit (or none).
function Hots.SetUnit(button, unit)
    if button.hotContainer then
        AuraContainer.SetUnit(button.hotContainer, unit)
    elseif unit then
        NeoHeal:RunOutOfCombat("hotContainer" .. button:GetName(), function() BuildContainer(button) end)
    end
end

local found = {}

-- Soonest to expire first. Icon 1 is the rightmost, so the HoT that runs out first
-- sits on the right and the longest-lasting one on the left.
local function BySoonestExpiration(a, b)
    return a.expirationTime < b.expirationTime
end

function Hots.Update(button)
    if not ClassHasHots() then return end
    LayoutIcons(button)
    local hidden = ReadHots(button.unit, found)
    if not hidden then table.sort(found, BySoonestExpiration) end
    AuraContainer.SetShown(button.hotContainer, hidden, button.unit)
    for index, icon in ipairs(button.hotIcons) do
        local aura = not hidden and found[index]
        if aura then ShowIcon(icon, aura) else HideIcon(icon) end
    end
end

-- After a layout change (out of combat): containers can't be resized, so one with
-- the old size is dropped and a new one built. Timers follow "Show HoT timers".
function Hots.RefreshSizes()
    local size = Hots.GetIconSize()
    for button in pairs(NeoHeal.UnitButton.buttons) do
        local container = button.hotContainer
        if container and container.neoSize ~= size then
            container:Hide()
            button.hotContainer = nil
            BuildContainer(button)
        end
    end
    AuraContainer.ApplyTimerSetting()
end

-- /neoheal debug: shows which HoT data the game hides right now, for your own
-- HoTs on you and on your target. Run it in combat to see what Forever hides.
function Hots.PrintDebug()
    local function Describe(value)
        if IsSecret(value) then return "|cffff5555hidden|r" end
        return tostring(value)
    end
    NeoHeal:Print(format("HoT debug (in combat: %s)", tostring(InCombatLockdown())))
    local marker = GetRaidTargetIndex("player")
    local marked = IsSecret(marker) or marker ~= nil
    Hots.debugTexture = Hots.debugTexture or UIParent:CreateTexture()   -- never shown
    local exact = marked and NeoHeal.UnitButton.ShowExactMarker(Hots.debugTexture, marker)
    print(format("  raid marker on you: %s (exact icon works: %s)", Describe(marker), tostring(exact)))
    for _, unit in ipairs({ "player", "target" }) do
        for index = 1, 5 do
            local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, FILTER)
            if not ok then
                print(format("  %s #%d: error while reading (%s)", unit, index, tostring(aura)))
                break
            elseif IsSecret(aura) then
                print(format("  %s #%d: the whole aura is hidden", unit, index))
                break
            elseif not aura then
                if index == 1 then print(format("  %s: none of your buffs", unit)) end
                break
            end
            print(format("  %s #%d: name=%s duration=%s expirationTime=%s icon=%s spellId=%s",
                unit, index, Describe(aura.name), Describe(aura.duration),
                Describe(aura.expirationTime), Describe(aura.icon), Describe(aura.spellId)))
        end
    end
end

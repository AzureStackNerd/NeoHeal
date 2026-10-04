-- NeoHeal core: saved variables, global events, the out-of-combat queue and the
-- slash command. Every module is a table on the shared NeoHeal namespace.
local _, NeoHeal = ...
local L = NeoHeal.L

-- Account-wide settings (NeoHealDB). Click bindings are per character (NeoHealCharDB).
local DEFAULTS = {
    layout = {
        -- Sizes and position per group size (Layout:GetPresetName): "party" solo and
        -- in a party, "raid" in a raid. Everything else is shared.
        sizes = {
            party = { buttonWidth = 110, buttonHeight = 44, spacing = 2, scale = 1,
                      position = { point = "CENTER", relativePoint = "CENTER", x = -350, y = 100 } },
            raid  = { buttonWidth = 80, buttonHeight = 36, spacing = 2, scale = 1,
                      position = { point = "CENTER", relativePoint = "CENTER", x = -350, y = 100 } },
        },
        showSolo = true,
        healthText = "percent",    -- "percent", "deficit" (health missing) or "none"
        powerBar = "all",          -- resource bar for "all", "healers" or "none"
        showRaidDebuffs = true,    -- debuffs Blizzard's raid frames show, such as boss debuffs
        showMissingBuffs = true,   -- out of combat: members lacking your class's raid buff
        showHotTimers = true,      -- countdown numbers on HoT icons (the swipe always shows)
        healthColor = "class",     -- "class": class colours, "health": green to red by health
        frameStyle = "forever",    -- "forever": flat and dark, "classic": stone background, tooltip border
        showIncomingHeals = true,
        showAggro = true,
        showTooltips = true,
        showPets = false,
        mainTankPosition = "none",   -- "none", "first" (before group 1) or "last" (after the groups)
        hideBlizzardFrames = false,
        sortOrder = "index",       -- "index", "name", "role" or "class"
    },
}

-- Copies every key from `defaults` that `target` is missing. Existing values are kept,
-- so settings added in a later version reach old saved variables automatically.
local function ApplyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            ApplyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

---------------------------------------------------------------------------
-- Secret values: WoW: Forever runs the retail 12.x API, where some unit data is
-- hidden from addons in combat. A secret value may be displayed (StatusBar,
-- FontString), but comparing it or doing arithmetic with it raises an error.
---------------------------------------------------------------------------
local issecretvalue = issecretvalue or function() return false end
NeoHeal.IsSecret = issecretvalue

-- True only for a readable, truthy value.
function NeoHeal.IsTrue(value)
    return not issecretvalue(value) and value and true or false
end

-- True only for a readable, falsy value.
function NeoHeal.IsFalse(value)
    return not issecretvalue(value) and not value
end

---------------------------------------------------------------------------
-- Out-of-combat queue. Secure frames (unit buttons, their headers and anything
-- they are anchored to) can't be changed in combat. Such work goes through here:
-- it runs now, or as soon as combat ends. Queuing the same key twice runs it once.
---------------------------------------------------------------------------
local pendingActions = {}

function NeoHeal:RunOutOfCombat(key, func)
    if InCombatLockdown() then
        pendingActions[key] = func
    else
        func()
    end
end

function NeoHeal:Print(message)
    print("|cff33ff99" .. L.ADDON_NAME .. "|r " .. message)
end

---------------------------------------------------------------------------
-- Global events
---------------------------------------------------------------------------
function NeoHeal:PLAYER_LOGIN()
    NeoHealDB = NeoHealDB or {}
    NeoHealCharDB = NeoHealCharDB or {}
    ApplyDefaults(NeoHealDB, DEFAULTS)
    -- "Show main tanks" used to be a separate toggle; it is now the "none" position.
    local layout = NeoHealDB.layout
    if layout.showMainTanks ~= nil then
        if not layout.showMainTanks then layout.mainTankPosition = "none" end
        layout.showMainTanks = nil
    end
    -- "Show resource bar" used to be a toggle; off is now the "none" choice.
    if layout.showPowerBar ~= nil then
        if not layout.showPowerBar then layout.powerBar = "none" end
        layout.showPowerBar = nil
    end
    -- "Show health percentage" used to be a toggle; off is now the "none" choice.
    if layout.showHealthText ~= nil then
        if not layout.showHealthText then layout.healthText = "none" end
        layout.showHealthText = nil
    end
    -- Sizes and position used to be one set; both presets start from it, so
    -- nothing moves or changes size on the first login with presets.
    if layout.buttonWidth ~= nil then
        for _, size in pairs(layout.sizes) do
            for _, key in ipairs({ "buttonWidth", "buttonHeight", "spacing", "scale" }) do
                if layout[key] ~= nil then size[key] = layout[key] end
            end
            if type(layout.position) == "table" then size.position = CopyTable(layout.position) end
        end
        layout.buttonWidth, layout.buttonHeight, layout.spacing, layout.scale, layout.position = nil, nil, nil, nil, nil
    end
    layout.orientation = nil    -- groups are always columns now
    layout.showTitleBar = nil   -- the title bar is always shown now
    self.db = NeoHealDB
    self.charDB = NeoHealCharDB

    self.Spells:Scan()
    self.Dispel:UpdateKnownDispels()
    self.MissingBuffs:UpdateKnownBuffs()
    self.ClickCast:Initialize()
    self:RunOutOfCombat("createFrames", function()
        self.Layout:Create()
        self.ClickCast:Apply()
    end)
    self.Options:RegisterSettingsCategory()
    self:Print(L.LOADED)
end

function NeoHeal:PLAYER_REGEN_ENABLED()
    for key, func in pairs(pendingActions) do
        pendingActions[key] = nil
        func()
    end
    -- Aura data is readable again: switch back from the Blizzard-drawn icons, and
    -- show missing buffs again.
    self.MissingBuffs.inCombat = false
    self.UnitButton:UpdateAllAuras()
end

-- Missing buffs are for buffing before a pull: they go away when combat starts.
function NeoHeal:PLAYER_REGEN_DISABLED()
    if not self.db then return end
    self.MissingBuffs.inCombat = true
    self.UnitButton:UpdateAllAuras()
end

function NeoHeal:GROUP_ROSTER_UPDATE()
    if not self.db then return end   -- can fire while logging in
    -- A unit token such as "raid7" may now belong to someone else.
    self.UnitButton:UpdateAllButtons()
    self:RunOutOfCombat("arrange", function()
        if self.Layout:PresetChanged() then
            self.Layout:Refresh()   -- party <-> raid: the other size preset (Refresh arranges too)
            self.Options:RefreshLayoutPage()
        else
            self.Layout:Arrange()
        end
        self.Blizzard:ApplyHiding()   -- Blizzard creates some group frames only when needed
    end)
end

-- Someone picked another role: "Resource bar: Healers only" follows it. Blizzard's
-- own raid frames listen to this too; GROUP_ROSTER_UPDATE isn't promised to fire.
function NeoHeal:PLAYER_ROLES_ASSIGNED()
    if not self.db then return end
    self.UnitButton:UpdateAllButtons()
end

-- A pet was summoned or dismissed: the pet header may need more or less room.
function NeoHeal:UNIT_PET()
    if not self.db then return end
    self:RunOutOfCombat("arrange", function() self.Layout:Arrange() end)
end

function NeoHeal:RAID_TARGET_UPDATE()
    self.UnitButton:UpdateRaidTargets()
end

function NeoHeal:PLAYER_TARGET_CHANGED()
    self.UnitButton:UpdateTargetHighlights()
end

-- Your target picked another target (a boss switching to someone else): the red
-- "targeted" border moves along. Registered for the "target" unit only.
function NeoHeal:UNIT_TARGET()
    self.UnitButton:UpdateTargetHighlights()
end

function NeoHeal:PARTY_LEADER_CHANGED()
    self.UnitButton:UpdateLeaders()
end

-- Ready check: answers show in the centre of each frame, and stay a few seconds
-- after the check ends, like Blizzard's frames.
local READY_CHECK_LINGER = 5   -- seconds

function NeoHeal:READY_CHECK()
    self.UnitButton.readyCheckActive = true
    self.UnitButton:UpdateStatusIcons()
end

function NeoHeal:READY_CHECK_CONFIRM()
    self.UnitButton:UpdateStatusIcons()
end

function NeoHeal:READY_CHECK_FINISHED()
    self.UnitButton:UpdateStatusIcons()   -- "waiting" answers show as they end
    C_Timer.After(READY_CHECK_LINGER, function()
        self.UnitButton.readyCheckActive = false
        self.UnitButton:UpdateStatusIcons()
    end)
end

-- Fires in bursts (login, learning spells, talent changes), so rescan once after it settles.
function NeoHeal:SPELLS_CHANGED()
    if not self.db or self.spellScanQueued then return end
    self.spellScanQueued = true
    C_Timer.After(0.5, function()
        self.spellScanQueued = false
        self.Spells:Scan()
        self.Dispel:UpdateKnownDispels()
        self.MissingBuffs:UpdateKnownBuffs()
        self.UnitButton:UpdateAllButtons()
        self.ClickCast:QueueApply()   -- "highest rank" bindings may now resolve to a new rank
        self.Options:RefreshClickCastingPage()   -- and the rows should say so
        self:RunOutOfCombat("dispelContainers", function()
            self.UnitButton:RefreshAuraContainers()   -- a first dispel spell may be learned
        end)
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...) NeoHeal[event](NeoHeal, ...) end)
eventFrame:RegisterUnitEvent("UNIT_TARGET", "target")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED", "GROUP_ROSTER_UPDATE", "SPELLS_CHANGED",
                         "UNIT_PET", "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED", "PARTY_LEADER_CHANGED",
                         "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "PLAYER_ROLES_ASSIGNED" }) do
    -- Skip events this client doesn't know (registering one raises an error).
    if not C_EventUtils or C_EventUtils.IsEventValid(event) then
        eventFrame:RegisterEvent(event)
    end
end

SLASH_NEOHEAL1 = "/neoheal"
SlashCmdList.NEOHEAL = function(message)
    if message:lower():match("^%s*debug") then
        NeoHeal.Hots.PrintDebug()
    elseif message:lower():match("^%s*clicks") then
        NeoHeal.UnitButton.debugClicks = not NeoHeal.UnitButton.debugClicks
        NeoHeal:Print("click debug " .. (NeoHeal.UnitButton.debugClicks and "on" or "off"))
    else
        NeoHeal.Options:Toggle()
    end
end

-- NeoHeal core: saved variables, global events, the out-of-combat queue and the
-- slash command. Every module is a table on the shared NeoHeal namespace.
local _, NeoHeal = ...
local L = NeoHeal.L

-- Account-wide settings (NeoHealDB). Click bindings are per character (NeoHealCharDB).
local DEFAULTS = {
    layout = {
        buttonWidth = 80,
        buttonHeight = 36,
        spacing = 2,
        scale = 1,
        showSolo = true,
        showHealthText = true,
        powerBar = "all",          -- resource bar for "all", "healers" or "none"
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
        position = { point = "CENTER", relativePoint = "CENTER", x = -350, y = 100 },
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
    layout.orientation = nil    -- groups are always columns now
    layout.showTitleBar = nil   -- the title bar is always shown now
    self.db = NeoHealDB
    self.charDB = NeoHealCharDB

    self.Spells:Scan()
    self.Dispel:UpdateKnownDispels()
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
    -- Aura data is readable again: switch back from the Blizzard-drawn icons.
    self.UnitButton:UpdateAllAuras()
end

function NeoHeal:GROUP_ROSTER_UPDATE()
    if not self.db then return end   -- can fire while logging in
    -- A unit token such as "raid7" may now belong to someone else.
    self.UnitButton:UpdateAllButtons()
    self:RunOutOfCombat("arrange", function()
        self.Layout:Arrange()
        self.Blizzard:ApplyHiding()   -- Blizzard creates some group frames only when needed
    end)
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
        self.UnitButton:UpdateAllButtons()
        self.ClickCast:QueueApply()   -- "highest rank" bindings may now resolve to a new rank
        self:RunOutOfCombat("dispelContainers", function()
            self.UnitButton:RefreshDispelContainers()   -- a first dispel spell may be learned
        end)
    end)
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...) NeoHeal[event](NeoHeal, ...) end)
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE", "SPELLS_CHANGED",
                         "UNIT_PET", "RAID_TARGET_UPDATE", "PLAYER_TARGET_CHANGED", "PARTY_LEADER_CHANGED",
                         "READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED" }) do
    eventFrame:RegisterEvent(event)
end

SLASH_NEOHEAL1 = "/neoheal"
SlashCmdList.NEOHEAL = function(message)
    if message:lower():match("^%s*debug") then
        NeoHeal.Hots.PrintDebug()
    else
        NeoHeal.Options:Toggle()
    end
end

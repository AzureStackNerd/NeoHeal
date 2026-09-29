-- Which debuff types the player can remove, and whether a unit has one of them.
-- It works for every class: whatever cure spells the character knows decide it.
local _, NeoHeal = ...
local IsSecret = NeoHeal.IsSecret

local Dispel = {
    known = {},   -- [debuffType] = true, e.g. known.Magic
}
NeoHeal.Dispel = Dispel

-- Cure spells (rank 1 IDs) and the debuff types they remove.
local DISPEL_SPELLS = {
    [527]  = { "Magic" },                       -- Priest: Dispel Magic
    [528]  = { "Disease" },                     -- Priest: Cure Disease
    [552]  = { "Disease" },                     -- Priest: Abolish Disease
    [1152] = { "Poison", "Disease" },           -- Paladin: Purify
    [4987] = { "Magic", "Poison", "Disease" },  -- Paladin: Cleanse
    [2782] = { "Curse" },                       -- Druid: Remove Curse
    [8946] = { "Poison" },                      -- Druid: Cure Poison
    [2893] = { "Poison" },                      -- Druid: Abolish Poison
    [526]  = { "Poison" },                      -- Shaman: Cure Poison
    [2870] = { "Disease" },                     -- Shaman: Cure Disease
    [475]  = { "Curse" },                       -- Mage: Remove Lesser Curse
}

Dispel.COLORS = {
    Magic   = { 0.20, 0.60, 1.00 },
    Curse   = { 0.60, 0.00, 1.00 },
    Disease = { 0.60, 0.40, 0.00 },
    Poison  = { 0.00, 0.60, 0.00 },
}

-- For the Blizzard-drawn icon in combat: debuffs *this player* can dispel.
Dispel.COMBAT_FILTER = "HARMFUL|RAID_PLAYER_DISPELLABLE"

function Dispel:CanDispelAnything()
    return next(self.known) ~= nil
end

function Dispel:UpdateKnownDispels()
    wipe(self.known)
    for spellID, debuffTypes in pairs(DISPEL_SPELLS) do
        if IsPlayerSpell(spellID) then
            for _, debuffType in ipairs(debuffTypes) do
                self.known[debuffType] = true
            end
        end
    end
end

-- Returns the debuff type to highlight on `unit` ("Magic", ...) or nil, and as a
-- second value true when the game is hiding aura data (in combat on Forever),
-- so the caller can fall back to Blizzard-drawn icons.
function Dispel:FindDispellable(unit)
    if not self:CanDispelAnything() then return nil, false end

    for index = 1, 40 do
        -- In combat the game refuses (throws) or hides the data; both mean "can't read".
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HARMFUL")
        if not ok or IsSecret(aura) or (aura and IsSecret(aura.dispelName)) then
            return nil, true
        end
        if not aura then return nil, false end
        if aura.dispelName and self.known[aura.dispelName] then
            return aura.dispelName, false
        end
    end
    return nil, false
end

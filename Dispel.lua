-- Which debuff types the player can remove, and what the game needs to draw the
-- dispel border (UnitButton.lua) itself. Addons can't read debuffs in combat, so
-- NeoHeal never looks: a candidate filter tells the game which dispel types count,
-- and a colour curve which colour each type gets. (Technique as in Decursive.)
-- It works for every class: whatever cure spells the character knows decide it.
local _, NeoHeal = ...

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

-- The game's number for each dispel type: the input of the colour curve.
local DISPEL_TYPE_NUMBERS = { Magic = 1, Curse = 2, Disease = 3, Poison = 4 }

-- Maps a debuff's dispel type to its colour; types you can't dispel stay invisible.
-- Updated in place when you learn a cure spell, so existing borders follow.
local colorCurve

function Dispel:GetColorCurve()
    if not colorCurve and C_CurveUtil and C_CurveUtil.CreateColorCurve then
        colorCurve = C_CurveUtil.CreateColorCurve()
        colorCurve:SetType(Enum.LuaCurveType.Step)
        self:UpdateColorCurve()
    end
    return colorCurve
end

function Dispel:UpdateColorCurve()
    if not colorCurve then return end
    colorCurve:ClearPoints()
    colorCurve:AddPoint(0, CreateColor(0, 0, 0, 0))   -- no dispel type
    for debuffType, number in pairs(DISPEL_TYPE_NUMBERS) do
        local color = self.COLORS[debuffType]
        colorCurve:AddPoint(number, self.known[debuffType] and CreateColor(color[1], color[2], color[3], 1)
            or CreateColor(0, 0, 0, 0))
    end
end

-- Candidate filters for the dispel border: only debuffs of a type you can remove.
function Dispel:GetBorderFilters()
    local types = {}
    for debuffType in pairs(self.known) do types[debuffType] = true end
    return { includeDispelTypes = types }
end

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
    self:UpdateColorCurve()
end

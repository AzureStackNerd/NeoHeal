-- Reads the player's spellbook and groups every rank of a spell together, so the
-- options can offer "Flash Heal > Rank 1..7" and bindings can find the highest rank.
local _, NeoHeal = ...

-- entry = { name = "Flash Heal", icon = 135907,
--           ranks = { { spellID = 2061, number = 1, text = "Rank 1" }, ... } }   -- lowest rank first
local Spells = {
    skillLines = {},   -- spellbook order: { { name = "Holy", spells = { entry, ... } }, ... }
    byName = {},       -- [spellName] = entry
}
NeoHeal.Spells = Spells

function Spells.GetName(spellID)
    return spellID and C_Spell.GetSpellName(spellID)
end

-- "Rank 3" -> 3, "Rank 3". Spells without ranks give 0.
local function ParseRank(spellID, subName)
    local text = subName
    if not text or text == "" then text = C_Spell.GetSpellSubtext(spellID) or "" end
    return tonumber(text:match("%d+")) or 0, text
end

local function AddRank(group, name, spellID, subName, icon)
    local entry = Spells.byName[name]
    if not entry then
        entry = { name = name, icon = icon, ranks = {} }
        Spells.byName[name] = entry
        table.insert(group.spells, entry)
    end
    local number, text = ParseRank(spellID, subName)
    table.insert(entry.ranks, { spellID = spellID, number = number, text = text })
end

local function ByName(a, b) return a.name < b.name end
local function ByRank(a, b) return a.number < b.number end

function Spells:Scan()
    wipe(self.skillLines)
    wipe(self.byName)

    local bank = Enum.SpellBookSpellBank.Player
    for lineIndex = 1, C_SpellBook.GetNumSpellBookSkillLines() do
        local line = C_SpellBook.GetSpellBookSkillLineInfo(lineIndex)
        if line and not line.shouldHide then
            local group = { name = line.name, spells = {} }
            for slot = line.itemIndexOffset + 1, line.itemIndexOffset + line.numSpellBookItems do
                local item = C_SpellBook.GetSpellBookItemInfo(slot, bank)
                if item and item.itemType == Enum.SpellBookItemType.Spell and item.spellID
                        and not item.isPassive and not item.isOffSpec then
                    AddRank(group, item.name or Spells.GetName(item.spellID), item.spellID, item.subName, item.iconID)
                end
            end
            if #group.spells > 0 then
                table.sort(group.spells, ByName)
                table.insert(self.skillLines, group)
            end
        end
    end

    for _, entry in pairs(self.byName) do
        table.sort(entry.ranks, ByRank)
    end
end

-- The spellbook entry for any rank of a spell.
function Spells:GetEntry(spellID)
    local name = Spells.GetName(spellID)
    return name and self.byName[name]
end

-- The highest rank of this spell that the player knows, or nil if it isn't in the spellbook.
function Spells:GetHighestRank(spellID)
    local entry = self:GetEntry(spellID)
    return entry and entry.ranks[#entry.ranks].spellID
end

-- "Rank 3" for ranked spells, nil otherwise.
function Spells:GetRankText(spellID)
    local number, text = ParseRank(spellID)
    return number > 0 and text or nil
end

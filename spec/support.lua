-- Test support: just enough of the WoW client API to load NeoHeal's files outside
-- the game, and a fake spellbook. Every Load() builds a fresh addon namespace and
-- reinstalls the globals in InstallGlobals. Globals a test sets itself (as
-- TestOptionsWindow does for the options window) stay set for later tests.
local Support = {
    root = ".",   -- the addon folder; set by run.lua
}

-- The fake spells. Flash Heal has seven ranks; Abolish Disease has one and no
-- rank text, like rankless spells in the game.
local FLASH_HEAL = { 2061, 9472, 9473, 9474, 10915, 10916, 10917 }   -- rank 1 to 7
local ABOLISH_DISEASE = 552
Support.FLASH_HEAL = FLASH_HEAL
Support.ABOLISH_DISEASE = ABOLISH_DISEASE

local CATALOGUE = {}   -- [spellID] = { name, subName }
for rank, spellID in ipairs(FLASH_HEAL) do
    CATALOGUE[spellID] = { name = "Flash Heal", subName = "Rank " .. rank }
end
CATALOGUE[ABOLISH_DISEASE] = { name = "Abolish Disease", subName = "" }

local state = {
    book = {},              -- spell IDs in the spellbook, in order
    known = {},             -- [spellID] = true
    subtextMissing = false, -- C_Spell.GetSpellSubtext returns "" for everything
}

local function Wipe(t)
    for key in pairs(t) do t[key] = nil end
    return t
end

-- A frame whose every method does nothing.
local function CreateFrameStub()
    return setmetatable({}, { __index = function() return function() end end })
end

local function InstallGlobals()
    format = string.format
    wipe = Wipe
    CreateFrame = CreateFrameStub
    InCombatLockdown = function() return false end
    C_Timer = { After = function(_, func) func() end }   -- no waiting in tests
    C_EventUtils = { IsEventValid = function() return true end }
    SlashCmdList = {}
    Enum = { SpellBookSpellBank = { Player = 0 }, SpellBookItemType = { Spell = 1 } }

    C_Spell = {
        GetSpellName = function(spellID)
            local spell = CATALOGUE[spellID]
            return spell and spell.name
        end,
        GetSpellSubtext = function(spellID)
            local spell = CATALOGUE[spellID]
            if not spell or state.subtextMissing then return "" end
            return spell.subName
        end,
    }
    IsPlayerSpell = function(spellID) return state.known[spellID] == true end

    -- One skill line holding the spellbook.
    C_SpellBook = {
        GetNumSpellBookSkillLines = function() return 1 end,
        GetSpellBookSkillLineInfo = function()
            return { name = "Holy", itemIndexOffset = 0, numSpellBookItems = #state.book }
        end,
        GetSpellBookItemInfo = function(slot)
            local spellID = state.book[slot]
            local spell = CATALOGUE[spellID]
            return { itemType = Enum.SpellBookItemType.Spell, spellID = spellID, name = spell.name,
                     subName = spell.subName, iconID = 1, isPassive = false, isOffSpec = false }
        end,
    }
end

-- Which spells the character knows (and finds in the spellbook).
function Support.SetKnown(spellIDs)
    state.book = spellIDs
    Wipe(state.known)
    for _, spellID in ipairs(spellIDs) do state.known[spellID] = true end
end

-- Makes C_Spell.GetSpellSubtext return "" (the scan still sees the spellbook's subName).
function Support.SetSubtextMissing(missing)
    state.subtextMissing = missing
end

-- Loads addon files (paths relative to the addon folder) into a new namespace.
-- `known` defaults to every fake spell.
function Support.Load(files, known)
    InstallGlobals()
    state.subtextMissing = false
    local all = { ABOLISH_DISEASE }
    for _, spellID in ipairs(FLASH_HEAL) do table.insert(all, spellID) end
    Support.SetKnown(known or all)

    local ns = {}
    for _, file in ipairs(files) do
        local chunk = assert(loadfile(Support.root .. "/" .. file))
        chunk("NeoHeal", ns)
    end
    return ns
end

return Support

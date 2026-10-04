-- Spells.lua: ranks of a spell, and which one "highest rank" (minus an offset) picks.
local lu = require("luaunit")
local Support = require("support")
local FLASH_HEAL, ABOLISH_DISEASE = Support.FLASH_HEAL, Support.ABOLISH_DISEASE

TestSpells = {}

function TestSpells:setUp()
    self.Spells = Support.Load({ "Locales/enUS.lua", "Spells.lua" }).Spells
    self.Spells:Scan()
end

function TestSpells:testHighestRankFromAnyRank()
    lu.assertEquals(self.Spells:GetHighestRank(FLASH_HEAL[1]), FLASH_HEAL[7])
    lu.assertEquals(self.Spells:GetHighestRank(FLASH_HEAL[4]), FLASH_HEAL[7])
end

function TestSpells:testOffsetCountsDownFromTheHighest()
    lu.assertEquals(self.Spells:GetHighestRank(FLASH_HEAL[1], 0), FLASH_HEAL[7])
    lu.assertEquals(self.Spells:GetHighestRank(FLASH_HEAL[1], 1), FLASH_HEAL[6])
end

function TestSpells:testOffsetStopsAtRankOne()
    lu.assertEquals(self.Spells:GetHighestRank(FLASH_HEAL[7], 10), FLASH_HEAL[1])
    lu.assertEquals(self.Spells:GetHighestRank(ABOLISH_DISEASE, 1), ABOLISH_DISEASE)
end

function TestSpells:testSpellNotInTheSpellbookHasNoRank()
    Support.SetKnown({})
    self.Spells:Scan()
    lu.assertNil(self.Spells:GetHighestRank(FLASH_HEAL[1]))
end

function TestSpells:testRankText()
    lu.assertEquals(self.Spells:GetRankText(FLASH_HEAL[3]), "Rank 3")
    lu.assertNil(self.Spells:GetRankText(ABOLISH_DISEASE))
end

-- The text the spellbook scan stored wins, so a macro still names the rank when
-- the game's subtext lookup comes back empty.
function TestSpells:testRankTextComesFromTheScanWhenTheSubtextIsMissing()
    Support.SetSubtextMissing(true)
    lu.assertEquals(self.Spells:GetRankText(FLASH_HEAL[6]), "Rank 6")
end

-- A rank the scan didn't see (say the spellbook shows only the top ranks) still
-- gets its text from the game.
function TestSpells:testRankTextOfARankTheScanDidNotSee()
    Support.SetKnown({ FLASH_HEAL[6], FLASH_HEAL[7] })
    self.Spells:Scan()
    lu.assertEquals(self.Spells:GetRankText(FLASH_HEAL[3]), "Rank 3")
end

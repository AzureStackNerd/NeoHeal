-- ClickCast.lua: which rank a spell binding casts, how its row describes it, and
-- the "Also target" macro.
local lu = require("luaunit")
local Support = require("support")
local FLASH_HEAL, ABOLISH_DISEASE = Support.FLASH_HEAL, Support.ABOLISH_DISEASE

local function Binding(spellID, highestRank, rankOffset, target)
    return { action = "spell", spellID = spellID, highestRank = highestRank, rankOffset = rankOffset,
             target = target or "unit" }
end

TestClickCast = {}

function TestClickCast:setUp()
    local ns = Support.Load({ "Locales/enUS.lua", "Spells.lua", "ClickCast.lua" })
    self.Spells, self.ClickCast = ns.Spells, ns.ClickCast
    self.Spells:Scan()
end

-- Casting

function TestClickCast:testHighestRankCastsTheHighest()
    lu.assertEquals(self.ClickCast:GetSpellValue(Binding(FLASH_HEAL[7], true)), FLASH_HEAL[7])
end

-- Bindings saved before "Highest rank -1" existed have no rankOffset.
function TestClickCast:testOldBindingWithoutOffsetStillCastsTheHighest()
    lu.assertEquals(self.ClickCast:GetSpellValue(Binding(FLASH_HEAL[1], true, nil)), FLASH_HEAL[7])
end

-- Saved when rank 5 was the highest; ranks 6 and 7 were learned since.
function TestClickCast:testMinusOneCastsTheRankBelowTheHighest()
    lu.assertEquals(self.ClickCast:GetSpellValue(Binding(FLASH_HEAL[4], true, 1)), FLASH_HEAL[6])
end

function TestClickCast:testMinusOneFollowsANewlyLearnedRank()
    Support.SetKnown({ FLASH_HEAL[1], FLASH_HEAL[2], FLASH_HEAL[3], FLASH_HEAL[4], FLASH_HEAL[5] })
    self.Spells:Scan()
    local binding = Binding(FLASH_HEAL[4], true, 1)
    lu.assertEquals(self.ClickCast:GetSpellValue(binding), FLASH_HEAL[4])

    Support.SetKnown(FLASH_HEAL)   -- learned ranks 6 and 7
    self.Spells:Scan()
    lu.assertEquals(self.ClickCast:GetSpellValue(binding), FLASH_HEAL[6])
end

function TestClickCast:testFixedRankCastsThatRank()
    lu.assertEquals(self.ClickCast:GetSpellValue(Binding(FLASH_HEAL[3], false)), FLASH_HEAL[3])
end

-- Without a spellbook entry the saved spell ID is cast: that is why the options
-- menu saves "Highest rank -1" as the rank below the highest.
function TestClickCast:testWithoutASpellbookEntryTheSavedRankIsCast()
    Support.SetKnown({})
    self.Spells:Scan()
    lu.assertEquals(self.ClickCast:GetSpellValue(Binding(FLASH_HEAL[6], true, 1)), FLASH_HEAL[6])
end

-- The row text. A "-1" binding saved before the last ranks were learned names the
-- rank it casts now, not the rank it was saved with.

function TestClickCast:testDescribe()
    lu.assertEquals(self.ClickCast:Describe(Binding(FLASH_HEAL[7], true)), "Flash Heal")
    lu.assertEquals(self.ClickCast:Describe(Binding(FLASH_HEAL[4], true, 1)), "Flash Heal (Rank 6, highest -1)")
    lu.assertEquals(self.ClickCast:Describe(Binding(FLASH_HEAL[3], false)), "Flash Heal (Rank 3)")
    lu.assertEquals(self.ClickCast:Describe(Binding(ABOLISH_DISEASE, true, 1)), "Abolish Disease (highest -1)")
end

function TestClickCast:testDescribeNotLearned()
    Support.SetKnown({})
    self.Spells:Scan()
    lu.assertEquals(self.ClickCast:Describe(Binding(FLASH_HEAL[7], true)), "Flash Heal (not learned)")
end

-- The "Also target" macro

function TestClickCast:testMacroForHighestRankNamesNoRank()
    lu.assertEquals(self.ClickCast:BuildTargetingMacro(Binding(FLASH_HEAL[7], true)),
        "/target mouseover\n/cast [@mouseover] Flash Heal")
end

function TestClickCast:testMacroForMinusOneNamesTheRankItCastsNow()
    lu.assertEquals(self.ClickCast:BuildTargetingMacro(Binding(FLASH_HEAL[4], true, 1)),
        "/target mouseover\n/cast [@mouseover] Flash Heal(Rank 6)")
end

function TestClickCast:testMacroCastsOnTheUnitsTarget()
    lu.assertEquals(self.ClickCast:BuildTargetingMacro(Binding(FLASH_HEAL[3], false, nil, "target")),
        "/target mouseovertarget\n/cast [@mouseovertarget] Flash Heal(Rank 3)")
end

-- An empty subtext from the game must not turn "-1" into the highest rank.
function TestClickCast:testMacroNamesTheRankWhenTheSubtextIsMissing()
    Support.SetSubtextMissing(true)
    lu.assertEquals(self.ClickCast:BuildTargetingMacro(Binding(FLASH_HEAL[4], true, 1)),
        "/target mouseover\n/cast [@mouseover] Flash Heal(Rank 6)")
end

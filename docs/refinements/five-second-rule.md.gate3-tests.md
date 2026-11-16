# Gate 3 tests: Show the five-second rule on your own frame

Tests: `spec/fivesecond_test.lua` (new, in `spec/run.lua`'s list; classes `TestFiveSecond` and
`TestFiveSecondCore`), `TestTargetFocusFiveSecond` in `spec/targetfocus_test.lua`, `TestFiveSecondOption` in
`spec/options_test.lua`, and `testFiveSecondBarOnOneFakeHealer` in `spec/preview_test.lua`. The fakes in
`spec/support.lua`: a clock (`GetTime`, `Support.SetTime`), a `C_Timer.NewTicker` that keeps its callback and never
runs it, `C_Spell.GetSpellPowerCost` (nil until set; a cost list, a hidden value or an error), `Support.Recorder`
(a frame that keeps its value, range, shown and every `SetAlphaFromBoolean` argument), `Support.Secret`, and real
unit buttons on Recorder frames (`Support.LoadUnitButtons`, `Support.RealButton`), so `UpdateAll` runs for real.
The tests call `UnitButton.UpdateFiveSecond()` at chosen fake times instead of running the ticker.

`lua spec/run.lua`: 333 tests, 0 failures, before and after the mutations. Each mutation ran in a copy of the addon files,
`Locales/` and `spec/` outside the repository: the file saved aside, one whole line replaced, only the named row
run, the saved file copied back and compared with the working tree's. "Proved on" is `git hash-object` of the
restored file, the same bytes as the working tree's at the refresh.

Not checked by any test (no game client): whether Forever fires the two cast events for your own casts, also in
combat; what `C_Spell.GetSpellPowerCost` answers there; whether `SetAlphaFromBoolean` places the bar on a frame whose
"is this you" answer the game hides. The fake cost entries use the field names of Blizzard's API docs.

## Site to test

| Site (file:line) | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `UnitButton.lua:21-24` | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | M16: `fivesecond_test.lua:108: halfway Actual: 0.58333333333333, expected: 0.5` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:548-557` | `TestFiveSecond.testTheBarTakesTheStyle` | M17: `fivesecond_test.lua:327: the bar has no colour of its own expected: not nil, actual: nil` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:1156-1165` | `TestFiveSecond.testTheBarSitsOnTheStrip` | M5: `fivesecond_test.lua:309: the bar isn't the strip's child expected and actual object should not be different` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:825-826` | `TestFiveSecond.testTheCountdownIsTheModulesOwn` | M18: `fivesecond_test.lua:390: the countdown is a global expected: nil, actual: 1000` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:831-835` | `TestFiveSecond.testOnlySpendingYourManaCounts` | M6: `fivesecond_test.lua:255: a frame with a rage strip shows a bar expected: nil, actual: 1.0` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:839-845` | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | M7: `fivesecond_test.lua:131: the bar is still there 5 seconds after the cast expected: nil, actual: 0.0` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:849-864` | `TestFiveSecond.testOnlyFramesThatShowYouCarryTheBar` | M8: `fivesecond_test.lua:219: party1 shows the bar expected: nil, actual: 0.8` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:870-877` | `TestFiveSecond.testTheOptionTurnsTheBarOff` | M9: `fivesecond_test.lua:297: on again, the seconds that were left show expected: nil, actual: 0.8` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:880-890` | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | M10: `fivesecond_test.lua:131: the bar is still there 5 seconds after the cast expected: nil, actual: 0.020000000000005` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:895-909` | `TestFiveSecond.testADruidSeesTheTimeLeftBackInCasterForm` | M11: `fivesecond_test.lua:108: back in caster form Actual: 0.9, expected: 0.6` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:911-932` | `TestFiveSecond.testNoManaSpentLeavesTheBarAsItIs` | M12: `fivesecond_test.lua:164: a wand's Shoot started the bar expected: nil, actual: 1.0` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:934-946` | `TestFiveSecond.testOtherMembersCastsNeverStartIt` | M13: `fivesecond_test.lua:196: another member's cast started your bar expected: nil, actual: 1.0` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:1068` | `TestFiveSecond.testTheBarFollowsAGroupChange` | M14: `fivesecond_test.lua:107: the frame that now shows you: no bar expected: not nil, actual: nil` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `UnitButton.lua:1508` | `TestFiveSecond.testTheTickerRunsTheUpdate` | M15: `fivesecond_test.lua:377: no ticker runs UpdateFiveSecond expected: not nil, actual: nil` | `UnitButton.lua` 05c6086489a5bd5953145d16505b417766de926c |
| `Core.lua:30` | `TestFiveSecondCore.testOnByDefault` | M19: `fivesecond_test.lua:451: Show five-second rule isn't on by default expected: true, actual: false` | `Core.lua` 1a8399c6689604205ab7803a87e1d5fdfa931378 |
| `Core.lua:212-226` | `TestFiveSecondCore.testTheEventsReachTheBar` | M1: `fivesecond_test.lua:430: expected: {{"player", "Cast-1", 2061}, {"player", "Cast-2", 15407}} actual: {{"player", "Cast-2", 15407}}` | `Core.lua` 1a8399c6689604205ab7803a87e1d5fdfa931378 |
| `Core.lua:281-282` | `TestFiveSecondCore.testBothCastEventsAreRegistered` | M2: `fivesecond_test.lua:406: UNIT_SPELLCAST_SUCCEEDED isn't registered expected: true, actual: false` | `Core.lua` 1a8399c6689604205ab7803a87e1d5fdfa931378 |
| `Options.lua:193` | `TestFiveSecondOption.testTheFiveSecondOptionIsOnTheLayoutPage` | M3b: `options_test.lua:609: no five-second checkbox on the Layout page expected: not nil, actual: nil` | `Options.lua` 17f7c759694e702a497253e6a9a686caf94a5b24 |
| `Locales/enUS.lua:111` | `TestFiveSecondOption.testTheFiveSecondOptionIsOnTheLayoutPage` | M20b: `options_test.lua:604: no string for the option: the checkbox shows its key expected: not nil, actual: nil` | `Locales/enUS.lua` 0bfa44d6850fb7ed873561ee986b8ef108d2090f |
| `Preview.lua:184-189` | `TestPreview.testFiveSecondBarOnOneFakeHealer` | M4: `preview_test.lua:410: Seraphine shows a five-second bar with the option off expected: false, actual: true` | `Preview.lua` 03ceebe900d9d8a27e109dd2d0fa758355ecefd9 |
| `Preview.lua:216` | `TestPreview.testFiveSecondBarOnOneFakeHealer` | M21: `preview_test.lua:401: the fake healer shows no five-second bar expected: true, actual: false` | `Preview.lua` 03ceebe900d9d8a27e109dd2d0fa758355ecefd9 |
| `Preview.lua:275` | `TestPreview.testFiveSecondBarOnOneFakeHealer` | M22: `preview_test.lua:404: Shadowmaw shows a five-second bar expected: false, actual: true` | `Preview.lua` 03ceebe900d9d8a27e109dd2d0fa758355ecefd9 |

The docs rows of the site list (`docs/features.md`, `docs/architecture.md`, `docs/saved-variables.md`) are no
code and have no test.

Rows to tests: S1, S2 `testAManaSpellStartsTheBarFull`; S3, S4 `testAChannelCountsFromItsStart`; S5 (no start, fail
or interrupt event is registered) `testBothCastEventsAreRegistered`; S6 `testNoManaSpentLeavesTheBarAsItIs`; S7, S8
`testAFreeOrUnreadableCostStartsTheBar`; S9 `testANewManaSpellFillsTheBarAgain`; S10
`testTheBarIsGoneAfterFiveSeconds`; S11, S14 `testOnlySpendingYourManaCounts`; S12, S13, S37
`testADruidSeesTheTimeLeftBackInCasterForm`; S15, S17, S19 to S21, S23, S40 `testOnlyFramesThatShowYouCarryTheBar`
and `TestTargetFocusFiveSecond.testTheTargetFrameOnYouShowsTheBar`; S18, S38 `testAHiddenAnswerGoesToTheGame`; S22
`testOtherMembersCastsNeverStartIt`; S25, S28 `testTheBarSitsOnTheStrip` (the bar is the strip's child, so the
strip's own hide covers it; the strip itself is not hidden in these tests); S26, S27, S39
`testTheOptionTurnsTheBarOff`; S29 the in-combat parts of `testTheOptionTurnsTheBarOff` and
`testAHiddenAnswerGoesToTheGame`; S30 `testTheBarFollowsAGroupChange`; S31
`TestTargetFocusFiveSecond.testTheBarFollowsTheTargetToAndFromYou`; S32 to S34 `testDeathAndReloadEndTheBar`; S35,
S36 `testFiveSecondBarOnOneFakeHealer`. S16 and S24 rest on the group header and the resource-bar setting, which this
story does not change, and have no test of their own.

## Mutations

| # | File | Line replaced | Became | Row run | Failure line |
| --- | --- | --- | --- | --- | --- |
| M1 | `Core.lua` | `function NeoHeal:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)` | the same with `do return end` after it | `TestFiveSecondCore.testTheEventsReachTheBar` | `fivesecond_test.lua:430: expected: {{"player", "Cast-1", 2061}, {"player", "Cast-2", 15407}} actual: {{"player", "Cast-2", 15407}}` |
| M2 | `Core.lua` | `"UPDATE_BINDINGS", "PLAYER_FOCUS_CHANGED", "UNIT_SPELLCAST_SUCCEEDED",` | without `"UNIT_SPELLCAST_SUCCEEDED",` | `TestFiveSecondCore.testBothCastEventsAreRegistered` | `fivesecond_test.lua:406: UNIT_SPELLCAST_SUCCEEDED isn't registered expected: true, actual: false` |
| M3b | `Options.lua` | `{ kind = "checkbox", key = "showFiveSecond", label = L.SHOW_FIVE_SECOND },` | a comment | `TestFiveSecondOption.testTheFiveSecondOptionIsOnTheLayoutPage` | `options_test.lua:609: no five-second checkbox on the Layout page expected: not nil, actual: nil` |
| M4 | `Preview.lua` | `frame.fiveSecond:SetShown(show and NeoHeal.db.layout.showFiveSecond == true)` | `frame.fiveSecond:SetShown(show)` | `TestPreview.testFiveSecondBarOnOneFakeHealer` | `preview_test.lua:410: Seraphine shows a five-second bar with the option off expected: false, actual: true` |
| M5 | `UnitButton.lua` | `local fiveSecond = CreateFrame("StatusBar", nil, power)` | the same with `frame` as parent | `TestFiveSecond.testTheBarSitsOnTheStrip` | `fivesecond_test.lua:309: the bar isn't the strip's child expected and actual object should not be different` |
| M6 | `UnitButton.lua` | `return powerType == MANA` | `do return true end` | `TestFiveSecond.testOnlySpendingYourManaCounts` | `fivesecond_test.lua:255: a frame with a rage strip shows a bar expected: nil, actual: 1.0` |
| M7 | `UnitButton.lua` | `if left <= 0 then return nil end` | a comment | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | `fivesecond_test.lua:131: the bar is still there 5 seconds after the cast expected: nil, actual: 0.0` |
| M8 | `UnitButton.lua` | `ShowIfSameUnit(bar, button.unit, "player")` | `bar:Show()` | `TestFiveSecond.testOnlyFramesThatShowYouCarryTheBar` | `fivesecond_test.lua:219: party1 shows the bar expected: nil, actual: 0.8` |
| M9 | `UnitButton.lua` | `castAt = nil` | a comment (the line in `EndCountdown`) | `TestFiveSecond.testTheOptionTurnsTheBarOff` | `fivesecond_test.lua:297: on again, the seconds that were left show expected: nil, actual: 0.8` |
| M10 | `UnitButton.lua` | `EndCountdown()` | a comment (the call in `UpdateFiveSecond`) | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | `fivesecond_test.lua:131: the bar is still there 5 seconds after the cast expected: nil, actual: 0.020000000000005` |
| M11 | `UnitButton.lua` | `return IsTrue(hasAura)` | `return true` | `TestFiveSecond.testADruidSeesTheTimeLeftBackInCasterForm` | `fivesecond_test.lua:108: back in caster form Actual: 0.9, expected: 0.6` |
| M12 | `UnitButton.lua` | `if not costs then return false end` | `if not costs then return true end` | `TestFiveSecond.testNoManaSpentLeavesTheBarAsItIs` | `fivesecond_test.lua:164: a wand's Shoot started the bar expected: nil, actual: 1.0` |
| M13 | `UnitButton.lua` | `if unit ~= "player" then return end` | a comment | `TestFiveSecond.testOtherMembersCastsNeverStartIt` | `fivesecond_test.lua:196: another member's cast started your bar expected: nil, actual: 1.0` |
| M14 | `UnitButton.lua` | `UpdateFiveSecondFor(button)` | a comment (the call in `UpdateAll`) | `TestFiveSecond.testTheBarFollowsAGroupChange` | `fivesecond_test.lua:107: the frame that now shows you: no bar expected: not nil, actual: nil` |
| M15 | `UnitButton.lua` | `C_Timer.NewTicker(FIVE_SECOND_TICK, UnitButton.UpdateFiveSecond)` | a comment | `TestFiveSecond.testTheTickerRunsTheUpdate` | `fivesecond_test.lua:377: no ticker runs UpdateFiveSecond expected: not nil, actual: nil` |
| M16 | `UnitButton.lua` | `local FIVE_SECOND_SECONDS = 5` | `local FIVE_SECOND_SECONDS = 6` | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | `fivesecond_test.lua:108: halfway Actual: 0.58333333333333, expected: 0.5` |
| M17 | `UnitButton.lua` | `fiveSecond:SetStatusBarColor(unpack(FIVE_SECOND_COLOR))` | a comment | `TestFiveSecond.testTheBarTakesTheStyle` | `fivesecond_test.lua:327: the bar has no colour of its own expected: not nil, actual: nil` |
| M18 | `UnitButton.lua` | `local castAt` | `castAt = nil` (a global) | `TestFiveSecond.testTheCountdownIsTheModulesOwn` | `fivesecond_test.lua:390: the countdown is a global expected: nil, actual: 1000` |
| M19 | `Core.lua` | `showFiveSecond = true,` | `showFiveSecond = false,` | `TestFiveSecondCore.testOnByDefault` | `fivesecond_test.lua:451: Show five-second rule isn't on by default expected: true, actual: false` |
| M20b | `Locales/enUS.lua` | `L.SHOW_FIVE_SECOND = "Show five-second rule"` | a comment | `TestFiveSecondOption.testTheFiveSecondOptionIsOnTheLayoutPage` | `options_test.lua:604: no string for the option: the checkbox shows its key expected: not nil, actual: nil` |
| M21 | `Preview.lua` | `ShowFakeFiveSecond(frame, member == LOW_MANA_MEMBER)` | `ShowFakeFiveSecond(frame, member == 3)` | `TestPreview.testFiveSecondBarOnOneFakeHealer` | `preview_test.lua:401: the fake healer shows no five-second bar expected: true, actual: false` |
| M22 | `Preview.lua` | `frame.fiveSecond:Hide()` | a comment (the line in `DecoratePet`) | `TestPreview.testFiveSecondBarOnOneFakeHealer` | `preview_test.lua:404: Shadowmaw shows a five-second bar expected: false, actual: true` |

Superseded runs: M3 (the same mutation as M3b, red with `options_test.lua:608: no five-second checkbox on the Layout
page`) ran before the option test changed, and M20 (the same mutation as M20b) stayed green: a missing string shows
its own key, so the checkbox was still found by that key. The test now looks for the string in the table itself
(M20b), and M3b ran again on the changed test. The line numbers of M1, M2 and M4 are from before
`testTheCountdownIsTheModulesOwn` was added. Two attempts on `Core.lua`'s `if not self.db then return end` matched 2
and 4 lines; the mutator refused them and nothing ran.

Mutation runs: 24 of 25.

## Fix round 1

The Review's two findings changed five sites; their earlier rows (`UnitButton.lua:831-835`, `849-864`, `934-946`,
`Core.lua:212-226`, `281-282`) are superseded by the rows below. New and changed tests:
`testAHiddenPowerTypeOnYourRaidFrameStillShowsTheBar` (S18, S38: a raid frame that hides who it is and its power
type), `testACastWithAHiddenUnitIsYours` (the events are registered for "player", so a hidden unit is yours), and
`testBothCastEventsAreRegistered`, which now requires both events registered for "player" only. Both finding tests
were red on the pre-fix code before the fix landed (`fivesecond_test.lua:255: the hidden answer didn't reach the
bar`; `fivesecond_test.lua:440: UNIT_SPELLCAST_SUCCEEDED is registered for every unit`). The fallback test for a client
without `RegisterUnitEvent` was dropped: `Core.lua` already needs that method for `UNIT_TARGET`, so such a client
never loaded NeoHeal. `lua spec/run.lua`: 335 tests, 0 failures, before and after the mutations.

| Site (file:line) | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `UnitButton.lua:828-841` | `TestFiveSecond.testAHiddenPowerTypeOnYourRaidFrameStillShowsTheBar` | F1: `fivesecond_test.lua:263: the hidden answer didn't reach the bar expected and actual object should not be different` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:855-858` | `TestFiveSecond.testAHiddenPowerTypeOnYourRaidFrameStillShowsTheBar` | F2: `fivesecond_test.lua:272: a warrior's raid frame shows the bar expected: false, actual: true` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:934-950` | `TestFiveSecond.testACastWithAHiddenUnitIsYours` (and `testOtherMembersCastsNeverStartIt` for a readable unit) | F3: `fivesecond_test.lua:107: a cast with a hidden unit didn't start the bar: no bar expected: not nil, actual: nil` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `Core.lua:213-226` | `TestFiveSecondCore.testTheEventsReachTheBar` | F5: `fivesecond_test.lua:475: expected: {{"player", "Cast-1", 2061}, {"player", "Cast-2", 15407}} actual: {{"player", "Cast-2", 15407}}` (the changed part is the comment, which no test can fail on; the handler was proved again on the changed file) | `Core.lua` cb6c22a837ad5643f1e8ed39f1a6a98c86905693 |
| `Core.lua:277-298` | `TestFiveSecondCore.testBothCastEventsAreRegistered` | F4: `fivesecond_test.lua:448: UNIT_SPELLCAST_SUCCEEDED is registered for every unit expected: nil, actual: true` | `Core.lua` cb6c22a837ad5643f1e8ed39f1a6a98c86905693 |

| # | File | Line replaced | Became | Row run | Failure line |
| --- | --- | --- | --- | --- | --- |
| F1 | `UnitButton.lua` | `local function ShowsManaStrip()`, `local powerType = UnitPowerType("player")`, `if left == nil or not button.unit or not ShowsManaStrip() then` (three lines, the finding as it was) | `ShowsManaStrip(unit)`, `UnitPowerType(unit)`, `ShowsManaStrip(button.unit)` | `TestFiveSecond.testAHiddenPowerTypeOnYourRaidFrameStillShowsTheBar` | `fivesecond_test.lua:263: the hidden answer didn't reach the bar` |
| F2 | `UnitButton.lua` | `if left == nil or not button.unit or not ShowsManaStrip() then` | `if left == nil or not button.unit then` | `TestFiveSecond.testAHiddenPowerTypeOnYourRaidFrameStillShowsTheBar` | `fivesecond_test.lua:272: a warrior's raid frame shows the bar expected: false, actual: true` |
| F3 | `UnitButton.lua` | `if not IsSecret(unit) and unit ~= "player" then return end` | `if unit ~= "player" then return end` | `TestFiveSecond.testACastWithAHiddenUnitIsYours` | `fivesecond_test.lua:107: a cast with a hidden unit didn't start the bar: no bar expected: not nil, actual: nil` |
| F4 | `Core.lua` | `eventFrame:RegisterUnitEvent(event, "player")` | `eventFrame:RegisterEvent(event)` | `TestFiveSecondCore.testBothCastEventsAreRegistered` | `fivesecond_test.lua:448: UNIT_SPELLCAST_SUCCEEDED is registered for every unit expected: nil, actual: true` |
| F5 | `Core.lua` | `function NeoHeal:UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID)` | the same with `do return end` after it | `TestFiveSecondCore.testTheEventsReachTheBar` | `fivesecond_test.lua:475: expected: {{"player", "Cast-1", 2061}, {"player", "Cast-2", 15407}} actual: {{"player", "Cast-2", 15407}}` |

Mutation runs this round: 5 of 10, all listed above (F1 to F5). The other 5 of the cap were not used: no other
mutation ran in fix round 1. Besides them, one unmutated run of the five-second rows on the pre-fix copy showed the
two finding tests red before the fix landed (the lines quoted above), and the whole suite ran in the working tree.

## Re-proof after fix round 1

Fix round 1 changed `UnitButton.lua` and `Core.lua`, so every earlier row on those files had a stale "Proved on" hash.
The copy was refreshed from the working tree (its `UnitButton.lua`, `Core.lua`, `spec/fivesecond_test.lua` and
`spec/support.lua` compared byte for byte with the working tree's) and each of those sites was mutated again with
the same mutation as before, at its current line. These rows replace the earlier rows for the same sites.

| Site (file:line, current) | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `UnitButton.lua:21-24` | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | R1: `fivesecond_test.lua:108: halfway Actual: 0.58333333333333, expected: 0.5` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:548-557` | `TestFiveSecond.testTheBarTakesTheStyle` | R2: `fivesecond_test.lua:359: the bar has no colour of its own expected: not nil, actual: nil` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:825-826` | `TestFiveSecond.testTheCountdownIsTheModulesOwn` | R3: `fivesecond_test.lua:422: the countdown is a global expected: nil, actual: 1000` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:842-848` (was 839-845) | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | R4: `fivesecond_test.lua:131: the bar is still there 5 seconds after the cast expected: nil, actual: 0.0` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:873-880` (was 870-877) | `TestFiveSecond.testTheOptionTurnsTheBarOff` | R5: `fivesecond_test.lua:329: on again, the seconds that were left show expected: nil, actual: 0.8` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:883-893` (was 880-890) | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | R6: `fivesecond_test.lua:131: the bar is still there 5 seconds after the cast expected: nil, actual: 0.020000000000005` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:898-912` (was 895-909) | `TestFiveSecond.testADruidSeesTheTimeLeftBackInCasterForm` | R7: `fivesecond_test.lua:108: back in caster form Actual: 0.9, expected: 0.6` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:914-935` (was 911-932) | `TestFiveSecond.testNoManaSpentLeavesTheBarAsItIs` | R8: `fivesecond_test.lua:164: a wand's Shoot started the bar expected: nil, actual: 1.0` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:1075` (was 1068) | `TestFiveSecond.testTheBarFollowsAGroupChange` | R9: `fivesecond_test.lua:107: the frame that now shows you: no bar expected: not nil, actual: nil` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:1163-1172` (was 1156-1165) | `TestFiveSecond.testTheBarSitsOnTheStrip` | R10: `fivesecond_test.lua:341: the bar isn't the strip's child expected and actual object should not be different` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `UnitButton.lua:1512-1515` (was 1508) | `TestFiveSecond.testTheTickerRunsTheUpdate` | R11: `fivesecond_test.lua:409: no ticker runs UpdateFiveSecond expected: not nil, actual: nil` | `UnitButton.lua` 3a02d5241e9c3d7b7e7d95a4a701a207f2260aa0 |
| `Core.lua:30` | `TestFiveSecondCore.testOnByDefault` | R12: `fivesecond_test.lua:487: Show five-second rule isn't on by default expected: true, actual: false` | `Core.lua` cb6c22a837ad5643f1e8ed39f1a6a98c86905693 |

| # | File | Line replaced | Became | Row run | Failure line |
| --- | --- | --- | --- | --- | --- |
| R1 | `UnitButton.lua` | `local FIVE_SECOND_SECONDS = 5` | `local FIVE_SECOND_SECONDS = 6` | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | `fivesecond_test.lua:108: halfway Actual: 0.58333333333333, expected: 0.5` |
| R2 | `UnitButton.lua` | `fiveSecond:SetStatusBarColor(unpack(FIVE_SECOND_COLOR))` | a comment | `TestFiveSecond.testTheBarTakesTheStyle` | `fivesecond_test.lua:359: the bar has no colour of its own` |
| R3 | `UnitButton.lua` | `local castAt` | `castAt = nil` (a global) | `TestFiveSecond.testTheCountdownIsTheModulesOwn` | `fivesecond_test.lua:422: the countdown is a global expected: nil, actual: 1000` |
| R4 | `UnitButton.lua` | `if left <= 0 then return nil end` | a comment | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | `fivesecond_test.lua:131: the bar is still there 5 seconds after the cast expected: nil, actual: 0.0` |
| R5 | `UnitButton.lua` | `castAt = nil` (in `EndCountdown`) | a comment | `TestFiveSecond.testTheOptionTurnsTheBarOff` | `fivesecond_test.lua:329: on again, the seconds that were left show expected: nil, actual: 0.8` |
| R6 | `UnitButton.lua` | `EndCountdown()` (in `UpdateFiveSecond`) | a comment | `TestFiveSecond.testTheBarIsGoneAfterFiveSeconds` | `fivesecond_test.lua:131: the bar is still there 5 seconds after the cast expected: nil, actual: 0.020000000000005` |
| R7 | `UnitButton.lua` | `return IsTrue(hasAura)` | `return true` | `TestFiveSecond.testADruidSeesTheTimeLeftBackInCasterForm` | `fivesecond_test.lua:108: back in caster form Actual: 0.9, expected: 0.6` |
| R8 | `UnitButton.lua` | `if not costs then return false end` | `if not costs then return true end` | `TestFiveSecond.testNoManaSpentLeavesTheBarAsItIs` | `fivesecond_test.lua:164: a wand's Shoot started the bar expected: nil, actual: 1.0` |
| R9 | `UnitButton.lua` | `UpdateFiveSecondFor(button)` (in `UpdateAll`) | a comment | `TestFiveSecond.testTheBarFollowsAGroupChange` | `fivesecond_test.lua:107: the frame that now shows you: no bar expected: not nil, actual: nil` |
| R10 | `UnitButton.lua` | `local fiveSecond = CreateFrame("StatusBar", nil, power)` | the same with `frame` as parent | `TestFiveSecond.testTheBarSitsOnTheStrip` | `fivesecond_test.lua:341: the bar isn't the strip's child expected and actual object should not be different` |
| R11 | `UnitButton.lua` | `C_Timer.NewTicker(FIVE_SECOND_TICK, UnitButton.UpdateFiveSecond)` | a comment | `TestFiveSecond.testTheTickerRunsTheUpdate` | `fivesecond_test.lua:409: no ticker runs UpdateFiveSecond expected: not nil, actual: nil` |
| R12 | `Core.lua` | `showFiveSecond = true,` | `showFiveSecond = false,` | `TestFiveSecondCore.testOnByDefault` | `fivesecond_test.lua:487: Show five-second rule isn't on by default expected: true, actual: false` |

Mutation runs for the re-proof: 12 of 14.

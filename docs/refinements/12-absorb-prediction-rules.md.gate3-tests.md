# Gate 3 tests: #12 Any absorb spell on left click is predicted with Power Word: Shield rules

Tests in `spec/prediction_test.lua` (classes `TestLeftClickHeal`, `TestHealPrediction`, `TestShieldRedraws`) and
the fake spells in `spec/support.lua` (Power Word: Shield rank 10 and Ice Barrier by name; their ids not checked in
game). `lua spec/run.lua -p TestLeftClickHeal -p TestHealPrediction -p TestShieldRedraws`: 44 tests, 0 failures,
before and after the mutations. Each mutation ran in a copy of the addon files, `Locales/` and `spec/`, outside the
repository: the file was saved aside, one whole line replaced, the named rows run, the saved file copied back.
"Proved on" is `git hash-object --no-filters` of the restored file, the same as the working tree's.

## Site to test

| Site (file:line) | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `ClickCast.lua:619-637` | `TestLeftClickHeal` contract tests (5, the fourth return value) and every shield test in `TestHealPrediction` | M1: `prediction_test.lua:89: expected: {942, 942, "absorb", 17} actual: {942, 942, "absorb"}` (14 red) | `ClickCast.lua` 2d97cfe3c43f3264ab1aae25d337b5bde3d8e3fb |
| `UnitButton.lua:194-205` | `testNoShieldOnWeakenedSoul`, `testNoShieldOnAShieldStillUp`, the hidden-aura tests, `testPowerWordShieldShowsOnYourOwnFrame` (rank 10) | M2: `prediction_test.lua:299: expected: "hidden" actual: 942` (6 red) | `UnitButton.lua` cb7e37d893baa98c5b47b7227ba011240633cb36 |
| `UnitButton.lua:207-217` | `testAShieldThatOnlyGoesOnYouShowsNothingWhereTheGameHidesWhoIsYou` | M3a: `prediction_test.lua:468: your own frame expected: 438, actual: "hidden"`; M3b: `prediction_test.lua:465: a raid frame expected: "hidden" actual: 438` | `UnitButton.lua` cb7e37d893baa98c5b47b7227ba011240633cb36 |
| `UnitButton.lua:219-224` | `testAShieldThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYou`, `TestShieldRedraws` (target, focus, roster, aura), `testAnotherShieldShowsNothingWhileItsOwnIsUpOrTheAurasAreHidden` | M4a: `prediction_test.lua:448: another member's frame expected: "hidden" actual: 438`, `:663: target changed to party1`, `:678: another member behind it`; M4b: `prediction_test.lua:506: its own aura up expected: "hidden" actual: 438`, `:697: your own Ice Barrier landed` | `UnitButton.lua` cb7e37d893baa98c5b47b7227ba011240633cb36 |
| `UnitButton.lua:226-239` | `testAShieldThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYou`, `testPowerWordShieldsAurasLeaveAnotherShieldShowing`, `testTheBarFollowsYourOwnShieldComingAndGoing`, the existing Power Word: Shield tests, `testAnotherShieldShowsNothingWhileItsOwnIsUpOrTheAurasAreHidden` | M5a: `prediction_test.lua:450: a pet's frame expected: "hidden" actual: 438`; M5b: `prediction_test.lua:291: expected: 942, actual: "hidden"`; M5c: `prediction_test.lua:519: no name for spell 11426 expected: "hidden" actual: 438` | `UnitButton.lua` cb7e37d893baa98c5b47b7227ba011240633cb36 |
| `UnitButton.lua:241-260` | every shield test in `TestHealPrediction` | M6: `prediction_test.lua:291: expected: 942, actual: "hidden"` (9 red) | `UnitButton.lua` cb7e37d893baa98c5b47b7227ba011240633cb36 |

Rows to tests: S1, S2 `testPowerWordShieldShowsOnYourOwnFrame`; S3 to S5 the existing shield tests; S6 to S8, S10
`testAShieldThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYou`; S9 `...WhereTheGameHidesWhoIsYou`; S11
`testPowerWordShieldsAurasLeaveAnotherShieldShowing`; S12, S13 `testAnotherShieldShowsNothingWhileItsOwnIsUpOrTheAurasAreHidden`
and `testAnotherShieldShowsNothingWhenTheAurasAreSecret`; S14, S19 `testTheBarFollowsYourOwnShieldComingAndGoing`;
S15 `testTheShieldFollowsTheTargetOrFocusUnderTheMouse`; S16 `testAShieldOnAModifierFollowsTheModifierAndTheFrame`;
S17 `testAHealIgnoresTheShieldRules`; S18 `testTheShieldFollowsARosterChangeUnderTheMouse`.

`TestShieldRedraws` runs the real redraws on a wider fake button: `PLAYER_TARGET_CHANGED`, `PLAYER_FOCUS_CHANGED`
and `GROUP_ROSTER_UPDATE` through `UpdateAll`, and an aura change through `UpdateAllAuras`, which runs the same
`UpdateAuras` as a `UNIT_AURA` batch; the `UNIT_AURA` event itself is not fired there.

## Mutations

| # | File:line | Mutation | Rows run | Result |
| --- | --- | --- | --- | --- |
| M1 | `ClickCast.lua:637` | `spellID` dropped from the return | `TestLeftClickHeal`, `TestHealPrediction` | 14 failures; `:89: expected: {942, 942, "absorb", 17} actual: {942, 942, "absorb"}` |
| M2 | `UnitButton.lua:201` | `CanTakePowerWordShield` returns `true` | `TestHealPrediction` | 6 failures; `:299: expected: "hidden" actual: 942` |
| M3a | `UnitButton.lua:212` | `unit == "player" or` dropped | `WhereTheGameHides` | 1 failure; `:468: your own frame expected: 438, actual: "hidden"` |
| M3b | `UnitButton.lua:212` | `IsTrue` dropped, the answer used as is | `WhereTheGameHides` | 1 failure; `:465: a raid frame expected: "hidden" actual: 438` |
| M4a | `UnitButton.lua:222` | the `ShowsThePlayer` guard removed | `OnlyGoesOnYouShowsOnly`, `TestShieldRedraws` | 3 failures; `:448: another member's frame expected: "hidden" actual: 438` |
| M4b | `UnitButton.lua:223` | the own-aura check returns `true` | `WhileItsOwnIsUp`, `ComingAndGoing` | 2 failures; `:506: its own aura up expected: "hidden" actual: 438` |
| M5a | `UnitButton.lua:237` | every shield takes Power Word: Shield's rule | `OnlyGoesOnYouShowsOnly`, `LeaveAnotherShield`, `ComingAndGoing` | 3 failures; `:450: a pet's frame expected: "hidden" actual: 438` |
| M5b | `UnitButton.lua:237` | no shield takes Power Word: Shield's rule | `TestHealPrediction` | 4 failures; `:291: expected: 942, actual: "hidden"` |
| M5c | `UnitButton.lua:236` | the nil-name guard removed | `WhileItsOwnIsUp` | 1 failure; `:519: no name for spell 11426 expected: "hidden" actual: 438` |
| M6 | `UnitButton.lua:257` | `spellID` not passed to `CanTakeShield` | `TestHealPrediction` | 9 failures; `:291: expected: 942, actual: "hidden"` |

10 mutation runs of the 15 allowed. Not checked in game: everything above runs on the fake API under Lua 5.4.

## Fix round 1

Reviewer finding: `TestShieldRedraws:setUp` set no `GameTooltip`, which `OnLeave` reads (`UnitButton.lua:1215`); the
class passed only because `TestHealPrediction` ran first and left one behind. Seen before the fix:
`lua spec/run.lua -p testTheShieldFollowsTheTargetOrFocusUnderTheMouse` gave
`./UnitButton.lua:1215: attempt to index a nil value (global 'GameTooltip')` and
`Ran 1 tests in 0.002 seconds, 0 successes, 1 error, 289 non-selected`.

Fix: `setUp` overrides `GameTooltip` with `Support.FakeTooltip()`, restored in `tearDown` like the other overrides.
The test lines after `setUp` moved down one; the red lines above quote the numbers of the run that produced them.
The sites are unchanged, so their proofs stand.

Runs after the fix:

| Command | Result line |
| --- | --- |
| `lua spec/run.lua -p testTheShieldFollowsTheTargetOrFocusUnderTheMouse` | `Ran 1 tests in 0.002 seconds, 1 success, 0 failures, 289 non-selected` |
| `lua spec/run.lua -p testTheShieldFollowsARosterChangeUnderTheMouse` | `Ran 1 tests in 0.003 seconds, 1 success, 0 failures, 289 non-selected` |
| `lua spec/run.lua -p testTheBarFollowsYourOwnShieldComingAndGoing` | `Ran 1 tests in 0.002 seconds, 1 success, 0 failures, 289 non-selected` |
| `lua spec/run.lua` | `Ran 290 tests in 1.417 seconds, 290 successes, 0 failures` |

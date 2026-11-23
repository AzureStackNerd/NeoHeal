# Gate 3: bug #21, the TestWriter's state

Appended after each area, so a replacement reads this file instead of a message.

## Before the build

Written before the Developer's first edit, on the base `UnitButton.lua` `6d0b41cb57d005b978d177b95ba2ee61b231227d`.
Every row is driven through the hover (`UnitButton.OnEnter`), the modifier watcher, `PLAYER_TARGET_CHANGED` /
`PLAYER_FOCUS_CHANGED` or `GROUP_ROSTER_UPDATE`; none calls a function the build has yet to write. All in
`spec/prediction_test.lua` (`10497efaf928fb144707a9b03f2e1cf068e916a3` at this run), fakes in `spec/support.lua`
(`63015ef2ee7c4244514cafb3a0eec70ca300bc72`). Command: `lua spec/run.lua -v -p GroupHeal -p FromAGroupHeal`: 12 tests
ran, 10 red, 2 green. The whole suite after these edits: 390 tests, 380 green, the 10 red ones these; no other test
changed result.

The fakes: `IsInRaid` (false), `GetNumSubgroupMembers` (0) and `GetRaidRosterInfo` (nothing) with solo defaults in
`InstallGlobals`; per test, the file's `Group(world)` sets `IsInRaid`, `GetNumSubgroupMembers`, `UnitInRaid`,
`GetRaidRosterInfo`, `UnitIsUnit` and `UnitIsPlayer` from one table read live, and `TestShieldRedraws:Raid()` does the
same through `Override`. A hidden answer is a `Support.Secret`, in `TestHealPrediction` only, whose `setUp(IsHidden)`
sets the secret check before `Core.lua` loads; `GetRaidRosterInfo` reads a hidden index as the index it stands for, so
only a check on the index keeps it out.

A red test stops at its first failing assertion: the assertions after it are not seen red on the base.

| AC | Scenario | Test | On the base |
| --- | --- | --- | --- |
| AC1 | S1, S2, S3, S4, S6, S7 | `testAGroupHealAroundYouShowsOnlyOnTheFramesOfYourGroup` | red: `prediction_test.lua:1014: solo, the focus frame on another player` expected `{"hidden", "hidden"}` actual `{312, 21}` |
| AC1 | S5 | `testAGroupHealAroundYouShowsNothingOnAPet` | red: `:1061: in a raid, pet` expected hidden, actual `{312, 21}` |
| AC1 | S8, plus the How's extra rows: both groups nil; a raid with "is it you" hidden and the roster readable; a party with it hidden; each index or group hidden or missing alone | `testAGroupHealAroundYouShowsNothingWhereTheGameHidesYourGroup` | red: `:1099: your raid index hidden, raid1, out of combat` expected hidden, actual `{312, 21}` |
| AC1 | S9, and #20's dragged row `testAGroupHealYouCastOnYourselfShowsAsToday`, rewritten into this test (`raid12` of another group now none) | `testAGroupHealAroundYouShowsOnlyOnTheFramesOfYourGroupInCombat` | red: `:1144: in a raid, raid12 of another group, out of combat` expected hidden, actual `{312, 21}` |
| AC2 | S10 | `testAGroupHealOnAModifierFollowsTheModifierAndTheFrame` | red: `:1157: raid5 with Shift` expected hidden, actual `{312, 21}` |
| AC2 | S11 | `TestShieldRedraws.testTheGroupHealFollowsTheTargetOrFocusUnderTheMouse` | red: `:1298: <target or focus> changed to raid5 of another group` (which of the two runs first varies by run) expected hidden, actual `{312, 21}` |
| AC2 | S12 | `TestShieldRedraws.testTheGroupHealFollowsARosterChangeUnderTheMouse` | red: `:1316: a member of another group behind it` expected hidden, actual `{312, 21}` |
| AC2 | S13 (the member moves, then you move) | `TestShieldRedraws.testTheGroupHealFollowsAMoveToAnotherGroupUnderTheMouse` | red: `:1329: raid1 moved to group 2` expected hidden, actual `{312, 21}` |
| AC3 | S14 | `TestShieldRedraws.testAGroupHealShowsOnAMemberOfYourGroupOutOfItsReach` | green: works today and must stay so (option a): the range is asked (the row checks `UnitInRange` was called), and the bars do not follow it |
| AC5 | S16 | `testAGroupHealCastOnTheClickedMemberShowsOnEveryFrame` | green: Chain Heal shows on every frame today and must keep doing so; a Shaman has no group-heal list entry |
| AC5 | S17 | #20's and #12's existing tests in `spec/prediction_test.lua` | green, unchanged |
| AC5 | S18, plus the How's order row (Prayer of Healing while both Desperate Prayer ids give no name) and "596 unnamed, Flash Heal on your own frame only" | `testAHealThatCantBeToldFromAGroupHealShowsOnlyOnAFrameThatShowsYou` | red: `:1200: Prayer of Healing unnamed, Flash Heal on party1` expected hidden, actual `{1887, 306}`; its cases with Prayer of Healing clicked (no name of its own, no class, Desperate Prayer unnamed) give the same as today |
| AC5 | S19 | `testAGroupHealsNameGivenLateCountsFromTheNextHover` | red: `:1223: no name yet, Flash Heal on party1` expected hidden, actual `{1887, 306}` |

## After the build: test changes

Two changes to `testAGroupHealAroundYouShowsNothingWhereTheGameHidesYourGroup`, made after the first mutation round
showed what no row could catch (see Mutations):

- A case "both groups hidden": one `Support.Secret` for both group numbers. Lua finds a value equal to itself without
  asking it, so only the checks on the hidden groups keep the bars off.
- The `Group` fake's `GetRaidRosterInfo` raises without a number index, as `IsPlayerSpell`'s fake does for a missing
  spell id, and each hidden or missing case asserts the hover raised nothing before it reads the bars. What the game's
  `GetRaidRosterInfo` does without an index is not checked in game; `UnitInRaid` may give nil (its `result` is
  Nilable in Blizzard's generated `UnitDocumentation.lua`).

Both rows green on the built code. The test file's hash moved, so every mutation was run again on the new bytes; the
results below are that second round.

## Site to test

Proved on: `UnitButton.lua` `c19cd99177a56d9086acdafd361e0f56ed0a587e` (byte-identical in the copy after every
restore, checked per run), `spec/prediction_test.lua` `d6aebe4b00ceaf6590f0ae558aadbdf0b45af2e9`, `spec/support.lua`
`63015ef2ee7c4244514cafb3a0eec70ca300bc72`. Each mutation ran the whole suite in the copy; `m` ids are in Mutations.

| Site (file:line) | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `UnitButton.lua:262-272` `YOUR_GROUP_HEALS` | `testAGroupHealAroundYouShowsNothingOnAPet` (and 9 more rows) | m01: `:1064: in a raid, pet` expected hidden, actual `{312, 21}` | c19cd99 |
| `UnitButton.lua:274-293` `HealNames` | S19 `testAGroupHealsNameGivenLateCountsFromTheNextHover`; #20's `testAHiddenSpellNameCantBeToldApart`, `testEveryNameOfTheListedHealCounts` | m02: `:1236: no name yet, Flash Heal on party1` actual `{1887, 306}`; m03: `:884: Desperate Prayer's names hidden, Flash Heal on party1` actual `{1887, 306}`; m04: `:893: Desperate Prayer on party1` actual `{134, 36}` | c19cd99 |
| `UnitButton.lua:295-315` `HealTargets` | S18 `testAHealThatCantBeToldFromAGroupHealShowsOnlyOnAFrameThatShowsYou`, S19, S16 `testAGroupHealCastOnTheClickedMemberShowsOnEveryFrame`, the pet row; #20's hidden-name, class and modifier rows | m05: `:879: Flash Heal's name hidden, party1`; m06: `:931: a hidden class, party1`; m07: `:1236: no name yet, Flash Heal on party1`; m08 and m09: `:1226: Desperate Prayer unnamed, Prayer of Healing on party1` actual `{312, 21}`; m10: `:1064: in a raid, pet`; m11: `:781: your own raid frame, out of combat` actual `{134, 36}`; m12: `:1198: raid1` expected `{320, 48}` actual hidden | c19cd99 |
| `UnitButton.lua:317-328` `PET_UNITS` | `testAGroupHealAroundYouShowsNothingOnAPet` | m13: `:1064: in a raid, pet`; m14: `in a raid, partypet1`; m15: `in a raid, raidpet1`; each actual `{312, 21}` | c19cd99 |
| `UnitButton.lua:330-348` `InYourGroup` | the four AC1 rows | m16, m18: `:1064: in a raid, pet`; m17: `:1130: in a party, 'is it you' hidden, your own frame` expected `{312, 21}` actual hidden; m19: `:1064: in a raid, target`; m20: `in a raid, focus`; m21: `:1070: in a party, party1 (the control)`; m22: `:1131: in a party, 'is it you' hidden, party1`; m24: `:1026: in a party, the target frame on party2`; m25, m26: `:1132: in a party, 'is it you' hidden, the target frame` actual `{312, 21}`; m27: `:1112: your raid index hidden, raid1`; m28: `:1111: no raid index for you, raid1, out of combat: the hover raised ... GetRaidRosterInfo needs a raid index`; m29: `:1112: raid1's raid index hidden, raid1`; m30: `:1111: no raid index for raid1 ... the hover raised`; m31: `:1111: no raid index for you ... the hover raised`; m34: `:1112: both groups hidden, raid1`; m37: `:1112: no group for either, raid1`; m38: `:1122: 'is it you' hidden, raid5`; m39: `:1062: in a raid, raid1 (the control)`. Survivors m23, m32, m33, m35, m36: equivalent, see Mutations | c19cd99 |
| `UnitButton.lua:350-359` `CanTakeHeal` | S16, the pet row, S19 | m40: `:1198: raid1` expected `{320, 48}` actual hidden; m41: `:1062: in a raid, raid1 (the control)` expected `{312, 21}` actual hidden; m42: `:1236: no name yet, Flash Heal on party1` actual `{1887, 306}` | c19cd99 |
| `UnitButton.lua:367-369` comment above `UpdateHealPrediction` | none: a comment | no mutation: a comment has no behaviour | - |
| `docs/features.md:310-329` | none: a doc | no mutation | - |
| `docs/architecture.md:265-288` | none: a doc | no mutation | - |
| `docs/curseforge.md:54` | none: a doc | no mutation | - |
| `docs/extending.md:118-122` | none: a doc | no mutation; its list of what the prediction tests cover matches the rows written | - |

Callers: `HealNames` is called only by `HealTargets`, `HealTargets` and `InYourGroup` only by `CanTakeHeal`, and
`CanTakeHeal` only by `UpdateHealPrediction` (grep of the repository's `*.lua`). `MissingBuffs.lua` has its own
local `InYourGroup`, untouched.

## Mutations

Driver: one file per run, anchored on a whole line, the mutated line printed back from disk before the run, the whole
suite run, its full output kept per mutation, the file restored from its saved bytes and compared. 42 mutations, run
twice (84 runs; the second round after the test change above). `TestRelease`'s check of `git ls-files` fails in the
copy, which is no git repository, and is left out of every result.

| Id | Mutation (`UnitButton.lua`) | Result |
| --- | --- | --- |
| m01 | `YOUR_GROUP_HEALS` Priest list empty | red, 10 tests |
| m02 | `HealNames`: a group with no name no longer gives nil | red, 5 |
| m03 | `HealNames`: a hidden listed name counts | red, 1 |
| m04 | `HealNames`: only the first name of a group | red, 1 |
| m05 | `HealTargets`: a hidden clicked name read | red, 1 |
| m06 | `HealTargets`: a hidden class read | red, 1 |
| m07 | `HealTargets`: an unnamed group list ignored | red, 2 |
| m08 | `HealTargets`: an unnamed self-only list ignored | red, 4 |
| m09 | `HealTargets`: "group" matched before the unnamed-list check | red, 1 |
| m10 | `HealTargets`: "group" answered as "others" | red, 9 |
| m11 | `HealTargets`: "you" dropped | red, 10 |
| m12 | `HealTargets`: "others" answered as nil | red, 16 |
| m13 to m15 | `PET_UNITS` without `pet`, `partypet`, `raidpet` | red, 1 each |
| m16 | the pet pattern needs a digit (`%d+`), so `pet` misses | red, 1 |
| m17 | `InYourGroup`: "shows you" dropped | red, 3 |
| m18 | the pet check dropped | red, 1 |
| m19 | the player check on target or focus dropped | red, 1 |
| m20 | `focus` not treated as target or focus | red, 1 |
| m21 | the party branch dropped | red, 5 |
| m22 | the `partyN` token answer dropped | red, 1 |
| m23 | `not isTargetOrFocus` dropped before the `partyN` match | survived: equivalent. `isTargetOrFocus` is true only for `target` and `focus`, which never match `^party%d+$`, so the term changes no answer |
| m24 | the party loop to 1 member | red, 1 |
| m25 | `IsTrue` dropped around the party `UnitIsUnit` | red, 1 |
| m26 | the party branch's no turned yes | red, 2 |
| m27 | the hidden check on your raid index dropped | red, 1 |
| m28, m30, m31 | the nil check on your index, on theirs, on both dropped | red, 1 / 2 / 2: the S8 row's own "the hover raised" assertion (first round, before the strict fake: survived) |
| m29 | the hidden check on their raid index dropped | red, 1 |
| m32, m33 | the hidden check on one group number dropped (yours, theirs) | survived: equivalent. The other number is readable, so the comparison of a hidden value with it is false in Lua and in the game ("a secret value never equals anything", `docs/forever-api.md`, section 2); the pair is m34 |
| m34 | both hidden checks on the group numbers dropped | red, 1 (the "both groups hidden" case) |
| m35, m36 | the nil check on one group number dropped | survived: equivalent. A nil compared with the other side is false unless that side is nil too, which the remaining check catches; the pair is m37 |
| m37 | both nil checks on the group numbers dropped | red, 1 |
| m38 | same group always | red, 8 |
| m39 | `~=` for `==` | red, 10 |
| m40 | `CanTakeHeal`: "others" no longer shows everywhere | red, 16 |
| m41 | `CanTakeHeal`: "group" asks `ShowsThePlayer` | red, 10 |
| m42 | `CanTakeHeal`: the rest shows everywhere | red, 16 |

## Not done

- Nothing here is checked in game: the fakes give what Blizzard's API docs say as far as the How reads them. What
  `GetRaidRosterInfo` does without an index, and whether a hidden value compared with a number gives false in combat
  as `docs/forever-api.md` says, are not checked in game.

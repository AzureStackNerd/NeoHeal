# Gate 3 tests: #20 A heal that only goes on you shows its prediction on other members' frames

Tests in `spec/prediction_test.lua` (classes `TestHealPrediction` and `TestShieldRedraws`) and the fake spells in
`spec/support.lua`: `Support.DESPERATE_PRAYER` (13908) and `Support.DESPERATE_PRAYER_2` (19236), both named Desperate
Prayer; their ids are Classic's as far as known, not checked in game. The descriptions are the fake's wording, not
the game's. Desperate Prayer's first id and Prayer of Healing join the test file's `KNOWN` spellbook.

Combat in these rows is what the fake can give: `InCombatLockdown` true and the auras refused. No heal rule reads
either; that the game hides nothing else the rule needs in combat is not checked in game. Everything here runs on the
fake API under Lua 5.4.

## Before the build

Run on the base: the working tree before the Developer's first edit (`UnitButton.lua` unmodified,
`git hash-object --no-filters` 830235e78f1b68ccddbf53747b1bfa80e656080e). Each row was also run alone
(`lua spec/run.lua -p <name>`, at least 1 test ran) with the same result. Whole run:
`lua spec/run.lua -p TestLeftClickHeal -p TestHealPrediction -p TestShieldRedraws`: 60 tests, 47 successes,
13 failures (the 13 red rows below; the 44 existing tests pass).

| AC | Rows | Test | On the base |
| --- | --- | --- | --- |
| AC1 | S1 to S5 | `testAHealThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYou` | red: `prediction_test.lua:764: another member's frame expected: {"hidden", "hidden"} actual: {134, 36}` |
| AC1 | S6 | `testAHealThatOnlyGoesOnYouShowsNothingWhereTheGameHidesWhoIsYou` | red: `:781: your own raid frame, out of combat expected: {"hidden", "hidden"} actual: {134, 36}` |
| AC1 | S7 | `testAHealThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYouInCombat` | red: `:795: party1 expected: {"hidden", "hidden"} actual: {134, 36}` |
| AC1 | S8 | `testAHealThatOnlyGoesOnYouOnAModifierFollowsTheModifierAndTheFrame` | red: `:806: party1 with Shift expected: {"hidden", "hidden"} actual: {134, 36}` |
| AC1 | S9 | `TestShieldRedraws.testTheHealFollowsTheTargetOrFocusUnderTheMouse` | red: `:952: target changed to party1 expected: {"hidden", "hidden"} actual: {134, 36}` |
| AC1 | S10 | `TestShieldRedraws.testTheHealFollowsARosterChangeUnderTheMouse` | red: `:968: another member behind it expected: {"hidden", "hidden"} actual: {134, 36}` |
| AC1 | S16 | `testAHiddenHealLeavesTheIncomingHealsAndShieldsInPlace` | red: `:822: expected: {"hidden", "hidden"} actual: {134, 36}` |
| AC1 | S17, the clicked spell unnamed (Flash Heal, then Desperate Prayer) | `testAHealThatCantBeToldApartShowsOnlyOnAFrameThatShowsYou` | red: `:832: Flash Heal unnamed, party1 expected: {"hidden", "hidden"} actual: {1887, 306}` |
| AC1 | S17, every id of the listed heal unnamed | `testAHealThatCantBeToldApartWhenTheListedHealHasNoName` | red: `:847: party1 expected: {"hidden", "hidden"} actual: {1887, 306}` |
| AC1 | S17 control: 13908 unnamed, 19236 named; Desperate Prayer (bound by 19236) on party1 none, Flash Heal on party1 shows | `testOneUnnamedIdOfTheListedHealIsEnough` | red: `:857: Desperate Prayer on party1 expected: {"hidden", "hidden"} actual: {134, 36}`; its Flash Heal half must stay as today |
| AC1 | every name of a group, not the first: 13908 names Renew, 19236 Desperate Prayer | `testEveryNameOfTheListedHealCounts` | red: `:869: Desperate Prayer on party1 expected: {"hidden", "hidden"} actual: {134, 36}` |
| AC1 | no cache: both ids unnamed on the first hover, named on the next | `testAListedHealNamedLaterStillCounts` | red: `:879: no name yet expected: {"hidden", "hidden"} actual: {134, 36}`; a build that keeps the first hover's list goes red at "named now" |
| AC1 | S17, a class NeoHeal can't read (nothing, or a hidden value) | `testAClassThatCantBeReadShowsHealsOnlyOnAFrameThatShowsYou` | red: `:897: no class, party1 expected: {"hidden", "hidden"} actual: {1887, 306}` |
| AC2 | S11, a class not in the list (Shaman): Flash Heal on party1 and your own frame | `testAClassWithoutSuchHealsShowsItsHealsOnEveryFrame` | green: today every heal shows on every frame, and a class without a listed heal must keep that |
| AC2 | S11, S12: Flash Heal on seven frames, in combat, and where the game hides who is you | `testAHealOnAnyFriendlyUnitShowsOnEveryFrame` | green: a heal on any friendly unit shows everywhere today and must stay so |
| AC3 | S13: Prayer of Healing on your own, party1's and a raid member's frame, in and out of combat | `testAGroupHealYouCastOnYourselfShowsAsToday` | green: open point 1 answered (a), it shows as today |
| AC4 | S14, S15 | the existing #12 shield tests, `testNothingWhenTheLeftClickDoesntHeal` and the `TestLeftClickHeal` tests | green (existing): unchanged behaviour |

The line numbers are those of the run that produced them.

## After the build: rows added

Two behaviours of the build had no row to kill them, so two rows were added before the mutations, and one row was
rewritten after M2h:

- `testOneUnnamedIdOfTheListedHealIsEnough` gained the other direction (19236 unnamed, 13908 named): without it,
  dropping 13908 from the list (M1a) survived.
- `testAHiddenSpellNameCantBeToldApart` (new): the clicked spell's name hidden, then both listed names hidden. The
  forever-branch API docs mark no hidden return for `C_Spell.GetSpellName`, but the build guards it, and without the
  row M2b and M2e had nothing to kill them. Whether the client ever hides a spell name is not checked in game.
- `testAListedHealNamedLaterStillCounts` rewritten. In its first form the first hover had Desperate Prayer on the
  click with both its ids unnamed, so the clicked name was missing and the draw returned before reading the list: the
  cache mutant M2h passed it (it was killed only by the S17 row at `:847`). Now the first hover is Flash Heal (named)
  with the list unnamed, so that draw reads the list; the row goes red on a cached build at `:909: named now` and on
  the base at `:905: no name yet, Flash Heal on party1 expected: {"hidden", "hidden"} actual: {1887, 306}`.

## Site to test

Sites from the Developer's `## Sites` and from `git diff`: the code diff is `UnitButton.lua` only (the docs diff is
`docs/architecture.md`, `docs/curseforge.md`, `docs/extending.md` and `docs/features.md`). `SELF_ONLY_HEALS`,
`HealGoesOnOthers` and `CanTakeHeal` have one caller each (`HealGoesOnOthers` in `CanTakeHeal`, `CanTakeHeal` in
`UpdateHealPrediction`); `UpdateHealPrediction`'s callers are unchanged. "Proved on" is `git hash-object --no-filters`
of the restored `UnitButton.lua` in the copy, the same bytes as the working tree
(b7118141ce6942ceab51744f5d3a0de711b65f1b; git's filtered blob id, which the Developer reported, is
6d0b41cb57d005b978d177b95ba2ee61b231227d). The test file proved against: `spec/prediction_test.lua`
4a2fd1e6b00fd100bc16f06d23daa3b65f1bef85 (M2h's re-run and the cache row's base run); the other runs used the copy
before the cache row's rewrite, which changed no other row.

| Site (file:line) | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `UnitButton.lua:249-260` `SELF_ONLY_HEALS` | `testOneUnnamedIdOfTheListedHealIsEnough`, `testEveryNameOfTheListedHealCounts`, every AC1 self-only row | M1a `:868: 19236 unnamed, Flash Heal on party1 expected: {1887, 306} actual: {"hidden", "hidden"}`; M1b `:860: Flash Heal on party1` and `:893: Desperate Prayer on party1 ... actual: {134, 36}`; M1c 12 rows, e.g. `:764: another member's frame expected: {"hidden", "hidden"} actual: {134, 36}` | `UnitButton.lua` b7118141ce6942ceab51744f5d3a0de711b65f1b |
| `UnitButton.lua:262-290` `HealGoesOnOthers` | `testAHealThatCantBeToldApartShowsOnlyOnAFrameThatShowsYou`, `testAHiddenSpellNameCantBeToldApart`, `testAClassThatCantBeReadShowsHealsOnlyOnAFrameThatShowsYou`, `testAHealThatCantBeToldApartWhenTheListedHealHasNoName`, `testEveryNameOfTheListedHealCounts`, `testAListedHealNamedLaterStillCounts`, every AC1 self-only row | M2a `:832: Flash Heal unnamed, party1`; M2b `:879: Flash Heal's name hidden, party1`; M2c `:921: no class, party1`; M2d `:927: a hidden class, party1` (each `expected: {"hidden", "hidden"} actual: {1887, 306}`); M2e `:884: Desperate Prayer's names hidden, Flash Heal on party1`; M2f `:847: party1`; M2g `:893: Desperate Prayer on party1 ... actual: {134, 36}`; M2h `:909: named now ... actual: {134, 36}`; M2i 10 rows, e.g. `:764: another member's frame` | `UnitButton.lua` b7118141ce6942ceab51744f5d3a0de711b65f1b |
| `UnitButton.lua:292-297` `CanTakeHeal` | every row with your own frame (`player`, `raid3`, `target` on you), `testAHealOnAnyFriendlyUnitShowsOnEveryFrame`, `testAClassWithoutSuchHealsShowsItsHealsOnEveryFrame`, `testAGroupHealYouCastOnYourselfShowsAsToday` | M3a 13 rows, e.g. `:768: your own frame expected: {134, 36} actual: {"hidden", "hidden"}`; M3b 13 rows, e.g. `:912: party1` (Shaman), `:957: party1, out of combat` (Prayer of Healing), `:935: party1` (any friendly unit), each `actual: {"hidden", "hidden"}` | `UnitButton.lua` b7118141ce6942ceab51744f5d3a0de711b65f1b |
| `UnitButton.lua:305-306` comment | none: a comment, no behaviour | - | - |
| `UnitButton.lua:315` the heal branch | every AC1 row (14 red) | M4 `:764: another member's frame expected: {"hidden", "hidden"} actual: {134, 36}`, `:976: focus changed to party1`, `:992: another member behind it` | `UnitButton.lua` b7118141ce6942ceab51744f5d3a0de711b65f1b |
| `docs/features.md:297-306` | none: docs | - | - |
| `docs/architecture.md:264-274` | none: docs | - | - |
| `docs/curseforge.md:54` | none: docs | - | - |
| `docs/extending.md:117-119` | none: docs (the test cover) | - | - |

Rows to tests: S1 to S5 `testAHealThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYou`; S6 `...ShowsNothingWhereTheGameHidesWhoIsYou`;
S7 `...ShowsOnlyOnAFrameThatShowsYouInCombat`; S8 `...OnAModifierFollowsTheModifierAndTheFrame`; S9 and S10 the two
`TestShieldRedraws` heal rows; S11 and S12 `testAHealOnAnyFriendlyUnitShowsOnEveryFrame` and
`testAClassWithoutSuchHealsShowsItsHealsOnEveryFrame`; S13 `testAGroupHealYouCastOnYourselfShowsAsToday`; S14 and
S15 the existing #12 and `TestLeftClickHeal` tests (no site touches them; M3b and M4 leave them green or turn them red
only through the heal branch); S16 `testAHiddenHealLeavesTheIncomingHealsAndShieldsInPlace`; S17 the two
`testAHealThatCantBeToldApart...` rows, `testAHiddenSpellNameCantBeToldApart`, `testOneUnnamedIdOfTheListedHealIsEnough`,
`testEveryNameOfTheListedHealCounts`, `testAListedHealNamedLaterStillCounts` and
`testAClassThatCantBeReadShowsHealsOnlyOnAFrameThatShowsYou`.

## Mutations

Driver and mutations as files beside the copy (each anchor dry-matched to exactly one line and the mutated line printed
before the run; the copy's file saved aside, one whole line replaced with its CRLF kept, the three test classes of
`spec/prediction_test.lua` run, the saved file copied back and hashed in the same command). Every run below ran all 61
rows of the file.

| # | File:line | Mutation | Result |
| --- | --- | --- | --- |
| M1a | `UnitButton.lua:259` | 13908 dropped from Desperate Prayer's group | 1 failure; `:868: 19236 unnamed, Flash Heal on party1 expected: {1887, 306} actual: {"hidden", "hidden"}` |
| M1b | `UnitButton.lua:259` | 19236 dropped from Desperate Prayer's group | 2 failures; `:893: Desperate Prayer on party1 ... actual: {134, 36}`, `:860: Flash Heal on party1 ... actual: {"hidden", "hidden"}` |
| M1c | `UnitButton.lua:259` | a Priest's list emptied | 12 failures; `:764: another member's frame ... actual: {134, 36}` |
| M2a | `UnitButton.lua:274` | `or not name` dropped | 1 failure; `:832: Flash Heal unnamed, party1 expected: {"hidden", "hidden"} actual: {1887, 306}` |
| M2b | `UnitButton.lua:274` | `IsSecret(name) or` dropped | 1 failure; `:879: Flash Heal's name hidden, party1 ... actual: {1887, 306}` |
| M2c | `UnitButton.lua:276` | `or not class` dropped | 1 failure; `:921: no class, party1 ... actual: {1887, 306}` |
| M2d | `UnitButton.lua:276` | `IsSecret(class) or` dropped | 1 failure; `:927: a hidden class, party1 ... actual: {1887, 306}` |
| M2e | `UnitButton.lua:282` | a hidden listed name counts (`if listed then`) | 1 failure; `:884: Desperate Prayer's names hidden, Flash Heal on party1 ... actual: {1887, 306}` |
| M2f | `UnitButton.lua:287` | the "group without a name" guard removed | 2 failures; `:847: party1 ... actual: {1887, 306}`, `:884` |
| M2g | `UnitButton.lua:284` | only a group's first name kept (`named = true break`) | 1 failure; `:893: Desperate Prayer on party1 ... actual: {134, 36}` |
| M2h | `UnitButton.lua:277` | the names kept from the first draw (a cache on the namespace) | first run: 1 failure, `:847: party1` only (the cache row passed: see "After the build"); after the rewrite, 2 failures: `:847: party1`, `:909: named now expected: {"hidden", "hidden"} actual: {134, 36}` |
| M2i | `UnitButton.lua:289` | `return true` | 10 failures; `:764: another member's frame ... actual: {134, 36}` |
| M3a | `UnitButton.lua:296` | `or ShowsThePlayer(unit)` dropped | 13 failures; `:768: your own frame expected: {134, 36} actual: {"hidden", "hidden"}` |
| M3b | `UnitButton.lua:296` | `HealGoesOnOthers(spellID) or` dropped | 13 failures; `:912: party1 expected: {1887, 306} actual: {"hidden", "hidden"}` |
| M4 | `UnitButton.lua:315` | the heal branch back to `kind == "heal" and low` | 14 failures; `:764: another member's frame ... actual: {134, 36}` |

Runs: 23 test runs in the copy: 1 unmutated control (61 of 61 green), 15 mutations, 5 of them run twice because the
first output filter dropped the failure lines (the results were the same; only the second, full output is quoted),
M2h's re-run after the cache row's rewrite, and M4 on the rewritten cache row alone for its base red. No mutation
survived. Not checked in game: everything above runs on the fake API under Lua 5.4.

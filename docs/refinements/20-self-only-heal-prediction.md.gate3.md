# Gate 3: bug #20, the Developer's build state

Appended after each area, so a replacement reads this file instead of a message.

## Done and verified

- Gate 2 settled: the refinement's How lines 1 to 12, agreed with architect-20 on 2026-11-23; main relayed AGREED.
- Area 1, source (`UnitButton.lua`): `SELF_ONLY_HEALS`, `HealGoesOnOthers` and `CanTakeHeal` added beside
  `CanTakeShield`, and `UpdateHealPrediction`'s heal branch asks `CanTakeHeal`. `lua spec/run.lua` after the
  build: 378 tests, 0 failures (base: 362); with tester-20's later row in, `lua spec/run.lua` 379 tests,
  0 failures. `node <skill dir>/check-gate.mjs`: PASS. CR 1787 = LF 1787.
- Area 2, docs (`docs/features.md`, `docs/architecture.md`, `docs/curseforge.md`, `docs/extending.md`): the
  self-only heal rule in the heal-prediction paragraph, the module item, the description's prediction line and
  the test cover. After the edits: `lua spec/run.lua` 378 tests, 0 failures; with tester-20's later rows in,
  379 tests, 0 failures; quick checks PASS; every edited file still CRLF, no bare LF.
- Fix round 1, docs only (the Reviewer's finding: the can't-tell case read as "shows nothing"): the two sentences
  in `docs/features.md` and the "refuses" sentence in `docs/architecture.md` restated as the code does it, plus
  the `docs/extending.md` cover line. Source, tests and everything else untouched: `UnitButton.lua`'s hash is
  still `6d0b41cb57d005b978d177b95ba2ee61b231227d`. After the edits: `lua spec/run.lua` 379 tests, 0 failures;
  `node <skill dir>/check-gate.mjs` PASS; CRLF kept (features.md CR 363 = LF 363, architecture.md CR 294 = LF 294,
  extending.md CR 182 = LF 182).

## Sites

| Site (file:line) | What it changes | Serves | Docs that describe it |
| --- | --- | --- | --- |
| `UnitButton.lua:249-260` | `SELF_ONLY_HEALS`, one group of ids per spell (Priest: 13908 and 19236) | AC1, S1-S10, S16, S17 | `docs/features.md:297-308` (1), `docs/architecture.md:264-275` (1) |
| `UnitButton.lua:262-290` | `HealGoesOnOthers(spellID)`: the clicked name and every name of the class's groups read per draw, class guard, safe side when a name is missing | AC1, S11, S17; S6-S8, S9, S10 | `docs/architecture.md:264-275` (1) |
| `UnitButton.lua:292-297` | `CanTakeHeal(unit, spellID)`: a heal that goes on others anywhere, a self-only heal only where `ShowsThePlayer` | AC1, AC2, AC3 | `docs/features.md:297-308` (1), `docs/architecture.md:264-275` (1) |
| `UnitButton.lua:305-306` | the comment above `UpdateHealPrediction`: a self-only heal draws only where the frame shows you | none (comment) | none |
| `UnitButton.lua:315` | the heal branch asks `CanTakeHeal(unit, spellID)` | every AC1 row; S11-S13 unchanged | `docs/features.md:297-308` (1), `docs/architecture.md:264-275` (1), `docs/curseforge.md:54` (1) |
| `docs/features.md:297-308` | the self-only heal paragraph in "Heal prediction"; fix round 1: the can't-tell case takes the same safe side (bars on a frame that shows you, not "nothing"), and Flash Heal's every-frame line names its exception | AC1, AC2, AC3 | - |
| `docs/architecture.md:264-275` | the heal prediction item: `CanTakeHeal`, the per-class list, per-draw names, the class guard; fix round 1: a nil or secret class counts as one NeoHeal can't tell and takes `ShowsThePlayer`, not "refuses" | AC1 | - |
| `docs/curseforge.md:54` | the description's prediction line names a heal that only goes on you | AC1 | - |
| `docs/extending.md:117-119` | what the prediction tests cover now; fix round 1: an unnamed spell or unreadable class takes the same frames | none (test cover) | - |

## AC table (Developer)

| AC | Test row | Seen red | Met |
| --- | --- | --- | --- |
| AC1 | `testAHealThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYou`, `testAHealThatOnlyGoesOnYouShowsNothingWhereTheGameHidesWhoIsYou`, `testAHealThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYouInCombat`, `testAHealThatOnlyGoesOnYouOnAModifierFollowsTheModifierAndTheFrame`, `TestShieldRedraws.testTheHealFollowsTheTargetOrFocusUnderTheMouse`, `TestShieldRedraws.testTheHealFollowsARosterChangeUnderTheMouse`, `testAHiddenHealLeavesTheIncomingHealsAndShieldsInPlace`, `testAHealThatCantBeToldApartShowsOnlyOnAFrameThatShowsYou`, `testAHiddenSpellNameCantBeToldApart`, `testAHealThatCantBeToldApartWhenTheListedHealHasNoName`, `testOneUnnamedIdOfTheListedHealIsEnough`, `testEveryNameOfTheListedHealCounts`, `testAListedHealNamedLaterStillCounts`, `testAClassThatCantBeReadShowsHealsOnlyOnAFrameThatShowsYou` | 13 rows red on the base, each line quoted in `20-self-only-heal-prediction.md.gate3-tests.md` (e.g. `:764: another member's frame expected: {"hidden", "hidden"} actual: {134, 36}`); `testAHiddenSpellNameCantBeToldApart` was written after the build, with its mutation-killed lines M2b and M2e in the same file | yes |
| AC2 | `testAHealOnAnyFriendlyUnitShowsOnEveryFrame`, `testAClassWithoutSuchHealsShowsItsHealsOnEveryFrame`, `testHoveringShowsTheLeftClickHeal` (exists) | green on the base on purpose (the behaviour must stay), quoted with its reason in the same file | yes |
| AC3 | `testAGroupHealYouCastOnYourselfShowsAsToday` | green on the base on purpose | yes |
| AC4 | `testNothingWhenTheLeftClickDoesntHeal` (exists), #12's shield tests in `TestHealPrediction` and `TestShieldRedraws`, `TestLeftClickHeal`'s "nothing when the click doesn't heal the clicked unit", "nothing for a spell not learned", "nothing without a number" | green, unchanged | yes |

The per-site mutation proofs (each changed site red when broken) are tester-20's rows in
`20-self-only-heal-prediction.md.gate3-tests.md` and follow the build; this table's "Seen red"
quotes the before-the-build rows.

## Not done

- The three in-game checks of How line 9, not made here (no game client in this session):
- `/dump C_Spell.GetSpellName(13908), C_Spell.GetSpellName(19236)` on a Priest prints Desperate Prayer for at least one of the two ids. Remco types it and reads the chat output.
- Flash Heal on the left click, hovering party1: its bars show, out of combat and in combat. Remco hovers party1 and looks at the health bar.
- Desperate Prayer on the left click, hovering party1: no bars. Only possible on a character that has the spell, a Human or Dwarf Priest in Classic as far as known; on any other character this check can't be made.

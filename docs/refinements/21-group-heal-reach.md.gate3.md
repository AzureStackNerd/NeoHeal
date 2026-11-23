# Gate 3: bug #21, the Developer's build state

Appended after each area, so a replacement reads this file instead of a message.

## Done and verified

- Gate 2 settled: the refinement's 8 How lines, agreed with architect-21 on 2026-11-23; main relayed AGREED at 3
  points, 6 sites in `UnitButton.lua`, 3 new fakes.
- Base measured before any edit: `git hash-object UnitButton.lua` = `6d0b41cb57d005b978d177b95ba2ee61b231227d`;
  `UnitButton.lua` CR 1787 = LF 1787.
- Area 1, source (`UnitButton.lua`): `YOUR_GROUP_HEALS`, `HealNames`, `HealTargets` (replacing
  `HealGoesOnOthers`), `PET_UNITS`, `InYourGroup` and the three-way `CanTakeHeal`, plus the comment above
  `UpdateHealPrediction`. After the edits: `lua spec/run.lua` 390 tests, 0 failures (base 390 tests with the
  TestWriter's 10 red); `lua spec/run.lua -p TestHealPrediction` 52 tests, 0 failures;
  `node <skill dir>/check-gate.mjs` PASS. `UnitButton.lua` CR 1850 = LF 1850,
  `git hash-object UnitButton.lua` = `c19cd99177a56d9086acdafd361e0f56ed0a587e`.
- Area 2, docs (`docs/features.md`, `docs/architecture.md`, `docs/curseforge.md`, `docs/extending.md`): the group
  heal's frames in the heal-prediction paragraph, `HealTargets` and `InYourGroup` in the module item, the
  description's prediction line, and the prediction cover. After the edits: `lua spec/run.lua` 390 tests, 0
  failures; quick checks PASS; every edited file still CRLF (`features.md` 384/384, `architecture.md` 307/307,
  `curseforge.md` 209/209, `extending.md` 187/187).
- Fix round 1, docs only (the Reviewer's three findings: "it reaches" claimed the heal's distance, the party
  frames were said to keep their bars whatever the game hides, and "unreadable-as-secret" said the opposite of
  the code): `curseforge.md` and `features.md` say "the members of your group"; `features.md` limits the party
  sentence to what the game hides about your group, names the can't-tell heal and party1's none, and limits Holy
  Nova's "everywhere"; `architecture.md` says each answer non-nil and not secret. `UnitButton.lua` untouched, its
  hash still `c19cd99177a56d9086acdafd361e0f56ed0a587e`. After the edits: `lua spec/run.lua` 390 tests, 0
  failures; quick checks PASS; CRLF kept (`features.md` 389/389).

## Sites

| Site (file:line) | What it changes | Serves | Docs that describe it |
| --- | --- | --- | --- |
| `UnitButton.lua:262-272` | `YOUR_GROUP_HEALS`, one group of ids per spell (Priest: 596) | AC1; S1-S9 | `docs/architecture.md:265-288` (1), `docs/features.md:310-329` (1) |
| `UnitButton.lua:274-293` | `HealNames(groups)`: every name a list's ids give, nil when a group gives none; replaces the loop inside `HealGoesOnOthers` | AC5; S18, S19 | `docs/architecture.md:265-288` (1) |
| `UnitButton.lua:295-315` | `HealTargets(spellID)`: three answers and nil, both lists read before the match, class guard kept | AC1, AC3, AC5; S1-S4, S16-S19 | `docs/architecture.md:265-288` (1), `docs/features.md:297-329` (1) |
| `UnitButton.lua:317-328` | `PET_UNITS` and its comment: a pet's frame shows none before any group answer | AC1; S5, S7 | `docs/architecture.md:265-288` (1), `docs/features.md:310-329` (1) |
| `UnitButton.lua:330-348` | `InYourGroup(unit)`: your frame, pet token, party token, player-only target or focus, raid roster subgroups, party `UnitIsUnit` loop | AC1, AC2; S2-S8, S11-S13 | `docs/architecture.md:265-288` (1), `docs/features.md:310-329` (1) |
| `UnitButton.lua:350-359` | `CanTakeHeal(unit, spellID)`: three ways on `HealTargets` | every AC1 row; AC5's S17 rows unchanged | `docs/architecture.md:265-288` (1), `docs/features.md:297-329` (1) |
| `UnitButton.lua:367-369` | the comment above `UpdateHealPrediction`: a group heal draws only on a frame of your group | none (comment) | none |
| `docs/features.md:310-334` | the group heal paragraph in "Heal prediction"; fix round 1: "the members of your group" instead of "it reaches", the party-frame sentence limited to what the game hides about your group, the can't-tell heal named, Holy Nova's "everywhere" limited to the every-frame rule and its exception | AC1, AC2, AC3, AC5 | - |
| `docs/architecture.md:265-288` | the heal prediction item: `HealTargets`, both lists, `InYourGroup`, the hidden and partial answers; fix round 1: each of the four answers non-nil and not secret before they are compared | AC1, AC5 | - |
| `docs/curseforge.md:54` | the description's prediction line names a group heal around you; fix round 1: "the members of your group" instead of "it reaches" | AC1 | - |
| `docs/extending.md:118-123` | what the prediction tests cover now | none (test cover) | - |

## AC table (Developer)

| AC | Test row | Seen red | Met |
| --- | --- | --- | --- |
| AC1 | `testAGroupHealAroundYouShowsOnlyOnTheFramesOfYourGroup`, `testAGroupHealAroundYouShowsNothingOnAPet`, `testAGroupHealAroundYouShowsNothingWhereTheGameHidesYourGroup`, `testAGroupHealAroundYouShowsOnlyOnTheFramesOfYourGroupInCombat` | yes, on the base: `:1014`, `:1061`, `:1099`, `:1144` (the TestWriter's file, "On the base") | yes |
| AC2 | `testAGroupHealOnAModifierFollowsTheModifierAndTheFrame`, `testTheGroupHealFollowsTheTargetOrFocusUnderTheMouse`, `testTheGroupHealFollowsARosterChangeUnderTheMouse`, `testTheGroupHealFollowsAMoveToAnotherGroupUnderTheMouse` | yes, on the base: `:1157`, `:1298`, `:1316`, `:1329` | yes |
| AC3 | `testAGroupHealShowsOnAMemberOfYourGroupOutOfItsReach` | green on purpose: works today and must stay so | yes |
| AC5 | `testAGroupHealCastOnTheClickedMemberShowsOnEveryFrame` (green on purpose), `testAHealThatCantBeToldFromAGroupHealShowsOnlyOnAFrameThatShowsYou`, `testAGroupHealsNameGivenLateCountsFromTheNextHover`, and #20's and #12's existing rows (unchanged) | yes, on the base: `:1200`, `:1223`; S16 and S17 green on purpose | yes |

## Not done

- The How section's two in-game checks, both for Remco, solo except the second:
  1. `/dump C_Spell.GetSpellName(596)` prints "Prayer of Healing".
  2. In a raid, `/dump UnitInRaid("player")` gives your own raid index and
     `/dump select(3, GetRaidRosterInfo(UnitInRaid("player")))` gives your subgroup, in and out of combat.
- The TestWriter's note, for the mutation round: a hidden value on only one of the two group numbers cannot go red
  in these fakes, because Lua 5.4 never calls a metamethod when a table is compared with a number; it is settled at
  mutation time.

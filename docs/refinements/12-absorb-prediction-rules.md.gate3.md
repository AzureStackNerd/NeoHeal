# Gate 3: bug #12, the Developer's build state

Appended after each area, so a replacement reads this file instead of a message.

## Done and verified

- Source, area 1 (`ClickCast.lua`): the spell travels with the amount.
  `lua spec/run.lua -p TestLeftClickHeal` after the edit: 11 tests, 0 failures; the whole file
  `lua spec/run.lua` 279 tests, 0 failures.
- Source, area 2 (`UnitButton.lua`): the two shield rules, the frame-shows-you check, and the bar
  picking the rule by the spell. `lua spec/run.lua` 279 tests, 0 failures;
  `node <skill dir>/check-gate.mjs` PASS (quick checks).
- Rows checked against the fake API with a probe, 21 of 21 as the refinement's Expected says
  (S1 to S5, S6 to S13, S17; S14, S15, S16, S18, S19 are redraw moments proven by the tests).

## Sites

| Site (file:line) | What it changes | Serves | Docs that describe it |
| --- | --- | --- | --- |
| `ClickCast.lua:619-637` | `GetLeftClickAmount` returns `low, high, kind, spellID` (four return values) and its comment says why the spell travels | all shield rows (S1-S19); contract for `UpdateHealPrediction` | `docs/architecture.md:206-219` (the heal prediction item, 1), `docs/extending.md:114-115` (1) |
| `UnitButton.lua:194-205` | `CanTakeShield` renamed `CanTakePowerWordShield`; behaviour unchanged | AC3, S1-S5 | `docs/features.md:230-237` (1), `docs/architecture.md:213-215` (1) |
| `UnitButton.lua:207-217` | new `ShowsThePlayer(unit)`: `unit == "player"`, else `IsTrue(UnitIsUnit(unit, "player"))` | AC1, S6-S10, S15, S18 | none by name; `docs/forever-api.md` section 2 covers the secret answer (0) |
| `UnitButton.lua:219-224` | new `CanTakeOwnShield(unit, name)`: shows you, and no aura of its own name up | AC1, AC2, S11-S13, S19 | `docs/features.md:230-237` (1) |
| `UnitButton.lua:226-239` | new `CanTakeShield(unit, spellID)`: Power Word: Shield by name, every other absorb by the self-only rule, nil name refuses | AC1, AC2, AC3, S5, S13 | `docs/features.md` (1), `docs/architecture.md` (1), `docs/curseforge.md:54,149` (2) |
| `UnitButton.lua:241-260` | `UpdateHealPrediction` takes the spell from the amount and passes it to `CanTakeShield` | every row | `docs/architecture.md:206-219` (1) |

## Docs

| Doc | Lines | Change | Serves |
| --- | --- | --- | --- |
| `docs/features.md` | 230-244 | the shield paragraph: Power Word: Shield's rule, and a self-only shield on frames that show you, its own aura, Weakened Soul leaving it showing, and what is not checked in game | AC1, AC2, AC3 |
| `docs/architecture.md` | 206-221 | the heal prediction item: the spell travelling with the amount, which shield takes which rule and where the name comes from | AC1-AC3 |
| `docs/curseforge.md` | 54 | the description's shield prediction line, worded no wider than the design | AC1, AC3 |
| `docs/extending.md` | 114-118 | what the prediction tests cover now | none (test cover) |

Verified after the doc edits: `lua spec/run.lua` 279 tests, 0 failures;
`node <skill dir>/check-gate.mjs` PASS; every edited file still CRLF, no LF-only lines.

With the TestWriter's tests in: `lua spec/run.lua` 290 tests, 0 failures; the named rows
`-p TestLeftClickHeal -p TestHealPrediction -p TestShieldRedraws` 44 tests, 0 failures;
`check-gate.mjs` PASS. Each of the 6 site rows above has its row in `...gate3-tests.md`, and its
"Proved on" hash equals `git hash-object --no-filters` of the working tree file now
(`ClickCast.lua` 2d97cfe, `UnitButton.lua` cb7e37d), so no proof is stale.

## AC table

| AC | Test row | Seen red | Met |
| --- | --- | --- | --- |
| AC1 (S6-S10, S15, S16, S18) | `testAShieldThatOnlyGoesOnYouShowsOnlyOnAFrameThatShowsYou`, `...WhereTheGameHidesWhoIsYou`, `testAShieldOnAModifierFollowsTheModifierAndTheFrame`, `testTheShieldFollowsTheTargetOrFocusUnderTheMouse`, `testTheShieldFollowsARosterChangeUnderTheMouse` | M3a `prediction_test.lua:468` your own frame expected 438 actual "hidden"; M3b `:465` a raid frame expected "hidden" actual 438; M4a `:448` another member's frame, `:663` target changed to party1, `:678` another member behind it; M6 `:483` your own frame with Shift expected 438 actual "hidden" (the modifier row) | Met |
| AC2 (S11-S14, S19) | `testPowerWordShieldsAurasLeaveAnotherShieldShowing`, `testAnotherShieldShowsNothingWhileItsOwnIsUpOrTheAurasAreHidden`, `testAnotherShieldShowsNothingWhenTheAurasAreSecret`, `testTheBarFollowsYourOwnShieldComingAndGoing` | M4b `:506` its own aura up expected "hidden" actual 438, `:697` your own Ice Barrier landed; M5c `:519` no name for spell 11426 expected "hidden" actual 438 | Met |
| AC3 (S1-S5) | `testPowerWordShieldShowsOnYourOwnFrame`, `testALeftClickShieldShowsItsAbsorb`, `testNoShieldOnWeakenedSoul`, `testNoShieldOnAShieldStillUp`, `testOtherAurasKeepTheShield`, the three hidden-aura tests, `testNoShieldWithoutASpellName` | M2 `:299` expected "hidden" actual 942; M5b `:291` expected 942 actual "hidden" | Met |
| AC4 (S17) | `testHoveringShowsTheLeftClickHeal`, `testAHealIgnoresTheShieldRules` | M1 `:89` expected `{942, 942, "absorb", 17}` actual `{942, 942, "absorb"}` (the contract, which the heal rows read too) | Met |

S16's and S18's red were re-checked by me in a scratch copy, since the TestWriter's file names no
line for those two rows: M6 (`spellID` not passed) fails `prediction_test.lua:483` "your own frame
with Shift" expected 438 actual "hidden", and M4a (the `ShowsThePlayer` guard removed) fails `:678`
"another member behind it" expected "hidden" actual 438. Both alone, one row at a time; the copy was
restored and its `UnitButton.lua` hash equals the working tree's (cb7e37d).

## Not done

- Nothing in the source or the docs is left open.
- `docs/curseforge.md:149` is the 0.4.0 changelog entry and stays as it is: it describes what that
  release shipped. This fix's changelog line is written by the release, not by this story.
- Not checked in game, and said so in the code and the docs: Ice Barrier's id and name; which
  absorbs besides Power Word: Shield read "absorbing N damage"; `UnitIsUnit` on your own raid frame.
- The in-game check for the gate file's Not done (solo, out of combat): a Priest with Power Word:
  Shield on the left click sees the blue bar on their own frame and on party1's, as that path now
  depends on the bound rank's name.

# Gate 3 tests: Show when the heal you are casting is no longer needed (cancel cue)

Tests: `spec/castcue_test.lua` (new, in `spec/run.lua`'s list; class `TestCastCue`), `TestTargetFocusCancelCue`
in `spec/targetfocus_test.lua`, `TestCancelCueOption` in `spec/options_test.lua`,
`testTheCancelCueOnTwoFakeFrames` in `spec/preview_test.lua`, and in `spec/fivesecond_test.lua`
`testBothCastEventsAreRegistered` (rewritten: the cue's four events are registered and start no bar),
`testACancelledCastStartsNoBar` and `testOnByDefaultForTheCue` (new).

The fakes in `spec/support.lua`: `Support.FireEvent` (an event reaches only the frames that registered it, for
every unit or for the unit in its first argument; a hidden unit counts as "player"), `Support.Click` (a button's
PreClick, OnClick and PostClick scripts and hooks, in that order), `Support.CueLook` (what a button's
`cancelCue` shows: "none", "running" gold 1, 0.7, 0, 0.8, "full" red 1, 0, 0, 1, or the colour it has),
`Support.Secret(name, value)` with `Support.Reveal` (a hidden value a test can still read), Recorder hooks that
chain like the game's, Recorder colours (`SetVertexColor`, `SetColorTexture`), and the spells of these tests.

The test plays the game: which cast a click starts and which events follow come from the scenario rows, never from
NeoHeal's code. Health runs three ways: readable without the curve API, readable with it, and hidden in combat,
where only a colour curve gives the cue's colour (read back through `Support.Reveal`).

`testEveryStartSpellAndEnd` runs the 450 cells of how the cast starts (10) x the spell (5) x how it ends (9). A
cell expects "running" on the clicked frame while its cast runs only when both the start and the spell count by
AC4, "none" on every other frame, and "none" everywhere once the cast has ended; a queued second click moves the
cue to the second frame when that cast starts.

Not checked by any test (no game client): whether Forever sends your cast events, also in combat; in which order
a click, a cast's start and a queued cast's start arrive; whether a hover key's virtual click runs PreClick; the
client's spell queue; whether `SetVertexColor` accepts a curve's hidden colour. The spell ids of the fake spells
are Classic's as far as known, not checked in game.

## Site to test

Sites from the Developer's `## Sites` (`docs/refinements/cancel-cue.md.gate3.md`) and its message
(`Core.lua:220-229`). "Proved on" is `git hash-object` of the restored file in the copy, the same bytes as the
working tree's.

| Site (file:line) | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `UnitButton.lua:301-350` | `TestCastCue.testTheCueTurnsFullAboveTheLine` | M1: `castcue_test.lua:241: S6: exactly 90% (party1, readable) expected: "running" actual: "full"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:532` | `TestCastCue.testTheCueTurnsBackBelowTheLine` | M2: `castcue_test.lua:241: S5: after the damage (party1, readable) expected: "running" actual: "full"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:1452-1460` | `TestCastCue.testTheCueIsABandOnTheHealthBarsBottomEdge` | M3: `castcue_test.lua:468: forever, health colour class: the band isn't on the bottom edge expected: {BOTTOMLEFT=true, BOTTOMRIGHT=true} actual: {BOTTOMRIGHT=true, TOPLEFT=true}` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:1041-1057` | `TestCastCue.testOnlyACastOnTheClickedMemberShowsTheCue` | M4: `castcue_test.lua:241: S31: the same spell 0.55 s later (party1, readable) expected: "none" actual: "running"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:1059-1072` | `TestCastCue.testTheOptionTurnsTheCueOff` | M5: `castcue_test.lua:241: S36: turned off during the cast (party1, readable) expected: "none" actual: "full"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:1079-1101` | `TestCastCue.testOnlyACastOnTheClickedMemberShowsTheCue` | M6: `castcue_test.lua:241: S31: another spell at once (party1, readable) expected: "none" actual: "running"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:1107-1115` | `TestCastCue.testTheCueEndsWhenTheGameHidesTheCast` | M7, second run: `castcue_test.lua:241: S38: UNIT_SPELLCAST_STOP hidden after a readable start (party1, readable) expected: "none" actual: "running"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:1277` | `TestTargetFocusCancelCue.testTheCueLeavesTheTargetFrameOnATargetSwitch` | M8: `targetfocus_test.lua:783: S21: the target frame kept the cue after a switch expected: "none" actual: "running"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:1581` | `TestCastCue.testTheCueTurnsFullAboveTheLine` | M9: `castcue_test.lua:241: S1: at 50% (party1, readable) expected: "running" actual: "none"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:1594-1599` | `TestCastCue.testAHiddenFrameDropsTheCue` | M10: `castcue_test.lua:241: S23: shown again after it hid (party1, readable) expected: "none" actual: "running"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `UnitButton.lua:1628-1632` | `TestCastCue.testAFrameGivenAnotherMemberDropsTheCue` | M11: `castcue_test.lua:241: S22: the same token for another member (Player-someone-else) (raid3, readable) expected: "none" actual: "running"` | `UnitButton.lua` 65f7ef9e40405715b742f057c330c3c17daa45e6 |
| `ClickCast.lua:573-625` | `TestCastCue.testOnlyACastOnTheClickedMemberShowsTheCue` | M12: `castcue_test.lua:241: S34: Prayer of Healing (party1, readable) expected: "none" actual: "running"` | `ClickCast.lua` cd1aeff156ab2cde8a9c8f775582fc9892ef34cd |
| `Core.lua:230-264`, the STOP handler only | `TestCastCue.testTheCueEndsWithTheCast` | M13: `castcue_test.lua:241: S7: you cancel it (party1, readable) expected: "none" actual: "full"` | `Core.lua` 16566839fb9ef09ad2240ef8b4771e59b0e4a19e |
| `Options.lua:213-217` | `TestCancelCueOption.testTheCancelCueOptionIsOnTheLayoutPage` | M14: `options_test.lua:671: turned off in combat, the running cue doesn't go at once expected: 1, actual: 0` | `Options.lua` a897dd876266d2cbda1462cdfdd501f31f0d12c5 |
| `Core.lua:31` | `TestFiveSecondCore.testOnByDefaultForTheCue` | N1: `fivesecond_test.lua:563: Show cancel cue isn't on by default expected: true, actual: false` | `Core.lua` 16566839fb9ef09ad2240ef8b4771e59b0e4a19e |
| `Core.lua:220-229` | `TestCastCue.testTheCueEndsWithTheCast` | N2: `castcue_test.lua:241: S44: only its success (party1, readable) expected: "none" actual: "full"` | `Core.lua` 16566839fb9ef09ad2240ef8b4771e59b0e4a19e |
| `Core.lua:230-264`, the START handler | `TestCastCue.testTheCueTurnsFullAboveTheLine` | N3: `castcue_test.lua:241: S1: at 50% (party1, readable) expected: "running" actual: "none"` | `Core.lua` 16566839fb9ef09ad2240ef8b4771e59b0e4a19e |
| `Core.lua:318` | `TestCastCue.testNoCueAfterAReload` | N4: `castcue_test.lua:241: S39: after a login or a loading screen (party1, readable) expected: "none" actual: "running"` | `Core.lua` 16566839fb9ef09ad2240ef8b4771e59b0e4a19e |
| `Core.lua:325-334` | `TestFiveSecondCore.testBothCastEventsAreRegistered` | N5: `fivesecond_test.lua:513: UNIT_SPELLCAST_START isn't registered for your own casts only expected: {"player"} actual: nil` | `Core.lua` 16566839fb9ef09ad2240ef8b4771e59b0e4a19e |
| `Core.lua:230-264`, the FAILED handler | `TestCastCue.testTheCueEndsWithTheCast` | P1: `castcue_test.lua:241: S9: it fails (party1, readable) expected: "none" actual: "full"` | `Core.lua` 16566839fb9ef09ad2240ef8b4771e59b0e4a19e |
| `Core.lua:230-264`, the INTERRUPTED handler | `TestCastCue.testTheCueEndsWithTheCast` | P2: `castcue_test.lua:241: S8: it is interrupted (party1, readable) expected: "none" actual: "full"` | `Core.lua` 16566839fb9ef09ad2240ef8b4771e59b0e4a19e |
| `Core.lua:230-264`, the PLAYER_ENTERING_WORLD handler | `TestCastCue.testNoCueAfterAReload` | P3: `castcue_test.lua:241: S39: after a login or a loading screen (party1, readable) expected: "none" actual: "running"` | `Core.lua` 16566839fb9ef09ad2240ef8b4771e59b0e4a19e |
| `Preview.lua:191-207` | `TestPreview.testTheCancelCueOnTwoFakeFrames` | N8: `preview_test.lua:445: Thornwood's cue expected: "full" actual: "running"` | `Preview.lua` 4cee5b5d663086c13c657cd20382748de78a7527 |
| `Preview.lua:209-213` | `TestPreview.testTheCancelCueOnTwoFakeFrames` | M15: `preview_test.lua:445: Thornwood's cue expected: "full" actual: "none"` | `Preview.lua` 4cee5b5d663086c13c657cd20382748de78a7527 |
| `Preview.lua:226-230` | `TestPreview.testTheCancelCueOnTwoFakeFrames` | N10: `preview_test.lua:447: the fake member with the full cue isn't above the line expected: true, actual: false` | `Preview.lua` 4cee5b5d663086c13c657cd20382748de78a7527 |
| `Preview.lua:241` | `TestPreview.testTheCancelCueOnTwoFakeFrames` | N11: `preview_test.lua:445: Grimthorn's cue expected: "none" actual: "full"` | `Preview.lua` 4cee5b5d663086c13c657cd20382748de78a7527 |
| `Preview.lua:299-300` | `TestPreview.testTheCancelCueOnTwoFakeFrames` | N12: `preview_test.lua:445: Shadowmaw's cue expected: "none" actual: "full"` | `Preview.lua` 4cee5b5d663086c13c657cd20382748de78a7527 |
| `Locales/enUS.lua:112` | `TestCancelCueOption.testTheCancelCueOptionIsOnTheLayoutPage` | P4: `options_test.lua:662: no string for the option: the checkbox shows its key expected: not nil, actual: nil` | `Locales/enUS.lua` 194a073e18b37035f02c9a8e9e32a2dc5f9450c6 |
| `Options.lua:194` | `TestCancelCueOption.testTheCancelCueOptionIsOnTheLayoutPage` | P5: `options_test.lua:667: no cancel cue checkbox on the Layout page expected: not nil, actual: nil` | `Options.lua` a897dd876266d2cbda1462cdfdd501f31f0d12c5 |

## Mutations

Each ran in a copy of the addon files, `Locales/` and `spec/` under the story's scratch folder: the file saved
aside, one anchor replaced (each counted exactly once before any run), only the named row run, the saved file copied
back and compared byte for byte with the working tree's (equal after every run). Unmutated, the 17 rows these
mutations name passed in the copy. 30 runs in all: M1 to M14 (M7 twice), then N1 to N12 and M15 after a second
budget of 10, then P1 to P5 after a third budget of 5. Before N8 to N12, `testTheCancelCueOnTwoFakeFrames` gained a cue shown on every reused frame before
the second `Show`: without it no pet frame had ever held a cue, so a pet frame's hide could not fail.

| Id | File | Mutation | Row | Result |
| --- | --- | --- | --- | --- |
| M1 | `UnitButton.lua` | `GetHealthFraction(unit) > CANCEL_CUE_LINE` to `>=` | `testTheCueTurnsFullAboveTheLine` | red, S6 |
| M2 | `UnitButton.lua` | `UpdateHealth`'s `UpdateCancelCue(button)` removed | `testTheCueTurnsBackBelowTheLine` | red, S5 |
| M3 | `UnitButton.lua` | the cue's `SetPoint("BOTTOMLEFT")` to `"TOPLEFT"` | `testTheCueIsABandOnTheHealthBarsBottomEdge` | red |
| M4 | `UnitButton.lua` | `CANCEL_CUE_WINDOW = 0.5` to `1.5` | `testOnlyACastOnTheClickedMemberShowsTheCue` | red, S31 at 0.55 s |
| M5 | `UnitButton.lua` | `ClearCancelCue`'s loop body removed | `testTheOptionTurnsTheCueOff` | red, S36 |
| M6 | `UnitButton.lua` | `OnCastStart`'s spell name check removed | `testOnlyACastOnTheClickedMemberShowsTheCue` | red, S31 another spell |
| M7 | `UnitButton.lua` | `OnCastEnd`: `IsSecret(castGUID) or` removed | `testTheCueEndsWhenTheGameHidesTheCast` | first run green (a fully hidden start stores `true`, which every end clears); the row gained a readable start with a hidden end; second run red |
| M8 | `UnitButton.lua` | `SetUnit`'s `ClearCancelCueFor` shadowed by a no-op | `TestTargetFocusCancelCue.testTheCueLeavesTheTargetFrameOnATargetSwitch` | red, S21 |
| M9 | `UnitButton.lua` | the `PreClick` hook removed | `testTheCueTurnsFullAboveTheLine` | red, S1 |
| M10 | `UnitButton.lua` | the `OnHide` clear removed | `testAHiddenFrameDropsTheCue` | red, S23 |
| M11 | `UnitButton.lua` | `UpdateAllButtons`' GUID clear removed | `testAFrameGivenAnotherMemberDropsTheCue` | red, S22 |
| M12 | `ClickCast.lua` | `PRIEST = { 596 }` to `PRIEST = {}` | `testOnlyACastOnTheClickedMemberShowsTheCue` | red, S34 |
| M13 | `Core.lua` | the STOP handler's `OnCastEnd` call removed | `testTheCueEndsWithTheCast` | red, S7 |
| M14 | `Options.lua` | the setter's `ClearCancelCue()` removed | `TestCancelCueOption.testTheCancelCueOptionIsOnTheLayoutPage` | red |
| N1 | `Core.lua` | `showCancelCue = true` to `false` in `DEFAULTS` | `TestFiveSecondCore.testOnByDefaultForTheCue` | red |
| N2 | `Core.lua` | the SUCCEEDED handler's `OnCastEnd` call removed | `testTheCueEndsWithTheCast` | red, S44 |
| N3 | `Core.lua` | the START handler's `OnCastStart` call removed | `testTheCueTurnsFullAboveTheLine` | red, S1 |
| N4 | `Core.lua` | `PLAYER_ENTERING_WORLD` taken out of the global event list | `testNoCueAfterAReload` | red, S39 |
| N5 | `Core.lua` | `UNIT_SPELLCAST_START` taken out of the cast event list | `TestFiveSecondCore.testBothCastEventsAreRegistered` | red |
| N8 | `Preview.lua` | `ShowFakeCancelCue` draws the full member's cue as running | `TestPreview.testTheCancelCueOnTwoFakeFrames` | red |
| M15 | `Preview.lua` | `CANCEL_CUE_FULL_MEMBER = 3` to `4` | `TestPreview.testTheCancelCueOnTwoFakeFrames` | red |
| N10 | `Preview.lua` | member 3's health above the line removed | `TestPreview.testTheCancelCueOnTwoFakeFrames` | red |
| N11 | `Preview.lua` | `Decorate`'s `ShowFakeCancelCue` call removed | `TestPreview.testTheCancelCueOnTwoFakeFrames` | red |
| N12 | `Preview.lua` | a pet's `cancelCue:Hide()` removed | `TestPreview.testTheCancelCueOnTwoFakeFrames` | red |
| P1 | `Core.lua` | the FAILED handler's `OnCastEnd` call removed | `testTheCueEndsWithTheCast` | red, S9 |
| P2 | `Core.lua` | the INTERRUPTED handler's `OnCastEnd` call removed | `testTheCueEndsWithTheCast` | red, S8 |
| P3 | `Core.lua` | the PLAYER_ENTERING_WORLD handler's `ClearCancelCue()` removed | `testNoCueAfterAReload` | red, S39 |
| P4 | `Locales/enUS.lua` | `L.SHOW_CANCEL_CUE` removed | `TestCancelCueOption.testTheCancelCueOptionIsOnTheLayoutPage` | red |
| P5 | `Options.lua` | the `showCancelCue` checkbox row removed | `TestCancelCueOption.testTheCancelCueOptionIsOnTheLayoutPage` | red |

## Seen red before the build was complete (the working tree, not a mutation)

- `TestPreview.testTheCancelCueOnTwoFakeFrames`: `preview_test.lua:441: Thornwood's cue expected: "full" actual:
  "none"`. In `Preview.lua`, `ShowFakeCancelCue` uses `CANCEL_CUE_FULL_MEMBER` and `CANCEL_CUE_RUNNING_MEMBER`
  before the lines that declare them as locals, so inside the function they are nil globals.
- `TestCastCue.testEveryStartSpellAndEnd`: `castcue_test.lua:241: an unmodified left click / a heal with a cast
  time / the queued cast's start comes before this cast's end: the queued cast started (party1, readable)
  expected: "none" actual: "running"`. AC4 says a queued click moves the cue when that cast starts; the first
  frame keeps it until the first cast's own end.
- Fixed by the Developer while these tests were written: an end reported only as the success (S44), and a
  roster change that leaves the token with a hidden `UnitGUID` (S22). The two defects above were fixed after
  them; both rows pass on the code the mutations ran against. These reds came from the unfinished code, not
  from mutations, and prove no site.

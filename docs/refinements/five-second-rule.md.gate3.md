# Gate 3: five-second rule, the Developer's build record

## Done and verified

### Area 1: the countdown, the bar and the settings (all source and docs)

- Done: the bar on the mana strip, the one shared countdown, the cast events, the mana-cost rule, the option, the
  preview and the three docs.
- Verified with `lua spec/run.lua`: `Ran 307 tests in 3.614 seconds, 307 successes, 0 failures` (the suite as it
  stood before the TestWriter's files; it loads every module, so a syntax or load error in any of them fails here).
- Line endings: every edited `.lua` still CRLF (CR count == LF count, checked bytewise), the `.md` files LF.

### Area 2: the TestWriter's tests, checked against the site list

- Verified with `lua spec/run.lua`: `Ran 333 tests in 4.638 seconds, 333 successes, 0 failures`, with the new
  `spec/fivesecond_test.lua` and the rows added to `spec/targetfocus_test.lua`, `spec/options_test.lua`,
  `spec/preview_test.lua` and `spec/support.lua`.
- `check-gate.mjs` from the repository root: `PASS: all tests` (its quick check), and
  `check-refinement.mjs docs/refinements/five-second-rule.md`: `PASS`.
- Site-to-test: all 22 code sites of `## Sites` have a row in `.gate3-tests.md`, each with a mutation and its failure
  line (M1 to M22; 24 of 25 mutation runs, the one refused being a duplicate). The 3 doc rows have no test, as they
  are no code.
- Rows without a test of their own, and why: **S16** (solo, "Show when solo" off) and **S24** (Resource bar "Healers
  only", you a healer) both rest on code this story does not change — the group header's `showSolo` and
  `ShowsPowerBarForButton` — and the bar's own part of them is the strip's, which `testTheBarSitsOnTheStrip` proves.

## Sites

Fix round 1 (Review CHANGES): the rows marked **edited** and **stale** change in this round; their earlier proof does
not count, and the TestWriter proves them again. Findings: (1) the mana gate read the frame's power type, which on a
restricted map can be hidden where yours is not, keeping the bar off your own raid frame (S18, S38); (2) the cast
events were registered for every unit and both comments claimed the cast's unit could not be secret, which the
client's generated docs contradict.

| Site | What it changes | AC / rows | Docs that describe it |
| --- | --- | --- | --- |
| UnitButton.lua:21-24 | the constants: 5 seconds, 0.1 s tick, 2 px, the bar's colour | AC1; S1 | features.md (the five-second rule paragraph) |
| UnitButton.lua:548-557 | `ApplyStyle` gives the bar the style's texture and its colour | AC1; S1 | architecture.md (not named; the bar list is not itemised) |
| UnitButton.lua:1156-1165 | `CreateVisuals` creates `frame.fiveSecond`, a StatusBar child of `frame.power`, 2 px on its top edge | AC1, AC3, AC5; S1, S25, S35 | features.md ("Bottom strip" row), architecture.md |
| UnitButton.lua:825-826 | `castAt` and `lastCastGUID`: the one countdown, module-level | AC1, AC6; S19, S20, S40 | architecture.md |
| **edited** UnitButton.lua:828-841 | **stale** `ShowsManaStrip` reads your own power type (`UnitPowerType("player")`), never the frame's, so a hidden power type on your raid frame no longer keeps the bar off it; a hidden one still shows no bar | AC3, AC4; S11, S12, S13, S14, S18, S37, S38 | features.md (warrior/rogue, druid in a form) |
| **edited** UnitButton.lua:855-858 | **stale** `UpdateFiveSecondFor` calls that gate without a unit | AC3, AC4; S18, S38 | features.md, architecture.md |
| UnitButton.lua:839-845 | `FiveSecondLeft`: the option, death, and the value from the clock | AC1, AC5, AC7; S1, S10, S27, S32, S34, S39 | features.md (the option and its combat exception) |
| UnitButton.lua:849-864 | `UpdateFiveSecondFor`: one frame's bar, shown for a frame that shows you (`ShowIfSameUnit`) | AC3; S15-S23, S40 | features.md, architecture.md |
| UnitButton.lua:870-877 | `EndCountdown`: hides every bar once and clears the countdown, so "on again" and a resurrection wait for the next spell | AC5, AC7; S27, S32 | features.md (the combat exception) |
| UnitButton.lua:880-890 | `UpdateFiveSecond`, the tick, exported for the tests | AC1, AC5; S1, S10, S27, S39 | architecture.md |
| UnitButton.lua:895-909 | `EntryCostsMana`: a MANA entry, and the aura it needs | AC2, AC4; S13 | features.md (druid in a form) |
| UnitButton.lua:911-932 | `CostsMana`: nil = no cost, unreadable = mana | AC2; S6, S8, S13 | features.md (an action that costs no mana) |
| **edited** UnitButton.lua:934-950 | **stale** `OnPlayerCast`: the comment now says the payload may be hidden and a hidden unit counts as yours; the unit check is `not IsSecret(unit) and unit ~= "player"`, since the events are registered for "player" | AC1, AC2, AC3; S1-S9, S22, S29 | architecture.md |
| UnitButton.lua:1068 | `UpdateAll` also redraws that frame's bar, so a roster or target change is right at once | AC6; S30, S31 | architecture.md |
| UnitButton.lua:1508 | the 0.1 s ticker | AC1; S1, S10 | architecture.md |
| Core.lua:30 | `showFiveSecond = true` in `DEFAULTS` | AC5; S1, S26 | saved-variables.md |
| **edited** Core.lua:213-226 | **stale** the comment on both handlers now says the events are registered for "player" and why the unit is still checked | AC1, AC2, AC3; S22 | architecture.md |
| **edited** Core.lua:277-298 | **stale** both cast events register with `RegisterUnitEvent(event, "player")` instead of `RegisterEvent`, in their own loop behind `IsEventValid` | AC1, AC3; S22, S29 | architecture.md (now names the "player" registration) |
| Options.lua:193 | the checkbox row in `LAYOUT_SETTINGS` | AC5; S26 | features.md (right column) |
| Locales/enUS.lua:111 | `L.SHOW_FIVE_SECOND` | AC5; S26 | features.md |
| Preview.lua:184-189 | `ShowFakeFiveSecond`: a still 0.6 bar on member 2, only with the option on | AC8; S35, S36 | features.md (test mode is not described per member) |
| Preview.lua:216 | the healer member gets that bar | AC8; S35, S36 | — |
| Preview.lua:275 | pets never show it | AC8; S36 | — |
| docs/features.md | the five-second rule paragraph, the "Bottom strip" row, the right-column option, the combat exception | AC1, AC5; S39, S4 | (itself) |
| **edited** docs/architecture.md | the update chain, how the one countdown works, and the "player" registration | AC1, AC6 | (itself) |
| docs/saved-variables.md | the `showFiveSecond` row | AC5 | (itself) |

### Area 3: fix round 1

- Done: finding 1 (the mana gate reads your own power type) and finding 2 (the cast events register for "player", both
  comments corrected).
- Verified with `lua spec/run.lua`: **335 tests, 335 successes, 0 failures**.
- The no-`RegisterUnitEvent` test this round started with (`TestFiveSecondCore.testWithoutUnitEventsBothStillRegister`) is
  gone: its premise was wrong. `Core.lua` already registers `UNIT_TARGET` with `RegisterUnitEvent` at line 278 (HEAD,
  before this story, at line 261), so a client without that method never loaded NeoHeal. Measured on both revisions
  with the same fake API on a frame without `RegisterUnitEvent`: HEAD's `Core.lua` failed at line 261 "attempt to call a
  boolean value (method 'RegisterUnitEvent')", the working tree's at line 278. A fallback to `RegisterEvent` for the two
  cast events would keep a load working that never worked; both register the same way as `UNIT_TARGET`.
- What the fix does in each state of its input (finding 1): your power type readable and MANA — the bar goes on, then
  `ShowIfSameUnit` decides per frame (a hidden "is this you" answer goes to the game as alpha); readable and not MANA
  (warrior, rogue, druid in a form) — no bar on any frame; hidden — no bar, as before, now only for your own power type.
- Finding 2's states: a cast arrives for "player" — accepted; for any other readable unit — dropped; with a hidden
  unit — accepted, because a hidden value compared with a constant is only "not equal", and the event is already
  filtered to your own unit.
- Line endings: `UnitButton.lua` and `Core.lua` still CRLF (byte counts equal).

## Not done

- Whether Forever fires `UNIT_SPELLCAST_SUCCEEDED` and `UNIT_SPELLCAST_CHANNEL_START` for your own casts, and in
  combat: not checked in game.
- Whether those events carry a readable `castGUID` and `spellID`: the client's generated API docs mark them
  `SecretWhenUnitSpellCastRestricted`; a hidden spellID starts the bar without reading its cost (S8), a hidden, equal
  GUID may restart the bar at the same moment (harmless). Not checked in game.
- Whether `C_Spell.GetSpellPowerCost` answers at all on Forever, and whether its mana entry carries `requiredAuraID`
  and `hasRequiredAura`: not checked in game; without them the entry counts as mana.
- **The channel-end question**: whether the client sends `UNIT_SPELLCAST_SUCCEEDED` for a channel when it starts or
  when it ends. A repeat under the same castGUID is ignored; under a new one it restarts the bar at the channel's
  end, which would show 5 more seconds where the rule says fewer. S3/S4 are met only if the start event is the one
  that arrives.
- Whether `SetAlphaFromBoolean` places the bar on a raid frame whose "is this you" answer the game hides (S18, S38):
  if the client refuses it there, AC3 cannot be met on such a map and that goes to Remco, as open point 1's residual
  risk says.
- Whether the 0.1 s ticker keeps running in combat: not checked in game; the bar is a plain frame's child.
- Whether a loading screen pauses `GetTime()`: the bar's value is recomputed from the clock, so it is never longer
  than the rule unless the clock itself stops and resumes with it (S34).
- Whether mana regeneration really stops for 5 seconds after a cast, and for the whole of a channel longer than 5
  seconds: community sources, not checked in game.

## Fix: bar placement

The 6 px strip and the bar on its bottom 2 px (open point 8, Remco 2026-11-16). The change Remco kept on an
installed copy, plus the comments and docs that stated the old place.

| Site | What it changes | AC / rows | Docs that describe it (grep) |
| --- | --- | --- | --- |
| UnitButton.lua:20 | `POWER_BAR_HEIGHT` 4 → 6, with a comment saying 4 px stay visible above the bar. Read by `power:SetHeight` (:1159) on every frame, so party, raid, target, focus and test mode are all 6 px with no second site | AC1, AC5; S1, S24, S25, S35 | features.md ("mana strip" 2, "6 px" 1); five-second-rule.md ("6 px" 2) |
| UnitButton.lua:23 | the `FIVE_SECOND_HEIGHT` comment: the strip's top edge → its bottom edge, mana above stays visible; the value stays 2 | AC1; S1 | features.md ("bottom 2 px" 1) |
| UnitButton.lua:24 | the `FIVE_SECOND_COLOR` comment: "brighter than the mana under it" → "above it" | AC1 | — |
| UnitButton.lua:1163-1171 | the comment on `frame.fiveSecond` and its two anchors: `TOPLEFT`/`TOPRIGHT` of the strip → `BOTTOMLEFT`/`BOTTOMRIGHT`, offset 0 | AC1, AC3, AC5; S1, S25, S35 | features.md ("bottom edge" 1, "bottom 2 px" 1); five-second-rule.md (the How line) |
| docs/features.md | the "Bottom strip" row ("above it" → "on its bottom edge"), and the five-second rule paragraph ("sits on the top of the mana strip" → "on the bottom 2 px", plus the 6 px strip and the 4 px of mana above it) | AC1; S1 | (itself) |
| docs/refinements/five-second-rule.md | the "How" line: the bar is 2 pixels on the strip's *bottom* edge, and the strip is 6 px since open point 8 | AC1 | (itself) |

Grep counts, working tree vs HEAD (`git show HEAD:<file> | grep -c -F`):

- docs/features.md: "top of the mana strip" 1 → 0, "above it, while" 1 → 0, "bottom edge" 0 → 1, "6 px" 0 → 1.
- docs/refinements/five-second-rule.md: "top edge" 1 → 0 (the How line), "6 px" 0 → 2 (open point 8 + the How line).
- Left as they are: the refinement's "Notes for gate 2" still says "a 4-pixel strip" (a record of the gate-2 question,
  true of the code then), docs/curseforge.md and docs/saved-variables.md name the bar "on the mana strip" only, with
  no place or height, and docs/architecture.md names neither; "Top edge" in features.md is the aggro line, not this.

Check on what else reads the strip's height: `grep -rn POWER_BAR_HEIGHT` gives three sites only, :20, :685 and :1159;
`Layout.lua` has no strip height, and `Preview.lua` and `TargetFocusFrames.lua` both build their frames through
`UnitButton.CreateVisuals`, so they get the 6 px from the same constant. `GetRaidDebuffSize` (:685) subtracts the
constant, so the room below the name follows on its own.

- Done: the four source sites and the two docs.
- Verified with `lua spec/run.lua`: `Ran 337 tests in 3.553 seconds, 337 successes, 0 failures`, the TestWriter's
  `testTheBarSitsOnTheStrip`, `testTheStripIsSixPixels` and `testTheDebuffRoomCountsTheSixPixelStrip` included.
  `check-gate.mjs`: `PASS: all tests`; `check-refinement.mjs docs/refinements/five-second-rule.md`: `PASS`.
- Line endings after every edit: `UnitButton.lua` CR=1524 LF=1524, `docs/features.md` CR=320 LF=320 (both CRLF);
  `docs/refinements/five-second-rule.md` CR=0 LF=217 (LF).
- Not done: nothing on this fix; the TestWriter's red proof per site is in `.gate3-tests.md`.
- Left for the Architect: AC1's wording. Open point 8 records Remco's new text ("a thin bar along the bottom of the
  mana strip ..., which is 6 px so 4 px of mana stay visible"), and the AC still reads "a thin bar on the mana strip",
  which stays true but no longer names the place. The AC table is the Architect's file, not mine.

### The lighter mana blue

Remco's second kept change on the same installed copy: Blizzard's `PowerBarColor["MANA"]` is too dark on a now-thin
strip, so mana is drawn in RGB 0, 115, 255 (Remco, 2026-11-16). Rage, energy and focus keep the game's colours, and a
hidden power type keeps the fallback.

| Site | What it changes | AC / rows | Docs that describe it (grep) |
| --- | --- | --- | --- |
| UnitButton.lua:20-23 | `MANA_BAR_COLOR = { r = 0, g = 0.45, b = 1.0 }`, defined once, with the comment saying why (Blizzard's blue is too dark on a 6 px strip; this one shows like the mana bar beside the portrait) | AC1; S1, S14 | features.md ("Bottom strip" row) |
| UnitButton.lua:572-579 | `PowerColor(token)`, exported for the preview: mana takes the colour above, every other token `PowerBarColor[token]`, a hidden token the fallback — one rule for the frames and test mode | AC1; S1, S11, S14 | features.md |
| UnitButton.lua:590 | `UpdatePower` asks that function instead of reading `PowerBarColor` itself, so a real frame and a fake one can't disagree | AC1; S1, S11, S14 | features.md, architecture.md (`UpdatePower` named, colour not) |
| Preview.lua:207 | the fake members take their strip colour from the same function | AC8; S35, S36 | features.md (test mode) |
| Preview.lua:264 | the fake pets too, so a warlock pet's mana is the same blue and a hunter pet's focus stays Blizzard's | AC8; S36 | features.md (test mode) |
| docs/features.md | the "Bottom strip" row: mana is a lighter blue than Blizzard's, which is too dark on a thin strip; rage, energy and focus keep the game's colours | AC1 | (itself) |

Grep counts: `PowerBarColor` outside `spec/`: 3 at HEAD (UnitButton.lua 1, Preview.lua 2) → 1 now, the single lookup
in `PowerColor`. `MANA_BAR_COLOR`: defined once at UnitButton.lua:23, read once at :576.

- Done: the four source sites and the doc.
- Verified with `lua spec/run.lua`: `Ran 339 tests in 4.347 seconds, 339 successes, 0 failures`, with the TestWriter's
  `testAManaStripIsTheLighterBlue` and `testManaStripsAreTheLighterBlue` in the run.
- Line endings after every edit: `UnitButton.lua` CR=1536 LF=1536, `Preview.lua` CR=360 LF=360, `docs/features.md`
  CR=320 LF=320 (all CRLF).
- Not done: whether the lighter blue reads right through Forever's own bar texture in game — Remco chose it on an
  installed copy of exactly this change, so the choice is checked in game and the rest is not (a druid's form strip,
  rage, energy, focus, pets).
- The TestWriter's red proof for these sites goes in `.gate3-tests.md` under the same heading.

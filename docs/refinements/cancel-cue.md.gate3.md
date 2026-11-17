# Gate 3: build log (Developer)

The story's build, area by area, as it lands. A replacement Developer or the Scrum Master reads this file instead
of the build's message history. The TestWriter's red lines are in `cancel-cue.md.gate3-tests.md`.

## Done and verified

- Look line in the How: updated to the kept look (candidate A, gold and red), checker PASS on
  `docs/refinements/cancel-cue.md`.
- Area 1, the cue's look and its update (UnitButton.lua): `lua spec/run.lua` → 339 tests, 339 successes,
  0 failures; `luac -p` on the file; CRLF kept (CR = LF).
- Area 2, which frame the cast is on (ClickCast.lua, UnitButton.lua, Core.lua, Options.lua, Locales,
  Preview.lua): `lua spec/run.lua` → 339 tests, 339 successes, 0 failures; `luac -p` on every edited file; CRLF
  kept on every edited file (CR = LF).
- Area 3, the TestWriter's defeatures fixed in the source (a Preview local declared after its use; a queued cast's
  start not clearing the previous frame's cue; a cast ending only with SUCCEEDED; a hidden roster GUID):
  `lua spec/run.lua` → 358 tests, 358 successes, 0 failures.
- Area 4, docs: `docs/features.md`, `docs/architecture.md`, `docs/saved-variables.md`, `docs/forever-api.md`
  (section 8, the cast events), `docs/extending.md` (tests list and checklist), `CLAUDE.md` (Tests paragraph).
  Read back with grep for `showCancelCue`, `cancel cue` and `S52` in each; no command proves prose.

## Sites

| Site | What it changes | Serves | Docs that describe it |
| --- | --- | --- | --- |
| UnitButton.lua:304-345 | constants, `ShowCancelCue`, `UpdateCancelCue` with the step colour curve | AC1 (S1, S3-S6, S13, S41, S42) | features.md (the cue), architecture.md |
| UnitButton.lua:532 | `UpdateHealth` redraws the cue | AC1, AC2 (S11, S12) | architecture.md (updates) |
| UnitButton.lua:1458-1466 | the cue texture in `CreateVisuals`, a child of `overlay` | AC1, AC3 (S1) | features.md, architecture.md |
| UnitButton.lua:1041-1057 | the click record: `CANCEL_CUE_WINDOW`, `OnPreClick`, `ClickCast.GetClickSpell` | AC4 (S26-S29, S33, S34) | architecture.md (the cue) |
| UnitButton.lua:1059-1072 | `ClearCancelCueFor`, `ClearCancelCue` | AC2, AC5 (S7-S9, S35-S37) | features.md, architecture.md |
| UnitButton.lua:1079-1107 | `OnCastStart`: the click that started this cast, every other cue cleared, the per-frame castGUID and UnitGUID | AC3, AC4, AC6 (S1, S24, S25, S38, S46) | architecture.md, forever-api.md §8 |
| UnitButton.lua:1109-1121 | `OnCastEnd`: one frame when its GUID matches, all when hidden | AC2 (S2, S7-S9, S44) | architecture.md, forever-api.md §8 |
| UnitButton.lua:1283 | `SetUnit` clears a cue for any unit change, nil included | AC3, AC6 (S21, S48, S49) | architecture.md |
| UnitButton.lua:1587 | the `PreClick` hook in `Init` | AC4 (S26, S27, S31) | architecture.md |
| UnitButton.lua:1600-1605 | the `OnHide` clear behind the one-frame visible check | AC3 (S23) | architecture.md |
| UnitButton.lua:1632-1640 | `UpdateAllButtons` clears on a roster GUID change, a hidden GUID included | AC3, AC6 (S22) | architecture.md |
| ClickCast.lua:573-625 | `GROUP_HEALS`, `GetGroupHealNames`, `ClickBindingKey`, `GetClickSpell` | AC4 (S28-S34) | architecture.md (the cue) |
| Core.lua:31 | `showCancelCue` default, on | AC5 (S35) | saved-variables.md, features.md |
| Core.lua:220-229 | `UNIT_SPELLCAST_SUCCEEDED` also clears the cue | AC2 (S44) | architecture.md, forever-api.md §8 |
| Core.lua:230-264 | `UNIT_SPELLCAST_START`, `STOP`, `FAILED`, `INTERRUPTED`, `PLAYER_ENTERING_WORLD` handlers | AC2, AC6 (S2, S7-S9, S39, S44, S52) | architecture.md (global events), forever-api.md §8 |
| Core.lua:318 | `PLAYER_ENTERING_WORLD` in the global event list | AC6 (S39, S52) | architecture.md |
| Core.lua:325-334 | the four cast ends and the start registered for "player" | AC2, AC3, AC4 (S1, S2, S44) | architecture.md, forever-api.md §8 |
| Locales/enUS.lua:112 | `SHOW_CANCEL_CUE` | AC5 (S35) | features.md (Layout options) |
| Options.lua:194 | the Layout page checkbox | AC5 (S35) | features.md (Layout options) |
| Options.lua:213-217 | the setter clears the cue at once when it goes off | AC5 (S36, S37) | features.md (the exception) |
| Preview.lua:194-212 | the two fake cue members and `ShowFakeCancelCue` | AC7 (S40, S50) | features.md (test mode), extending.md |
| Preview.lua:229 | member 3's fake health above the line | AC7 (S40) | features.md |
| Preview.lua:241 | the cue drawn in `Decorate` | AC7 (S40, S50) | features.md |
| Preview.lua:300 | a pet's preview hides the cue | AC7 (S40, S50) | features.md |
| spec/support.lua | the TestWriter's: the cue's test spells, a second HookScript, recorded colours, `Support.Click`, `Support.CueLook`. Not a Developer site | the tests' setup | extending.md |

Not a Developer site, listed so no hunk of `git diff` is left out of the table: `spec/run.lua` (adds
`castcue_test`), `spec/support.lua`, `spec/castcue_test.lua` — all the TestWriter's, per brief 4b.

## Not done

Not checked in game, worded so in the code and the docs (the product owner turns each into an in-game check of the
release):

- Whether Forever sends `UNIT_SPELLCAST_START`, `STOP`, `FAILED`, `INTERRUPTED` and `SUCCEEDED` for your own casts,
  also in combat, and whether the payload is readable there.
- Whether a hover key's virtual-button click reaches the button's `PreClick` hook (S27).
- The client's spell queue and the order of a queued cast's start against the previous cast's end (S25, S46).
- Whether a loading screen or zone change sends no cast end event (S52's premise).
- Whether `SetVertexColor` accepts a colour curve's hidden answer (the low-health tint's pattern, S13, S14, S16-S20).
- That no Classic-era heal is flagged "always secret" (the backlog item's two `/dump` lines).
- The Classic-era spell IDs of the group heals (`ClickCast.GROUP_HEALS`) and of the test fakes.

Not mine to do: the release notes (`### <next version>`) are the product owner's.

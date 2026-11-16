# Gate 3: build, bug #6

The Developer's state file for gate 3. The TestWriter's counterpart is
`6-key-capture-stops.md.gate3-tests.md`.

## Contract for the TestWriter

`Options.lua`, the hover-key wait (issue #6):

| Piece | Takes | Does |
| --- | --- | --- |
| `waitingCapture` (file local) | — | the one button waiting for a key, or nil |
| `button:Refresh()` | — | when `waitingCapture == button`: clears it and calls `EnableKeyboard(false)`; then writes the button's text from the saved key |
| `button`'s `OnClick`, left | — | ends any other wait (`waitingCapture:Refresh()`), sets itself waiting, writes "Press a key", `EnableKeyboard(true)`, `SetPropagateKeyboardInput(false)`. Refused in combat |
| `button`'s `OnClick`, right | — | clears the key, then `Options:RefreshBindingRows()`, which ends the wait through `Refresh` |
| `button`'s `OnKeyDown` | a key | modifier alone waits; a movement key warns and waits; Escape and any other key end the wait through `RefreshBindingRows` |
| `button`'s `OnHide` | — | `button:Refresh()`, so a page switch or the window closing ends the wait |
| `Options:EndKeyCapture()` | — | `waitingCapture:Refresh()` when there is one; called on `PLAYER_REGEN_DISABLED` |

The invariant the tests state: `keyboardEnabled == (text == L.PRESS_A_KEY)` on every hover-key button.

## Sites

| Site (file:line) | What it changes | Serves | Docs that describe it |
| --- | --- | --- | --- |
| `Options.lua:301` | `local waitingCapture`, the one waiting button | S6, S11, AC2, AC3 | `docs/architecture.md` (hover keys), `docs/forever-api.md` section 7 |
| `Options.lua:312` | `button:Refresh` ends this button's wait (clears `waitingCapture`, `EnableKeyboard(false)`) before writing its text; `StopCapture` is gone | S10, S12, S13, S14, S15, S17, S18, AC1, AC3, AC5 | `docs/forever-api.md` section 7, `docs/architecture.md` (hover keys) |
| `Options.lua:325` | `OnClick`: the left branch ends the previous wait first; the right branch's comment says `RefreshBindingRows` ends it | S6, S10, S11, AC2 | `docs/features.md` (click casting) |
| `Options.lua:339` | `OnKeyDown` ends the wait through `RefreshBindingRows` instead of `StopCapture` | S2, S3, AC5 | `docs/forever-api.md` section 7 |
| `Options.lua:353` | `OnHide` calls `button:Refresh()` | S7, S8, AC5 | `docs/forever-api.md` section 7 |
| `Options.lua:366` | `Options:EndKeyCapture()`, the outside ending | S19, AC4 | `docs/architecture.md` (Options row) |
| `Options.lua:515` | `PLAYER_REGEN_DISABLED` calls `Options:EndKeyCapture()` | S19, AC4 | `docs/forever-api.md` section 7 |

## Done and verified

- **The wait and its endings** (`Options.lua`): every redraw of a hover-key row now ends the
  wait inside the button's own `Refresh`, and combat start and `OnHide` reach it too. The
  suite passes: `lua spec/run.lua`, 271 tests, 0 failures; `check-gate.mjs` PASS.
- **Docs**: `docs/forever-api.md` section 7 gained "The reverse rule (issue #6)";
  `docs/features.md` says in the click-casting paragraph which moments end a wait;
  `docs/architecture.md` names `waitingCapture`, `Refresh` and `EndKeyCapture` and adds
  `EndKeyCapture` to the Options row.
- **Review finding, docs only** (Reviewer, relay 17): `docs/features.md` said the button
  "stops reading that the moment you do anything else", which is false for the S16 and S20
  clicks the product owner left keeping the wait. Rewritten to name what ends a wait (a
  redraw of the rows, a page switch, closing the window, combat) and what does not (cast on,
  Also target, dragging or clicking the window, a menu opened and closed). The other two
  changed docs said "any redraw of the rows ends a wait", which the code does, so they
  stand.
- **Not seen red yet**: the tests and the red lines are the TestWriter's; this build says
  only that today's suite is green on the changed source.
- **Every site proved** (`6-key-capture-stops.md.gate3-tests.md`): all seven rows of
  `## Sites` have a row there, with the two branches at `:325` split into two. The TestWriter
  names the `OnHide` site at `:353`, the comment line, where my table names the statement at
  `:354`; the mutation ran on `:354`, so it is one site.
- **S6 does not fail from the left-branch site** (TestWriter, M3): on a second click on the
  same button `waitingCapture` already is that button, so `Refresh` ends nothing observable
  before the start sets it again. The left branch is needed for S11 only, and the How line's
  "(S6, S11)" overstates it; the wording change is the Architect's to approve.

## AC table

| AC | Test row | Seen red | Met |
| --- | --- | --- | --- |
| AC1 | `testRightClickDuringAWaitClearsTheKeyAndStopsTakingKeys` | on `HEAD`: `:303: hover key 1 still takes keys expected: false, actual: true` | Yes, up to W walking after, which is not checked in game |
| AC2 | `testSetKeyOnASecondHoverKeyEndsTheFirstWait` | on `HEAD`: `:313: expected: "Key: E" actual: "Press a key"` | Yes |
| AC3 | `testARedrawOfTheRowsDuringAWaitNeverLeavesKeysTaken` | on `HEAD`: 18 cells (S12, S13, S14, S15, S17, S18 x 3 saved keys) at `:379: hover key 1 still takes keys`; S16 and S20 pass, as their rows say | Yes |
| AC4 | `testCombatStartEndsAWait`, `testAClickInCombatStartsNoWait` | on `HEAD`: `:404: expected: "Key: E" actual: "Press a key"`; the click-in-combat test passes on `HEAD`, as its row says | Yes, up to W walking in combat, which is not checked in game |
| AC5 | `testNoKeyCaptureTakesKeysBeforeItsClick`, `testTheKeyCaptureRefusesAKeyThatMovesYou`, `testEscapeCancelsAWaitAndKeepsTheKey`, `testAModifierKeyOrASecondClickKeepsOneWait`, `testSwitchingPageOrClosingTheWindowEndsAWait` | pass on `HEAD` too, as the rows say (they hold today); the S7, S8 hide scripts and S20's Escape are not checked in game | Yes, up to the client hiding a button with its page or window and Escape with a menu open |

## Not done

In-game checks, none of them possible here:

- **Keyboard off at combat start (S19, AC4):** enter combat (a target dummy) with a hover-key
  button reading "Press a key". You will see it show its key again, and W will walk in combat.
- **Escape with an action or "cast on" menu open during a wait (S20, AC5):** with a wait on,
  open a row's action menu and press Escape. You will see either the menu close and the button
  still read "Press a key", or the menu and the wait both end and the button show its key. In
  both, W behaves as the button's text says.
- **The client firing `OnHide` when a page or the window hides (S7, S8, AC5):** with a wait on,
  click the Layout tab, and separately close the window. You will see W walk afterwards, and
  the button show its key when you return.
- **Escape with a wait on and no menu open (AC5):** press Escape with hover key 1 reading
  "Press a key". You will see it show its old key and W walk; whether Escape also closes the
  window is what this check tells us.
- **A right click ending the wait (S10, AC1):** right-click the waiting button. You will see
  it read "Set key..." and W walk, and the next key does its normal thing.
- **Set key on a second hover key (S11, AC2):** click Set key on hover key 2 while 1 waits. You
  will see hover key 1 show its key, hover key 2 read "Press a key", and a key set only 2.

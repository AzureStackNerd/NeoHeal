# Refinement: #6 A hover-key button keeps taking keys after its wait should have ended

## User value

As a healer setting up hover keys, I want my keys to do what they always do whenever no hover-key button reads
"Press a key", so that I never lose movement, or a key I press, to the options window.

When this is done, a healer who sets or clears a hover key walks with W again as soon as no button reads "Press a
key", from the release that carries this fix.

A "wait" below is a hover-key button reading "Press a key" after a left click on it. Today a button can stop reading
"Press a key" while it still takes every key: after a right-click on it, after Set key on another hover key, or after
a click elsewhere in the window that redraws the rows. W then shows the red "moves your character" message instead of
walking, and by the code the next other key is saved as that hover key, until Escape, a key, or closing the window. A
wait that is on when combat starts keeps taking keys in combat.

## Delivers value alone

yes: the fix reaches every healer who opens the options window with the next release; nothing else has to land first.
Waits on: none

## Acceptance criteria

| AC | Criterion | Scenarios | Proving test |
| --- | --- | --- | --- |
| AC1 | Right-clicking a hover-key button that reads "Press a key" clears its key, the button reads "Set key...", W walks, and the next key does what it does in the game. | S10 | `spec/options_test.lua` "right-click during a wait clears the key and stops taking keys"; that W then walks is not checked in game |
| AC2 | Only one hover-key button waits at a time: Set key on another ends the first, which shows its key again, and the next key is set on the new one only. | S11 | `spec/options_test.lua` "Set key on a second hover key ends the first wait" |
| AC3 | No hover-key button takes keys unless it reads "Press a key": a click elsewhere in the window or a change the game makes that redraws the rows ends the wait, and the button shows its key and takes none; a click that redraws nothing leaves the wait on, still reading "Press a key" and taking the next key. | S12, S13, S14, S15, S16, S17, S18, S20 | `spec/options_test.lua` "a redraw of the rows during a wait never leaves keys taken", one case per source |
| AC4 | When combat starts during a wait, the wait ends: the button shows its key and W walks in combat; a click on a hover-key button in combat starts and clears nothing. | S19, S9 | `spec/options_test.lua` "combat start ends a wait" and "a click in combat starts no wait"; W in combat is not checked in game |
| AC5 | What works today keeps working: a key sets the hover key and ends the wait, Escape ends it and keeps the old key, a key that moves you is refused with the red message while the wait goes on, a modifier key alone or a second click on the same button keeps one wait, the Layout tab or closing the window ends it, and whenever the window opens no button takes keys. | S1, S2, S3, S4, S5, S6, S7, S8, S20 | `spec/options_test.lua` "no key capture takes keys before its click", "the key capture refuses a key that moves you" (both exist), "Escape cancels a wait and keeps the key", "a modifier key or a second click keeps one wait", "switching page or closing the window ends a wait"; that the client hides the button with its page or window is not checked in game |

## Dimensions

| Dimension | Values | Rows |
| --- | --- | --- |
| What happens during the wait | a key that sets (Q), Escape, a key that moves you (W), a modifier key alone, a left click on the same button, the Layout tab, closing the window, a right click on the same button, Set key on another hover key, a right click on another hover key, a modifier button, an action menu choice, Reset to class defaults, a click that redraws no row, a menu opened and closed without a choice, a spell learned, a key binding changed | S2, S3, S4, S5, S6, S7, S8, S10, S11, S12, S13, S14, S15, S16, S20, S17, S18 |
| Combat | out of combat throughout, combat starts during the wait, in combat at the click on a hover-key button | S2 (and every row but the next two), S19, S9 |
| The hover key's saved key before the wait | none, an ordinary key (E), a key that moves you (W) | S3 holds all three: its state names each value and its Expected the text each returns to; every other ending returns to the same text, so no second row adds a case |
| Which hover key waits | 1, 2, 3 | 1 in S2 and every row; 2 in S11, after its click; 3 in no row, because the three buttons are built by the same code and a third adds no case beyond S11's pair |

17 x 3 x 3 x 3 = 459 cells. They collapse: the three hover-key buttons are built by the same code, so the slot only
matters where two buttons meet (S11, S12); the saved key only decides the text a button returns to, the same on every
ending (S3 shows all three); a click on a hover-key button in combat is refused whatever it is (S9), and combat starting
is one moment (S19). Live: the 17 endings out of combat, S9, S19, and S1 (no wait at all) = 20 rows. A test over
AC3's seven cases (the six redraws S12 to S15, S17, S18, and S16, which redraws nothing) x the three saved keys is 21
cells, one loop; S20 would add one case.

## States, moments and places

Unless a row says otherwise: the options window is open on Click Casting, out of combat, and hover key 1 waits (its
button was left-clicked and reads "Press a key"). Every "Today" is read in the code: S10 is the issue's case, S11 and
S13 the reviewer's report it names as not re-checked, and none is seen in game.

| Id | State, moment or place | Operation | Expected |
| --- | --- | --- | --- |
| S1 | No wait: the window opens, the first time after a `/reload` or again after a close | the healer presses W | W walks; no hover-key button takes a key (works today: "no key capture takes keys before its click") |
| S2 | Wait on | the healer presses Q (not a movement key) | Hover key 1 is Q, its button reads "Key: Q"; W walks after; the next key does its normal thing (works today) |
| S3 | Wait on; hover key 1 was empty, E, or W (moves you) | the healer presses Escape | Hover key 1 is unchanged and its button reads "Set key...", "Key: E" or "W (moves you)" as before the wait; W walks after (works today, no test) |
| S4 | Wait on | the healer presses W | The red message "W moves your character...", the button keeps reading "Press a key" and the wait goes on; Q after sets it (works today: "the key capture refuses a key that moves you") |
| S5 | Wait on | the healer presses Shift alone | The wait goes on, still "Press a key"; Shift is not saved (works today, no test) |
| S6 | Wait on | the healer left-clicks hover key 1 again | It keeps reading "Press a key"; one wait; the next key sets hover key 1 (works today, no test) |
| S7 | Wait on | the healer clicks the Layout tab | The wait ends: W walks on the Layout page; back on Click Casting, hover key 1 reads its key. Works today by the code, through the button's hide script; that the client fires it when its page hides is not checked in game |
| S8 | Wait on | the healer closes the window (its X, `/neoheal`, the addon compartment; with a wait on, Escape first ends the wait, S3; that it does not also close the window is not checked in game) | The wait ends, W walks; reopened, no button takes a key and each reads its key. Works today by the code; not checked in game |
| S9 | In combat, no wait | the healer left- or right-clicks a hover-key button | Nothing starts and nothing is cleared; W walks (works today, no test) |
| S10 | Wait on (issue #6) | the healer right-clicks hover key 1 | Hover key 1 is cleared, its button reads "Set key...", W walks, and the next key does its normal thing. Today: W shows the red message and the next other key is saved as hover key 1 |
| S11 | Wait on | the healer left-clicks hover key 2 | Hover key 1 shows its key again and takes no key; hover key 2 reads "Press a key"; Q sets hover key 2 only; W walks after. Today: both wait; which one gets Q is not checked in game, and the other keeps taking keys under its old text |
| S12 | Wait on | the healer right-clicks hover key 2 | Hover key 2 is cleared and reads "Set key..."; the wait ends: hover key 1 shows its key again, takes no key, and W walks. Today: hover key 1 shows its old text and keeps taking keys |
| S13 | Wait on | the healer clicks a modifier button (Shift) | The rows show Shift's actions; the wait ends: hover key 1 shows its key, takes no key, and W walks. Today: as S12 |
| S14 | Wait on | the healer picks an action in any row's action menu, hover key 1's own included | The action is saved; the wait ends: hover key 1 shows its key, takes no key, and W walks. Today: as S12 |
| S15 | Wait on | the healer clicks Reset to class defaults | The bindings reset; the wait ends: hover key 1 shows its key, takes no key, and W walks. Today: as S12 |
| S16 | Wait on | the healer picks a "cast on" choice, ticks "Also target", clicks the window's background or drags the window | Nothing redraws the rows: hover key 1 keeps reading "Press a key" and the next key sets it. Today: the same; nothing is hidden |
| S17 | Wait on | a spell is learned or talents change (the rows redraw half a second later) | When the rows redraw, the wait ends: hover key 1 shows its key, takes no key, and W walks. Today: as S12 |
| S18 | Wait on | a key binding changes (the game's key bindings event) | The rows redraw and the wait ends: hover key 1 shows its key, takes no key, and W walks. Today: as S12 |
| S19 | Wait on; the window stays open | combat starts | The wait ends: hover key 1 shows its key, W walks in combat, and the next key does its normal thing. Whether the client allows turning the button's keyboard off at that moment is not checked in game. Today: it keeps reading "Press a key", W shows the red message in combat, and any other key is saved as hover key 1 |
| S20 | Wait on | the healer opens an action or "cast on" menu and closes it without a choice (a click on the window's background, or Escape) | Opening and closing a menu redraws no row: hover key 1 keeps reading "Press a key" and the next key sets it, as S16. Escape with the menu open either closes the menu, and the wait goes on still reading "Press a key", or reaches hover key 1 and ends the wait as S3; which one is not checked in game, and in both the button's text matches whether it takes keys. Today: the same |

## Conflicts and unclear points

- [x] Clicks elsewhere in the window during a wait (S12 to S16, AC3): does the wait end? Options: (a) a click that changes what the rows show (a right click on another hover key, a modifier button, an action choice, Reset) ends the wait, the button shows its key and W walks; a click that changes nothing (S16) leaves the wait reading "Press a key"; (b) no such click ends the wait, and the button keeps reading "Press a key" until a key or Escape; (c) any click anywhere else in the window ends the wait, S16 included. Proposed: (a), since the healer has moved on and the issue's own case ends the wait. Against (a): S16 then differs from S13 (Shift ends the wait, "Also target" does not), which (c) avoids at the cost of noticing every click in the window, not counted. Answer: (a). A click that redraws the rows ends the wait, and the button shows its key; a click that redraws nothing (S16) leaves the wait on, still reading "Press a key", so the text always tells the truth. Against: S13 and S16 then behave differently, which a healer may notice; accepted, because in both the button's text matches whether it takes keys, and that is what the issue is about. Residual risk: a healer who clicks "Also target" mid-wait and then presses W sees the red message, as today, with the button reading "Press a key". Serves: the end state, "everything a healer needs ... without the setup burden", and the issue's own expected result (the right-click case ends the wait). (product owner, 2026-11-16)
- [x] The game's changes during a wait (S17, S18, AC3): does a spell learned or a key binding changed end it? Options: (a) the wait goes on and the button keeps reading "Press a key"; (b) the wait ends and the button shows its key. Proposed: (b) if clicks pick (a), so one rule holds: whatever redraws the rows ends the wait. Against (b): a wait the healer did not touch ends at a moment they did not choose, and they click Set key again. Answer: (b). One rule for the healer: whatever redraws the rows ends the wait. Against: a wait ends unasked; accepted, since a spell learned or a binding changed in the seconds of a wait is rare and costs one more click on Set key. Residual risk: none beyond that click. Serves: own judgement. (product owner, 2026-11-16)
- [x] Combat starting during a wait (S19, AC4): Options: (a) the wait ends when combat starts, the button shows its key and W walks in combat; (b) the wait goes on into combat, as today. Proposed: (a): the end state is that a healer never loses movement to the options window, and in combat that costs most. Against (a): a healer who was setting a key must click Set key again after combat, because clicks on it are refused in combat (S9). Answer: (a). Against: Set key must be clicked again after combat; accepted, losing movement in combat costs far more. Residual risk: whether turning the button's keyboard off is allowed at that moment on Forever is not checked in game (Notes for gate 2); it becomes a solo in-combat check. Serves: the end state, "everything a healer needs to see and to cast on". (product owner, 2026-11-16)
- [x] Escape with a menu open during a wait (S20, AC5): AC5 says Escape ends a wait; with an action or "cast on" menu open, the game may send Escape to the menu instead. Options: (a) keep AC5 as written and make S20's Escape an in-game check; (b) narrow AC5 to "Escape with no menu open ends it". Answer: (a); AC5 stays as written, no AC changes. Against: if the game sends Escape to the menu, AC5 is literally false in that state. Accepted: the button's text matches whether it takes keys in both outcomes, which is what the issue is about, and the in-game check tells us which one holds. Residual risk: AC5 reads wider than one untested state. Serves: own judgement. (product owner, 2026-11-16)
- [x] Which acceptance criterion lists S20 (a menu opened and closed during a wait): Answer: both AC3 (closing the menu without a choice redraws nothing, the wait goes on) and AC5 (Escape with the menu open, an in-game check). Against: AC5 then lists a scenario whose Escape outcome is unknown until checked in game. Serves: Remco's choice in this session, "Both AC3 and AC5". (Remco, 2026-11-16)

## Not in this story

- A click that redraws no row ending the wait (S16, S20): the product owner chose to leave the wait on there
  (Conflicts, clicks); a new issue if wanted.
- Starting a wait again by itself after combat: the healer clicks Set key again (Conflicts, combat).
- Which of an open menu and the waiting button gets Escape (S20): an in-game check, not a change (Conflicts, Escape).

## Estimate

**2 points.** Basis: the Developer counted 2 from the code: 1 source file, `Options.lua`, 4 sites (the start and
right-click branches with `StopCapture`, `RefreshBindingRows`, the modifier-button handler if the redraw does not cover
it, the combat handler), about 20 to 35 changed lines; `spec/options_test.lua` 8 test functions (AC1 1, AC2 1, AC3 1
looping the 21 cells, AC4 2, AC5 3), about 110 to 140 lines, and `FakeFrame` taught to propagate hides, about 25 to 35
lines; 2 docs, and the tooltip only if an ending must be told. The Architect counted 2, or 3 if the fake's propagation
and the 21-cell table both landed; the Developer showed both are cheap (the propagation fires only on a real hide, the
cells are one loop), so both count 2. S20 came after the count and adds no code site.

## Notes for gate 2

- Every redraw of the rows sets each hover-key button's text without looking at the keyboard state; the callers today:
  the right-click branch, a captured key, the modifier buttons, an action choice, Reset, and the page's refresh (on
  show, after `SPELLS_CHANGED` and `UPDATE_BINDINGS` through `Options:RefreshClickCastingPage`). A design must cover
  all of them, and a caller added later must not reopen the bug.
- The fake frames in `spec/options_test.lua` fire no `OnHide` on children when a page or the window hides (`Hide` and
  `SetShown` are no-ops), so S7 and S8 can be tested through the window only if the fake learns to; calling the
  button's hide script directly proves only the button's own reaction.
- The window's combat handler (its `OnEvent`, kept by the fake) also calls `Layout:SetTestMode` and
  `Layout:SetMoveMode`; the window test fakes only `Layout.GetSize`, so an S19 test needs those too.
- Combat (S19): `PLAYER_REGEN_DISABLED` fires just before lockdown (comment in `TrackCombatAndModes`). Whether
  `EnableKeyboard` and `SetPropagateKeyboardInput` on a plain options button may be called in combat on Forever is not
  checked; the start of a wait is refused in combat already.
- S11 today: with two keyboard-enabled buttons, which one gets a key is not checked in game; a design that allows one
  wait at a time does not depend on it.
- Docs at gate 3: `docs/forever-api.md` section 7 says only a captured key or `OnHide` turns the keyboard off;
  `docs/features.md` describes setting a hover key; the tooltip (`L.HOVER_KEY_TOOLTIP`) names Escape and right click
  only.
- Which button waits (Developer): no state names it today; a wait lives only in each button's keyboard flag. Gate 2
  decides what tracks the waiting button and every place it clears: a key or Escape, a right click on it, Set key on
  another, a redraw of the rows, its own hide (page switch, window close), combat start.
- The redraw path for S11 (Developer): `StopCapture` redraws only its own button (`Options.lua:313`); after a captured
  key all rows redraw (`:335`). S11 needs hover key 1 to show its key when hover key 2 starts: gate 2 names the path
  that redraws it.
- `SetPropagateKeyboardInput(false)` at the start of a wait (`Options.lua:325`) is the only call in the addon and is
  never set back to true (Developer). Likely harmless, because the keyboard is off once a wait ends and the next start
  sets it again; gate 2 says so or resets it.
- `ClickCast.appliedHoverKeys` (Developer): copied from the saved hover keys on every `Apply` (`ClickCast.lua:450`), which
  runs out of combat, and read by the tooltip (`:666`). Ending a wait at combat start (S19) changes no saved key, so it
  is not expected to need a re-apply; gate 2 states it.
- The fake's propagation (Developer): firing `OnHide`/`OnShow` down the tree needs child links in `FakeFrame`. `Create`
  calls `ShowPage(1)` (`Options.lua:537`) while the window is hidden, so a propagated `OnShow` must fire nothing under a
  hidden window, or S1's test sees a build-time redraw. No existing window test hides a frame, so the change cannot
  spread into them.
- `RefreshClickCastingPage` returns unless the page `IsVisible()` (`Options.lua:444-446`): `SPELLS_CHANGED` and
  `UPDATE_BINDINGS` redraw nothing while the Layout page shows, so a test must not expect a redraw there; no wait can be
  on then (S7).
- S20: the fake models no keyboard focus, so whether Escape reaches an open menu or the waiting button is for the game
  only.
- In-game checks this story will need, by situation. Solo, out of combat: S10 (right-click a waiting button: it reads
  "Set key..." and W walks), S11, S12 to S15 (each ends the wait), S7, S8, Escape with a wait on and the window open
  (it ends the wait; whether it also closes the window, S8), and Escape with a menu open during a wait (S20). Solo, in
  combat (a mob or a target dummy): S19, the wait ends as combat starts and W walks.

## How

- Where a wait ends: the hover-key button's own `Refresh` turns its keyboard off and clears the wait when it holds that
  button, because it is the only code that writes a text other than "Press a key", so text and keyboard change
  together (architect and developer, 2026-11-16)
- One wait at a time: one module-level `waitingCapture` in `Options.lua`, set by the start and cleared by `Refresh`
  only when it holds that button (`Options.lua:303-310`), instead of a keyboard flag per button to scan
  (architect and developer, 2026-11-16)
- The contract: the start writes "Press a key" and never calls `Refresh`; any `Refresh` on that button is an ending,
  so a caller added later cannot reopen the bug (`Options.lua:323-325`) (architect and developer, 2026-11-16)
- Who ends it: the right-click branch, a captured key or Escape, a modifier button, an action choice, Reset and the
  page's refresh all reach `Refresh` or `RefreshBindingRows` unchanged; `OnHide` calls `Refresh` with no guard, and
  ends a wait only through `waitingCapture` (architect and developer, 2026-11-16)
- A second Set key: the left branch refreshes the previous waiting button before starting its own, which shows its key
  again (S11; S6 holds either way, since a second click on the same button ends and restarts the same wait)
  (architect and developer, 2026-11-16)
- Combat: the window's existing `PLAYER_REGEN_DISABLED` handler in `TrackCombatAndModes` ends a wait as combat starts
  (S19); S9 is untouched and `InCombatLockdown` still returns at a click (architect and developer, 2026-11-16)
- Keyboard calls: `SetPropagateKeyboardInput(false)` at the start is never reset, because the keyboard is off at every
  ending and the next start sets it again; an ending calls `EnableKeyboard(false)` only, so no call of unchecked combat
  legality runs when combat starts (architect and developer, 2026-11-16)
- No re-apply: ending a wait saves no key, so `ClickCast.appliedHoverKeys` is not refreshed at combat start
  (architect and developer, 2026-11-16)
- The fake: frames learn their children, and `IsVisible` is computed from the frame's own flag and every ancestor's;
  `Hide`, `Show` and `SetShown` fire `OnHide`/`OnShow` only on a real change, so the build's `ShowPage(1)`
  (`Options.lua:537`) fires nothing under the hidden window (architect and developer, 2026-11-16)
- Wait tests: each calls `Options:Show()` first, so the wait exists as it does in the game and
  `RefreshClickCastingPage`'s `IsVisible` check (`Options.lua:444-446`) is real; S17 and S18 drive that call, and its
  step from each event to it is covered by "learning a spell refreshes the rows" and `testTheOptionsPageIsRefreshed`
  (`spec/hoverkeys_test.lua`), so no `Core.lua` loads in the window test (architect and developer, 2026-11-16)
- S16's controls: the "Also target" checkbox is found as the `CheckButton` whose parent is the row (one per row), and
  `FakeMenu:CreateRadio` records its setter; ticking or choosing redraws nothing, so the wait goes on
  (architect and developer, 2026-11-16)
- The invariant: one helper asserts `keyboardEnabled == (text == L.PRESS_A_KEY)` on all three buttons, called in the
  21-cell loop and in every ending test, which states AC3's rule as an assertion (architect and developer, 2026-11-16)
- Tooltip unchanged: the new endings show on the button itself, which returns to its key, so the healer is told nothing
  new, and no locale string changes (architect and developer, 2026-11-16)
- Mutations: the end in `Refresh` removed turns AC1 and every redraw case red; the left branch's end removed, S11;
  the combat call removed, S19; a source's redraw call removed, that source's case only; the fake's hide
  propagation removed, S7 and S8 (architect and developer, 2026-11-16)

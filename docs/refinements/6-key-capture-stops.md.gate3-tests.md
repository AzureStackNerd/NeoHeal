# Gate 3 tests: #6 A hover-key button keeps taking keys after its wait should have ended (TestWriter)

Tests: `spec/options_test.lua`, class `TestHoverKeyWait` (8 tests), plus the fake changes above it (frames know
their type, parent and children; `IsVisible` is computed; `Show`/`Hide`/`SetShown` run `OnShow`/`OnHide` down the
tree only when visibility changes; `SetupMenu` keeps the builder on its dropdown; `FakeMenu:CreateRadio` keeps its
setter). No new spec file, so `spec/run.lua` is unchanged. Expected texts are the scenario rows' own words.

Mutation copy: `C:/CODE/scratch/neoheal-6/mut/` (the addon's `*.lua`, `NeoHeal.toc`, `Locales/`, `spec/`), refreshed
from the working tree before every mutation by `C:/CODE/scratch/neoheal-6/mut.sh`, which saves the file aside, mutates
one whole line through `mutate.lua` (refuses unless the anchor matches exactly one line), runs
`lua spec/run.lua -p TestHoverKeyWait`, restores from the saved file and `cmp`s it with the working tree. In the copy,
the 8 `TestRelease` tests error because they read repository files the copy leaves out (`.pkgmeta`, `.github/`,
`git ls-files`); in the repository the suite is `Ran 279 tests, 279 successes, 0 failures`.

## First proof: the bug tests on the code before the fix

`Options.lua` from `HEAD` (read with `git show` into the copy only), new tests run: 4 red, 4 green, as the rows say.

| Test | Rows | On HEAD | Failure line |
| --- | --- | --- | --- |
| `testRightClickDuringAWaitClearsTheKeyAndStopsTakingKeys` | S10, AC1 | red | `:303: hover key 1 still takes keys expected: false, actual: true` |
| `testSetKeyOnASecondHoverKeyEndsTheFirstWait` | S11, AC2 | red | `:313: expected: "Key: E" actual: "Press a key"` |
| `testARedrawOfTheRowsDuringAWaitNeverLeavesKeysTaken` | S12-S18, S20, AC3 | red | 18 cells (S12, S13, S14, S15, S17, S18 x 3 saved keys) at `:379: hover key 1 still takes keys`; S16 and S20 pass, as their rows say |
| `testCombatStartEndsAWait` | S19, AC4 | red | `:404: expected: "Key: E" actual: "Press a key"` |
| `testAClickInCombatStartsNoWait` | S9, AC4 | green | works today |
| `testEscapeCancelsAWaitAndKeepsTheKey` | S3, AC5 | green | works today |
| `testAModifierKeyOrASecondClickKeepsOneWait` | S5, S6, AC5 | green | works today |
| `testSwitchingPageOrClosingTheWindowEndsAWait` | S7, S8, AC5 | green | works today |

S1 and S4 keep their existing tests (`testNoKeyCaptureTakesKeysBeforeItsClick`,
`testTheKeyCaptureRefusesAKeyThatMovesYou`), unchanged and green.

## Site to test

| Site (file:line) | Test | Red line | Proved on |
| --- | --- | --- | --- |
| `Options.lua:301` `local waitingCapture` (mutated at its set, `:334`) | redraw loop, Shift/second click | M2: 18+ cells at `:379` "hover key 1 still takes keys"; `:244` "after Q: hover key 1 reads "Key: Q" but takes keys" | `1e87bdb2422edcd2384a23407173c88caf5eab2d` |
| `Options.lua:312` `Refresh` ends the wait (`:315` `EnableKeyboard(false)`) | redraw loop, Shift/second click | M1: same lines as M2 | `1e87bdb2422edcd2384a23407173c88caf5eab2d` |
| `Options.lua:325` left branch ends the previous wait (`:333`) | `testSetKeyOnASecondHoverKeyEndsTheFirstWait` | M3: `:313: expected: "Key: E" actual: "Press a key"` | `1e87bdb2422edcd2384a23407173c88caf5eab2d` |
| `Options.lua:325` right branch redraw (`:329`) | `testRightClick...`, redraw loop | M4: `:302: expected: "Set key..."`, loop at `:394` | `1e87bdb2422edcd2384a23407173c88caf5eab2d` |
| `Options.lua:339` `OnKeyDown` redraw (now `:346`) | Escape, Shift/second click, second hover key | M5: `:429: expected: "Set key..."`, `:447: expected: "Key: Q"`, `:319: expected: "Key: Q"` | `1e87bdb2422edcd2384a23407173c88caf5eab2d` |
| `Options.lua:353` `OnHide` calls `Refresh` (now `:354`) | `testSwitchingPageOrClosingTheWindowEndsAWait` | M6: `:459: hover key 1 takes keys on the Layout page` | `1e87bdb2422edcd2384a23407173c88caf5eab2d` |
| `Options.lua:366` `EndKeyCapture` (body `:367`) | `testCombatStartEndsAWait` | M7: `:404: expected: "Key: E"` | `1e87bdb2422edcd2384a23407173c88caf5eab2d` |
| `Options.lua:515` combat call (now `:524`) | `testCombatStartEndsAWait` | M8: `:404: expected: "Key: E"` | `1e87bdb2422edcd2384a23407173c88caf5eab2d` |

Line numbers in brackets are the lines on disk at mutation time (`Options.lua` mtime 13:28:17); the Developer's
table names the start of each site.

## Mutations

12 runs of the 15 allowed. Each failed on the test's own assertion, never on a load or setup error.

| # | File: line, mutation | Red | Not red |
| --- | --- | --- | --- |
| M1 | `Options.lua:315` `self:EnableKeyboard(false)` in `Refresh` removed | redraw loop (S12-S18 cells at `:379`), Shift/second click `:244` (output cut at 40 lines; rest not read) | |
| M2 | `Options.lua:334` `waitingCapture = self` removed | as M1 | |
| M3 | `Options.lua:333` left branch's `waitingCapture:Refresh()` removed | S11 only (`:313`) | S6: a second click on the same button looks the same either way, so S6 cannot go red here; the How line's "S6 and S11" holds for S11 only |
| M4 | `Options.lua:329` right branch's `RefreshBindingRows()` removed | AC1 `:302`, redraw loop (S12) | |
| M5 | `Options.lua:346` `OnKeyDown`'s `RefreshBindingRows()` removed | Escape `:429`, Shift/second click `:447`, second hover key `:319` | |
| M6 | `Options.lua:354` `OnHide` emptied | S7 `:459` (S8 not reached in that run: S7 fails first) | |
| M7 | `Options.lua:367` `EndKeyCapture` emptied | S19 `:404` | |
| M8 | `Options.lua:524` `Options:EndKeyCapture()` call removed | S19 `:404` | |
| M9 | `Options.lua:431` modifier button's `RefreshBindingRows()` removed (unchanged source; How's per-source check) | loop: S13 x 3 cells only | |
| M10 | `Options.lua:450` Reset returns before its redraw (unchanged source) | loop: S15 x 3 cells only | |
| M11 | `Options.lua:455` `page:Refresh` emptied (unchanged source) | loop: S17 x 3, S18 x 3; also S9 `:414` (its "Key: E" comes from the redraw on open) | |
| M12 | `spec/options_test.lua:95` the fake's visibility scripts removed | S7 `:459`; also S9 `:414` (no redraw on open) | |

## Not checked here (in game only)

That W walks after any ending; which button the client sends a key to; that the client runs `OnHide` on the button
when its page or the window hides (S7, S8); that `EnableKeyboard(false)` is allowed as combat starts (S19); where
Escape goes with a menu open (S20).

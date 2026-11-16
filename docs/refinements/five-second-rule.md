# Refinement: Show the five-second rule on your own frame

## User value

As a healer, I want to see when my mana regeneration comes back after a cast, so that I can time my casts and save
mana.

When this is done, whoever casts a spell that costs mana sees, on their own frame and right from that moment, how
long it is until their mana regeneration is back, from the release that carries this story.

On Classic-era content a caster's mana stops coming back for five seconds after the last spell that cost mana. Today
NeoHeal's frames show how much mana you have, never whether it is coming back, so a healer who wants to wait those
five seconds out needs another addon or a count in their head.

## Delivers value alone

yes: the bar shows on your own frame with the next release; nothing else has to land first.
Waits on: none

## Acceptance criteria

| AC | Criterion | Scenarios | Proving test |
| --- | --- | --- | --- |
| AC1 | The moment you spend mana on a spell (when a cast finishes, at once for an instant, when a channel starts), a thin bar on the mana strip of your own frame appears full and drains to empty over 5 seconds, a channel longer than 5 seconds included; when it is gone, your mana regeneration is back. This holds in and out of combat, on your party frame and on your raid frame. | S1, S2, S3, S4, S10, S29, S38 | `spec/fivesecond_test.lua` "testAManaSpellStartsTheBarFull" and "testTheBarIsGoneAfterFiveSeconds" |
| AC2 | Every cast of a spell with a mana cost starts the bar, a free cast of one and one whose cost the game hides included; a new one fills it again for a full 5 seconds; a cast that is interrupted or fails, and anything without a mana cost, leave it as it is. | S5, S6, S7, S8, S9 | `spec/fivesecond_test.lua` "testANewManaSpellFillsTheBarAgain" and "testNoManaSpentLeavesTheBarAsItIs" |
| AC3 | Every frame that shows you carries the bar with the same time left: your own frame solo, in a party or in a raid (both of your raid frames when you are also in the main tank group, and also where the game hides which raid frame is you), and the target or focus frame while it shows you. No other frame shows it, and other members' casts never start it. | S15, S16, S17, S18, S19, S20, S21, S22, S23, S38, S40 | `spec/fivesecond_test.lua` "testOnlyFramesThatShowYouCarryTheBar" and `spec/targetfocus_test.lua` "testTheTargetFrameOnYouShowsTheBar" |
| AC4 | Anyone with mana sees the bar, a mage as much as a priest; a warrior or a rogue never does. A druid sees no bar while their strip shows energy or rage; back in caster form within the 5 seconds after a shapeshift or spell that cost mana, they see the time left. | S11, S12, S13, S14, S37 | `spec/fivesecond_test.lua` "testOnlySpendingYourManaCounts" and "testADruidSeesTheTimeLeftBackInCasterForm" |
| AC5 | An option on the Layout page, on by default, turns the bar on and off: off, no frame shows it, and turning it off hides a running bar at once, also in combat. Your frame shows the bar only while it shows a strip (the resource-bar setting decides); when the strip returns during a countdown, the bar shows the time left. | S24, S25, S26, S27, S28, S39 | `spec/fivesecond_test.lua` "testTheOptionTurnsTheBarOff" and `spec/options_test.lua` "testTheFiveSecondOptionIsOnTheLayoutPage" |
| AC6 | When the frame that shows you changes during a countdown (you join a group, the raid moves you to another frame, your target or focus becomes you or someone else), the bar moves to the frame that now shows you, with the time left, and leaves the one that no longer does. | S30, S31 | `spec/fivesecond_test.lua` "testTheBarFollowsAGroupChange" and `spec/targetfocus_test.lua` "testTheBarFollowsTheTargetToAndFromYou" |
| AC7 | The bar never outlasts the rule it shows: dying ends it, a reload or a login starts with none, and a loading screen never makes it show longer. | S32, S33, S34 | `spec/fivesecond_test.lua` "testDeathAndReloadEndTheBar" |
| AC8 | In test mode, with the option on, one fake healer's frame shows the bar part drained; with the option off, no fake frame does. | S35, S36 | `spec/preview_test.lua` "testFiveSecondBarOnOneFakeHealer" |

## Dimensions

| Dimension | Values | Rows |
| --- | --- | --- |
| The action you take | a spell with a cast time that costs mana, an instant that costs mana, a channel of 5 seconds or less, a channel longer than 5 seconds, a cast interrupted or failed, an action that costs no mana, a spell made free, a spell whose cost the game hides, a shapeshift that costs mana, an ability that costs rage or energy | S1; S2; S3; S4; S5; S6; S7; S8; S12; S13 |
| Who you are | a healer class with mana, a class with mana that is no healer, a class without mana, a druid in a form | S1; S14; S11; S12, S13, S37 |
| The frame | your frame solo, your frame in a party, your raid frame, your raid frame where the game hides that it is you, both of your raid frames with the main tank group on, no frame shows you, the target frame on you, the focus frame on you, the target or focus frame on someone else, another member's frame, a pet's frame | S15; S1; S17, S38; S18; S40; S16; S19; S20; S21; S22; S23 |
| Resource bar | Everyone, Healers only and you a healer, Healers only and you no healer, Off | S1, S14; S24; S25; S25, S28 |
| The five-second option | on, off | S1; S26, S27, S39 |
| Combat | out of combat, in combat | S1; S29, S38, S39 |
| The moment | the spell goes off, while the bar drains, the 5 seconds end, a new spell that costs mana during the countdown, an action without mana during the countdown, back in caster form during the countdown, the option changed during the countdown, the resource bar changed during the countdown, the group changes during the countdown, the target or focus switches during the countdown, you die during the countdown, a reload or a login, a loading screen during the countdown | S1; S1; S10; S9; S5, S6, S13; S37; S27, S39; S28; S30; S31; S32; S33; S34 |
| Test mode | off, on | S1; S35, S36 |

10 x 4 x 11 x 4 x 2 x 2 x 13 x 2 = 183040 cells. They collapse to 40 rows, because each dimension decides one
thing only. The action decides whether the bar starts and for how long (S1 to S9, S12, S13); who you are decides
whether you have mana to spend and whether your strip shows it (S11 to S14, S37); the frame decides only where the bar
shows, so its rows vary the place around one mana spell (S15 to S23, S38, S40); the resource bar decides only whether
there is a strip to show it on (S24, S25, S28). Combat has rows of its own where it can change what shows: your raid
frame in combat, the story's main case (S38), and the option turned off in combat (S39). For the rest one row (S29)
holds the combat cells: the research in the backlog item found the player's own casts are not hidden in combat (not
checked in game). Each moment that can change what shows during a countdown has its own row.

## States, moments and places

Unless a row says otherwise: you play a priest (a class with mana and a healer by class), alive, out of combat, in a
party; "your frame" is your own party frame; Resource bar is Everyone; the five-second option is on; test mode is off.
"The bar" is the five-second bar this story adds; "the strip" is the resource bar along the bottom of a frame. That
the game stops mana regeneration for 5 seconds after mana is spent, from the end of a cast or the start of a channel,
comes from community sources (wikis and a Forever priest guide), not checked in game.

| Id | State, moment or place | Operation | Expected |
| --- | --- | --- | --- |
| S1 | A spell with a cast time that costs mana (Flash Heal) | the cast finishes | Nothing while casting; when the cast finishes, the bar appears full on the strip of your frame and drains to empty over 5 seconds, then is gone. |
| S2 | An instant that costs mana (Renew) | cast | The bar appears full at the cast and drains to empty over 5 seconds. |
| S3 | A channel of 5 seconds or less (Mind Flay) | the channel starts | The bar appears full when the channel starts and drains to empty 5 seconds after that start. |
| S4 | A channel longer than 5 seconds (a druid's Tranquility, 10 seconds) | the channel starts | The bar appears full when the channel starts and drains to empty 5 seconds after that start, while the channel may still run. The docs name this as a known limit: by community sources, not checked in game, regeneration stays off for the whole channel. |
| S5 | A spell with a cast time interrupted, cancelled by moving, or failing (out of range, not enough mana, out of sight) | cast attempt | No bar starts; a bar already running keeps draining as before. |
| S6 | An action that costs no mana: a wand's Shoot, a melee swing, Life Tap, a mana potion | use | No bar starts; a bar already running keeps draining as before. |
| S7 | A spell with a mana cost made free (a cast on Clearcasting, or after Inner Focus) | cast | The bar as in S2: every cast of a spell with a mana cost starts it, a free one too. |
| S8 | A spell whose mana cost the game hides or does not give | cast | The bar as in S2. |
| S9 | A new spell that costs mana with 2 seconds of the bar left | cast | The bar is full again and empties 5 seconds after this cast. |
| S10 | 5 seconds pass after the last spell that cost mana | time | The bar is empty and gone; the strip shows only your mana. |
| S11 | You play a warrior or a rogue | any ability | No bar, ever. |
| S12 | You play a druid and shift into Cat Form or Bear Form, which costs mana; your strip now shows energy or rage | shapeshift | No bar shows while the strip shows energy or rage; the 5 seconds still count from the shift. |
| S13 | A druid in a form uses an ability that costs energy or rage (Claw, Maul) | use | No bar shows and the 5 seconds are not restarted. |
| S14 | You play a mage (mana, no healer by class) | cast Frostbolt | The bar shows on your frame exactly as for a priest. |
| S15 | Solo, "Show when solo" on | cast | The bar shows on your frame. |
| S16 | Solo, "Show when solo" off, and no target or focus frame shows you | cast | No frame shows a bar; nothing else changes. |
| S17 | In a raid: your own raid frame, wherever it sits among up to 40 | cast | The bar shows on the strip of your own raid frame; no other frame shows it. |
| S18 | In a raid, on a map where the game hides whether a raid frame is you | cast | The bar shows on the strip of your own raid frame; no other member's frame ever shows it. |
| S19 | The target frame while you target yourself | cast | The target frame shows the bar with the same time left as your own frame, at the same moment. |
| S20 | The focus frame while your focus is you | cast | The focus frame shows the bar with the same time left as your own frame. |
| S21 | The target or focus frame showing someone else | your cast | That frame shows no bar. |
| S22 | Another member's frame; another member casts a spell that costs mana | your cast; their cast | Their frame never shows a bar; their cast starts no bar on any frame. |
| S23 | A pet's frame | your cast | The pet's frame shows no bar. |
| S24 | Resource bar "Healers only", you a healer | cast | As S1: your strip shows and the bar is on it. |
| S25 | Resource bar "Off", or "Healers only" and you no healer (a mage) | cast | No bar: your frame shows no strip, so it shows no bar either. |
| S26 | The five-second option off | cast | No frame shows a bar, whatever you cast; the rest of the frame is as today. |
| S27 | The five-second option turned off during a countdown, then on again | options | Off: the bar is gone at once. On again: the bar shows from the next spell that costs mana. |
| S28 | Resource bar changed during a countdown (Everyone to Off, then back) | options | While there is no strip, no bar; when the strip returns during the countdown, the bar is on it with the time left. |
| S29 | In combat | the casts of S1 to S10 | The same as out of combat. That the game tells an addon about your casts and their mana cost in combat is not checked in game. |
| S30 | The group changes during a countdown: you join a party or a raid, or the raid puts you on another raid frame | roster change | The bar shows on the frame that now shows you, with the time left; the frame that showed you before shows none. |
| S31 | Your target or focus becomes you, or someone else, during a countdown | target or focus change | The target or focus frame shows the bar with the time left when it becomes you, and none from the moment it shows someone else. |
| S32 | You die during a countdown | death | The bar is gone; after a resurrection, no bar until the next spell that costs mana. |
| S33 | A reload or a login during a countdown | reload or login | No bar until the next spell that costs mana; the seconds that were left are not shown. |
| S34 | A loading screen during a countdown (a portal, an instance) | zone change | After the loading screen the bar shows the time left, or nothing if the rule has ended; never longer than the rule. |
| S35 | Test mode, five-second option on | test mode | One fake healer's frame shows the bar part drained on its strip, and so does the target or focus preview while it shows that member; no other fake frame shows it. |
| S36 | Test mode, five-second option off | test mode | No fake frame shows the bar. |
| S37 | A druid shifts back to caster form during a countdown (2 seconds after shifting into a form) | shapeshift | The strip shows mana again and the bar shows on it with the time left (here 3 seconds), then drains to empty. |
| S38 | In a raid, in combat: your own raid frame | cast | As S17: the bar shows full on the strip of your own raid frame and drains over 5 seconds; no other frame shows it. |
| S39 | The five-second option turned off during a countdown, in combat | options | The bar is gone at once, not when combat ends. |
| S40 | In a raid with "Main tank group" on, while you are a main tank: you show on your group's frame and in the main tank group | cast | Both of your frames show the bar with the same time left. |

## Conflicts and unclear points

- [x] 1. In a raid your own frame can be any of up to 40, and on maps where the game hides whether a raid frame is you NeoHeal cannot tell which: is the bar on your raid frame's strip (the agreed design, and the game may still place it there unseen by the addon, not checked in game), or on a strip under the title bar that always sits in the same place, or both? Answer: on your own raid frame's strip, as agreed, also where the game hides which raid frame is you (AC3 stands as written; how is the pair's, see "Notes for gate 2"), and never on a frame that is not you. Against it: in a raid of 40 your frame takes looking for, which a strip under the title bar would not; that strip is a second design and can be a story of its own. Residual risk: if no way exists to place the bar where the game hides which frame is you, AC3 cannot be met there, and that comes back as a question to Remco at the build. Serves: "sounds good" to the bar on your own frame's mana strip (Remco, 2026-11-16) (product owner, 2026-11-16)
- [x] 2. When your frame shows no strip (Resource bar "Off", or "Healers only" while you are no healer): no bar at all (the strip setting wins), the bar on its own along the bottom of your frame, or your own strip shows anyway while the option is on? Answer: no bar at all: the strip setting wins, as AC5 already says the bar follows it, and the option's text says the bar sits on the mana strip. Against it: a player with the strip off who turns the option on sees nothing and may think it broken. Residual risk: that confusion, eased by the option's text; a bar of its own is a later story if asked for. Serves: the agreed design, "a thin bar on the mana strip of your own frame" (Remco, 2026-11-16) (product owner, 2026-11-16)
- [x] 3. A druid in Cat Form or Bear Form has a strip that shows energy or rage, while shifting itself costs mana: does the bar show on that strip, or not at all while in a form? Answer: not at all while the strip shows energy or rage; the countdown still runs, and back in caster form within the 5 seconds the bar shows the time left on the mana strip. Against it: a feral druid who shifts out to heal cannot see the countdown before shifting. Residual risk: a feral druid times the shift-out without it. Serves: the agreed design, the bar sits on the mana strip (Remco, 2026-11-16) (product owner, 2026-11-16)
- [x] 4. A channel longer than 5 seconds (Tranquility) keeps mana regeneration off for the whole channel, by community sources and not checked in game: does the bar drain over 5 seconds as the design says (empty while regeneration is still off), or over the channel's length? Answer: over 5 seconds from the channel's start, as the design says; the docs name channels longer than 5 seconds as a known limit, not checked in game. Against it: during Tranquility the bar may be gone while regeneration is still off. Residual risk: that, for the few healer channels longer than 5 seconds; the claim it rests on is unchecked, so building for it first would be building on a guess. Serves: own judgement (product owner, 2026-11-16)
- [x] 5. When NeoHeal cannot tell whether a cast cost mana (the game hides or does not give its cost): no bar (may say regeneration is back while it is not), or the bar (may say it is off while it is not)? Answer: the bar: a cost NeoHeal could not read is no proof that nothing was spent, and nearly every spell a mana user casts costs mana. Against it: a free cast whose cost is hidden shows a bar while regeneration goes on. Residual risk: a healer waits up to 5 seconds without need. Serves: own judgement: an answer NeoHeal could not get is never shown as "nothing there" (product owner, 2026-11-16)
- [x] 6. The new option on the Layout page: on by default for every player after the update (like "Show low mana"), or off until they turn it on (like the target and focus frames)? Answer: on by default. Against it: every player gets a moving bar on their own frame after the update without asking for it. Residual risk: a player who dislikes it has to find the option. Serves: "everything a healer needs to see and to cast on, without the setup burden" (the end state in the project file) (product owner, 2026-11-16)
- [x] 7. In combat NeoHeal cannot tell a cast made free (Clearcasting, Inner Focus) from one that spent mana, as auras are hidden from addons then, so AC2's free-cast exception (S7) cannot hold in combat: drop it everywhere, or keep it out of combat only? Answer: drop it everywhere: every cast of a spell with a mana cost starts the bar, a free one too, in and out of combat; AC2 loses "a cast made free" and S7 expects the bar as in S2. Against it: after a rare free cast the bar may show up to 5 seconds while regeneration is on. Residual risk: that wait, and it no longer rests on the unchecked claim that a free cast keeps regeneration going. Serves: "Every cast starts it" (Remco, 2026-11-16) (Remco, 2026-11-16)

## Not in this story

- The 2-second mana tick after the rule ends, which the standalone FiveSecondRule addon also shows: a story of its own
  if wanted.
- The five-second rule of other members: their casts are not yours to time, and only your own regeneration is shown.
- Effects that let mana come back while casting (Innervate, the Meditation talent, Mage Armor): the bar shows the 5
  seconds whatever those let through.
- Energy ticks for rogues and druids in Cat Form.
- A bar of its own that you can move away from the frames, a sound, or a flash when regeneration returns.
- Keeping a countdown across a reload: the seconds left at a reload are lost (S33).

## Estimate

**8 points.** Basis: the Developer's recount and the Architect's, agreed. 5 addon files, about 12 sites and 130 to
190 source lines: UnitButton.lua 6 (the bar in CreateVisuals, ApplyStyle, the countdown and its update, UpdateAll,
the check whether a frame shows you, the dead path), Core.lua 2 (a DEFAULTS row, listening to your casts),
Options.lua 1 (LAYOUT_SETTINGS), Locales/enUS.lua 1 string, Preview.lua 2 (one fake healer, and pets cleared). One
contract changes: a unit button now hears your own casts. spec/support.lua needs 3 additions (a clock, a mana cost
with a hidden-cost mode, a timer that runs its callback). Tests: a new spec/fivesecond_test.lua in spec/run.lua's
list with about 18 to 22 functions and 300 to 380 lines, spec/targetfocus_test.lua about 4 functions and 80 to 110
lines, spec/options_test.lua 1, spec/preview_test.lua 1 or 2 with 40 to 60 lines; the first 36 rows collapse to about
26 functions. Docs: docs/features.md, docs/architecture.md, docs/saved-variables.md. The four rows added after the
recount (S37 to S40) are states the Developer named as missing; the Architect counts them as about 4 more test
functions, still within 8 points. Dropping the option and test mode would bring it back to 5, but the repository's
rules ask both of a new setting.

## Notes for gate 2

- Which events and calls tell that a cast of yours went off and spent mana, and when a channel starts; the research in
  the backlog item: your own casts are not secret in 12.0, also in combat, and C_Spell.GetSpellPowerCost has no secret
  predicate on its wiki page. Neither is checked in game.
- How to draw and drain the bar on a 4-pixel strip so it stays readable on both frame styles, and how a test advances
  the drain: the fake API has no clock to move today (the Developer's count).
- Your raid frame where the game hides whether it is you (S18, S38): today's check whether a frame shows you reads a
  hidden answer as "not you", so as it stands your raid frame would show no bar there. The target borders already hand
  such a hidden answer to the game; whether that works for this bar is not checked in game. If no way places the bar
  there, AC3 cannot be met there: an AC change, decided before the build goes on.
- The option turned off in combat (S39): the Layout page stores a setting at once but redraws the frames only after
  combat, and docs/features.md says changes made in combat are applied when combat ends; the bar must go at once, and
  that sentence then needs its exception.
- A druid in a form (S12, S13, S37): the countdown runs while no bar shows, and must show the time left when the strip
  shows mana again.
- The target and focus frames keep their unit while the person behind it changes: any countdown kept per frame must be
  dropped when that person changes (S31), and on a roster change (S30).
- Test mode: which fake healer shows the bar (fake member 2 is the low-mana priest and the target preview's member),
  and whether its bar stands still or drains over and over.

## How

- One countdown for the whole addon, `castAt` (the GetTime of the last cast that spent mana) and one 0.1 s ticker; no
  state per button, because every frame draws the same time left: two frames that show you (S19, S20, S40) agree for
  free, and a frame that stops showing you (S30, S31) has nothing to drop (architect and developer, 2026-11-16).
- The bar's value comes from the clock, never from subtracting a step per tick, and it hides at the moment the 5
  seconds are over: a jump in time shows the right time left in one update (S28, S34, S37, S30, S31), the tick that
  ends a countdown (5 s passed, the option off, your death) hides every bar before the early return a nil `castAt`
  takes, and a button without a unit gets its bar hidden on that tick (architect and developer, 2026-11-16).
- `UnitButton.UpdateFiveSecond()` is the one update and is exported for the tests, as `UpdateLowMana` is; it is also
  called from `UpdateAll`, so a target switching away from you or a roster change is right at once, not up to a tick
  later (S30, S31), and the tests call it at chosen fake times instead of running the ticker (architect and developer,
  2026-11-16).
- A unit button hears `UNIT_SPELLCAST_SUCCEEDED` and `UNIT_SPELLCAST_CHANNEL_START` for "player" from Core's event
  frame, each guarded by `C_EventUtils.IsEventValid` and a `self.db` check; that Forever fires them, and with a
  readable castGUID and spellID, is not checked in game. A failed or interrupted cast meets S5 by sending neither
  event, which is not checked in game either (architect and developer, 2026-11-16).
- A castGUID is compared only while the game gives it readable, so a hidden one may restart the bar at the same
  moment and does no harm, and a hidden spellID starts the bar without asking for its cost; the client marks both
  values `SecretWhenUnitSpellCastRestricted` in Blizzard's generated API docs, whatever the wiki says about your own
  casts (both not checked in game). The cost lookup runs in a `pcall`, and an error starts the bar (architect and
  developer, 2026-11-16).
- `C_Spell.GetSpellPowerCost` returning nil means the spell has no resource cost, so no bar (S6, S13); only a
  missing function, a value the game hides, or an error counts as a cost NeoHeal could not read, and that starts the
  bar (S8). A MANA entry counts only when `requiredAuraID` is 0 or `hasRequiredAura` is true, so an ability that lists
  a mana cost for another form never starts it (S13); a hidden field of the entry counts as mana (architect and
  developer, 2026-11-16).
- The bar is a StatusBar named `frame.fiveSecond`, a child of `frame.power`: 2 pixels high on the top edge of the
  strip and as wide as it, so the strip's own hide covers "Resource bar Off" (S25), and it takes its texture and
  colour on `ApplyStyle`'s list, like every other bar (architect and developer, 2026-11-16).
- Whether the frame shows you reuses `ShowIfSameUnit`, the rule the target borders already use: a readable answer
  shows the bar on the frame that is you (S19, S20, S21, S40), a hidden one goes to the bar's `SetAlphaFromBoolean`,
  and a client without that method keeps the bar hidden (S18, S38). Should the client refuse it there, AC3 cannot be
  met on such a map and that comes to Remco, as open point 1's residual risk says (architect and developer,
  2026-11-16).
- A frame shows the bar only while its strip shows mana (a readable `UnitPowerType` of MANA), which covers a warrior
  and a rogue (S11), a mage (S14), the form strips (S12, S13) and the return to caster form (S37) without a
  shapeshift case of its own (architect and developer, 2026-11-16).
- The setting `showFiveSecond` (a `DEFAULTS` row, on by default) is read by the cast handler and by the ticker rather
  than wired into `SetLayoutSetting`, which is every Layout key's setter: turning it off clears `castAt` and hides the
  bar within 0.1 s, in and out of combat (S27, S39), "at once" to the eye, and turning it on shows the bar from the
  next spell; docs/features.md gets that exception to "changes made in combat are applied when combat ends"
  (architect and developer, 2026-11-16).
- Death clears `castAt` when the ticker sees `UnitIsDeadOrGhost("player")` (through `IsTrue`), so a resurrection
  within the 5 seconds does not bring the bar back (S32); a reload or login starts with none (S33); a loading screen
  keeps the clock honest because the value is recomputed from it, which is not checked in game (S34) (architect and
  developer, 2026-11-16).
- Test mode: `Preview.Decorate` draws a still bar at 0.6 on fake member 2 (also the target preview's member) and only
  with the option on, and pets never show one (S35, S36); preview frames never enter `UnitButton.buttons`, so the
  ticker never touches them (architect and developer, 2026-11-16).
- `spec/support.lua` gains a fake clock, a ticker that keeps its callback, and `GetSpellPowerCost` with nil and
  hidden-cost modes: the TestWriter's work, driven by the tests that call the update at chosen times (architect and
  developer, 2026-11-16).

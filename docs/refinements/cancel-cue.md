# Refinement: Show when the heal you are casting is no longer needed (cancel cue)

## User value

As a healer, I want my frame to tell me when the heal I am casting is no longer needed, so that I can cancel it and
save the mana (and keep the five-second rule from restarting).

When this is done, a healer who starts a heal by clicking a NeoHeal frame sees on that frame, for as long as the cast
runs, whether the member still needs it, and the moment the member is back above the line, from the release that
carries this story.

Classic-era healers pre-cast slow heals (2.5 to 3 seconds) and cancel them by eye when someone else's heal or a HoT
got there first. Today NeoHeal shows the member's health and nothing about your own cast, so the healer has to watch
the health bar and their cast bar at once and judge the gap. The cue matters most on slow heals; on a 1.5-second Flash
Heal there is little time to act on it.

## Delivers value alone

yes: the cue shows on the frame you heal with the next release; nothing else has to land first.
Waits on: none

## Acceptance criteria

| AC | Criterion | Scenarios | Proving test |
| --- | --- | --- | --- |
| AC1 | While a heal you started by clicking a NeoHeal frame is casting, that frame shows it; the moment the member is above 90% health the frame shows the heal is no longer needed, and when their health drops below that again it shows the heal is needed again. This holds in and out of combat, reads the same whatever colours and style the frames use, and cannot be mistaken for the borders, the aggro line or the dispel strip a frame already shows. | S1, S3, S4, S5, S6, S13, S41, S42, S51 | `spec/castcue_test.lua` "testTheCueTurnsFullAboveTheLine" and "testTheCueTurnsBackBelowTheLine" |
| AC2 | The cue is gone the moment the cast ends, however it ends: finished, cancelled by you, interrupted, failed, or later than planned after pushback. Cancelling on the cue spends no mana and starts no five-second bar. A dead or offline member never shows the heal as no longer needed. | S2, S7, S8, S9, S10, S11, S12, S44, S47, S52 | `spec/castcue_test.lua` "testTheCueEndsWithTheCast" and `spec/fivesecond_test.lua` "testACancelledCastStartsNoBar" |
| AC3 | The cue shows on whichever NeoHeal frame you cast on: your own, a party or raid member's, the main tank group, a pet's, the target frame and the focus frame, in combat too. It never shows on a frame that has come to show someone else, or no one, during the cast. | S14, S15, S16, S17, S18, S19, S20, S21, S22, S23, S48, S49 | `spec/castcue_test.lua` "testTheCueShowsOnEveryKindOfFrame" and `spec/targetfocus_test.lua` "testTheCueLeavesTheTargetFrameOnATargetSwitch" |
| AC4 | Every way of casting a heal on the clicked member from a NeoHeal frame shows the cue: every mouse button, modifier and hover key, and "Cast and also target". A heal sent to the member's target, a res, a group heal, an instant, a channel, a click that casts nothing and a cast from outside NeoHeal show none, with one known limit: a click that casts nothing, followed within half a second by the same spell cast from outside NeoHeal (any spell when the game hides that cast's details), shows the cue on the clicked frame until that cast ends. A heal started while you channel shows it too. A second click while you cast leaves the cue on the first frame; a click the game queues moves it when that cast starts. | S24, S25, S26, S27, S28, S29, S30, S31, S32, S33, S34, S43, S45, S46 | `spec/castcue_test.lua` "testOnlyACastOnTheClickedMemberShowsTheCue" and "testASecondClickLeavesTheCueOnTheFirstFrame" |
| AC5 | An option on the Layout page turns the cue on and off. Off, no frame shows it, and turning it off hides a running cue at once, also in combat. | S35, S36, S37 | `spec/castcue_test.lua` "testTheOptionTurnsTheCueOff" and `spec/options_test.lua` "testTheCancelCueOptionIsOnTheLayoutPage" |
| AC6 | The cue never outlasts your cast and never shows for a cast it did not see start: also when the game hides the details of your cast, and after a reload or a login. | S38, S39 | `spec/castcue_test.lua` "testTheCueEndsWhenTheGameHidesTheCast" and "testNoCueAfterAReload" |
| AC7 | In test mode with the option on, one fake frame shows a heal still needed and another a heal no longer needed; the fake target and focus frames show none; with the option off, no fake frame shows the cue. | S40, S50 | `spec/preview_test.lua` "testTheCancelCueOnTwoFakeFrames" |

## Dimensions

| Dimension | Values | Rows |
| --- | --- | --- |
| How the cast starts | an unmodified left click on a heal bound to the member; a modifier or another mouse button; a hover key; "Cast and also target"; a click on a dead member that becomes your res; a heal bound to the member's target or target's target; a click that starts no cast; a Target or Menu or missing-buff click; a cast started outside NeoHeal; a heal started while you channel | S1; S26; S27; S28; S33; S29; S31; S31; S32; S45 |
| The spell | a heal on one member with a cast time; a group heal with a cast time; a res; an instant; a channel | S1; S34; S33; S30; S43 |
| The member's health | below the line throughout; rises above the line during the cast; above the line at the start; falls below the line during the cast; exactly at the line; dies during the cast; goes offline during the cast; dead and brought back during your res | S1; S3; S4; S5; S6; S11; S12; S47 |
| How the cast ends | it finishes; it finishes and the game reports only that the spell went off; you cancel it; it is interrupted or you die; it fails at its end; it is pushed back first; a second click during it is refused; a second click near its end is queued; the queued cast's start is reported before this cast's end | S2; S44; S7; S8; S9; S10; S24; S25; S46 |
| The frame cast on | your own frame; a party member's frame; a raid member's frame; a main tank group frame; a pet's frame; the target frame; the focus frame | S15; S1; S14; S16; S17; S18, S20; S19 |
| The frame during the cast | keeps showing the member; the target or focus switches; the target or focus switches away and back; a roster change gives it another member; it is left with no member; it hides | S1; S21; S48; S22; S49; S23 |
| Combat | out of combat; in combat | S1; S13, S14, S16, S17, S19, S20, S36 |
| The cue option | on; off; turned off during a cast; turned on during a cast | S1; S35; S36; S37 |
| What the game tells about your cast | readable; hidden | S1; S38 |
| The moment in the session | a running game; a reload or a login during a cast; a loading screen or zone change during a cast | S1; S39; S52 |
| Test mode | off; on | S1; S40, S50 |
| The frame's look | health coloured by class; health coloured green to red; the low-health tint showing; the classic style; the forever style; the white target border; the red targeted border; the aggro line; the dispel strip | S41; S41; S41; S42; S42; S51; S51; S51; S51 |

10 x 5 x 8 x 9 x 7 x 6 x 2 x 4 x 2 x 3 x 2 x 9 = 130,636,800 cells. They collapse to 52 rows because each
dimension decides one thing only. How the cast starts and the spell decide whether a cue shows at all (S26 to S34,
S43, S45); the member's health decides which of its two looks shows (S1, S3 to S6, S11, S12, S47); how the cast ends
decides when it goes (S2, S7 to S10, S24, S25, S44, S46); the frame decides only where it shows, so its rows vary
the place around one heal (S14 to S20), crossed with combat on every kind of frame whose health the game hides in
combat (S13, S14, S16, S17, S19, S20). The frame during the cast, the option, the hidden details, a reload and test mode each have a row per
value that can change what shows. The look rows (S41, S42, S51) hold one cast each, as the look decides nothing but
whether the cue can be told apart.

## States, moments and places

Unless a row says otherwise: you play a priest, alive, in a party, out of combat; the cue option is on (open point 3)
and test mode is off; you start the cast with an unmodified left click bound to a slow heal (Heal or Greater Heal)
on the clicked member. "The line" is 90% health (open point 2). "The cue" is the mark this story adds to the frame,
with a "running" look while the heal is still needed and a "full" look once it is not (open point 4). The cast events
Forever sends for your own casts are readable by Blizzard's generated API docs and its 12.0 notes (the backlog item's
research), not checked in game; health is hidden from addons in combat (docs/forever-api.md, section 2), so in
combat the cue can only compare health with the fixed line, never with the size of your heal.

| Id | State, moment or place | Operation | Expected |
| --- | --- | --- | --- |
| S1 | A party member at 50% health | you left-click their frame and the cast starts | From the start of the cast that member's frame shows the cue in its "running" look; no other frame shows it. |
| S2 | The cast of S1 | the cast finishes and the heal lands | The cue is gone when the cast ends; the five-second bar starts as it does today. |
| S3 | The member's health rises above the line during the cast (another healer's heal, a HoT) | health changes | The cue turns to its "full" look at once: your heal is no longer needed and you can cancel it. |
| S4 | The member is above the line when you start (pre-casting on a tank before the damage comes) | the cast starts | The cue shows its "full" look from the start. |
| S5 | The member is above the line, then drops below it during the cast (the damage lands) | health changes | The cue turns back to its "running" look at once. |
| S6 | The member's health is exactly 90% | the cast starts, or health changes to exactly 90% | The cue shows its "running" look: "full" means above the line. |
| S7 | The cue shows "full" | you cancel the cast (you move, jump or press Escape) | The cue is gone at once; the cancelled cast spent no mana and starts no five-second bar. |
| S8 | A cast running | it is interrupted (a kick, a stun, a silence) or you die | The cue is gone at once. |
| S9 | A cast running | it fails at its end (the member out of range or out of sight by then) | The cue is gone at once. |
| S10 | A cast running | damage pushes it back, so it runs longer | The cue stays until the cast really ends and keeps following the member's health meanwhile. |
| S11 | The member dies during the cast | death | The frame shows "Dead"; the cue never shows "full" on it and is gone when the cast ends. |
| S12 | The member goes offline during the cast | disconnect | The frame shows "Offline"; as S11. |
| S13 | In combat, where the game hides health from addons | the member's health crosses the line up and then down during the cast | As S3 and then S5: "full" above the line, "running" below it. |
| S14 | A raid member's frame in a raid, in combat | you cast on it | As S1, S3 and S5 on that raid frame. |
| S15 | Your own frame (you heal yourself), in and out of combat | you cast on it | As S1, S3 and S5 on your own frame. |
| S16 | A main tank's frame in the main tank group, who also has a frame in their own group, in combat | you cast on the main tank group frame | As S1, S3 and S5 on the frame you clicked only; their frame in their own group shows no cue. |
| S17 | A pet's frame, in combat | you cast on it | As S1, S3 and S5 on the pet's frame. |
| S18 | The target frame showing a friendly player outside your group | you cast on it | As S1, S3 and S5 on the target frame. |
| S19 | The focus frame, in combat | you cast on it | As S1, S3 and S5 on the focus frame. |
| S20 | The target frame, in combat | you cast on it | As S13 on the target frame. |
| S21 | You cast from the target frame (or the focus frame) | you switch your target (or focus) during the cast | The cue leaves that frame at once, as it now shows someone your heal is not going to; the new target never shows the old cast's cue. The heal still lands on the member you clicked. |
| S22 | A roster change during the cast gives the frame you clicked to another member, or moves your member to another frame | group change | No frame shows the cue for someone your heal is not going to; the cue does not move to the member's new frame. |
| S23 | The frame you cast on | it hides during the cast (the member leaves the group, your target clears) | The cue is gone; a frame shown again later shows no cue until a new cast starts on it. |
| S24 | A cast running on one member | you click another member's frame and the game refuses that cast ("another action is in progress") | The cue stays on the first frame; the second frame shows none. |
| S25 | A cast running on one member | near its end you click another member's frame and the game queues that cast (the client's spell queue; not checked in game on Forever) | The cue leaves the first frame when its cast ends and shows on the second frame when the queued cast starts. |
| S26 | A heal bound to a modifier and click, or to another mouse button (Shift + right click) | you cast with it | As S1. |
| S27 | A heal bound to a hover key | you press it over the frame | As S1. |
| S28 | A heal bound with "Cast and also target" | you cast with it | As S1 on the frame you clicked. |
| S29 | A heal bound to cast on the member's target or their target's target | you cast with it | No cue on any frame: the heal goes to someone other than the member you clicked. |
| S30 | An instant spell (Renew, Power Word: Shield) | you cast it | No cue: there is no cast to cancel. |
| S31 | A click that starts no cast (out of range, moving, not enough mana, the global cooldown, or a Target, Menu or missing-buff click) | you click, then start a cast elsewhere (an action bar) | No cue on that frame, then or later, when the cast elsewhere is another spell or starts more than half a second after the click. Known limit: the same spell started elsewhere within half a second (any spell when the game hides that cast's details) shows the cue on that frame until that cast ends. |
| S32 | A cast started outside NeoHeal (an action bar button, a macro, a mouseover macro over a NeoHeal frame) | you cast | No cue on any frame ("Not in this story"). |
| S33 | A dead member, whose click NeoHeal turns into your res | you click their frame | No cue on any frame: a res is no heal on a living member. |
| S34 | A group heal with a cast time started on a member (Prayer of Healing, Chain Heal) | you cast it | No cue on any frame: the clicked member being full says nothing about the others the heal reaches. |
| S35 | The cue option is off | you cast | No cue on any frame. |
| S36 | A cast running, in combat | you turn the option off | The cue is gone at once. |
| S37 | A cast running with the option off | you turn the option on | No cue for that cast; the next cast shows it. |
| S38 | The game hides the details of your cast (a spell Blizzard flags as always hidden; its docs say your own casts are readable, not checked in game) | the cast starts, health changes, the cast ends | The cue shows while the cast runs, follows the health as in S3 and S5, and is gone when the cast ends. |
| S39 | A cast running | a reload or a login | No cue until a new cast starts from a frame. |
| S40 | Test mode | you open it with the option on, then with it off | On: one fake frame shows the cue "running" and another shows it "full"; off: no fake frame shows it. |
| S41 | Health coloured by class, health coloured green to red, and the low-health tint showing | you cast | In each, the cue's two looks can be told apart from the bar's colour, from the tint and from each other. |
| S42 | The classic and the forever frame style | you cast | As S41 in both styles. |
| S43 | A channel started from a frame (a warlock's Health Funnel on the pet's frame) | you cast it | No cue ("Not in this story"). |
| S44 | A cast running | it finishes, and the game reports only that the spell went off, or hides the report of its end | The cue is gone when the cast ends, whichever of the two the game reports. |
| S45 | You are channelling (Mind Flay) | you start a heal from a frame, which ends the channel | The cue shows on that frame as in S1; the channel's end, reported before or after the heal's start, leaves it there. |
| S46 | A queued cast as in S25 | the game reports the queued cast's start before the first cast's end | As S25: the cue shows on the second frame and stays there; the first cast's end does not take it away. Which order Forever uses is not documented and not checked in game. |
| S47 | You res a dead member and someone else brings them back during your res | they are alive again | No cue, as in S33, also once they are alive again. |
| S48 | You cast from the target frame | you switch your target away and back to the member during the same cast | The cue leaves the target frame at the first switch (S21) and does not come back for that cast; the next cast shows it. |
| S49 | The member you cast on leaves the group during the cast | the frame you clicked is left with no member | No frame shows the cue; a frame given a member later shows none until a new cast starts on it. |
| S50 | Test mode with the option on, the target and focus frames on | you open it | The fake target and focus frames show no cue; only the two fake group frames of S40 do. |
| S51 | The frame also shows the white target border, the red targeted border, the red aggro line or the dispel strip | you cast | The cue's two looks can be told apart from each of these. |
| S52 | A cast running | a loading screen or a zone change (a portal, entering an instance) | The cue is gone after the loading screen, and no cue shows until a new cast starts from a frame. |

## Conflicts and unclear points

- [x] Which casts show the cue (S29 to S34). Answer: only a heal on one member with a cast time, started on the clicked member by a NeoHeal click or hover key; a res (S33) and a group heal (S34) show no cue. A res on a dead member has no "full" to show, and a group heal's "full" on the clicked member says nothing about the others it heals, so either would mislead. Strongest case against: a Shaman's Chain Heal starts on the clicked member and gets no cue. Residual risk: healers who want it on group heals ask for it later. Serves: "simple but effective. not as complicated as Healbot" (Remco, 2026-11-15) (product owner, 2026-11-17)
- [x] What "no longer needed" means. Answer: (a) fixed, above 90% health; other healers' incoming heals do not count. Strongest case against: 90% may be too early on a tank taking big hits. Residual risk: a slider can follow if healers ask; one fixed line keeps the option list short. Serves: "simple but effective. not as complicated as Healbot" (Remco, 2026-11-15) (product owner, 2026-11-17)
- [x] The cue option on or off by default. Answer: (a) on, as the five-second bar. Strongest case against: every user's frames change after the update without being asked. Residual risk: accepted, because the cue only shows while you cast a heal from a NeoHeal frame, and its look is tried in game by Remco before the build. Serves: the end state, "everything a healer needs to see and to cast on" (product owner, 2026-11-17)
- [x] What the healer sees while the cast runs and is still needed. Answer: (a) a "running" mark on the frame you cast on that turns to a "full" look above the line: the healer sees which frame the cast is on and that the cue is working. The place and colours are a look choice, tried on the installed copy and kept by Remco before the build. Strongest case against: (b) is quieter. Residual risk: one more element on a busy frame, judged in game. Serves: NeoHeal look choices are tried on the installed copy before anything is built (Remco's way of working since 0.7.1) (product owner, 2026-11-17)
- [x] A member shown on two frames (S16, S22). Answer: (a) only the frame you clicked: that is where your eyes are when you click. Strongest case against: a cast from the target frame on the tank does not show on the tank's raid frame. Residual risk: accepted; (b) rests on hidden comparisons and doubles the rows. Serves: own judgement (product owner, 2026-11-17)
- [x] The backlog item's first step, an in-game probe before the build. Answer: (a) drop it as a gate; the two /dump lines become in-game checks of the release. Blizzard's generated docs on the forever branch say your own cast events stay readable, and a hidden detail hides only the details (S38). Strongest case against: a heal flagged "always secret" would hide its details too. Residual risk: covered by S38 and the release check. Serves: own judgement (product owner, 2026-11-17)
- [x] A false cue after a click that casts nothing (AC4, S31; found at gate 2): a NeoHeal click the game refuses, followed within half a second by the same spell cast from outside NeoHeal on another member (any spell when the game hides that cast's details), ties that cast to the clicked frame; no event tells an addon that a click cast nothing. Answer: On Remco's delegation (2026-11-17): accept it as a known limit stated in AC4 and S31, and build no rule that drops clicks: such a rule rests on an event order that is not documented and not checked in game. Strongest case against: a false "full" costs more than a missing cue, and this knowingly ships the costlier error. Residual risk: in that rare case a reflex cancel loses a heal the other member needed. Serves: "simple but effective. not as complicated as Healbot" and, in autonomous mode, "in doubt, do not do it" (deciding architect, 2026-11-17)

## Not in this story

- A cue for casts started outside NeoHeal's frames (action bars, macros, mouseover macros; S32): by Blizzard's generated docs the cast events carry only the caster, the cast and the spell, never whom the cast is on, so only NeoHeal's own click knows the member. A later story, if healers ask for it.
- Whether your heal will overheal (its size against the health missing): health is hidden in combat, so the cue compares health with a fixed line only.
- Other healers' incoming heals counted toward the line.
- NeoHeal cancelling the cast for you: the healer cancels by moving, Escape or their own stop-casting key.
- Channels (S43): the cue covers spells with a cast time. A later story, if a channel on one member matters to a healer.

## Estimate

**8 points**, the top of the band. Basis: the Developer's count from the code, which the Architect agrees with (the
Architect's first count, 12 to 15 sites, was low). 7 addon files, 20 to 22 sites, 205 to 240 source lines:
Core.lua 4 (a DEFAULTS row; a handler each for your cast's start, stop, failure and interrupt, as every registered
event needs its own; the registration list; about 25 lines), UnitButton.lua 11 (the 90% line and its colour curve,
the cue in CreateVisuals, its style, the readable path out of combat and the curve in combat, the calls in
UpdateHealth and UpdateAll, attaching at a cast's start and clearing at its end, the click handler and its hook, the
clears on a unit taken away, in ReloadUnitButtons and on hide; 130 to 150 lines), ClickCast.lua 1 (whether a click
lands a spell on the clicked member: prefix, suffix, hover keys, the res swap, "Cast and also target"; 30 to 35
lines), Options.lua 1, Locales/enUS.lua 1, Preview.lua 2 or 3, spec/run.lua 1. Two contracts change: the five-second
bar's rule that the cast start, fail and interrupt events are never registered (spec/fivesecond_test.lua
"testBothCastEventsAreRegistered", rewritten so those events start no bar), and a unit button's clicks now say which
frame a cast is on. Tests: 29 to 38 functions, 600 to 800 lines: a new spec/castcue_test.lua (the 51 rows collapse
to about 24 to 30 functions, 450 to 600 lines), spec/support.lua 80 to 120 lines (cast events with readable and
hidden details, a click helper, health per unit), spec/targetfocus_test.lua 2 or 3, spec/options_test.lua 1,
spec/preview_test.lua 1, spec/fivesecond_test.lua 1 rewritten and 2 new beside it ("testACancelledCastStartsNoBar",
"testOnByDefaultForTheCue"). Docs: docs/features.md, docs/architecture.md, docs/saved-variables.md,
docs/forever-api.md (the cast events), docs/extending.md (the test list). The five-second story, the nearest one, was
8 points and came to about 210 source and 810 test lines. Risk to the estimate: tying a cast to the clicked frame is
the one part whose feasibility is open (see "Notes for gate 2"); if gate 2 finds it needs secure plumbing, the story
is past 8, and the one value cut the Developer sees is the option and its test-mode rows (AC5, about 2 points).

## Notes for gate 2

- Tying a cast to the frame: the cast events carry no target (Blizzard's generated UnitDocumentation.lua, forever
  branch: unitTarget, castGUID, spellID, castBarID). A click hook on the frame sees the mouse button; the modifiers,
  the binding and the res snippet's swap on a dead member decide whether that click cast a spell on the clicked
  member. The docs mark the cast events SynchronousEvent; whether UNIT_SPELLCAST_START arrives inside the click or
  after it is not documented, nor checked in game, so the click is recorded in PreClick, before the cast can start
  (see "How"). UNIT_SPELLCAST_SENT carries a `target` name (ConditionalSecret), a possible cross-check. The pair
  decides how a refused second click (S24), a queued one (S25, S46) and a click that starts nothing (S31) stay apart
  from the cast that does start.
- A "Cast and also target" binding is a macro with no spell attribute, so the clicked spell is read from the binding
  itself, not from the button's attributes, and matched with the cast's spell by name (see "How") (S24, S25, S28,
  S31).
- Hover keys arrive as the virtual buttons neokey1 to neokey3; whether PreClick runs for such a click is not checked
  in game, so S27 may need another route.
- A cast's end may come as STOP, SUCCEEDED, FAILED or INTERRUPTED, and a channel's start or end (already registered
  for the five-second bar) may arrive around a heal's start (S44, S45).
- Matching a start to its end by castGUID while it is readable; with hidden details (S38) only one cast of yours runs
  at a time.
- The line as a colour curve on UnitHealthPercent, like the low-health tint at 35%; the dead and offline path as in
  UpdateLowHealth.
- The target and focus frames keep their unit token while the person behind it changes: whatever the cue keeps per
  button is also cleared in UnitButton:ReloadUnitButtons (S21).
- UNIT_SPELLCAST_DELAYED matters only if the look shows the cast's progress (open point 4, option c).
- Registering the cast start, fail and interrupt events must not reach the five-second bar's OnPlayerCast (S2, S7).

## How

- A click record on the button's `PreClick` hook, not `PostClick`: the click being made is always the newest record
  when a cast's `UNIT_SPELLCAST_START` arrives, whichever side of `OnClick` the client runs it on, so a refused click
  followed by another member's click cannot leave the cue on the first frame (S24, S25, S31). It is a real Lua hook
  on a plain script, so it touches no secure attribute (architect and developer, 2026-11-17).
- The spell a click casts comes from `ClickCast.appliedBindings`, the source the tooltip and `GetLeftClickSpell`
  already read, through `GetSpellValue`, never from the button's `spell` attribute: a "Cast and also target"
  binding is a `macro` attribute with no spellID in it (S28) (architect and developer, 2026-11-17).
- A cast's start is tied to a click by a 0.5 s window, one constant: a click at the very start of the client's
  400 ms spell-queue window starts its cast about 400 ms plus a frame later. The window itself is not checked in
  game (S25, S46) (architect and developer, 2026-11-17).
- Spells are matched by name on both sides through `C_Spell.GetSpellName`: a binding's ID and the event's ID can
  differ by rank or by an override after `SPELLS_CHANGED` (not checked in game), and a name match still rejects a
  different spell (S24, S25) (architect and developer, 2026-11-17).
- A click is recorded only for a spell binding cast on the clicked member itself ("Cast on: unit"), on a living,
  connected unit, and for a spell whose name is not a group heal's: a binding sent to the member's target goes to
  someone other than the member, the record is taken before the click so the res swap on a dead member is not in
  it, and a res's name never equals the binding's heal name (S29, S33, S47, S12) (architect and developer,
  2026-11-17).
- Group heals are denied by spell ID per class, turned into names at run time with `C_Spell.GetSpellName`, as
  `HOT_SPELLS`/`GetHotNames` (Hots.lua) and `CanTakeShield` (UnitButton.lua) already do: it covers every client
  language and every rank, where a table of English names would rest on wording no test here can foresee (S34)
  (architect and developer, 2026-11-17).
- The cue hears `UNIT_SPELLCAST_STOP`, `FAILED`, `INTERRUPTED` and `SUCCEEDED` for "player" and never the channel
  events: a cast whose end is reported only as its success still clears the cue (S44), and a channel that starts or
  ends around a heal never reaches it, so no ordering rule between the two is needed (S43, S45) (architect and
  developer, 2026-11-17).
- The per-button state is the cast's castGUID: an end event clears the button whose GUID matches, and every button
  when the game hides the GUID, as with hidden details only one cast of yours runs at a time (S38, S46). The
  five-second bar's `OnPlayerCast` keeps receiving exactly the two events it registers today (S2, S7) (architect and
  developer, 2026-11-17).
- Clears: `SetUnit` for any unit change, nil included, which covers `ReloadUnitButtons` (S21, S48, S49); an `OnHide`
  behind the one-frame `IsVisible` check that hook already uses, so a `Layout:Refresh` that hides and re-shows the
  frames keeps a running cue (S23); `UpdateAllButtons` when a roster change leaves the token and its `UnitGUID`
  differs or is hidden (S22); the option's own setter, at once and also in combat (S36, S37); and
  `PLAYER_ENTERING_WORLD`, guarded by `C_EventUtils.IsEventValid` as every Core event is, which covers a login, a
  reload and a loading screen (S39, and the loading-screen row asked of main) (architect and developer, 2026-11-17).
- Death and offline hide the cue the way the low-health tint is hidden: `UpdateHealth` shows "Dead"/"Offline" and
  clears the cue, so it never shows "full" on such a member (S11, S12, S47) (architect and developer, 2026-11-17).
- One texture with one step colour curve, the low-health tint's pattern: running below the line and full from
  0.901, so exactly 90% stays "running" (S6), and in combat the game applies the curve without the addon comparing
  health (S13, S14, S16, S17, S19, S20) (architect and developer, 2026-11-17).
- The cue texture is a child of `overlay` (a frame child of `health` at its level + 3), not of `health`: the
  incoming-heal, prediction and shield bars are children of `health` at + 1 and would draw over it, while at +3 it
  sits above them and above the hover highlight. `health:SetClipsChildren(true)` still clips it, because `overlay`
  is `health`'s child, so the cue never draws past the end of the bar (architect and developer, 2026-11-17).
- The look Remco kept is candidate A (a 3 px band on the health bar's bottom edge), running gold (1, 0.7, 0, 0.8)
  like Blizzard's own cast bar and full red (1, 0, 0, 1): the colour of an action indicator follows its meaning, and
  red is what Blizzard's cast bar shows for an interrupted or failed cast (CastingBarFrame.lua on the forever
  branch: yellow while casting, green when finished, red when interrupted or failed). Candidate B, a 4 px strip on
  the right edge, was not taken. A band along the bottom keeps clear of the aggro line at the top, the dispel strip
  on the left and the five-second bar inside the resource strip; the red is told apart from the white target border,
  the red targeted border and the red aggro line in the game (S41, S42, S51) (Remco, 2026-11-17).
- The look was tried as two patched copies, `UnitButton.lua` and `Preview.lua`, in the story's scratch `look/`
  folder, copied to the installed addon by main as earlier look choices were; only the look Remco keeps is built,
  tested and reviewed (open point 4) (architect and developer, 2026-11-17).
- Test mode: `Preview.Decorate` picks the fake cue members by number, as it picks the targeted border
  (member == 3): "full" on member 3 and "running" on member 5, which keeps members 1 and 2 (the focus and target
  previews) and the main tanks out, so no cue shows on a target or focus preview and none shows twice (S40, S50).
  Member 3's fake health goes above the line (its formula puts it at 61% today), so its "full" cue agrees with its
  bar; the preview passes that fraction through the same step curve the real frames use, so the two can never
  disagree. `Decorate`'s contract does not change (architect and developer, 2026-11-17).
- The tests cover the product of how the cast starts, the spell and how the cast ends, 450 cells, in one
  table-driven test whose expected value per cell comes from the ACs, not from a copy of the code's rule; the
  per-row tests stay beside it (product owner's note 1, architect and developer, 2026-11-17).
- Known limit, accepted: a NeoHeal click that casts nothing, followed within half a second by the same spell cast
  from outside NeoHeal on another member (any spell when the game hides that cast's details), shows the cue on the
  clicked frame until that cast ends, worst of all a false "full" on a member above 90%. No rule that drops clicks
  is built: one that drops a click at its PostClick would also drop a queued click, which has started nothing by
  then, and it would rest on whether a cast's start arrives before or after PostClick, which is not documented and
  not checked in game (S25, S31, S38, S46) (deciding architect on the product owner's delegation, 2026-11-17).
- Two rows rest on behaviour not checked in game, the client's spell queue (S25) and whether a virtual-button click
  reaches the PreClick hook (S27): both become in-game checks of the release rather than a gate on the build
  (architect and developer, 2026-11-17).

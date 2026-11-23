# Refinement: #21 A group heal on the left click shows its prediction on raid members it never reaches

## User value

As a healer, I want the green heal bars of a group heal on my left click to show only on the frames of the members
it reaches, so that I never count on a heal that will not land there.

When this is done, whoever hovers a frame with Prayer of Healing on the left click sees its green bars only on the
frames of the members it heals (themselves, their party, in a raid their own group), from the release that carries
this fix.

The user story is the issue's. Prayer of Healing is a group heal you cast around yourself: whichever frame you click,
it heals your party, in a raid your own group, and the member behind the clicked frame only when that member is one
of them (as far as known; not checked in game). Today the heal prediction asks one question of a heal, since #20:
whether it only goes on you. Prayer of Healing does not, so its green bars show on every frame hovered, also on a
raid member outside your group, whom it never heals. Read in the code, not seen in game; #20 pinned this as today in
its AC3 until this bug. That Prayer of Healing's description matches NeoHeal's heal patterns is not checked in game.
The issue also names the heal's reach: around you (30 yards as far as known, not checked in game), not around the
hovered frame, so a fix by group alone still shows bars on a member of your group out of reach (open point 1).

## Delivers value alone

yes: every healer with Prayer of Healing on the left click gets the fix with the next release; nothing else has to
land first.
Waits on: none

## Acceptance criteria

| AC | Criterion | Scenarios | Proving test |
| --- | --- | --- | --- |
| AC1 | Prayer of Healing on the left click shows its green bars only on the frames of the members it heals: your own frame, a party member's frame in a party, in a raid your own raid frame and the frames of the members of your own group (among the main tanks too), and the target or focus frame while it shows one of them; in and out of combat. A raid member outside your group, a pet, or the target or focus frame on someone outside your group shows none. Where the game hides whether a frame shows a member of your group, it shows none; where it hides only whether a frame shows you but gives the raid's group numbers, the frame follows them, so your own raid frame and a target or focus frame on you show the bars; your own frame and a party member's frame in a party keep them. | S1, S2, S3, S4, S5, S6, S7, S8, S9 | `spec/prediction_test.lua` "a group heal around you shows only on the frames of your group", "a group heal around you shows nothing on a pet", "a group heal around you shows nothing where the game hides your group" and "a group heal around you shows only on the frames of your group in combat" |
| AC2 | This holds when you start hovering, when you press or release Shift, Ctrl or Alt, when the target or focus changes under the mouse, when the group puts another member behind a raid frame under the mouse, and when the member behind it, or you, move to another group. | S10, S11, S12, S13 | `spec/prediction_test.lua` "a group heal on a modifier follows the modifier and the frame", "the group heal follows the target or focus under the mouse", "the group heal follows a roster change under the mouse" and "the group heal follows a move to another group under the mouse" |
| AC3 | A member of your group out of the heal's reach shows its green bars as any other member of your group does; the frame's range fade is the only sign that the heal may not land there (open point 1, option a). | S14 | `spec/prediction_test.lua` "a group heal shows on a member of your group out of its reach" |
| AC5 | Every other left click shows as #20 left it: Chain Heal, which lands on the member you click, and every other heal on any friendly unit on every frame; a heal that only goes on you only on a frame that shows you; shields by #12's rules; nothing for a left click that heals nothing NeoHeal can read. A heal NeoHeal can't tell from a group heal shows only on a frame that shows you, until the game gives the name it was missing. | S16, S17, S18, S19 | `spec/prediction_test.lua` "a group heal cast on the clicked member shows on every frame", the tests there for #20's and #12's rows (exist), "a heal that can't be told from a group heal shows only on a frame that shows you" and "a group heal's name given late counts from the next hover" |

## Dimensions

| Dimension | Values | Rows |
| --- | --- | --- |
| The spell on the left click with the modifiers held now | Prayer of Healing, Chain Heal, every other left click as #20 left it (Flash Heal and Desperate Prayer and a shield and nothing predictable) | S1 to S14; S16; S17 |
| Whose frame is hovered | your own frame solo or in a party, a party member's frame in a party, your own raid frame, a raid member's frame in your group (main tanks too), a raid member's frame outside your group (main tanks too), a pet's frame or the target or focus frame on a pet, the target or focus frame on you or on a member of your group, the target or focus frame on someone outside your group (solo: anyone but you), a frame where the game hides whether it shows your group or you | S1, S9; S2, S9; S3; S3, S9; S4, S9; S5; S6; S7; S8 |
| Whether NeoHeal can tell the heal apart | it can, it can't (no name from the game for the clicked spell or for the group heal it compares it with or no class for you) | S1 to S17; S18, S19 |
| Whether the game tells who is in your group and who is you | it tells, it hides all or part of it (maps where it restricts addons) | S1 to S7, S9 to S19; S8 |
| Combat | out of combat, in combat | S1 to S8, S10 to S18; S8, S9 |
| Modifiers held | none, Shift (Ctrl and Alt alike) | S1 to S9; S10 |
| The moment the bar is drawn | the hover starts, a modifier is pressed or released, the target or focus changes to another person under the mouse, the group puts another member behind the hovered raid frame, the member behind it or you move to another group, a hover after one where the game gave no name it gives now | S1 to S9, S14 to S18; S10; S11; S12; S13; S19 |
| The distance from you to the member (open point 1) | within the heal's reach, out of it | S1 to S13; S14 |

3 x 9 x 2 x 2 x 2 x 2 x 6 x 2 = 5184 cells. They collapse to 18 rows. Prayer of Healing is the one spell whose bars
now depend on the hovered member's group: it takes a row per frame (S1 to S8, the hidden answer in S8), one combat
row (S9), a row per moment where the answer can change (S10 to S13), and one for distance (S14). S15 left this bug
with Holy Nova (open point 2). Chain Heal and every other left click keep #20's answer on every
frame and in every moment, one row each (S16, S17); a heal NeoHeal can't tell from a group heal takes #20's safe
side (S18), and only until the game gives the missing name (S19). Combat matters only through what the game hides then: in the forever-branch API docs the answers for
whether a unit is in your party or your subgroup carry no secret flag, the raid answer is hidden where the game
restricts a unit's identity, and whether a frame is you where it restricts comparisons (Notes for gate 2). So the
hidden state is a map's, not combat's: S8 covers it in and out of combat, S9 pins combat where the game tells. A
modifier only picks which spell is on the left click (works today: "a modifier switches to its left click"), so one
row with Prayer of Healing on Shift (S10). The "Show left-click heal prediction" option, a dead or offline member and
the spell's rank decide before any heal rule (works today): they are not dimensions of this change.

## States, moments and places

Unless a row says otherwise: out of combat, "Show left-click heal prediction" on, the hovered unit alive and
connected, the spell on the plain left click cast on the clicked unit, a map where the game tells who is in your
group and who is you, every member within the heal's reach, and the bar read when the hover starts. In these rows
Prayer of Healing heals 312 to 333 and Flash Heal 1887 to 2193 (the test fake's numbers, not the game's). That
Prayer of Healing heals your party, in a raid your own group, is as far as known, not checked in game. "Today" is
read in the code; no row is seen in game or with a probe.

| Id | State, moment or place | Operation | Expected |
| --- | --- | --- | --- |
| S1 | Prayer of Healing on the left click; your own frame, solo or in a party | the healer hovers it | The green bars show 312 to 333 (works today) |
| S2 | Prayer of Healing on the left click; in a party, a party member's frame (party1) | the healer hovers it | The green bars show 312 to 333 (works today) |
| S3 | Prayer of Healing on the left click; in a raid, your own raid frame and the frame of a raid member in your group, in the group frames or among the main tanks | the healer hovers each | The green bars show 312 to 333 on each (works today) |
| S4 | Prayer of Healing on the left click; in a raid, the frame of a raid member outside your group, in the group frames or among the main tanks | the healer hovers it | No green bars. Today: 312 to 333 (the issue). This row drags #20's test "a group heal you cast on yourself shows as today" (its AC3 and S13), which expects these bars on a raid frame |
| S5 | Prayer of Healing on the left click; a pet's frame: your pet's, a party member's pet's, a raid member's pet's; and the target or focus frame while it shows a pet, yours or anyone's | the healer hovers it | No green bars: Prayer of Healing heals party members, and a pet is none as far as known (not checked in game); if it does heal pets, a bar missing there is the safe side. Today: 312 to 333 |
| S6 | Prayer of Healing on the left click; the target or focus frame while it shows you, a party member, or a raid member in your group | the healer hovers it | The green bars show 312 to 333 (works today) |
| S7 | Prayer of Healing on the left click; the target or focus frame while it shows someone outside your group: a raid member of another group, a player not in your group, a friendly NPC, and solo anyone but you | the healer hovers it | No green bars. Today: 312 to 333 |
| S8 | Prayer of Healing on the left click; a raid, target or focus frame where the game hides whether it shows a member of your group (maps where it restricts addons), your own raid frame included; also where it gives only part of that answer (the member's group but not yours, or yours but not the member's); and where it hides only whether the frame shows you but gives the raid's group numbers; in and out of combat | the healer hovers it | No green bars where the group answer is hidden or partly given: a heal that may not land there is not shown, and a part of the answer counts as none of it; as #12 settled for a shield and #20 for a heal that only goes on you. Where the game hides only whether the frame shows you but gives the raid's group numbers, the frame follows them: your own raid frame and a target or focus frame on you show 312 to 333, a frame on a member of another group none (the stakeholder's answer at gate 2). Outside a raid there are no group numbers, so a target or focus frame on you shows none while that answer is hidden. Your own frame in solo or a party, and a party member's frame in a party, keep them: those frames show you or your party whatever the game hides. Today: 312 to 333 |
| S9 | Prayer of Healing on the left click; in combat, on a map where the game tells who is in your group | the healer hovers your own frame, party1's in a party, then in a raid the frame of a member of your group and of a member outside it | On your own frame, party1's and your group member's the green bars show 312 to 333; on the member outside your group none. Today: all show. That the game hides none of the answers this needs in combat is what its API docs say, not checked in game |
| S10 | Prayer of Healing on Shift + left click, Flash Heal on the plain left click; in a raid | the healer hovers a raid member outside your group, holds Shift, then hovers a member of your group still holding Shift, then releases Shift | On the member outside your group: Flash Heal's 1887 to 2193, then with Shift no bars at all; on the member of your group with Shift: 312 to 333; on release: Flash Heal's 1887 to 2193. Today: 312 to 333 on the member outside your group with Shift |
| S11 | Prayer of Healing on the left click; hovering the target (or focus) frame | your target changes from a member of your group to a raid member outside it and back, the mouse staying on the frame | No green bars while it shows the member outside your group; 312 to 333 while it shows the member of your group. Today: 312 to 333 throughout. That the frame redraws at the change is by the code (the target and focus frames keep their unit while the person changes); not checked in game |
| S12 | Prayer of Healing on the left click; hovering a raid frame | the group puts a raid member of another group behind that frame, the mouse staying on it, and later a member of your group again | No green bars while it shows the member of another group; 312 to 333 while it shows the member of yours. Today: 312 to 333 throughout. That the frame redraws at a roster change is by the code; not checked in game |
| S13 | Prayer of Healing on the left click; hovering the raid frame of a member of your group | that member is moved to another group (or you are), the mouse staying on the frame, and later back | The bars follow who the frame shows and that member's group: none while it shows a member outside your group, 312 to 333 while it shows one in it. Today: 312 to 333 throughout. That the game reports a move to another group as a roster change is not checked in game |
| S14 | Prayer of Healing on the left click; a member of your group out of the heal's reach (30 yards around you as far as known, not checked in game): party1, or a raid member in your group, whether or not the frame is faded for range | the healer hovers it | The green bars show 312 to 333, as on any member of your group (open point 1, option a); the frame's range fade is the only sign that the heal may not land. Today: the same |
| S16 | Chain Heal on a Shaman's left click (it lands on the member you click, then jumps on); every frame of S1 to S8 | the healer hovers each | Its green bars show on every one, as today: it lands on the clicked member, a heal on any friendly unit by #20's rule. Today: by the code; no test hovers a raid member outside your group, a pet or a hidden frame with it |
| S17 | Every other left click: Flash Heal, Desperate Prayer, a shield, or a left click with nothing predictable; any frame, any moment | the healer hovers it | As #20 left it: Flash Heal on every frame, Desperate Prayer only on a frame that shows you, a shield by #12's rules, nothing for a left click without a readable amount (works today: #20's and #12's tests in `spec/prediction_test.lua`) |
| S18 | A heal on the left click that NeoHeal can't tell from a group heal: the game gives no name for the clicked spell, none for Prayer of Healing to compare it with, or no class for you; Prayer of Healing or Flash Heal alike | the healer hovers your own frame in solo or a party, then party1's | On your own frame its green bars show; on party1's none: the safe side #20's AC1 promises for a heal NeoHeal can't tell apart. The cost: Flash Heal without its bars on other frames while the game gives no name for a group heal. Today: with no name for the clicked spell or no class, the same since #20; with no name for Prayer of Healing, Flash Heal shows on both. Whether the game ever gives no name for a learned spell is not checked in game |
| S19 | Flash Heal on the left click; the game gives no name for Prayer of Healing at one hover and gives it at a later one | the healer hovers party1's frame, leaves it, and hovers it again after the name is given | At the first hover no green bars (S18); at the later hover Flash Heal's 1887 to 2193: the answer follows the name the game gives now, never one it failed to give earlier. Today: 1887 to 2193 both times. Whether the game gives a spell's name late is not checked in game |

## Conflicts and unclear points

- [x] Does this bug promise the heal's reach, or only your group (AC3, S14)? Prayer of Healing reaches the members of your group around you (30 yards as far as known, not checked in game), not around the frame you hover, so a member of your group out of reach gets nothing from it while the rows above give it bars. Options: (a) group only: bars on every member of your group at any distance, as today; the frame's range fade is the only sign; (b) group and the frames' range fade: no bars on a member of your group whose frame is faded for range; that fade is the game's group range check, whose distance its API docs do not give and which is not the heal's as far as known (not checked in game), so a member between the two still keeps bars, and where the game hides that answer it only applies it itself, as it does for the fade: the bars then fade to nothing but keep their place, and the shield bar after them starts after an empty gap; the target and focus frames never fade for Prayer of Healing, so they keep their bars; (c) group and the heal's own reach: the game's API docs list a distance answer with no secret flag, but not what it measures, so it can stand for 30 yards only after an in-game probe. Proposed: (a). Against (a): the issue's own residual stays, a healer may count on Prayer of Healing for a party member just out of reach; against (b): it still errs between the two distances, and where the answer is hidden it leaves a gap before the shield bar that no test here can check (Notes for gate 2); against (c): it rests on a measure nobody has seen, and a wrong one hides bars where the heal lands. Under (b) or (c) rows follow for a member walking out of or into range with the mouse on the frame, in and out of combat, and for a range answer the game hides or cannot give. Answer: (a), group only: bars on every member of your group at any distance, none outside it; the frame's range fade stays the only sign that a member is too far (AC3, S14 as written). Why: it is the fix the issue asks for at 3 points, and both other options still err, (b) between the fade's distance and the heal's, (c) on a distance answer nobody has seen in game. Against it: a healer may still count on Prayer of Healing for a member of the group just out of reach. Residual risk: that stays as today, shown only by the range fade. Serves: the issue's own note that "a fix by group membership would still show bars on a party member out of the spell's reach" (stakeholder, 2026-11-23)
- [x] Is Holy Nova, a Priest's other group heal cast around you, in this bug (AC4, S15)? As far as known (not checked in game) it heals the party members within 10 yards of you, and its description names its healing as Prayer of Healing's does, so today its bars would show on every frame hovered. Options: (a) in: it follows Prayer of Healing's rows (S1 to S13) with its own amount; (b) out: it keeps its bars on every frame, and a bug of its own names it. Proposed: (a): the want covers every group heal on the left click, and the rule is the same one. Against (a): which spell ids and ranks stand for it on Forever is not checked in game, and an instant heal around you is rarely bound to a frame click; against (b): a Priest with Holy Nova on the left click keeps this bug. Answer: (b), out: Holy Nova keeps its bars on every frame, AC4 and S15 leave this bug, and bug #22 ("Holy Nova on the left click shows its prediction on members it never reaches") names it. Why: its ids on Forever are not checked in game, and by S18 a listed group heal the game gives no name for takes every heal to the safe side, so a wrong Holy Nova id would cost every Priest's heals their bars on other frames; the count is 3 points either way. Against it: a Priest with Holy Nova on the left click keeps today's wrong bars. Residual risk: that stays as today, now named in its own bug. Serves: own judgement on the stakeholder's pick of the recommended option (stakeholder, 2026-11-23)
- [x] At gate 2: where the game hides whether a frame shows you but still gives the raid's group numbers, does your own raid frame (or the target or focus frame on you) show Prayer of Healing's bars (AC1, S8)? S8 said "your own raid frame included" shows none wherever the game hides whether a frame shows you. Options: (a) the group numbers decide: they say the frame is in your group, so the bars show, and S8 and AC1 say so; (b) keep S8 as written: none on your own raid frame whenever that answer is hidden. Answer: (a). Why: the heal does land on you, and the group numbers the game still gives say so, so the bar is right; (b) would hide a correct bar for no gain. Against it: S8's "your own raid frame included" no longer holds in that one state. Residual risk: none beyond S8's, a frame whose group answer is hidden still shows none. Serves: AC1's "only on the frames of the members it heals" (stakeholder, 2026-11-23)

## Not in this story

- The bars on every member a group heal reaches at once: only the hovered frame shows a prediction, as today.
- Chain Heal's jumps: its bars show on the clicked member only, as today.
- Holy Nova, a Priest's other group heal cast around you: it keeps its bars on every frame hovered; bug #22, "Holy
  Nova on the left click shows its prediction on members it never reaches" (open point 2).
- Other heals cast around you (a Druid's Tranquility, a Shaman's healing totems): whether NeoHeal reads an amount
  from their descriptions is not checked in game; this bug does not change what they show.
- The tooltip: hovering a raid member outside your group still lists "Prayer of Healing 312-333" for the left click.
  It describes the spell, not the frame it lands on; unchanged, as #12 and #20 left it.
- The cancel cue: it already shows nothing for a group heal; unchanged.
- Test mode: it paints a fixed fake prediction on one member and this bug adds no setting; unchanged.
- Under open point 1's option (a), the heal's own reach (30 yards as far as known): a bug of its own, after an
  in-game probe of what NeoHeal can read for a member's distance in combat.

## Estimate

**3 points**, agreed by the Developer and the Architect, with open point 1 at option (a) and open point 2 at
option (b).
Basis: the Developer's count from the code, 1 source file (`UnitButton.lua`), 5 sites, about 60 to 85 lines: a
per-class list of group heals cast around you beside `SELF_ONLY_HEALS`, a rule for whether a unit is in your group,
a rule for whether the clicked heal goes on your group (three answers), a third branch in `CanTakeHeal`, and the
comments on it and on `UpdateHealPrediction`; no contract changes (`GetLeftClickAmount` already returns the spell, no
new field or record); about 11 to 12 new test functions (about 230 to 270 lines) and 1 dragged row, #20's
"a group heal you cast on yourself shows as today" in `spec/prediction_test.lua`, whose raid frame now shows none; 5
new fakes in `spec/support.lua` (`UnitInParty`, `UnitInSubgroup`, `GetRaidRosterInfo`, `IsInRaid`, `IsInGroup`); 4
docs. Two would undercount it: #20 was 2 points for 3 sites, about 40 lines, 14 tests and 2 fakes. Open point 1's
option (b) or (c) would have added 1 point each (5 points); open point 2 counts 3 either way by the Developer's prices:
its option (b) leaves out the one Holy Nova id and the about 2 test functions that option (a) would have added. S19 and the partial answer in S8 were added after the count, from the rows the Developer
found missing; they add test rows inside the 3-point band.

## Notes for gate 2

- Today's rule: `CanTakeHeal(unit, spellID)` in `UnitButton.lua` is `HealGoesOnOthers(spellID) or
  ShowsThePlayer(unit)`; Prayer of Healing is not in `SELF_ONLY_HEALS`, so it goes on others and shows on every
  frame. This bug adds a third answer: a heal that goes on your group.
- `GROUP_HEALS` in `ClickCast.lua` lists Prayer of Healing (596) and Chain Heal (1064) for the cancel cue, which
  refuses both; for the prediction they differ (Chain Heal lands on the clicked member). A design that splits or
  reuses that list drags the cancel cue's rows in `spec/castcue_test.lua` ("a group heal with a cast time" and the
  S34 rows). Its ids are "Classic-era's, not checked in game", by its own comment, and its name cache keeps a nil for
  good, the trap #20's How turned down for `SELF_ONLY_HEALS`. The Developer's count assumes a new per-class list of
  group heals cast around you beside `SELF_ONLY_HEALS`, read on every draw as that one is, which leaves the cancel
  cue's rows and `ClickCast.lua` untouched and keeps no nil (S19); splitting `GROUP_HEALS` instead drags about 3
  cancel cue rows and adds a `ClickCast.lua` site (Developer).
- The group rule as the Developer counted it: the hovered unit's raid index, then your own subgroup against the
  member's, with every answer guarded for a hidden value (`UnitInRaid` carries `SecretWhenUnitIdentityRestricted`;
  `Layout.lua` already guards a subgroup); the clicked heal checked against your class's group heals, with three
  answers (goes on your group, goes on others, can't tell). Any answer only partly given counts as hidden (S8).
- Whether a frame shows a member of your group: the frames' units are `player`, `partyN`, `raidN` (group and
  main-tank headers), pets (`pet`, `partypetN`, `raidpetN`), `target` and `focus`. In the forever-branch API docs
  (the copies kept from #20, `UnitDocumentation.lua`): `UnitInParty` and `UnitInSubgroup` carry no secret flag,
  `UnitInRaid` carries `SecretWhenUnitIdentityRestricted`, `UnitIsUnit` `SecretWhenUnitComparisonRestricted`, and
  `UnitInRange` `SecretReturns`. `GetRaidRosterInfo` is not in those copies; `Layout.lua` guards its subgroup as
  possibly secret. `MissingBuffs.lua` says `UnitInParty` can be secret on restricted maps, which those docs do not
  flag. What `UnitInParty` and `UnitInSubgroup` answer for a raid member of another group, or for `target` and
  `focus`, the docs do not say; not checked in game.
- Range, for open point 1's option (b): the group frames fade by `UnitInRange` in `UpdateRange`, a hidden answer
  going to `SetAlphaFromBoolean`; the target and focus frames fade by `C_Spell.IsSpellInRange` of the plain left
  click's spell, which for a spell without a target range gives nil and never fades (Prayer of Healing has none as
  far as known, not checked in game). Under (b) the prediction bars would take a hidden answer the same way:
  `AnchorAmountBars` skips only a bar whose `IsShown()` is false, so a bar faded to alpha 0 still anchors the shield
  bar after its width, and a hidden answer cannot be read in Lua to hide the bar instead; (b) either keeps that gap
  where the answer is hidden or adds a skip rule that works only on a readable answer. About 30 to 40 lines and 5
  test rows, in `UnitButton.lua` only, no new field (Developer).
- Range, for open point 1's option (c): `UnitDistanceSquared(unit)` in the forever-branch API docs (the copies kept
  from #20) returns `distance` and `checkedDistance` with no secret flag, unlike `UnitInRange`'s `SecretReturns`; no
  documentation says what the distance measures. It would need a guard for a hidden value and an in-game probe
  before it can stand for 30 yards (Developer; the doc entry read again by the Architect).
- Every moment redraws through `UpdateHealPrediction`: `OnEnter`, the modifier watcher, `ReloadUnitButtons` at a
  target or focus change, and `UpdateAllButtons` from `GROUP_ROSTER_UPDATE` in `Core.lua`. #20's `TestShieldRedraws`
  runs that chain (S11, S12). The target and focus frames keep their token while the person behind it changes:
  nothing cached per button on the token, or it is cleared in `ReloadUnitButtons`.
- Tests: `spec/support.lua` fakes `UnitInRange` and has no `UnitInParty`, `UnitInSubgroup`, `GetRaidRosterInfo`,
  `IsInRaid` or `IsInGroup`; the Developer counts 5 new fakes for them. The dragged row, `testAGroupHealYouCastOnYourselfShowsAsToday` in
  `spec/prediction_test.lua`, hovers `player`, `party1` and `raid12` in and out of combat and expects bars on all
  three; under S4 a `raid12` outside your group shows none.
- Docs at gate 3: the heal prediction paragraph in `docs/features.md`, the heal-prediction item in
  `docs/architecture.md`, the prediction line in the description in `docs/curseforge.md`, and the prediction cover
  in `docs/extending.md`.
- In-game checks this bug may need: that Prayer of Healing's tooltip line shows an amount (NeoHeal reads it), solo
  and out of combat; in a raid, what the chosen group answer gives for a member of another group and for a target on
  them.

## How

- A per-class list of the group heals cast around you, `YOUR_GROUP_HEALS = { PRIEST = { { 596 } } }`, one group of ids per spell, lives in UnitButton.lua beside `SELF_ONLY_HEALS`, and its names are read on every draw and never cached, as #20's list is. 596's only source is `GROUP_HEALS`'s own comment, "Classic-era's, not checked in game": an id the game gives no name for sends every Priest heal to a frame that shows you (S18), and an id that names another spell hands that spell the group rule and leaves Prayer of Healing today's bars on every frame. A late name counts from the next hover, which a cache of the kind `GROUP_HEALS` and `HOT_SPELLS` keep would not (S19) (architect and developer, 2026-11-23)
- `HealTargets(spellID)` answers "group", "you", "others" or nil, and collects every name of every group in both `YOUR_GROUP_HEALS[class]` and `SELF_ONLY_HEALS[class]` before it matches, so a group of which no id gives a name returns nil with no early "group" match: that is #20's own order (`HealGoesOnOthers` gives false as soon as a group is unnamed) and its S17, "no name for the heals it compares it with". The cost is S18's: Prayer of Healing clicked while Desperate Prayer's ids give no name shows only on a frame that shows you, where #20 already puts every Priest heal. The class guards stay #20's: an unreadable class is nil, and a class the list does not name gets an empty list (architect and developer, 2026-11-23)
- `CanTakeHeal(unit, spellID)` branches three ways on that answer: "others" shows on every frame, "group" asks `InYourGroup(unit)`, and "you" or nil asks `ShowsThePlayer(unit)`. #20's can't-tell side and its self-only side stay one branch: two functions would repeat the name and class guards that S18 and S19 must get right once (architect and developer, 2026-11-23)
- `InYourGroup(unit)` asks in this order, and a hidden, nil or unreadable answer is no: `ShowsThePlayer(unit)` yes (S1, S9); a pet's token, `pet`, `partypetN` or `raidpetN`, no before any lookup, because a raid pet is a raid unit whose index would take its owner's group (S5; that Forever gives a raid pet its owner's index is not checked in game); a `partyN` frame outside a raid yes by its token alone, since a party is group 1 whatever the game hides and no API is needed (S2, S8); a target or focus frame only after `IsTrue(UnitIsPlayer(unit))`, so a target on a pet or on a friendly NPC is no (S5, S7); in a raid, `UnitInRaid("player")` and `UnitInRaid(unit)` each an index, `GetRaidRosterInfo(index)` each a subgroup, both indexes and both subgroups non-nil and not secret before they are compared and then equal, so two nil subgroups are never equal (S3, S4, S8); outside a raid, `IsTrue(UnitIsUnit(unit, "party" .. index))` over `GetNumSubgroupMembers()` (S2, S6, S7). A hidden `UnitIsUnit` reads as no in `ShowsThePlayer`, and the raid branch then still runs: the two subgroup numbers decide, so your own raid frame or a target on you shows the bars where the roster is readable, while outside a raid a target on you with that answer hidden shows none (S8, the stakeholder's answer at gate 2) (architect and developer, 2026-11-23)
- Nothing is cached per frame and no redraw is added: the hover, the modifier watcher, `ReloadUnitButtons` at a target or focus change and `UpdateAllButtons` from `GROUP_ROSTER_UPDATE` all reach `UpdateHealPrediction` already, the chain #20's `TestShieldRedraws` runs (S10 to S13) (architect and developer, 2026-11-23)
- The docs say no more than this: the heal prediction paragraph in `docs/features.md`, the heal-prediction item in `docs/architecture.md`, the description line in `docs/curseforge.md` and the prediction cover in `docs/extending.md` gain that Prayer of Healing shows only on the frames of the members it reaches, your own, a party's and in a raid your own group's, and none on a raid member outside your group, a pet, or a target or focus frame on someone outside it; none where the game hides or only partly gives who is in your group, while your own frame and a party's keep theirs, and where the game hides only whether a frame shows you, a raid's group numbers decide; a member of your group at any distance keeps its bars with the frame's range fade the only sign; and a heal NeoHeal can't tell from a group heal takes the safe side until the game gives the name. Holy Nova keeps its bars on every frame, named as bug #22's (architect and developer, 2026-11-23)
- Test rows beyond one per scenario, and the fakes they need: the order row, Prayer of Healing clicked while both Desperate Prayer ids give no name, with party1 none; both subgroups nil, a raid frame none; a target on a raid pet none; S8's three cases, a raid with `UnitIsUnit` hidden and the roster readable, a party with `UnitIsUnit` hidden, and a raid with the index or subgroup hidden or nil; 596 unnamed, Flash Heal on your own frame only; and #20's dragged row `testAGroupHealYouCastOnYourselfShowsAsToday` rewritten, its `raid12` outside your group now showing none. The fakes are `IsInRaid`, `GetRaidRosterInfo` and `GetNumSubgroupMembers` with solo defaults beside the others in `spec/support.lua`, and `UnitIsPlayer` answered per test, since its fake default is a no-op returning nil (architect and developer, 2026-11-23)
- In-game checks this story cannot make here, for the gate file's Not done, all solo and out of combat except the second: `/dump C_Spell.GetSpellName(596)` prints "Prayer of Healing"; in a raid, `/dump UnitInRaid("player")` gives your own raid index and `/dump select(3, GetRaidRosterInfo(UnitInRaid("player")))` gives your subgroup, in and out of combat (architect and developer, 2026-11-23)

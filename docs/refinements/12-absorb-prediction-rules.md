# Refinement: #12 Any absorb spell on left click is predicted with Power Word: Shield rules

## User value

As a healer, I want the blue shield bar on the frame under my mouse to show only where my left click would really
put that shield, so that I never count on a shield that will not land there.

When this is done, whoever hovers a frame with a shield on a left click sees its absorb only on the frames that
shield lands on, and only when it would land, from the release that carries this fix.

The user story is the Architect's proposal: the issue has none. Today NeoHeal knows the spell on the left click only
by its description, and every spell that reads "absorbing N damage" gets Power Word: Shield's rules. A Mage with Ice
Barrier, a shield that only ever goes on the caster, on a left click sees its absorb on every frame they hover,
party1's included, although that click never shields party1; and on their own frame, a Priest's shield on them
(its Weakened Soul, or the shield itself) hides the Ice Barrier prediction, though Ice Barrier would land. Seen with
a probe on the fake API on 2026-11-16 (438 on party1's frame; nothing on your own frame with Weakened Soul), not in
game. What the game does with Ice Barrier cast on party1's frame (it shields you, or the cast fails) is not checked
in game; it never shields party1. That Power Word: Shield and Ice Barrier are the only shields whose descriptions read
"absorbing N damage" in the game's content is not checked in game.

## Delivers value alone

yes: the fix reaches every player with a shield on a left click with the next release; nothing else has to land first.
Waits on: none

## Acceptance criteria

| AC | Criterion | Scenarios | Proving test |
| --- | --- | --- | --- |
| AC1 | A shield that only goes on you shows its absorb only on a frame that shows you: your own frame, your own raid frame, the target or focus frame while it shows you. Another member's, a pet's, or a target or focus frame on someone else shows nothing; where the game hides whether a frame is you, it shows nothing. This holds when you start hovering, when you press or release Shift, Ctrl or Alt, when the target or focus changes under the mouse, and when the group puts another member behind a raid frame under the mouse. | S6, S7, S8, S9, S10, S15, S16, S18 | `spec/prediction_test.lua` "a shield that only goes on you shows only on a frame that shows you", "the shield follows the target or focus under the mouse" and "the shield follows a roster change under the mouse" |
| AC2 | On your own frame, Weakened Soul or a Power Word: Shield on you leaves a shield other than Power Word: Shield showing, also when they come or go while you hover; that shield shows nothing while its own aura, of any rank, is still up on you, or while your auras can't be read (in combat), as Power Word: Shield does, and the bar follows when that aura comes or goes while you hover. | S11, S12, S13, S14, S19 | `spec/prediction_test.lua` "Power Word: Shield's auras leave another shield showing" and "another shield shows nothing while its own is up or the auras are hidden" and "the bar follows your own shield coming and going" |
| AC3 | Power Word: Shield shows as today: its absorb on any member's frame, your own included, and nothing on one with Weakened Soul, with a Power Word: Shield still up, or whose auras can't be read (in combat). | S1, S2, S3, S4, S5 | `spec/prediction_test.lua` "Power Word: Shield shows on your own frame", and the shield tests that exist there ("a left-click shield shows its absorb", "no shield on Weakened Soul", "no shield on a shield still up", "other auras keep the shield", the three hidden-aura tests, "no shield without a spell name") |
| AC4 | A heal on the left click shows as today, on every frame, whatever the unit's auras, in and out of combat. | S17 | `spec/prediction_test.lua` "hovering shows the left-click heal" (exists) and "a heal ignores the shield rules" |

## Dimensions

| Dimension | Values | Rows |
| --- | --- | --- |
| The spell on the left click, with the modifiers held now | Power Word: Shield (any rank), a shield that only goes on you (Ice Barrier), a heal (Flash Heal) | S1 to S5; S6 to S16; S17 |
| Whose frame is hovered | another member's or a pet's frame, your own frame in solo or a party, your own frame in a raid, the target or focus frame on you, the target or focus frame on someone else, a frame where the game hides whether it shows you | S1, S6; S2, S7; S2, S8; S10, S15; S6, S15; S9 |
| The hovered unit's auras | none or only unrelated ones, Weakened Soul, a Power Word: Shield still up, the self-only shield's own aura still up, hidden in combat, a spell name the game does not give | S1, S7; S3, S11; S4, S11; S12; S5, S13; S5, S13 |
| Combat | out of combat, in combat | every row but S5, S13 and S17 is out of combat; S5, S13 in combat; S17 both |
| Modifiers held | none, Shift (Ctrl and Alt alike) | every row but S16; S16 |
| The moment the bar is drawn | the hover starts, a modifier is pressed or released, an aura comes or goes while hovering, the target or focus changes to another person while hovering, the group puts another member behind a hovered raid frame | S1, S6; S16; S14, S19; S15; S18 |

3 x 6 x 6 x 2 x 2 x 5 = 2160 cells. They collapse to 19 rows. A heal follows no frame or aura rule, so one row (S17)
holds all its cells. Power Word: Shield goes on any friendly frame, so its frame only needs one row for your own
(S2) beside its aura rows (S1, S3 to S5). A self-only shield shows nothing on a frame that does not show you whatever
the auras (S6), so its aura rows sit on your own frame only (S11 to S13), and its frame rows have no aura (S7 to
S10). Combat matters only through the auras it hides (`docs/forever-api.md`, section 3): S5 and S13, and S17 for a
heal. A modifier only picks which spell is on the left click (works today: "the held modifier picks the binding"),
so one row with a self-only shield on Shift (S16). Every moment redraws the bar the same way, by the code; a row per
moment where the answer can change: S14, S15, S16, S18, S19. A spell's rank, the "Show left-click heal prediction" option and a
dead or offline member are not dimensions of this change: they decide before any shield rule (works today).

## States, moments and places

Unless a row says otherwise: out of combat, "Show left-click heal prediction" on, the hovered unit alive and
connected, the spell on the plain left click cast on the clicked unit, and the bar read when the hover starts. Power
Word: Shield absorbs 942 and Ice Barrier 438 in these rows. "Today" is read in the code; S6, S7 and S11 were seen
with a probe on the fake API on 2026-11-16; none is seen in game.

| Id | State, moment or place | Operation | Expected |
| --- | --- | --- | --- |
| S1 | Power Word: Shield on the left click; another member's or a pet's frame, with no aura or only unrelated ones (Renew, Forbearance, their own Ice Barrier: only a Power Word: Shield of any rank counts as a shield still up, matched by name) | the healer hovers the frame | The blue bar shows 942 (works today: "a left-click shield shows its absorb", "other auras keep the shield"; no test has an Ice Barrier up) |
| S2 | Power Word: Shield on the left click; your own frame, in solo, a party or a raid, no aura | the healer hovers it | The blue bar shows 942 (works today by the code; no test hovers your own frame) |
| S3 | Power Word: Shield on the left click; any frame whose unit has Weakened Soul, whoever's shield left it | the healer hovers it | No blue bar (works today: "no shield on Weakened Soul") |
| S4 | Power Word: Shield on the left click; any frame whose unit has a Power Word: Shield still up | the healer hovers it | No blue bar (works today: "no shield on a shield still up") |
| S5 | Power Word: Shield on the left click; in combat, where the game refuses the auras or hands out a secret aura or a secret name; or the game gives no name for Weakened Soul or Power Word: Shield | the healer hovers any frame | No blue bar (works today: the three hidden-aura tests and "no shield without a spell name") |
| S6 | Ice Barrier on the left click; a frame that does not show you: another member's (party1, a raid member), a pet's, or the target or focus frame on someone else | the healer hovers it | No blue bar, whatever the unit's auras. Today: 438 (the issue) |
| S7 | Ice Barrier on the left click; your own frame in solo or a party, no aura | the healer hovers it | The blue bar shows 438 (works today) |
| S8 | Ice Barrier on the left click; your own frame in a raid (the raid member that is you), in your group or among the main tanks, no aura | the healer hovers it | The blue bar shows 438 (works today, because today it shows on every frame) |
| S9 | Ice Barrier on the left click; a raid, target or focus frame where the game hides whether it shows you (maps where it restricts addons) | the healer hovers it | No blue bar: a shield that may not land there is not shown. Today: 438 |
| S10 | Ice Barrier on the left click; the target or focus frame while you target or focus yourself, no aura | the healer hovers it | The blue bar shows 438 (works today) |
| S11 | Ice Barrier on the left click; your own frame, with Weakened Soul, a Power Word: Shield, or both on you (a Priest shielded you) | the healer hovers it | The blue bar shows 438: they only stop a new Power Word: Shield. Today: no blue bar. That Ice Barrier and Power Word: Shield both hold at once is not checked in game |
| S12 | Ice Barrier on the left click; your own frame, your Ice Barrier still up, of any rank | the healer hovers it | No blue bar: a new one would not add to the one up. Today: 438. Whether a new Ice Barrier replaces the old one or is refused is not checked in game |
| S13 | Ice Barrier on the left click; your own frame in combat (your auras hidden), or the game gives no name for Ice Barrier | the healer hovers it | No blue bar: its own aura can't be ruled out, as for Power Word: Shield (works today) |
| S14 | Ice Barrier on the left click; hovering your own frame, out of combat | a Priest's Power Word: Shield lands on you, then fades, while the mouse stays on your frame | The blue bar shows 438 throughout. Today: it goes when the shield lands and comes back when Weakened Soul fades |
| S15 | Ice Barrier on the left click; hovering the target (or focus) frame | your target changes from yourself to party1 and back, the mouse staying on the frame | No blue bar while it shows party1; 438 while it shows you. Today: 438 throughout. That the frame redraws at the change is by the code (the target and focus frames keep their unit while the person changes); not checked in game |
| S16 | Ice Barrier on Shift + left click, Flash Heal on the plain left click | the healer hovers party1's frame, holds Shift, then hovers your own frame still holding Shift, then releases Shift | On party1: Flash Heal's green bars, then with Shift no bar at all; on your own frame with Shift: the blue bar shows 438; on release: Flash Heal's green bars. Today: 438 on party1 with Shift |
| S17 | A heal (Flash Heal) on the left click; any frame, with Weakened Soul, a Power Word: Shield, or hidden auras, in or out of combat | the healer hovers it | Its green bars show as today, and no blue bar (works today: "hovering shows the left-click heal"; no test has a heal with these auras) |
| S18 | Ice Barrier on the left click; hovering your own raid frame | the group changes so that another member is behind that frame, the mouse staying on it, and later you again | No blue bar while it shows the other member; 438 while it shows you. Today: 438 throughout. That the frame redraws at a roster change is by the code; not checked in game |
| S19 | Ice Barrier on the left click; hovering your own frame, out of combat | you cast Ice Barrier (its aura lands on you), then it breaks or ends, the mouse staying on your frame | The blue bar goes when the aura lands and shows 438 again when it ends. Today: 438 throughout |

## Conflicts and unclear points

- [x] Does a shield that only goes on you show its absorb on a frame that shows you (AC1; S7, S8, S10, S11, S14, S15, S16)? Options: (a) yes, on every frame that shows you (your own frame, your raid frame, the target or focus frame on you), and nothing where the game hides whether a frame is you (S9); (b) no: only Power Word: Shield is shown, and any other shield shows nothing anywhere, so those rows expect no blue bar. Proposed: (a), as the bar is then right wherever the shield lands. Against (a): your raid, target and focus frames need an answer the game may hide, so on some maps the bar shows on your solo frame and not on your raid frame; (b) has no such case, at the cost of never showing a Mage's Ice Barrier. Answer: (a). The issue names the bug as the bar on frames the shield never reaches; on the frames it does reach, the bar is right and worth keeping. Against: on maps where the game hides whether a frame is you, the bar shows on your solo frame but not your raid frame; accepted, as showing nothing there errs on the safe side, as S9 says. Serves: issue #12, "A self-only shield such as Ice Barrier would show its prediction on another member's frame" (product owner, 2026-11-16)
- [x] With a shield other than Power Word: Shield on the left click, do Weakened Soul and a Power Word: Shield on you leave its absorb showing (AC2; S11, S14)? Options: (a) yes, they only stop a new Power Word: Shield; (b) no, it hides as today. Proposed: (a), as the issue names hiding it as the bug. Against (a): that Ice Barrier holds beside a Power Word: Shield is not checked in game. Answer: (a). Weakened Soul and a shield up only stop a new Power Word: Shield; hiding another shield for them is the bug the issue names. Against: that Ice Barrier holds beside a Power Word: Shield is not checked in game; accepted, and it goes on the in-game check if gate 3 confirms the bar depends on it. Serves: issue #12, "Every absorb spell bound to left click is predicted and checked against the Power Word: Shield rules" (product owner, 2026-11-16)
- [x] Does a shield other than Power Word: Shield show nothing while its own aura is still up, and so nothing in combat when the auras are hidden (AC2; S12, S13)? Options: (a) yes, the rule Power Word: Shield has: a shield that would not add to the one up is not shown, and in combat no shield prediction shows, as `docs/features.md` says today; (b) no: its absorb always shows on your own frame, in combat too, whatever your auras. Proposed: (a), one rule for every shield. Against (a): a Mage then sees Ice Barrier's absorb only out of combat, when it matters least. Answer: (a). One rule for every shield: a shield that would not add to the one up is not shown, and unreadable auras show no shield, as docs/features.md promises today. Against: a Mage sees Ice Barrier's bar only out of combat; accepted, as a wrong bar in combat is worse than none. Serves: own judgement (product owner, 2026-11-16)
- [x] Is a heal that only goes on you (Desperate Prayer, a Priest heal; its description reads "heals the caster for N to M" as far as known, not checked in game) in this story? Today its green bars show on every frame hovered, party1's included, for the same reason. Options: (a) out: a new bug, so this story stays within its issue; (b) in: two rows (another member's frame: no green bar; your own frame: its green bars) and a test, if gate 2's way to tell a spell that only goes on you covers heals too. Proposed: (a), the issue's scope. Against (a): the healer keeps seeing a wrong green bar until that bug is fixed, and the same rule may cover it for one more test. Answer: (a), out of this story. The issue is about shields; a self-only heal is a separate bug, filed after this refinement. Against: the wrong green bar stays until that bug is fixed, though the same rule might cover it for one more test; accepted, to keep this story at its size. Serves: issue #12's title, "Any absorb spell on left click is predicted with Power Word: Shield rules" (product owner, 2026-11-16)

## Not in this story

- A heal that only goes on you (Desperate Prayer): open point above; if it stays out, a new bug.
- The tooltip: hovering party1 still lists "Ice Barrier 438 absorb" for the left click. It describes the spell, not
  the frame it lands on; unchanged.
- Shields whose description gives no amount ("Absorbs N damage": Mana Shield, Fire Ward, Frost Ward, Shadow Ward, as
  far as known, not checked in game) show no bar today and none after.
- A spell on cooldown still shows its bar, heals and shields alike; unchanged.
- The left click's spell changing while the mouse stays on a frame (bindings applied, or a new rank learned for a
  "highest rank" binding): today the bar keeps the old spell's amount until the next redraw (a new hover, a modifier,
  the unit's health or auras), for every spell alike; this story does not change that.

## Estimate

**3 points**, agreed by the Developer and the Architect. Basis: the Developer's count from the code, 2 source files,
4 sites, about 40 to 55 lines (`ClickCast:GetLeftClickAmount` returns the spell with its amount; the shield check
in `UnitButton.lua` splits into Power Word: Shield's rule and one for a shield that only goes on you, with a check
that the frame shows you and one for the shield's own aura; `UpdateHealPrediction` passes the spell on); 1 contract
changed, that return, which reaches the `Heal()` helper and 5 assertions in `spec/prediction_test.lua`; about 14
new test functions (S18 and S19 came after the count, one each), about 150 to 210 lines; about 25 to 35 changed test
lines, in the 10 existing `SHIELD` setups and in `spec/support.lua`, which knows no Ice Barrier yet (about 8 to 12
lines); 4 docs. The Architect first counted 2 without the contract change and `spec/support.lua`; on the
Developer's basis both count 3.

## Notes for gate 2

- How to tell Power Word: Shield from another shield, and a spell that only goes on you: the bar knows the left
  click's spell only by its description (`MatchAmount` in `ClickCast.lua`), while the binding holds the spell's id.
  Candidates: the spell's id or name (`CanTakeShield` already looks up Power Word: Shield by id 17 for its name; its
  ranks have other ids), its description ("shields you"), or a client call that tells a spell's range or whether it
  can go on others. Which client call answers that on Forever is not checked in game; no id, name or client call
  for "only goes on you" is checked in game, only the description's wording, which is English-only like
  `MatchAmount` (Developer).
- The spell must reach the bar with its amount: `GetLeftClickAmount` can return it, or a new getter can;
  `GetLeftClickSpell` reads the unmodified left click only and cannot serve S16 (Developer).
- The shield's own aura name can come from the bound rank's spell name, so a shield of any rank up matches (S12)
  (Developer). `HasAura` reads at most 40 auras per filter; the own-aura check inherits that limit.
- `spec/support.lua` knows no Ice Barrier id or name; binding Power Word: Shield's own id predicts nothing until
  the fake knows that spell as learned (measured by the Developer on 2026-11-16).
- The existing shield tests in `spec/prediction_test.lua` bind Flash Heal's id with Power Word: Shield's description
  (`SHIELD`, 10 uses, `TestHealPrediction` and `TestLeftClickHeal`); a design that tells Power Word: Shield by its id
  or name changes their setup in the same pass, and the count above holds them.
- Your own frame: `player` in solo and a party (a plain string); in a raid the `raidN` that is you, and the target
  and focus frames, need `UnitIsUnit(unit, "player")`, which may be secret on maps where the game restricts addons
  (S9; `IsTrue` reads secret as false). The fakes for it exist (`spec/clicktypes_test.lua`,
  `spec/targetfocus_test.lua`).
- The self-only shield's own aura (open point 3, option a) needs its aura name; `CanTakeShield`'s rule "false when it
  can't be told" carries over.
- Every moment redraws through `UpdateHealPrediction`: `OnEnter`, the modifier watcher, `UpdateAuras`, and
  `UpdateHealth` through `SetUnit` when `ReloadUnitButtons` handles a target or focus change. The target and focus
  frames keep their unit token while the person behind it changes: nothing cached per button on the token, or it is
  cleared in `ReloadUnitButtons` (S15). A roster change redraws every button through `UpdateAllButtons` and
  `UpdateHealth` (S18); a binding applied while hovering redraws nothing (Not in this story).
- Docs at gate 3: `docs/features.md` (the shield paragraph under the heal prediction), `docs/architecture.md` (the
  heal prediction item), `docs/curseforge.md` (two lines on the shield prediction), `docs/extending.md` (what the
  prediction tests cover).
- In-game checks this story may need, solo and out of combat: Ice Barrier cast from party1's frame (where it lands),
  and Ice Barrier beside a Power Word: Shield (S11) and on top of its own (S12); only if those answers change what
  the bar shows.

## How

- Which absorb is Power Word: Shield: the name of the rank the click casts (`C_Spell.GetSpellName(GetSpellValue(binding))`) equals `C_Spell.GetSpellName(17)`, never the description's wording, which would pass our own tests whatever the real Ice Barrier text says (not checked in game) and could leave the issue's bug shipped unchanged; a nil name on either side shows no bar, the safe side (architect and developer, 2026-11-16)
- Every absorb that is not Power Word: Shield takes the rule for a shield that only goes on you; that "not Power Word: Shield" means the same is an assumption about the game's content (not checked in game): an absorb that can go on others would show only on your own frame, a bar missing where it could show, never a wrong one (architect and developer, 2026-11-16)
- The spell reaches the bar with its amount: `ClickCast:GetLeftClickAmount` returns `low, high, kind, spellID`, and `MatchAmount`, `GetSpellAmount` and the tooltip stay as they are (architect and developer, 2026-11-16)
- The frame shows you: `ShowsThePlayer(unit)` is `unit == "player"` first, a plain string, then `IsTrue(UnitIsUnit(unit, "player"))`, so your own frame shows the bar where the game hides the answer and a raid, target or focus frame shows nothing then (S7, S9); whether the game hides `UnitIsUnit` on your own raid frame is not checked in game (architect and developer, 2026-11-16)
- A shield that only goes on you shows nothing while an aura of its own name is up (`HasAura(unit, name, "HELPFUL") == false`), so a shield of any rank matches and a refused or secret answer shows nothing (S12, S13, S19); it reads neither Weakened Soul nor Power Word: Shield (S11, S14) (architect and developer, 2026-11-16)
- Power Word: Shield keeps today's rule (`CanTakePowerWordShield`), so AC3 cannot change (architect and developer, 2026-11-16)
- Nothing is cached per button: every redraw reads the unit and its auras, so a new person behind a hovered raid, target or focus frame needs no clearing (S15, S18; the redraws run from `Core.lua:193-199` and `Core.lua:159-162` through `UpdateHealth` in `UnitButton.lua:427`) (architect and developer, 2026-11-16)
- Tests: the 10 `SHIELD` setups in `spec/prediction_test.lua` bind Power Word: Shield's own id (17) now; `spec/support.lua` gains an Ice Barrier id and name (not checked in game); S18's test runs the real `UpdateAllButtons` chain on a wider fake button than `Support.FakeButton` gives (architect and developer, 2026-11-16)
- Docs: the shield paragraph in `docs/features.md`, the heal-prediction item in `docs/architecture.md`, the two shield lines in `docs/curseforge.md` (54, 149) and the prediction cover in `docs/extending.md` (114-115), worded no wider than this design: only Power Word: Shield shows a bar on a frame that does not show you (architect and developer, 2026-11-16)
- Not checked in game, said so in the code and the docs: Ice Barrier's id and name, which absorbs besides Power Word: Shield read "absorbing N damage", and `UnitIsUnit` on your own raid frame (architect and developer, 2026-11-16)
- In-game check for the gate file's Not done, solo and out of combat: a Priest with Power Word: Shield on the left click sees the blue bar on their own frame and on party1's, as that path now depends on the bound rank's name (architect and developer, 2026-11-16)


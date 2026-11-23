# Refinement: #20 A heal that only goes on you shows its prediction on other members' frames

## User value

As a healer, I want the green heal bars on the frame under my mouse to show only where my left click would really
heal, so that I never count on a heal that will not land there.

When this is done, whoever hovers a frame with a heal that only goes on them on a left click sees its green bars only
on the frames that show them, from the release that carries this fix.

The user story is the issue's. Today NeoHeal knows the spell on the left click only by its description: every heal
it reads an amount from shows its green bars on whatever frame is hovered. A Priest with Desperate Prayer, a heal
that only ever goes on the caster, on a left click sees its green bars on party1's frame, although that click never
heals party1. Read in the code (`ClickCast:GetLeftClickAmount` reads the amount and no rule asks whether the spell
can go on the hovered unit; `UpdateHealPrediction` draws every heal), not seen in game and not probed: the test fake
knows no Desperate Prayer. That Desperate Prayer's description ("heals the caster for N to M", as far as known)
matches NeoHeal's heal patterns is not checked in game; what the game does with Desperate Prayer clicked on
party1's frame (it heals you, or the cast fails) is not checked in game either; it never heals party1. #12 fixed the
same bug for shields; this story is its heal half (#12's open point 4, answered "out of this story" on 2026-11-16).

## Delivers value alone

yes: the fix reaches every healer with a heal that only goes on them on a left click with the next release; nothing
else has to land first.
Waits on: none

## Acceptance criteria

| AC | Criterion | Scenarios | Proving test |
| --- | --- | --- | --- |
| AC1 | A heal that only goes on you shows its green bars only on a frame that shows you: your own frame, your own raid frame, the target or focus frame while it shows you, in and out of combat. Another member's, a pet's, or a target or focus frame on someone else shows none; where the game hides whether a frame is you, it shows none. A heal NeoHeal can't tell apart is shown the same way, only on a frame that shows you. Where no green bars show, the frame's incoming heals and shields sit as they do without a prediction. This holds when you start hovering, when you press or release Shift, Ctrl or Alt, when the target or focus changes under the mouse, and when the group puts another member behind a raid frame under the mouse. | S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S16, S17 | `spec/prediction_test.lua` "a heal that only goes on you shows only on a frame that shows you", "a heal that only goes on you shows nothing where the game hides who is you", "a heal that only goes on you on a modifier follows the modifier and the frame", "the heal follows the target or focus under the mouse", "the heal follows a roster change under the mouse", "a hidden heal leaves the incoming heals and shields in place" and "a heal that can't be told apart shows only on a frame that shows you" |
| AC2 | A heal that goes on any friendly member shows as today: its green bars on every frame hovered, yours and everyone else's, in and out of combat, wherever NeoHeal can tell it apart (AC1 holds where it can't). | S11, S12 | `spec/prediction_test.lua` "hovering shows the left-click heal" (exists) and "a heal on any friendly unit shows on every frame" |
| AC3 | A group heal you cast on yourself, which reaches your party, shows as today: its green bars on every frame hovered. | S13 | `spec/prediction_test.lua` "a group heal you cast on yourself shows as today" |
| AC4 | Shields, and a left click that heals nothing NeoHeal can read, show as today: Power Word: Shield and a shield that only goes on you by #12's rules, and nothing at all for a left click without a readable amount. | S14, S15 | `spec/prediction_test.lua` "nothing when the left click doesn't heal" (exists), and the tests that exist there for the rest: #12's shield tests, and in `TestLeftClickHeal` "nothing when the click doesn't heal the clicked unit", "nothing for a spell not learned" and "nothing without a number" |

## Dimensions

| Dimension | Values | Rows |
| --- | --- | --- |
| The spell on the left click, with the modifiers held now | a heal that only goes on you (Desperate Prayer), a heal on any friendly unit (Flash Heal and the like: S11), a group heal you cast on yourself (Prayer of Healing), a shield (Power Word: Shield or Ice Barrier), nothing predictable (the cases S15 lists) | S1 to S10, S16; S11, S12; S13; S14; S15 |
| Whose frame is hovered | your own frame in solo or a party, your own raid frame, another member's or a pet's frame, the target or focus frame on you, the target or focus frame on someone else, a frame where the game hides whether it shows you | S2, S7, S8, S17; S3, S7, S10; S1, S7, S8, S16, S17; S4, S9; S5, S9; S6 |
| Whether NeoHeal can tell the heal apart | it can tell whether the heal goes on others, it can't (the game gives no name or no answer for it) | every heal row but S17; S17 |
| Combat | out of combat, in combat | every row but S6, S7 and S12 to S15 is out of combat; S7 and S12 in combat; S6 and S13 to S15 both |
| Modifiers held | none, Shift (Ctrl and Alt alike) | every row but S8; S8 |
| The moment the bar is drawn | the hover starts, a modifier is pressed or released, the target or focus changes to another person while hovering, the group puts another member behind a hovered raid frame | S1 to S7, S11 to S17; S8; S9; S10 |

5 x 6 x 2 x 2 x 2 x 4 = 960 cells. They collapse to 17 rows. A heal that only goes on you is the one spell whose
bars depend on the frame, so it takes a row per frame (S1 to S6), per moment where the answer can change (S8 to S10),
one combat row (S7), and one for the bars it hides beside the incoming heals and shields (S16). A heal NeoHeal can't
tell apart takes the safe side, one row (S17). A heal on any friendly unit shows on every frame whatever the moment (S11, and S12 for combat).
The group heal (S13), the shields (S14, #12's 19 rows) and a left click with nothing predictable (S15) keep today's
answer on every frame and in every moment; one row each pins it. Combat matters only through what the game hides
then: auras (`docs/forever-api.md`, section 3), which no heal rule reads, and nothing the forever-branch API docs
mark as hidden for a spell's range (Notes for gate 2); S7 and S12 pin it. A modifier only picks which spell is on
the left click (works today: "a modifier switches to its left click"), so one row with the self-only heal on Shift
(S8). A spell's rank, the "Show left-click heal prediction" option and a dead or offline member are not dimensions
of this change: they decide before any heal rule (works today).

## States, moments and places

Unless a row says otherwise: out of combat, "Show left-click heal prediction" on, the hovered unit alive and
connected, the spell on the plain left click cast on the clicked unit, and the bar read when the hover starts. In
these rows Flash Heal heals 1887 to 2193 and Desperate Prayer 134 to 170 (the test fake's numbers, not the game's).
"Today" is read in the code; no row is seen in game or with a probe.

| Id | State, moment or place | Operation | Expected |
| --- | --- | --- | --- |
| S1 | Desperate Prayer on the left click; another member's frame (party1, a raid member) or a pet's | the healer hovers it | No green bars. Today: 134 to 170 (the issue) |
| S2 | Desperate Prayer on the left click; your own frame in solo or a party | the healer hovers it | The green bars show 134 to 170 (works today) |
| S3 | Desperate Prayer on the left click; your own raid frame (the raid member that is you), in your group or among the main tanks | the healer hovers it | The green bars show 134 to 170 (works today, because today they show on every frame) |
| S4 | Desperate Prayer on the left click; the target or focus frame while you target or focus yourself | the healer hovers it | The green bars show 134 to 170 (works today) |
| S5 | Desperate Prayer on the left click; the target or focus frame on someone else (party1, or a player outside your group) | the healer hovers it | No green bars. Today: 134 to 170 |
| S6 | Desperate Prayer on the left click; a raid, target or focus frame where the game hides whether it shows you (maps where it restricts addons), your own raid frame included; in and out of combat | the healer hovers it | No green bars: a heal that may not land there is not shown, as #12 settled for a shield that only goes on you. Your own frame in solo or a party keeps them (S2). Today: 134 to 170 |
| S7 | Desperate Prayer on the left click; in combat, on a map where the game tells whether a frame is you | the healer hovers your own frame in solo or a party, your own raid frame, then party1's | On your own frame and your own raid frame the green bars show 134 to 170; on party1's none. Today: all three show. That the game hides nothing this needs in combat is what its API docs say, not checked in game |
| S8 | Desperate Prayer on Shift + left click, Flash Heal on the plain left click | the healer hovers party1's frame, holds Shift, then hovers your own frame still holding Shift, then releases Shift | On party1: Flash Heal's green bars, then with Shift no bars at all; on your own frame with Shift: 134 to 170; on release: Flash Heal's green bars. Today: 134 to 170 on party1 with Shift |
| S9 | Desperate Prayer on the left click; hovering the target (or focus) frame | your target changes from yourself to party1 and back, the mouse staying on the frame | No green bars while it shows party1; 134 to 170 while it shows you. Today: 134 to 170 throughout. That the frame redraws at the change is by the code (the target and focus frames keep their unit while the person changes); not checked in game |
| S10 | Desperate Prayer on the left click; hovering your own raid frame | the group changes so that another member is behind that frame, the mouse staying on it, and later you again | No green bars while it shows the other member; 134 to 170 while it shows you. Today: 134 to 170 throughout. That the frame redraws at a roster change is by the code; not checked in game |
| S11 | A heal on any friendly unit on the left click (Flash Heal, a heal over time, Chain Heal); every frame: your own in solo, a party or a raid, another member's, a pet's, the target or focus frame on you or on someone else inside or outside your group, and a frame where the game hides whether it shows you | the healer hovers it | The green bars show 1887 to 2193 on every one, as today (works today: "hovering shows the left-click heal" on party1; no test hovers the other frames) |
| S12 | Flash Heal on the left click; in combat | the healer hovers your own frame, then party1's | The green bars show 1887 to 2193 on both, as today (seen in game on 2026-10-04 that heals show in combat; which frames then is not recorded) |
| S13 | Prayer of Healing (a group heal you cast on yourself, which reaches your party) on the left click; your own frame, party1's frame, a raid member's frame outside your group; in and out of combat | the healer hovers each | Its green bars show on every one, as today (open point 1, option a). Today: by the code; no test binds it, and that its description matches NeoHeal's heal patterns is not checked in game |
| S14 | Power Word: Shield or a shield that only goes on you (Ice Barrier) on the left click; any frame, any auras, in and out of combat | the healer hovers it | As today, by #12's rules: Power Word: Shield's absorb on any member's frame that can take it, Ice Barrier's only on a frame that shows you, none where the auras are hidden; no green bars (works today: #12's shield tests) |
| S15 | Nothing predictable on the left click: Target, the menu, a missing buff, a spell cast on the unit's target, a spell not learned, or a spell without a readable amount; any frame, in and out of combat | the healer hovers it | No bars at all, as today (works today: "nothing when the left click doesn't heal" and the `TestLeftClickHeal` tests) |
| S16 | Desperate Prayer on the left click; party1's frame, with heals incoming on party1 and a shield on them | the healer hovers it | No green bars; the incoming heals and the shield bar sit right after each other as they do with no prediction (works today for a hidden prediction: "the shield skips the hidden prediction"; no test hides a heal this way) |
| S17 | A heal on the left click that NeoHeal can't tell apart: the game gives no name or no answer for it, or for the heals it compares it with; Flash Heal or Desperate Prayer alike | the healer hovers your own frame in solo or a party, then party1's | On your own frame its green bars show; on party1's none: a heal that may not land there is not shown, the safe side #12 took for a shield whose name the game does not give. Showing them on party1 would be this issue's bug again; the cost is a heal on any friendly unit without its bars on other frames in this state. Today: both show. The game's API docs give no name only for a spell they do not find; whether that happens to a learned spell is not checked in game |

## Conflicts and unclear points

- [x] Is a group heal you cast on yourself (Prayer of Healing, which heals your party; AC3, S13) in this story? Today its green bars show on every frame hovered, also on a raid member outside your group, whom it never heals. Options: (a) out: it shows as today on every frame, and this story only makes sure it keeps doing so on the frames it does reach; (b) in: its green bars show only on a frame of someone it reaches (you, your party, in a raid your own group), and none on other raid members, pets, or a target or focus frame on someone outside your group. Proposed: (a), the issue's scope, a heal that only goes on you. Against (a): the want ("show only where my left click would really heal") covers it, and a raid healer with Prayer of Healing on the left click keeps a wrong green bar on 35 of 40 raid frames; against (b): it needs a rule for whom a group heal reaches that no part of NeoHeal has today, and its reach (30 yards around you, as far as known, not checked in game) is not around the hovered frame, so even (b) would show bars on a party member out of reach. Under (b) rows follow for your own group changing under the mouse, and for a group answer the game hides, which shows nothing. Answer: (a), out of this story; Prayer of Healing keeps its bars on every frame (AC3), and its reach becomes a bug of its own. Why: the issue is about a heal that only goes on you, which takes one rule against the frame; a group heal's reach is a second rule (who is in your group, which the game can hide) and, as the option itself says, still wrong on a party member out of range, so it is a different fix at twice the price. Against it: a raid healer with Prayer of Healing on the left click keeps a wrong green bar on most raid frames until that bug is fixed. Residual risk: that stays as today, now named in its own bug. Serves: the issue's scope, "A heal that only goes on the caster, bound to the left click, shows its heal prediction on every frame hovered" (product owner, 2026-11-23)

## Not in this story

- A group heal you cast on yourself (Prayer of Healing) showing on raid members it never reaches: bug #21, "A group
  heal on the left click shows its prediction on raid members it never reaches".
- The tooltip: hovering party1 still lists "Desperate Prayer 134-170" for the left click. It describes the spell, not
  the frame it lands on; unchanged, as #12 left it for shields.
- A heal that only goes on your pet (a Hunter's Mend Pet, a Warlock's Health Funnel): whether NeoHeal reads an amount
  from their descriptions is not checked in game; this story does not change what they show.
- The cancel cue: it shows only while a cast with a cast bar runs; Desperate Prayer is instant as far as known (not
  checked in game), so it shows none.
- A spell on cooldown still shows its bars; unchanged.
- The left click's spell changing while the mouse stays on a frame (bindings applied, or a new rank learned for a
  "highest rank" binding): today the bars keep the old spell's amount until the next redraw, for every spell alike;
  this story does not change that.

## Estimate

**2 points**, agreed by the Developer and the Architect, with open point 1 at option (a).
Basis: the Developer's count at gate 2, from the code and the How section, 1 source file (`UnitButton.lua`), 3 sites,
about 35 to 45 lines: the per-class list of id groups, `CanTakeHeal` with its class guard and the names it collects
per group, and the heal branch of `UpdateHealPrediction`; no contract changes (`GetLeftClickAmount` already returns
the spell); about 14 new test functions in `spec/prediction_test.lua`, S13's pin included, and no existing test row
changes; 2 catalogue entries in `spec/support.lua` (13908 and 19236); 4 docs. At gate 1 the count was about 20 to 30
lines and about 8 test functions, plus one each for S16 and S17; the two-id groups, the class guard and their test
rows grew it inside the 2-point band. The Architect first counted 2 source files; the Developer's count needs only
`UnitButton.lua`.

## Notes for gate 2

- How to tell a heal that only goes on you: the bar knows the spell id since #12 (`GetLeftClickAmount` returns it).
  Read in Blizzard's generated API docs on the forever branch (`Blizzard_APIDocumentationGenerated/SpellDocumentation.lua`):
  `C_Spell.SpellHasRange(spellID)` "Returns true if the spell has a min and/or max range greater than 0";
  `C_Spell.GetSpellInfo(spellID)` returns `minRange` and `maxRange` (no documentation on them);
  `C_Spell.IsSpellInRange(spellID, unit)` "May be nil if the range check was invalid, ie due to unknown/invalid
  spell, missing/invalid target, etc", so a nil may not tell a self-only spell from an unknown one;
  `C_Spell.IsSpellHelpful` is true for "the player or other friendly targets" alike; `C_Spell.IsSelfBuff` speaks of
  an aura ("only applies effects to the player"), and Desperate Prayer leaves none as far as known. None of these
  five entries carries a secret-return flag (`SecretReturns`, `SecretWhen...`) on the forever branch; that the
  client gives a plain answer in combat is what the docs say, not checked in game. Other candidates: a list of
  spell ids turned into names, as `GROUP_HEALS` and #12's Power Word: Shield do (Desperate Prayer's id is not
  checked in game), or the description's wording, which #12's design turned down for shields (English-only, and a
  test fake writes its own wording). What `SpellHasRange` and `maxRange` give for Desperate Prayer, Flash Heal and
  Prayer of Healing on Forever is not checked in game.
- A rule on range alone would also catch Prayer of Healing (it has no target range, as far as known, not checked in
  game), and S13 then loses its bars on party1's frame: under open point 1's option (a), a range rule and AC3
  contradict each other (Developer).
- The Developer's first candidate: a per-class list of the heals that only go on you, spell ids turned into names at
  run time as `GROUP_HEALS` and `Hots.lua` do; it lives in `UnitButton.lua` beside `CanTakeShield` or in
  `ClickCast.lua` beside `GROUP_HEALS`. That the list holds every such heal is an assumption about the game's
  content, worded as not checked in game. A "highest rank" binding resolves to another rank; `C_Spell.GetSpellName`
  gives every rank the same name, as `Spells.lua` groups a spell by name (Developer). A range call would need the
  test fake to answer it per spell, and a fake's answer proves nothing about the client (Developer).
- `C_Spell.GetSpellName` "Returns nil if spell is not found" (forever-branch docs): the producer of S17's missing
  name. #12 settled a missing name on the safe side for shields ("a nil name on either side shows no bar").
- Your own frame: `ShowsThePlayer` exists since #12, with its rule for a hidden answer (S6).
- Every moment redraws through `UpdateHealPrediction`, as #12's How lists: `OnEnter`, the modifier watcher,
  `UpdateHealth` through `SetUnit` when `ReloadUnitButtons` handles a target or focus change (S9), and
  `UpdateAllButtons` at a roster change (S10). The target and focus frames keep their unit token while the person
  behind it changes: nothing cached per button on the token, or it is cleared in `ReloadUnitButtons`.
- Tests: the heal tests in `spec/prediction_test.lua` hover party1 only; `spec/support.lua` knows Prayer of
  Healing's id and name (no description) and no Desperate Prayer. #12's `TestShieldRedraws` runs the real redraw
  chain for S9 and S10.
- Docs at gate 3: the heal prediction paragraph in `docs/features.md`, the heal-prediction item in
  `docs/architecture.md`, the heal prediction line in `docs/curseforge.md`, and the prediction cover in
  `docs/extending.md`.
- In-game checks this story may need, solo and out of combat: Desperate Prayer's description and where it lands when
  clicked on party1's frame, and what the client answers for the spell call gate 2 picks, for Desperate Prayer,
  Flash Heal and Prayer of Healing.

## How

- A per-class list of the heals that only go on you, `SELF_ONLY_HEALS = { PRIEST = { { 13908, 19236 } } }`, one group of ids per spell, lives in UnitButton.lua beside `CanTakeShield`; the ids become names at run time with `C_Spell.GetSpellName`, as `GROUP_HEALS` and `HOT_SPELLS` do, so every rank matches by name and a "highest rank" binding needs nothing extra. Two ids stand for Desperate Prayer: 13908 (Desperate Prayer on Wowhead's Classic pages, a third-party source) and 19236 (the same spell as far as known); which ids and ranks Forever has is not checked in game, and the second id keeps one missing id from counting every Priest heal as self-only. It is a deny-list, so a self-only heal it misses shows on other frames (the unsafe side) and the reverse list would take the bars off every any-friendly heal it misses; that the list holds every self-only heal is not checked in game (architect and developer, 2026-11-23)
- No cache, unlike `GROUP_HEALS` and `HOT_SPELLS`: the names are looked up on every draw. A cache built their way keeps a nil for good, and a listed id whose name came back nil on the first draw would then count as any-friendly for the rest of the session, which is S17 failing on the unsafe side. Only the hovered button asks, and only when the amount is a heal (architect and developer, 2026-11-23)
- `CanTakeHeal(unit, spellID)` decides in this order: with the clicked spell's name readable, every group for your class carrying at least one name, and that name in none of those names, the heal goes on any friendly unit and shows on every frame (S11, S12); every other answer counts as a heal that only goes on you and shows only where `ShowsThePlayer(unit)` says (S1 to S10, S16, S17). So an unnamed clicked spell, a group of which no id gives a name, or a class NeoHeal cannot read all take the safe side. A group collects every name its ids give, not the first one: with the first, an id that names another spell on Forever would keep Desperate Prayer's own name out of the list and ship this issue's bug, while collecting all of them only adds that other spell to the deny-list, which takes bars away and never shows a wrong one (architect and developer, 2026-11-23)
- The class is split in two cases before it is used as a table key: read but not in the list is an empty list, so that class's heals are any-friendly (S11 names Chain Heal, a Shaman spell; reading an absent class as self-only would take the bars off every Shaman, Druid and Paladin heal); unreadable, `UnitClass` giving nothing or a hidden value, is self-only, S17's "no answer for the heals it compares it with". The guard is `if not class or IsSecret(class) then` a self-only heal, before `SELF_ONLY_HEALS[class]`: `UnitClass` carries `MayReturnNothing` and `SecretWhenUnitIdentityRestricted` in the forever branch's UnitDocumentation.lua, and a hidden value used as a table key is not among the safe uses forever-api.md section 2 lists. `GROUP_HEALS` and `HOT_SPELLS` read the class unguarded today and are left as they are, outside this story (architect and developer, 2026-11-23)
- The draw: in `UpdateHealPrediction`, `local heal = kind == "heal" and CanTakeHeal(unit, spellID) and low`, exactly where the absorb branch asks `CanTakeShield`. With `heal` false both prediction bars hide, `AnchorAmountBars` skips hidden bars, and S16 needs no change (architect and developer, 2026-11-23)
- No new contract: `ClickCast:GetLeftClickAmount` already returns the spell, and `MatchAmount`, `GetSpellAmount` and the tooltip stay as they are (architect and developer, 2026-11-23)
- Nothing cached per button, so the target and focus frames keep nothing across a person change and S9 and S10 need no clearing (architect and developer, 2026-11-23)
- Preview.lua stays as it is: test mode paints a fixed fake prediction on member 5 and there is no new setting, so member 5 shows no rule (architect and developer, 2026-11-23)
- In-game checks this story cannot make here, for the gate file's Not done, all solo and out of combat except the second: `/dump C_Spell.GetSpellName(13908), C_Spell.GetSpellName(19236)` prints Desperate Prayer for at least one of them; Flash Heal on party1 shows its bars in and out of combat; Desperate Prayer on party1 shows none. As far as known, Desperate Prayer is a Human or Dwarf Priest spell in Classic, so the third click may not be possible on every character while the dump works for any (architect and developer, 2026-11-23)
- `C_Spell.GetSpellName` carries no secret flag in the forever branch's SpellDocumentation.lua (`MayReturnNothing = true`, no `SecretReturns`), and the cancel cue's `ClickCast.GetClickSpell`, which returns nil whenever the name is missing, was seen working in combat in game on 2026-11-17. That the name is readable in combat is inferred from that, not measured: were it hidden there, every heal would count as self-only in combat and S12 would fail for every healer (architect and developer, 2026-11-23)
- Tests, the TestWriter's in `spec/prediction_test.lua` with `Support.DESPERATE_PRAYER = 13908` and 19236 beside it in `spec/support.lua`, both named Desperate Prayer and worded as Classic's as far as known: one row per scenario row, S17 split in two (the clicked spell unnamed; every id of the listed spell unnamed), a control row with 13908 unnamed and 19236 named (Desperate Prayer on party1 shows nothing, Flash Heal on party1 shows its bars), a row that separates a group's every name from its first: 13908 naming another spell and 19236 naming Desperate Prayer, with Desperate Prayer on party1 showing nothing (red against a build that keeps only the first name), a row for a class not in the list (Shaman: a heal on party1 shows its bars, S11), a row for a class NeoHeal cannot read (nil or hidden: bars on your own frame, none on party1, S17), and the TestWriter's row for a cache that would lose a listed id, so a cached build goes red on it. #12's `TestShieldRedraws` chain is reused for S9 and S10 (architect and developer, 2026-11-23)
- Docs: the heal-prediction paragraph in `docs/features.md`, the heal-prediction item in `docs/architecture.md`, the prediction line in the description in `docs/curseforge.md` (the changelog line is written at release) and the test cover in `docs/extending.md`, worded no wider than this design: a self-only heal shows only on a frame that shows you, and that the list holds every such heal is not checked in game (architect and developer, 2026-11-23)

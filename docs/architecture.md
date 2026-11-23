# Architecture

## Namespace and modules

Every file starts with `local _, NeoHeal = ...` and adds one table to the shared
addon namespace (`NeoHeal.Layout`, `NeoHeal.UnitButton`, ...). There are no
globals besides the saved variables, the slash command, the addon compartment
click handler the TOC names (`NeoHeal_OnAddonCompartmentClick`) and a few named
frames (`NeoHealFrame`, `NeoHealGroup1..8`, `NeoHealMainTanks`, `NeoHealPets`,
`NeoHealTarget`, `NeoHealFocus`, `NeoHealOptionsFrame`, `NeoHealResHandler`).

Load order (`NeoHeal.toc`) matters only at file scope. Most cross-module calls
happen at runtime, after `PLAYER_LOGIN`.

```
Locales/enUS.lua → Core → Spells → Dispel → AuraContainer → Hots → MissingBuffs
→ ClickCast → UnitButton → TargetFocusFrames → Layout → Preview → Blizzard → Options
```

## Module responsibilities

| Module | Owns | Key functions |
| --- | --- | --- |
| **Core** | Defaults, migrations, global events, the out-of-combat queue, `/neoheal` and the addon compartment entry | `RunOutOfCombat`, `IsSecret/IsTrue/IsFalse`, `Print`, `NeoHeal_OnAddonCompartmentClick` |
| **Spells** | Spellbook scan grouped by name with all ranks | `Scan`, `GetHighestRank`, `GetRankText` |
| **Dispel** | Debuff types the player can cure; colour curve and filter for the dispel strip | `UpdateKnownDispels`, `GetColorCurve`, `GetBorderFilters` |
| **AuraContainer** | Wrapper around Blizzard's `CustomAuraContainerTemplate`; the shared countdown font | `Create`, `CreateDispelStrip`, `SetUnit`, `SetShown`, `AddTimedCooldown` |
| **Hots** | Own-HoT icons (Lua-drawn out of combat, container in combat) | `Attach`, `SetUnit`, `Update`, `RefreshSizes`, `ShowPreview` |
| **MissingBuffs** | Missing or running-out class-buff icon, with a per-button re-check timer for the moment a buff starts running out; `*spell-neobuff` attribute for the buff click | `Attach`, `Update`, `UpdateClick`, `ExplainClick` |
| **ClickCast** | Bindings ↔ secure attributes, hover keys, auto-res snippet, class defaults | `Initialize`, `Set`, `BuildAttributes`, `Apply`, `ApplyToButton`, `QueueApply`, `AddBindingsToTooltip`, `GetModifierPrefix`, `GetLeftClickAmount`, `MovesTheCharacter`, `CheckHoverKeys` |
| **UnitButton** | Visuals and per-unit event handling of one frame; also the five-second rule and the cancel cue | `CreateVisuals`, `Init`, `UpdateAllButtons`, `UpdateAllAuras`, `RefreshAuraContainers`, `ReloadUnitButtons`, `OnPlayerCast`, `OnPreClick`, `OnCastStart`, `OnCastEnd`, `ClearCancelCue` |
| **TargetFocusFrames** | The optional target and focus frames above the groups: secure unit buttons with a fixed unit, shown by a state driver; their fake versions in test mode | `Create`, `Refresh` |
| **Layout** | Container, 8 group headers + main tank + pet header, arrangement, titles, move mode, size presets, test mode | `Create`, `Refresh`, `Arrange`, `FitToContent`, `SetTestMode`, `GetSize` |
| **Preview** | Fake members for test mode, using `UnitButton.CreateVisuals` | `Show`, `Hide` |
| **Blizzard** | Re-parents Blizzard group frames into a hidden frame | `ApplyHiding` |
| **Options** | The options window; Layout page generated from `LAYOUT_SETTINGS` | `Toggle`, `RefreshLayoutPage`, `RefreshBindingRows`, `RefreshClickCastingPage`, `EndKeyCapture` |

## Start-up (`PLAYER_LOGIN`)

1. Create the saved variables, fill in defaults (`ApplyDefaults` only adds missing
   keys), run migrations. See [saved-variables.md](saved-variables.md).
2. `Spells:Scan()` → `Dispel:UpdateKnownDispels()` → `MissingBuffs:UpdateKnownBuffs()`.
3. `ClickCast:Initialize()` (class defaults on a character's first login).
4. Out of combat: `Layout:Create()` (which also calls `TargetFocusFrames:Create`)
   → `ClickCast:Apply()`.
5. Register the settings entry under Esc > Options > AddOns.

## How a unit frame comes to life

```
Layout:Create
  └─ headers (SecureGroupHeaderTemplate), template =
       SecureUnitButtonTemplate + SecureHandlerEnterLeave + SecureHandlerShowHide
       └─ INITIAL_CONFIG (secure snippet, may run in combat)
            ├─ size from header attrs neoWidth/neoHeight
            ├─ copy click attributes neoClickName/Value1..N onto the button
            └─ header:CallMethod("InitUnitButton") ──► UnitButton.Init (Lua)
                 ├─ CreateVisuals (bars, texts, icons, borders, Hots.Attach, MissingBuffs.Attach)
                 ├─ hooks: OnEnter/OnLeave/OnHide (tooltip, heal prediction), OnClick (debug),
                 │         PostClick (buff explain)
                 ├─ child frame `events` for unit events (no secure frame touched)
                 ├─ OnAttributeChanged "unit" ──► SetUnit
                 └─ RunOutOfCombat: RegisterForClicks, ApplyToButton (hover snippets),
                                    SecureHandlerWrapScript(OnClick, RES_SNIPPET)
```

`SetUnit(button, unit)` runs whenever the header gives a button a new unit. It
re-registers unit events for the new unit, points the aura containers at it
(or queues building them), and calls `UpdateAll`.

### The target and focus frames

`TargetFocusFrames:Create` (from `Layout:Create`, out of combat) makes two
buttons that no header owns, `NeoHealTarget` and `NeoHealFocus`, on the same
`BUTTON_TEMPLATE` as the group buttons. It sets their unit attribute to
`"target"` / `"focus"` and calls `UnitButton.Init`, so they join
`UnitButton.buttons` and get every visual, hook, binding (`ClickCast:Apply`) and
the res snippet. Their unit attribute never changes, so `SetUnit` doesn't run
when the unit behind it does: `PLAYER_TARGET_CHANGED` and `PLAYER_FOCUS_CHANGED`
call `UnitButton:ReloadUnitButtons(unit)`, which runs `SetUnit` again for the
buttons with that unit (no secure attribute, so fine in combat) and asks their
aura containers to redraw (whether a container follows the new unit by itself
isn't checked in game). `UpdateTargetHighlight` never shows the white target
border on the `"target"` button.

`TargetFocusFrames:Refresh` (from `Layout:Refresh`, before its test-mode return)
sizes and anchors both above the container, clear of the title bar and group
labels (target left, focus one column right), and gives a frame whose option is
on the state driver `[@target,help] show; hide` (or `@focus`), which the game
runs in combat too. With its option off, or in test mode, it unregisters the
driver and hides the button. Each has a title-frame label as its child, so the
label shows with it. That the focus unit and these macro conditions work on
Forever isn't checked in game.

### Updates

`UpdateAll` calls one function per aspect: `ApplyStyle`, `UpdateIdentity`,
`UpdateHealth` (which also updates the low-health tint, the low-mana "OOM" text,
incoming heals, the heal prediction and absorbs), `UpdatePower` (the resource
bar, and the low-mana text again, as it follows the member's mana),
`UpdateRange`, `UpdateAuras`, `UpdateAggro`, `UpdateRaidTarget`,
`UpdateTargetHighlight`, `UpdateLeader`, `UpdateStatusIcon`, `UpdateFiveSecondFor`
(that frame's five-second bar only). `UpdateHealth` also redraws that frame's cancel cue
(`UpdateCancelCue`), which hides on a dead or offline member.

The **five-second rule** is the one update that is not per member: `castAt` in
UnitButton.lua holds the moment your last spell that spent mana went off, and a
0.1 s ticker (`UnitButton.UpdateFiveSecond`) draws every frame's bar from it, so a
frame that starts or stops showing you needs nothing carried over. `Core.lua` gives
`UNIT_SPELLCAST_SUCCEEDED` and `UNIT_SPELLCAST_CHANNEL_START` (registered for the
"player" unit) to `UnitButton.OnPlayerCast`, which asks
`C_Spell.GetSpellPowerCost` whether the spell spends mana. The value is read from
`GetTime()` on every update, never stepped down, so a jump in time (a loading
screen, a return to caster form) shows the right time left at once. What Forever
tells an addon about your casts and their cost is not checked in game
([features.md](features.md), "What one frame shows").

The **cancel cue** is per frame, because the cast events carry no target: Blizzard's
generated docs on the forever branch give `unitTarget`, `castGUID` and `spellID` only.
Each button's `PreClick` hook (`UnitButton.OnPreClick`) records the click when it
casts a spell on the clicked member itself, on a living member; the spell comes from
the bindings last applied to the frames (`ClickCast.GetClickSpell`), an `alsoTarget`
macro binding having no spellID of its own, and a group heal is refused by name. A
cast's `UNIT_SPELLCAST_START` takes that record when it is at most 0.5 s old and its
spell name matches, then holds the castGUID on that button (with the member's GUID).
`PreClick` rather than `PostClick` so the newest record is the click being made
whichever side of `OnClick` the client fires the event on. A new start clears every
other cue, so a queued cast's start arriving before the previous cast's end moves the
cue at once. `STOP`, `FAILED`, `INTERRUPTED` and `SUCCEEDED` clear the frame whose
GUID matches (every frame when the GUID is hidden); a channel is never heard. The cue
is cleared in `SetUnit` when the button's token changes (a header that sets the same
token again keeps a running cue), in `ReloadUnitButtons` (the target and focus frames
keep their token while the member changes), in the `OnHide` hook after the one-frame
visible check, in `UpdateAllButtons` when a roster change leaves the token with another
member's GUID (a hidden GUID, or none kept at the cast's start, clears it too, since
there is nothing to compare with), by the option's setter, and on
`PLAYER_ENTERING_WORLD`. Its
colour is one step colour curve on `UnitHealthPercent`, the low-health tint's pattern:
gold up to 90%, red above. The cue showing, going with a cancelled cast, and moving
with a queued cast were checked in game on 2026-11-17; whether a virtual-button click
reaches `PreClick`, and whether a queued cast still starts within the 0.5 s at a higher
latency, are not checked in game ([forever-api.md](forever-api.md), section 8).

Who counts as a **healer** is one rule, `UnitButton.IsHealer(role, class)`, used
by both the resource bar's "Healers only" and the low-mana text.
`IsHealerButton` reads the role and class for a button, keeping what it knew when
the game hides the role in combat; the low-mana text shows through a colour
curve (`UpdateLowMana`), so secret mana is never tested.

Unit events map to these functions in `EVENT_UPDATES` (UnitButton.lua).
`UNIT_AURA` is **batched**: it marks the button, and all marked buttons are
scanned once after 0.1s. Range is the one thing also polled every second, as a
backup for `UNIT_IN_RANGE_UPDATE`. That event carries a unit token and whether
it is in range, and it belongs with the group range check `UnitInRange` (the
wiki documents the party-or-raid limit for `UnitInRange`; for the event its scope
isn't documented). Whether either says anything about a `target` or `focus` unit
isn't checked in game, so the poll is what keeps those two frames current.
`UpdateRange` uses `UnitInRange` for the group units and
`C_Spell.IsSpellInRange` with the unmodified left-click spell
(`ClickCast:GetLeftClickSpell`) for `target` and `focus`.

Global events (Core.lua) fan out to the `UnitButton:Update*` loops over all
buttons:

| Event | Effect |
| --- | --- |
| `GROUP_ROSTER_UPDATE` | Update all buttons; out of combat: `Arrange`, or a full `Refresh` if party ↔ raid switched preset; re-hide Blizzard frames |
| `PLAYER_ROLES_ASSIGNED` | Update all buttons (role icon, healer-only power bar, low-mana text) |
| `UNIT_PET` | Re-arrange (pet column) |
| `PLAYER_REGEN_DISABLED/ENABLED` | Missing buffs off/on; refresh auras (switch Lua icons ↔ containers); run queued work |
| `UNIT_SPELLCAST_START`, `STOP`, `FAILED`, `INTERRUPTED`, `SUCCEEDED` (for `player`) | The five-second bar (`OnPlayerCast`, on `SUCCEEDED` and `CHANNEL_START`) and the cancel cue (`OnCastStart`, `OnCastEnd`) |
| `PLAYER_ENTERING_WORLD` | Every cancel cue goes: a login, a reload, a loading screen or a zone change |
| `PLAYER_TARGET_CHANGED`, `UNIT_TARGET` (target) | Target / targeted borders; `PLAYER_TARGET_CHANGED` also reloads the target frame (`ReloadUnitButtons("target")`) |
| `PLAYER_FOCUS_CHANGED` | Reloads the focus frame (`ReloadUnitButtons("focus")`) |
| `RAID_TARGET_UPDATE`, `PARTY_LEADER_CHANGED` | Top icons |
| `READY_CHECK*` | Centre icon; lingers 5s after the check ends |
| `SPELLS_CHANGED` | Debounced 0.5s: rescan spells, dispels, buffs; re-apply bindings (highest rank); refresh the click casting rows if that page shows |
| `UPDATE_BINDINGS` | `ClickCast:CheckHoverKeys`: re-apply bindings only if a hover key now moves your character, or no longer does; refresh the click casting rows if that page shows |

## Layout

- `Refresh()` applies **all** settings (out of combat only). It picks the size
  preset, applies scale and position, places the target and focus frames
  (`TargetFocusFrames:Refresh`), then hides each header, sets its
  attributes (size, sort, spacing) and shows it again. A visible header re-runs
  its layout on every attribute change and would error on half-applied
  settings. After that it calls `Arrange`, then refreshes HoT sizes and aura
  containers, applies Blizzard frame hiding, and updates all buttons.
- `Arrange()` places the headers left to right by **member counts from the
  roster**, never by header sizes, so empty groups leave no gaps. Main tanks go
  first or last ("last" = after pets).
- `FitToContent(order, isRaid)` sizes the container and places the title bar or
  per-group labels. The preview calls it too.
- Position is saved as `TOPLEFT` relative to the screen's bottom-left, per preset.
  `ApplyScale` converts the offsets so a new scale keeps the corner in place.

## Click casting data flow

```
charDB.bindings["shift-2"] = { action="spell", spellID=139, highestRank=true, target="unit" }
        │  ClickCast:BuildAttributes()
        ▼
{ ["shift-type2"]="spell", ["shift-spell2"]=<highest Renew ID>, ... ,
  ["*type-neores"]="spell", ["*spell-neores"]=<res>, ["*type-neobuff"]="spell",
  _onenter=<hover key snippet>, _onleave/_onhide="self:ClearBindings()" }
        │  ClickCast:Apply()
        ├─► every header: neoClickCount + neoClickName/Value{i}  (for future buttons)
        └─► every existing button: SetAttribute directly
```

- **Hover keys** use virtual buttons `neokey1..3`. The `_onenter` snippet calls
  `SetBindingClick` for the key with every modifier, but only for a hover key
  with an action on at least one modifier whose key doesn't move the character
  (`ClickCast.MovesTheCharacter`); any other key stays the game's. `_onleave`
  and `_onhide` always clear these bindings, also when there's no snippet. The
  key capture in the options refuses a key that moves the character. A saved
  one (set before that check, or bound to movement since) isn't bound: the
  tooltip leaves it out and its options button reads "W (moves you)".
  `UPDATE_BINDINGS` re-checks after a key binding change. Why:
  [forever-api.md](forever-api.md) section 6. The key capture itself is one
  wait at a time, `waitingCapture` in `Options.lua`: the button's `Refresh`
  writes its text and turns its keyboard off together, so any redraw of the
  rows and the window's combat handler end a wait (`EndKeyCapture`). Why:
  [forever-api.md](forever-api.md) section 7.
- **Target and Open unit menu** keep the game's types (`target`, `togglemenu`)
  only on plain left and right click. Everywhere else Blizzard's click bindings
  would drop those types (see [forever-api.md](forever-api.md)), so the slot gets
  `neotarget` or `neomenu`. A `neotarget` click goes through RES_SNIPPET to the
  virtual button `neotarget`, `neotarget-target` or `neotarget-targettarget`
  (following the slot's `unitsuffix`), each a `/target mouseover…` macro. For a
  `neomenu` click the game calls `button.neomenu` (`ClickCast.OpenUnitMenu`, set
  by `ApplyToButton`) outside secure code. For the group units it picks the menu
  by unit type; for `target` and `focus` it asks the game what is behind the
  unit (the file-local `DetectedMenu` in ClickCast.lua), as Blizzard's own
  TargetFrame and FocusFrame do (source cited in the comment there).
- **RES_SNIPPET** wraps each button's `OnClick` in the secure environment. On a
  dead friendly unit it redirects spell/macro clicks to the virtual button
  `neores`. It sends `neotarget` clicks to their `/target` macro, also on a dead
  unit. For `neobuff` it returns `"neobuff"` (cast `*spell-neobuff`) or
  `false` (cancel). It reads modifiers the way the game does, every one held as
  `alt-ctrl-shift-` (like `ClickCast.GetModifierPrefix`), so with two held it
  redirects nothing.
- **The tooltip** (`ClickCast:AddBindingsToTooltip`) lists the bindings as last
  applied to the frames (`appliedBindings` and `appliedHoverKeys`, set by
  `Apply`), for the modifiers held now. A learned spell gets its amount from
  `ClickCast.GetSpellAmount`, which reads the description of the rank the click
  casts (`C_Spell.GetSpellDescription`).
- **The heal prediction** (`UpdateHealPrediction` in UnitButton.lua) shows only
  on the button under the mouse (`hoveredButton`, set by `OnEnter` and cleared
  by `OnLeave`, which also runs a frame after the button hides if it stays
  hidden). `ClickCast:GetLeftClickAmount` gives the lowest and highest amount of
  the applied left-click binding for the modifiers held now, whether it heals
  or absorbs, and the spell it casts, read the same way as the tooltip amounts.
  Two bars after the incoming heals show a heal's lowest amount and the rest of
  its range; a third shows a shield's absorb, unless `CanTakeShield` says the
  shield would not land. That check tells Power Word: Shield from every other
  absorb by the bound rank's spell name (never by the description, which is
  English-only text no test can foresee): Power Word: Shield takes
  `CanTakePowerWordShield`, unless a Weakened Soul or a Power Word: Shield is on
  the unit; every other absorb is treated as a shield that only goes on you, and
  takes `CanTakeOwnShield`, which asks `ShowsThePlayer` (the plain unit `player`,
  else `UnitIsUnit`) and refuses while an aura of the shield's own name is up. A
  hidden aura, a hidden name or a hidden `UnitIsUnit` refuses. That the other
  absorbs only go on you is not checked in game. A heal is drawn unless
  `CanTakeHeal` says it would not land there. `HealTargets` reads the clicked
  spell's name, the class, and every name the ids of two per-class lists give, one
  group of ids per spell so every rank matches: `SELF_ONLY_HEALS` (a Priest's
  Desperate Prayer, 13908 and 19236) and `YOUR_GROUP_HEALS` (Prayer of Healing, 596;
  both not checked in game), and answers `"group"`, `"you"`, `"others"` or nil. A
  clicked name on the group list is `"group"`, on the self-only list `"you"`, and
  any other readable name `"others"`; every other answer is nil, and nil takes the
  safe side with `"you"`. The names are read on every draw, never cached: a cache
  would keep a nil from the first draw and treat the spell as landing on others.
  Both lists are read before the name is matched, and a group of which no id gives a
  name makes the answer nil, so a heal compared with a spell the game doesn't name
  is one NeoHeal can't place. `UnitClass` is read first and a nil or secret class
  counts as one it can't tell, because a hidden value may not be a table key; a
  class the lists do not name has empty lists, so its heals go on others. A heal it
  can't tell, and a heal that only goes on you, then takes `ShowsThePlayer`: bars on
  a frame that shows you, none on another member's frame, as a self-only shield. A
  `"group"` heal takes `InYourGroup` instead: `ShowsThePlayer` yes; a pet token
  (pet, partypetN, raidpetN) no, since a raid pet's index would read as its owner's
  group; a partyN frame outside a raid yes by its token, a party being group 1; a
  target or focus frame only after `IsTrue(UnitIsPlayer)`, so a pet or an NPC shows
  none; then in a raid the two `UnitInRaid` indexes and the two roster subgroups,
  each non-nil and not secret before they are compared and then equal, and outside a
  raid `UnitIsUnit` against each `partyn`. Every hidden, nil or partly given answer
  is no. The shields come after them. `AnchorAmountBars` starts each shown bar at the end
  of the last shown one, skipping hidden bars (in game a hidden, emptied bar
  kept its old fill width: [forever-api.md](forever-api.md), section 5).
  `UpdateHealth` and `UpdateAuras` redraw it, and while the mouse is over a
  button that shows a tooltip or a prediction, one `MODIFIER_STATE_CHANGED`
  watcher redraws both.
- **Also target** turns the binding into a two-line macro using `mouseover`.

## Test mode

`Layout:SetTestMode(size)` hides the real headers, and `Refresh` hands off to
`Preview:Show(size)`. That builds plain frames with the same
`UnitButton.CreateVisuals` and decorates them with fake data. The preview reuses
the exported helpers (`ApplyStyle`, `LayoutBars`, `AnchorAmountBars`,
`ShowsPowerBar`, `ShowHealthText`, `ShowLowHealth`, `ShowCancelCue`, `SetStatusIcons`,
`Hots.ShowPreview`, `MissingBuffs.ShowPreview`) so it stays visually identical.
The target and focus frames hide in test mode; `TargetFocusFrames:Refresh` shows
a plain frame in the place of each whose option is on, filled with a fake member
by `Preview.Decorate`.
Test mode ends when the options window closes or combat starts (Options.lua).

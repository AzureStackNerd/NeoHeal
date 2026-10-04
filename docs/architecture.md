# Architecture

## Namespace and modules

Every file starts with `local _, NeoHeal = ...` and adds one table to the shared
addon namespace (`NeoHeal.Layout`, `NeoHeal.UnitButton`, ...). There are no
globals besides the saved variables, the slash command and a few named frames
(`NeoHealFrame`, `NeoHealGroup1..8`, `NeoHealMainTanks`, `NeoHealPets`,
`NeoHealOptionsFrame`, `NeoHealResHandler`).

Load order (`NeoHeal.toc`) matters only at file scope. Most cross-module calls
happen at runtime, after `PLAYER_LOGIN`.

```
Locales/enUS.lua → Core → Spells → Dispel → AuraContainer → Hots → MissingBuffs
→ ClickCast → UnitButton → Layout → Preview → Blizzard → Options
```

## Module responsibilities

| Module | Owns | Key functions |
| --- | --- | --- |
| **Core** | Defaults, migrations, global events, the out-of-combat queue, `/neoheal` | `RunOutOfCombat`, `IsSecret/IsTrue/IsFalse`, `Print` |
| **Spells** | Spellbook scan grouped by name with all ranks | `Scan`, `GetHighestRank`, `GetRankText` |
| **Dispel** | Debuff types the player can cure; colour curve and filter for the dispel strip | `UpdateKnownDispels`, `GetColorCurve`, `GetBorderFilters` |
| **AuraContainer** | Wrapper around Blizzard's `CustomAuraContainerTemplate`; the shared countdown font | `Create`, `CreateDispelStrip`, `SetUnit`, `SetShown`, `AddTimedCooldown` |
| **Hots** | Own-HoT icons (Lua-drawn out of combat, container in combat) | `Attach`, `SetUnit`, `Update`, `RefreshSizes`, `ShowPreview` |
| **MissingBuffs** | Missing class-buff icon; `*spell-neobuff` attribute for the buff click | `Attach`, `Update`, `UpdateClick`, `ExplainClick` |
| **ClickCast** | Bindings ↔ secure attributes, hover keys, auto-res snippet, class defaults | `Initialize`, `Set`, `BuildAttributes`, `Apply`, `ApplyToButton`, `QueueApply`, `AddBindingsToTooltip`, `GetModifierPrefix` |
| **UnitButton** | Visuals and per-unit event handling of one frame | `CreateVisuals`, `Init`, `UpdateAllButtons`, `UpdateAllAuras`, `RefreshAuraContainers` |
| **Layout** | Container, 8 group headers + main tank + pet header, arrangement, titles, move mode, size presets, test mode | `Create`, `Refresh`, `Arrange`, `FitToContent`, `SetTestMode`, `GetSize` |
| **Preview** | Fake members for test mode, using `UnitButton.CreateVisuals` | `Show`, `Hide` |
| **Blizzard** | Re-parents Blizzard group frames into a hidden frame | `ApplyHiding` |
| **Options** | The options window; Layout page generated from `LAYOUT_SETTINGS` | `Toggle`, `RefreshLayoutPage`, `RefreshBindingRows`, `RefreshClickCastingPage` |

## Start-up (`PLAYER_LOGIN`)

1. Create the saved variables, fill in defaults (`ApplyDefaults` only adds missing
   keys), run migrations. See [saved-variables.md](saved-variables.md).
2. `Spells:Scan()` → `Dispel:UpdateKnownDispels()` → `MissingBuffs:UpdateKnownBuffs()`.
3. `ClickCast:Initialize()` (class defaults on a character's first login).
4. Out of combat: `Layout:Create()` → `ClickCast:Apply()`.
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
                 ├─ hooks: OnEnter/OnLeave (tooltip + bindings), OnClick (debug), PostClick (buff explain)
                 ├─ child frame `events` for unit events (no secure frame touched)
                 ├─ OnAttributeChanged "unit" ──► SetUnit
                 └─ RunOutOfCombat: RegisterForClicks, ApplyToButton (hover snippets),
                                    SecureHandlerWrapScript(OnClick, RES_SNIPPET)
```

`SetUnit(button, unit)` runs whenever the header gives a button a new unit. It
re-registers unit events for the new unit, points the aura containers at it
(or queues building them), and calls `UpdateAll`.

### Updates

`UpdateAll` calls one function per aspect: `ApplyStyle`, `UpdateIdentity`,
`UpdateHealth` (which also updates the low-health tint, incoming heals and
absorbs), `UpdatePower`, `UpdateRange`, `UpdateAuras`, `UpdateAggro`,
`UpdateRaidTarget`, `UpdateTargetHighlight`, `UpdateLeader`,
`UpdateStatusIcon`.

Unit events map to these functions in `EVENT_UPDATES` (UnitButton.lua).
`UNIT_AURA` is **batched**: it marks the button, and all marked buttons are
scanned once after 0.1s. Range is also polled every second as a backup.

Global events (Core.lua) fan out to the `UnitButton:Update*` loops over all
buttons:

| Event | Effect |
| --- | --- |
| `GROUP_ROSTER_UPDATE` | Update all buttons; out of combat: `Arrange`, or a full `Refresh` if party ↔ raid switched preset; re-hide Blizzard frames |
| `PLAYER_ROLES_ASSIGNED` | Update all buttons (role icon, healer-only power bar) |
| `UNIT_PET` | Re-arrange (pet column) |
| `PLAYER_REGEN_DISABLED/ENABLED` | Missing buffs off/on; refresh auras (switch Lua icons ↔ containers); run queued work |
| `PLAYER_TARGET_CHANGED`, `UNIT_TARGET` (target) | Target / targeted borders |
| `RAID_TARGET_UPDATE`, `PARTY_LEADER_CHANGED` | Top icons |
| `READY_CHECK*` | Centre icon; lingers 5s after the check ends |
| `SPELLS_CHANGED` | Debounced 0.5s: rescan spells, dispels, buffs; re-apply bindings (highest rank); refresh the click casting rows if that page shows |

## Layout

- `Refresh()` applies **all** settings (out of combat only). It picks the size
  preset, applies scale and position, then hides each header, sets its
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
  `SetBindingClick` for the key with every modifier.
- **Target and Open unit menu** keep the game's types (`target`, `togglemenu`)
  only on plain left and right click. Everywhere else Blizzard's click bindings
  would drop those types (see [forever-api.md](forever-api.md)), so the slot gets
  `neotarget` or `neomenu`. A `neotarget` click goes through RES_SNIPPET to the
  virtual button `neotarget`, `neotarget-target` or `neotarget-targettarget`
  (following the slot's `unitsuffix`), each a `/target mouseover…` macro. For a
  `neomenu` click the game calls `button.neomenu` (`ClickCast.OpenUnitMenu`, set
  by `ApplyToButton`) outside secure code.
- **RES_SNIPPET** wraps each button's `OnClick` in the secure environment. On a
  dead friendly unit it redirects spell/macro clicks to the virtual button
  `neores`. It sends `neotarget` clicks to their `/target` macro, also on a dead
  unit. For `neobuff` it returns `"neobuff"` (cast `*spell-neobuff`) or
  `false` (cancel). It reads modifiers the way the game does, every one held as
  `alt-ctrl-shift-` (like `ClickCast.GetModifierPrefix`), so with two held it
  redirects nothing.
- **The tooltip** (`ClickCast:AddBindingsToTooltip`) lists the bindings as last
  applied to the frames (`appliedBindings` and `appliedHoverKeys`, set by
  `Apply`), for the modifiers held now.
- **Also target** turns the binding into a two-line macro using `mouseover`.

## Test mode

`Layout:SetTestMode(size)` hides the real headers, and `Refresh` hands off to
`Preview:Show(size)`. That builds plain frames with the same
`UnitButton.CreateVisuals` and decorates them with fake data. The preview reuses
the exported helpers (`ApplyStyle`, `LayoutBars`, `ShowsPowerBar`,
`ShowHealthText`, `ShowLowHealth`, `SetStatusIcons`, `Hots.ShowPreview`,
`MissingBuffs.ShowPreview`) so it stays visually identical. Test mode ends when
the options window closes or combat starts (Options.lua).

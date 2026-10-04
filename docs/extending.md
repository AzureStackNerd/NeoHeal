# Extending NeoHeal

Recipes for the common kinds of change. Read [forever-api.md](forever-api.md)
first.

## Add a layout setting (checkbox or choice)

1. **Default:** add the key to `DEFAULTS.layout` in `Core.lua`, with a comment
   listing the values.
2. **Strings:** add the label (and choice labels) to `Locales/enUS.lua`.
3. **Options:** add one row to `LAYOUT_SETTINGS` in `Options.lua`:
   ```lua
   { kind = "checkbox", key = "showFoo", label = L.SHOW_FOO },
   { kind = "choice",   key = "fooMode", label = L.FOO_MODE, choices = {
       { value = "a", label = L.FOO_A }, { value = "b", label = L.FOO_B } } },
   ```
   Changing it calls `Layout:Refresh()` out of combat. That ends in
   `UnitButton:UpdateAllButtons()`, so the update functions only need to read
   `NeoHeal.db.layout.fooMode`.
4. **Use it** in the relevant `Update*` function in `UnitButton.lua`.
5. **Preview:** if it changes how a frame looks, make `Preview.lua`'s `Decorate`
   follow it too. Prefer an exported helper shared by both, like
   `UnitButton.ShowHealthText`.

A size-like value that should differ between party and raid goes into both
`sizes.party` and `sizes.raid`, with `size = true` on the settings row.

## Add a new visual element to the frame

1. Create it in `UnitButton.CreateVisuals(frame)`. Respect the frame-level
   order: background < health < incoming/prediction/absorb (+1) < HoT icons (+2) <
   overlay text (+3) < borders (+4) < dispel strip (+5).
2. Write an `UpdateFoo(button)` function and call it from `UpdateAll`.
3. If an event drives it, add `UNIT_FOO = UpdateFoo` to `EVENT_UPDATES` (unit
   events) or a handler in `Core.lua` (global events) that loops over
   `UnitButton.buttons`.
4. Treat every API value as possibly secret.
5. Top-right icons must go through `LayoutTopIcons`, so the name clips correctly.
6. A bar after the health fill goes into `AMOUNT_BARS` (UnitButton.lua), in
   drawing order, and its update ends with `AnchorAmountBars(button)`. Every
   button must have it, as `AnchorAmountBars` doesn't check: create it with
   `CreateAmountBar` in `CreateVisuals`, give it its texture and colour in
   `ApplyStyle`, and add it to `Support.FakeButton` for the tests.

## Track another class's HoTs

Add the class to `HOT_SPELLS` in `Hots.lua` with **rank 1** spell IDs. They are
matched by name, so every rank counts. In combat only filter + duration apply
(`MAX_DURATION = 30`). A HoT longer than 30s needs that limit raised, which lets
more of your own long buffs into the combat display.

## Add a cure spell or debuff type

Add the spell to `DISPEL_SPELLS` in `Dispel.lua`. A new debuff type also needs
an entry in `Dispel.COLORS` and the game's number in `DISPEL_TYPE_NUMBERS`.

## Add a class buff to "missing buffs"

Add an entry to `CLASS_BUFFS` in `MissingBuffs.lua`: `spells` (single first,
then group version), `group`, `reagent`, and optionally `manaOnly`.

## Add a click action

1. Add a value to `ACTION_TYPES` in `ClickCast.lua` (the secure `type`
   attribute it becomes). A type of `target`, `menu` or `togglemenu` also needs
   a `FALLBACK_TYPES` entry: Blizzard's click bindings drop those types except on
   plain left and right click ([forever-api.md](forever-api.md), section 4).
2. Handle it in `BuildAttributes`, in `Describe`, and in the action menu
   (`BuildActionMenu` in `Options.lua`). If "Cast on" doesn't apply, also update
   the target dropdown's enabled check in `CreateBindingRow`.
3. Any attribute a binding writes must be listed in `ClickCast.ATTRIBUTE_NAMES`.
   Otherwise the header won't copy it to new buttons and an old value won't be
   cleared.
4. Logic that has to decide *at click time* belongs in `RES_SNIPPET`. That runs
   in the restricted secure environment: no addon Lua, only
   attributes and `SecureCmdOptionParse`.

## Add a class to the defaults or res spells

`CLASS_DEFAULTS` and `RES_SPELLS` in `ClickCast.lua`. Spells the character hasn't
learned are skipped.

## Add a language

Create `Locales/deDE.lua`, list it in `NeoHeal.toc` after `enUS.lua`, and start it with:

```lua
if GetLocale() ~= "deDE" then return end
local L = select(2, ...).L
```

Only override the keys you translate. Missing keys fall back to English, and
unknown keys show their own name.

## Register a new global event

Add a `function NeoHeal:EVENT_NAME(...)` in `Core.lua` and add the name to the
list at the bottom. The list skips events this client doesn't know. Guard with
`if not self.db then return end` if the event can fire during login.

## Automated tests

Run `lua spec/run.lua` from the addon folder, or `lua <full path>/spec/run.lua`
from anywhere else (not `lua run.lua` from inside `spec/`). It needs plain Lua (5.1 or newer) and
nothing else: LuaUnit is included as `spec/luaunit.lua`. The game never loads
`spec/`, because the folder isn't listed in `NeoHeal.toc`.

- `spec/support.lua` fakes the parts of the game API the tested files need,
  including a small spellbook (Flash Heal ranks 1–7, and Abolish Disease, which
  has no rank). `Support.Load({ files })` loads addon files into a fresh namespace.
- One `*_test.lua` per module or feature, listed in `spec/run.lua`.
- Covered now: spell ranks, click-cast bindings, the row text, macros, event
  wiring, the tooltip (hovering, the binding lines and their heal amounts, the
  switch when a modifier changes), the heal prediction (which left click it
  reads, and its heal and shield bars on hover, with Weakened Soul and hidden
  auras, and where each bar is anchored; `Support.FakeBar` records a bar and
  `Support.FakeButton` holds a button's bars), clicks
  with modifiers (`RES_SNIPPET` runs as plain Lua with fakes for the secure
  environment), and the options window's click-casting menu.
  `spec/options_test.lua` builds the real window on fake frames that record each
  dropdown's menu builder, so a test can click through a menu. Fake frames from
  `CreateFrame` keep their scripts and events, so a test can fire an event at
  them. Not covered: how the unit frames look, and the layout. Anything that
  depends on the real client stays on the checklist below.
- Before trusting a new test, break the code it covers in a copy of the addon
  and check that the test fails.

## Manual test checklist

In game:

- `/reload` with no Lua errors (use BugSack or `/console scriptErrors 1`).
- Test mode 5 / 10 / 25 / 40 with the option toggled both ways.
- Solo, party, raid; a party → raid conversion **in combat** (the preset must
  switch only after combat).
- Enter combat with the feature active: no "secret value" or "action blocked" errors.
- `/neoheal debug` and `/neoheal clicks` for aura and binding issues.

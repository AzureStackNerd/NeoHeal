# Rules of the WoW: Forever client

WoW: Forever runs Classic-era content on the retail 12.x client. Three things in
that client shape almost every design choice in NeoHeal. Most bugs come from
breaking one of them.

## 1. Combat lockdown

Secure frames are the unit buttons, their group headers and anything they are
anchored to. In combat (`InCombatLockdown()`) you can't create them, resize
them, move them, set their attributes or register their clicks.

**Rule:** anything that touches a secure frame goes through the out-of-combat queue:

```lua
NeoHeal:RunOutOfCombat("someKey", function() ... end)
```

It runs now, or on `PLAYER_REGEN_ENABLED`. Queuing the same key twice runs it
once (the last function wins), so pick a key per job, e.g. `"layout"`,
`"applyBindings"`, or `"setupButton" .. button:GetName()` for per-button work.

What still works in combat:

- Secure group headers add, remove and reorder buttons by themselves. That's
  why the layout is built on `SecureGroupHeaderTemplate`, and why click
  bindings are copied onto new buttons by the header's `initialConfigFunction`
  (a snippet that runs in the secure environment), not by Lua.
- Plain (non-secure) frames can change freely. Range fading is applied to
  `button.content`, a plain child frame, because the secure button's own
  alpha is locked.
- Showing and hiding `AuraContainer`s.

`Layout:PreCreateButtons()` creates all five buttons per group in advance:
a button created in combat can't register clicks until combat ends.

## 2. Secret values

In combat (and for some data always), the API returns **secret values**. A
secret value can be **displayed**: passed to `StatusBar:SetValue`,
`FontString:SetText`, `SetVertexColor` and similar. **Comparing it, testing it
or doing arithmetic with it raises an error.**

Helpers in `Core.lua`:

| Helper | Meaning |
| --- | --- |
| `NeoHeal.IsSecret(v)` | `issecretvalue`, or always false on clients without it |
| `NeoHeal.IsTrue(v)` | readable **and** truthy |
| `NeoHeal.IsFalse(v)` | readable **and** falsy |

Patterns used across the code:

- **Never write `if value then`** on API results that may be secret. Use
  `IsTrue` / `IsFalse`, or `if not IsSecret(x) and not x`.
- **Equality against a constant is safe:** `role == "MAINTANK"`. A secret
  value never equals anything, so the result is just `false`.
- **Curves instead of maths.** `UnitHealthPercent(unit, true, curve)` maps the
  (secret) fraction through a `C_CurveUtil` curve. The result is secret too,
  but a widget accepts it. Used for: health percentage text, the health colour
  gradient, the low-health tint (alpha jumps to 0 above 35%), and fading out
  the deficit text at full health.
- **Let the game apply a boolean:** `frame:SetAlphaFromBoolean(secretBool, 1, 0.4)`
  for range fading and target borders.
- **`pcall` around experiments** that may be refused on some builds, e.g.
  putting a secret amount on the incoming-heal bar.
- Known-secret data: health, aura data (in combat), `UnitIsUnit` (on maps where
  the game restricts addons; there always for compound tokens such as
  `targettarget`),
  `UnitInRange`, raid target index (**always**, even out of combat;
  `SetRaidTargetIconTexture` still accepts it), sometimes roles and classes.

## 3. Auras: addons can't read them in combat

`C_UnitAuras.GetAuraDataByIndex` returns secret data in combat ("Auras cannot
be accessed when secret while tainted"). NeoHeal handles this in two ways:

- **Out of combat:** read the aura data and draw our own icons (HoTs, missing buffs).
- **In combat:** hand Blizzard's `AuraContainer` (`CustomAuraContainerTemplate`)
  a **filter**. Blizzard's code fills our textures and cooldowns without the
  addon ever seeing the data. See `AuraContainer.lua`.

Hard rules for containers:

1. Never create or enable one in combat. The client errors in a way `pcall`
   can't catch.
2. Build order: create → anchor → `SetUnit` → `AddAuraGroup`/`AddAuraSlot` →
   `SetEnabled(true)` last.
3. Containers can't be resized. On a size change, hide the old one and build a
   new one (`Hots.RefreshSizes`, `BuildRaidDebuffContainer`).
4. Showing/hiding and `SetUnit` are fine in combat.

Containers can only filter by **filter string** (`HELPFUL|PLAYER`,
`HARMFUL|!RAID|!PLAYER`), `maxDuration`, and `includeDispelTypes`. They can't
filter by spell name. So in combat the HoT container shows *every* buff you cast
of 30s or less (a known limitation: Spirit Tap shows on your own frame).

The dispel strip is a single aura slot whose dispel-type texture is coloured by
a step colour curve (`Dispel:GetColorCurve`). Types you can't remove map to
transparent. The technique comes from Decursive.

## 4. Blizzard's click bindings can drop Target and Menu clicks

Forever has Blizzard's own click-binding system (`C_ClickBindings`, the Click
Casting window: `/run ToggleClickBindingFrame()`). In `SecureUnitButton_OnClick`
(`Blizzard_FrameXML/SecureTemplates.lua`), a click whose type is `target`, `menu`
or `togglemenu` only goes through if that system holds an *Interaction* binding
for the same mouse button and modifiers. With Blizzard's default bindings those
are only plain left click (Target) and plain right click (Open menu). Every other
click with these types is dropped silently, including clicks from hover keys.

NeoHeal therefore uses the game's types only on plain left and right click, and
its own `neotarget` / `neomenu` everywhere else. See "Click casting data flow" in
[architecture.md](architecture.md). This assumes Blizzard's defaults. If you
rebind Target or Open menu in the Click Casting window, plain left/right Target
or Menu can be dropped too. A spell, macro or pet action bound there runs
instead of what NeoHeal binds on that button and modifiers. The exception is a
click the click snippet redirects: Target off plain left and right click, Cast
missing buff, and the res on a dead member. That click reaches Blizzard's check
under NeoHeal's own virtual button name, which Blizzard's bindings don't cover.
This follows from the source and hasn't been checked in the game.

## Checklist before shipping a change

- [ ] Does it touch a secure frame or attribute? → `RunOutOfCombat`.
- [ ] Could any API value be secret? → no `if`, no `<`, no `+` on it.
- [ ] Does it read auras? → it needs a combat path through `AuraContainer`, or it hides in combat.
- [ ] Does it register a new event? → guard with `C_EventUtils.IsEventValid`.
- [ ] Test in combat, with a raid marker, and with `/neoheal debug`.

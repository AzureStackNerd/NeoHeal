# NeoHeal

Click-cast raid frames for **WoW: Forever** (Classic-era content on the retail 12.x client API, Interface 16001). Plain Lua addon, no libraries, no build step.

Tests: `lua spec/run.lua` from the addon folder (LuaUnit, included in `spec/`; the game never loads `spec/`). They cover logic that runs outside the game against a fake API in `spec/support.lua`. The options window can be built on fake frames (see `spec/options_test.lua`); the unit frames and layout aren't covered and are tested in game with `/reload`. A new test must be seen failing on a broken copy of the code before it counts.

Docs live in `docs/`: start with `docs/forever-api.md` (client rules) and `docs/architecture.md` (modules, data flow). Recipes for common changes are in `docs/extending.md`. Update the docs when behaviour, settings or module responsibilities change.

## Hard rules

- **Combat lockdown:** anything touching a secure frame (unit buttons, group headers, their attributes, anything anchored to them) goes through `NeoHeal:RunOutOfCombat(key, func)`.
- **Secret values:** API results such as health, auras in combat, `UnitIsUnit`, range and raid marker index may be secret. Never test, compare or do arithmetic on them. Use `NeoHeal.IsSecret / IsTrue / IsFalse`, curves (`C_CurveUtil`), `SetAlphaFromBoolean`, or pass them straight to a widget.
- **Auras in combat** can only be shown through `AuraContainer.lua` (Blizzard-drawn, filter-based). Never create or enable a container in combat.
- Guard new events with `C_EventUtils.IsEventValid` (see `Core.lua`).
- New settings: a default in `Core.lua` `DEFAULTS`, a string in `Locales/enUS.lua`, a row in `LAYOUT_SETTINGS` (`Options.lua`). Make test mode (`Preview.lua`) show it too.
- Renamed or reshaped settings need a migration in `NeoHeal:PLAYER_LOGIN`.

## Code style

- Each file: `local _, NeoHeal = ...`, one module table on the namespace, file-level comment explaining the why.
- Comments explain reasons and Forever quirks in plain sentences; keep that density.
- All user-visible text goes through `L` (`Locales/enUS.lua`).
- 4-space indent, `PascalCase` functions, `UPPER_CASE` constants, `camelCase` locals.

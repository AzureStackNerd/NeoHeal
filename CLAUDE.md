# NeoHeal

Click-cast raid frames for **WoW: Forever** (Classic-era content on the retail 12.x client API, Interface 16001). Plain Lua addon, no libraries, no build step.

Tests: `lua spec/run.lua` from the repository root (LuaUnit, included in `spec/`; the game never loads `spec/`). The repository is not the game's addon folder: to try a change in game, copy the changed files there and `/reload` (a new file needs a full restart). The tests run the addon's files against a fake API and fake frames in `spec/support.lua`. On fake frames are the options window and its hover-key capture (`spec/options_test.lua`), the target and focus frames (`spec/targetfocus_test.lua`) and low mana (`spec/lowmana_test.lua`); the group headers and the rest of the layout aren't covered and are checked in game. A new test must be seen failing on a broken copy of the code before it counts.

Releases: pushing a `v*` tag runs `.github/workflows/release.yml`, which runs the tests and the release stops in `spec/release.lua` (tag against the toc version, the notes, the project id, the game version) and then uploads to CurseForge. A pull request into `main` or a hand start builds the ZIP and stops before the upload. `docs/curseforge.md` covers the rest.

Stories and bugs are delivered with `.claude/delivery.md`: where the backlog lives (only bugs are public issues; stories and in-game checks are items on a private project), the commands, and the rules for briefs and done.

Docs live in `docs/`: start with `docs/forever-api.md` (client rules) and `docs/architecture.md` (modules, data flow). Recipes for common changes are in `docs/extending.md`. Update the docs when behaviour, settings or module responsibilities change.

## Hard rules

- **Combat lockdown:** anything touching a secure frame (unit buttons, group headers, their attributes, anything anchored to them) goes through `NeoHeal:RunOutOfCombat(key, func)`.
- **Secret values:** API results such as health, auras in combat, `UnitIsUnit`, range and raid marker index may be secret. Never test, compare or do arithmetic on them. Use `NeoHeal.IsSecret / IsTrue / IsFalse`, curves (`C_CurveUtil`), `SetAlphaFromBoolean`, or pass them straight to a widget.
- **Auras in combat** can only be shown through `AuraContainer.lua` (Blizzard-drawn, filter-based). Never create or enable a container in combat.
- **Click types `target`, `menu`, `togglemenu`** only work on plain left/right click: Blizzard's click bindings drop them elsewhere. Use `neotarget` / `neomenu` there (`docs/forever-api.md`, section 4).
- Guard new events with `C_EventUtils.IsEventValid` (see `Core.lua`).
- New settings: a default in `Core.lua` `DEFAULTS`, a string in `Locales/enUS.lua`, a row in `LAYOUT_SETTINGS` (`Options.lua`). Make test mode (`Preview.lua`) show it too.
- Renamed or reshaped settings need a migration in `NeoHeal:PLAYER_LOGIN`.

## Code style

- Each file: `local _, NeoHeal = ...`, one module table on the namespace, file-level comment explaining the why.
- Comments explain reasons and Forever quirks in plain sentences; keep that density.
- All user-visible text goes through `L` (`Locales/enUS.lua`).
- 4-space indent, `PascalCase` functions, `UPPER_CASE` constants, `camelCase` locals.

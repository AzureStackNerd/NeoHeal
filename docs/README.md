# NeoHeal documentation

NeoHeal is a small click-cast raid frame addon for party and raid healing on
**WoW: Forever** (the Classic-era game running on the retail 12.x client API).
Interface version `16001`, addon version `0.2.0`.

| Document | For whom | What's in it |
| --- | --- | --- |
| [features.md](features.md) | players | Everything the addon does, every option, slash commands |
| [architecture.md](architecture.md) | developers | Modules, load order, start-up, events, how a frame is built and updated |
| [forever-api.md](forever-api.md) | developers | The rules of the Forever client: combat lockdown, secret values, Blizzard-drawn auras. **Read this before changing code.** |
| [saved-variables.md](saved-variables.md) | developers | `NeoHealDB` / `NeoHealCharDB` layout, defaults and migrations |
| [extending.md](extending.md) | developers | Recipes: add a setting, a class's HoTs, a cure spell, a buff, a language, an event |

## Repository layout

```
NeoHeal.toc          load order and saved variables
Locales/enUS.lua     strings (L); loads first
Core.lua             saved variables, global events, out-of-combat queue, /neoheal
Spells.lua           spellbook scan, spell ranks
Dispel.lua           which debuff types you can remove; colour curve for the dispel strip
AuraContainer.lua    Blizzard-drawn aura icons (the only way to show auras in combat)
Hots.lua             your own HoT icons, bottom-right of each frame
MissingBuffs.lua     "missing raid buff" icon and the cast-missing-buff click
ClickCast.lua        bindings -> secure attributes, hover keys, auto-res
UnitButton.lua       the look and live updates of one unit frame
Layout.lua           secure group headers, arrangement, size presets, moving
Preview.lua          test mode: fake raid members
Blizzard.lua         optionally hides Blizzard's party/raid frames
Options.lua          the /neoheal options window
spec/                tests, run with `lua spec/run.lua` (not loaded by the game)
```

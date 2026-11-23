# NeoHeal documentation

NeoHeal is a small click-cast raid frame addon for party and raid healing on
**WoW: Forever** (the Classic-era game running on the retail 12.x client API).
Interface version `16001`, addon version `0.8.1`.

## What it does

Everything below is described in full, with every option, in [features.md](features.md).

- **Click casting:** five mouse buttons and three hover keys, each with no modifier, Shift, Ctrl or Alt.
  Cast any spell at its highest rank, the rank below it ("Highest rank -1") or a fixed rank, on the
  unit, its target or its target's target, and optionally target them in the same click. Target, open
  the unit menu, or cast the raid buff a member is missing. A spell click on a dead member casts your
  resurrection.
- **See what a click does:** the tooltip lists your bindings, per modifier, with how much each heal heals
  or each shield absorbs. The frame under your mouse shows how much your left click would heal (heal
  prediction), and a shield's absorb.
- **Frames:** one column per group, separate sizes for party and raid, optional main tanks, pets, and a
  target and a focus frame with the same click casting. Class or health colours, incoming heals,
  shields, a low-health tint, health as a percentage or as health missing.
- **What a frame shows:** debuffs you can't dispel and a strip for those you can; your own HoTs and
  shields with timers; who lacks your raid buff; aggro, your target, who your enemy targets, raid
  markers, role and leader icons, ready checks, resurrections and summons; range fading.
- **Mana:** a blue "OOM" on healers at 20% mana or less, and the five-second rule: after a spell that
  costs mana, a bar on your own mana strip runs empty in 5 seconds, when your regeneration is back.
- **The cancel cue:** while you cast a heal on a member from their frame, a band at the bottom of that
  frame shows gold while the heal is needed and red once they are back above 90%, so you can cancel
  and keep the mana.
- **Options:** `/neoheal` or the addon compartment icon; test mode shows a fake group of 5, 10, 25 or
  40 players.

| Document | For whom | What's in it |
| --- | --- | --- |
| [features.md](features.md) | players | Everything the addon does, every option, slash commands |
| [architecture.md](architecture.md) | developers | Modules, load order, start-up, events, how a frame is built and updated |
| [forever-api.md](forever-api.md) | developers | The rules of the Forever client: combat lockdown, secret values, Blizzard-drawn auras. **Read this before changing code.** |
| [saved-variables.md](saved-variables.md) | developers | `NeoHealDB` / `NeoHealCharDB` layout, defaults and migrations |
| [extending.md](extending.md) | developers | Recipes: add a setting, a class's HoTs, a cure spell, a buff, a language, an event |
| [curseforge.md](curseforge.md) | the maintainer | Publishing on CurseForge: what a release tag does, the project fields, texts to paste, building a ZIP by hand for a test build |

## Repository layout

```
NeoHeal.toc          load order, saved variables, addon compartment entry
Locales/enUS.lua     strings (L); loads first
Core.lua             saved variables, global events, out-of-combat queue, /neoheal, compartment entry
Spells.lua           spellbook scan, spell ranks
Dispel.lua           which debuff types you can remove; colour curve for the dispel strip
AuraContainer.lua    Blizzard-drawn aura icons (the only way to show auras in combat)
Hots.lua             your own HoT icons, bottom-right of each frame
MissingBuffs.lua     "missing or running-out raid buff" icon and the cast-missing-buff click
ClickCast.lua        bindings -> secure attributes, hover keys, auto-res
UnitButton.lua       the look and live updates of one unit frame
TargetFocusFrames.lua  the optional target and focus frames above the group frames
Layout.lua           secure group headers, arrangement, size presets, moving
Preview.lua          test mode: fake raid members
Blizzard.lua         optionally hides Blizzard's party/raid frames
Options.lua          the /neoheal options window
spec/                tests, run with `lua spec/run.lua` (not loaded by the game)
```

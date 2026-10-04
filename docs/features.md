# Features

## Opening the options

- `/neoheal` opens or closes the options window (Escape closes it too).
- Esc > Options > AddOns > NeoHeal has a button that opens the same window.
- `/neoheal debug` prints which HoT and raid marker data the game hides right
  now. Run it in combat to see what Forever hides.
- `/neoheal clicks` turns click debugging on or off: every click on a frame
  prints which mouse button arrived and what it is bound to.

While the options window is open the frames are in **move mode**: a green
overlay that you can drag. Outside move mode, **Ctrl + drag** a title ("NeoHeal"
bar, or a "Group N" label in a raid) to move the frames. Nothing moves in
combat.

## The frames

One column per raid group (1–8). Only groups with members take up room, so a
party shows one column and a full raid eight. The frames are pinned by their
top-left corner and grow to the right and down.

- **Solo or party:** one "NeoHeal" title bar above all frames.
- **Raid:** a label above every column ("Group 1", "Main tanks", "Pets").
- **Main tank group** (optional): raid members marked as Main Tank, before group
  1 or after everything. They also stay in their own group.
- **Pets** (optional): their own column(s) after the groups.

### What one frame shows

| Where | What |
| --- | --- |
| Health bar | Class colour (pets green), or green → yellow → red by health |
| After the health fill | Incoming heals (light green), then shields/absorbs (pale blue) |
| Empty part of health bar | Turns red below 35% health |
| Bottom strip | Resource bar (mana/rage/energy) for everyone, healers only, or nobody |
| Top left | Name, cut off at the icons (no "...") |
| Top right | Raid marker, role icon (main tank / main assist / tank / healer), leader crown or assist flag |
| Bottom left | Health text: percentage, health missing (`-2340`), or off. "Dead" / "Offline" |
| Bottom right | Up to 3 of **your own** HoTs with a cooldown swipe and optional countdown |
| Bottom right, 3rd slot | Out of combat: grey icon with red edge = this member lacks your class's raid buff |
| Centre, below the name | Up to 2 raid debuffs (e.g. boss debuffs), 1.5× the HoT icon size |
| Centre | Ready check answer, incoming resurrection, or incoming summon |
| Left edge | Dispel strip in the debuff type's colour, only for types **you** can remove (Magic blue, Curse purple, Disease brown, Poison green) |
| Top edge | Red line while the member has aggro |
| Border | White: your current target. Red: who your hostile target is targeting |
| Whole frame | Fades to 40% when out of range |

HoTs tracked per class: Priest Renew + Power Word: Shield, Druid Rejuvenation +
Regrowth. Other classes show no HoT icons.

Missing buffs per class: Priest Fortitude (+ Divine Spirit if talented), Druid
Mark of the Wild, Mage Arcane Intellect (not for warriors and rogues). Paladin
blessings are left out on purpose.

## Click casting (per character)

Pick a modifier (none, Shift, Ctrl, Alt), then choose per mouse button what a
click does. Five mouse buttons plus three **hover keys**: keyboard keys that
"click" the frame under the mouse (left click the key button to set, right click
to clear).

Actions:

- **None**
- **Target**
- **Open unit menu**
- **Cast missing buff**: casts the buff whose icon shows on that frame. In a raid
  it uses the group version if you know it and carry the reagent. Out of combat
  only, and not during a ready check. Otherwise the click does nothing and
  explains why in red at the top of the screen.
- **A spell** from your spellbook: "Highest rank" (follows new ranks you learn),
  "Highest rank -1" (the rank below that, also follows; useful as a cheaper,
  mana-efficient heal), or a fixed rank. The rank choices show only for spells
  with two or more ranks.

Per binding:

- **Cast on**: the clicked unit, its target, or its target's target.
- **Also target**: cast *and* target the unit in one click (spells only).

**Auto-resurrect:** a spell click on a dead friendly member casts your res
spell instead (Priest Resurrection, Paladin Redemption, Shaman Ancestral Spirit,
Druid Rebirth). Target and menu clicks keep working.

**Reset to class defaults** restores the starting bindings: left = Target,
right = menu, plus the class's main heals and cures where learned.

## Layout options (account-wide)

Left column:

| Option | Choices |
| --- | --- |
| Frame style | Forever (flat, dark) · Classic (stone, tooltip border) |
| Health bar color | Class · Health (green to red) |
| Sort members | Raid order · By name · Tanks, healers, damage · By class |
| Main tank group | None · First · Last |
| Health text | Percentage · Health missing · Off |
| Resource bar | Everyone · Healers only · Off |
| Test mode | Off · 5 · 10 · 25 · 40 fake players (lasts while the window is open) |
| Button width / height, spacing, scale | Saved **per size preset** |

**Size presets:** sizes, scale and position are kept separately for *Party*
(solo and party) and *Raid*. The sliders edit the preset in use. In test mode,
5 players edits Party and 10+ edits Raid.

Right column (checkboxes): show when solo, raid debuffs, missing buffs, HoT
timers, incoming heals, aggro, tooltips, pets, hide Blizzard group frames
(turning this off again needs a `/reload`).

Changes made in combat are applied when combat ends. The window shows a red
notice while that is the case.

# CurseForge

Everything needed to publish NeoHeal on CurseForge: the project fields, the text
to paste, and how to build the release ZIP.

Requirements as found on 2026-10-04:

- The project name is unique and holds no game name, version or category.
- The summary is preferably one sentence about what sets the project apart.
- The description is in English, grammatically correct and describes the
  project well, without walls of text or "like X" comparisons.
- The logo is your own square PNG of at least 400×400, not a plain color or
  gradient.
- Files are `.zip`. A project only syncs to the CurseForge app once it has a
  file of type *Release*.

## Project fields

| Field | Value |
| --- | --- |
| Game | World of Warcraft (shown as "World of Warcraft Midnight" in the Author Console, the only WoW entry). Forever isn't a separate game: it's chosen per file, see [First file](#first-file). |
| Name | NeoHeal |
| Summary | See [Summary](#summary) |
| Description | See [Description](#description). Switch the editor to Markdown first: it starts in WYSIWYG, where `##` and `-` show as plain text. |
| License | MIT (the repo's `LICENSE`) |
| Logo | [`images/logo.png`](images/logo.png) (512×512, made for NeoHeal) |
| Media | [`images/Party5Options.png`](images/Party5Options.png), [`images/Test40Options.png`](images/Test40Options.png) and [`images/ClickCastingOptions.png`](images/ClickCastingOptions.png); the first two were uploaded on 2026-10-04 |
| Categories | Main: Unit Frames › Raid Frames. Also: Healer (combat roles) and Buffs & Debuffs; optionally the class categories Priest, Druid, Paladin and Shaman. All four were seen in the category list on 2026-10-04. |

### Summary

Click-cast party and raid frames for healers, with a tooltip that shows what
every click casts and how much it heals.

### Description

```markdown
NeoHeal is a small set of party and raid frames for healers on WoW: Forever. Bind your heals, cures and buffs to mouse clicks and keys, and cast them straight on the frame under your mouse.

## Click casting

- Five mouse buttons (left, right, middle, 4 and 5) and three hover keys, each with no modifier, Shift, Ctrl or Alt.
- Cast any spell from your spellbook: always the highest rank, the rank below it ("Highest rank -1", a cheaper heal that follows new ranks), or a fixed rank.
- Cast on the unit, its target or its target's target, and optionally target whoever you cast on in the same click.
- Target, open the unit menu, or cast the raid buff a member is missing (Priest, Druid and Mage).
- Priests, Paladins, Shamans and Druids: a spell click on a dead group member casts your resurrection instead (Rebirth for Druids).

## A tooltip that tells you what a click does

Hover a frame to see your bindings, and hold Shift, Ctrl or Alt to see that modifier's bindings. Each heal or shield shows how much the rank you cast heals or absorbs, for example "Healing Wave 237-280" or "942 absorb".

## Frames

- One column per group, with separate sizes for party and raid. Optional: a group of your raid's main tanks, and pets.
- Class or health colors, incoming heals, shields, a low-health tint, and health as a percentage or as health missing.
- Up to two debuffs you can't dispel, such as boss debuffs, and a colored strip for debuffs you can dispel.
- Priests and Druids: your own HoTs and shields with timers. Priests, Druids and Mages: out of combat, an icon shows who lacks your raid buff.
- Aggro, your target, the member your enemy target is targeting, raid markers, role and leader icons, ready checks, resurrections and summons. Members out of range fade.

## Options

Type /neoheal. Test mode shows a fake group of 5, 10, 25 or 40 players, so you can tune the look and layout without a raid.

Made for WoW: Forever (Interface 16001). The heal amounts are read from the spell descriptions of an English client.

NOTE: Inspired by HealBot which I loved to use for a long time
```

## First file

| Field | Value |
| --- | --- |
| File | `NeoHeal-0.3.0.zip` (see [Building the ZIP](#building-the-zip)) |
| Release type | Release |
| Game version | Only Forever (1.60.1); no Retail or Classic. This tag decides which installs the CurseForge app offers the file to. CurseForge doesn't check it against the `.toc` (`## Interface: 16001`), so keep the two in line. |

Changelog (Markdown, like the description):

```markdown
First release on CurseForge.

- Click casting with five mouse buttons, three hover keys and Shift/Ctrl/Alt; highest rank, "Highest rank -1" or a fixed rank; cast on the unit, its target or its target's target.
- A tooltip that lists your bindings and how much each heal or shield heals or absorbs.
- Party and raid frames with size presets, HoT timers, debuffs, a dispel strip, missing raid buffs, role icons and test mode.
```

## Building the ZIP

The ZIP must hold one folder, `NeoHeal/`, with the `.toc`, the `.lua` files,
`Locales/` and `LICENSE`. `.gitattributes` keeps `docs/`, `spec/`, `CLAUDE.md`
and the git files out, but only for what is committed: `git archive` reads the
tagged commit. So commit everything first, then tag, then build the ZIP outside
the AddOns folder:

```sh
git commit ...                      # the version in NeoHeal.toc and everything else
git tag v0.3.0
git archive --format=zip --prefix=NeoHeal/ -o "<outside the repo>/NeoHeal-0.3.0.zip" v0.3.0
```

Before uploading, list the ZIP's contents and check the version in its
`NeoHeal.toc`.

# CurseForge

Everything needed to publish NeoHeal on CurseForge: the project fields, the text
to paste, and how to build the release ZIP.

The project: <https://www.curseforge.com/wow/addons/neoheal>, approved on
2026-10-04 with version 0.3.0.

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
| Game | World of Warcraft (shown as "World of Warcraft Midnight" in the Author Console, the only WoW entry). Forever isn't a separate game: it's chosen per file, see [The file and its changelog](#the-file-and-its-changelog). |
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

NeoHeal is a small set of party and raid frames for healers on WoW: Forever. Bind your heals, cures and buffs to mouse clicks and keys, and cast them straight on the frame under your mouse.

## Click casting

- Five mouse buttons (left, right, middle, 4 and 5) and three hover keys, each with no modifier, Shift, Ctrl or Alt.
- Cast any spell from your spellbook: always the highest rank, the rank below it ("Highest rank -1", a cheaper heal that follows new ranks), or a fixed rank.
- Cast on the unit, its target or its target's target, and optionally target whoever you cast on in the same click.
- Target, open the unit menu, or cast the raid buff a member is missing (Priest, Druid and Mage).
- Priests, Paladins, Shamans and Druids: a spell click on a dead group member casts your resurrection instead (Rebirth for Druids).

## See what a click does

Hover a frame to see your bindings, and hold Shift, Ctrl or Alt to see that modifier's bindings. Each heal or shield shows how much the rank you cast heals or absorbs, for example "Healing Wave 237-280" or "942 absorb".

The frame under your mouse also shows how much your left click would heal: a lighter bar right after the incoming heals, which follows Shift, Ctrl and Alt too. A shield shows its absorb in blue, out of combat and only where that shield would land: Power Word: Shield on any member, another shield only on your own frame.

## Frames

- One column per group, with separate sizes for party and raid. Optional: a group of your raid's main tanks, and pets.
- Optional: a frame for your target and one for your focus, with the same click casting, to heal someone outside your group.
- Class or health colors, incoming heals, shields, a low-health tint, and health as a percentage or as health missing.
- Up to two debuffs you can't dispel, such as boss debuffs, and a colored strip for debuffs you can dispel.
- Priests and Druids: your own HoTs and shields with timers. Priests, Druids and Mages: out of combat, an icon shows who lacks your raid buff or has little of it left.
- Healers at 20% mana or less show a blue "OOM".
- The five-second rule: after a spell that costs mana, a bar on your own mana strip runs empty in 5 seconds, when your mana regeneration is back.
- The cancel cue: while you cast a heal on a member from their frame, a band at the bottom of that frame shows gold while the heal is needed and red once they are back above 90%, so you can cancel and keep the mana.
- Aggro, your target, the member your enemy target is targeting, raid markers, role and leader icons, ready checks, resurrections and summons. Members out of range fade.

## Options

Type /neoheal, or click the NeoHeal icon in the addon compartment beside the minimap. Test mode shows a fake group of 5, 10, 25 or 40 players, so you can tune the look and layout without a raid.

Does a click cast something other than you bound? Check the game's own Click Casting window (/run ToggleClickBindingFrame()): a spell bound there on the same button and modifiers wins over NeoHeal's binding.

Made for WoW: Forever (Interface 16001). The heal amounts are read from the spell descriptions of an English client.

NOTE: Inspired by HealBot which I loved to use for a long time

## Publishing a release

A release publishes itself: push its version tag and the GitHub workflow
`.github/workflows/release.yml` builds the ZIP and uploads it. Do this, in order:

1. Write the version's notes below, under a heading `### <version>`, exactly in that
   form (`### 0.7.0`). The workflow copies that section, and nothing else, to
   CurseForge; a missing or empty section stops the release.
2. Set `## Version:` in `NeoHeal.toc` to the same version. A tag that names another
   version stops the release, naming both.
3. Commit and push to `main`.
4. Tag and push the tag: `git tag v<version>` then `git push origin v<version>`. Only
   `vX.Y.Z` publishes (so `v0.7.0`, not `v0.7` or `v0.7.0-beta1`); another `v*` tag
   builds nothing and says so in its run.
5. Watch the run under Actions. Its log shows the Forever version and the ZIP's
   contents, and the file appears on the project's files page.

A wrong version, a version without notes, a missing or refused token, and an Interface
that CurseForge has no Forever version for all stop the run before anything is
uploaded, and its log names the reason.

The stops for the version, the notes, the project ID and the Forever version live in
`spec/release.lua`: the workflow runs it before the packager, and `lua spec/run.lua`
runs its checks too, through `spec/release_test.lua`. The token is checked by the
workflow step before it.

The project ID lives in `NeoHeal.toc`, as `## X-Curse-Project-ID: 1726356`, and the
packager uploads to the project that line names. `spec/release.lua` holds the same
number and stops the release when the toc names another.

**When a run fails, how to fix it depends on where the cause is.**

- The token, CurseForge's version list, or the network: check NeoHeal's files page on
  CurseForge first, because a network failure can happen after the upload went
  through. When no file for this version is listed there, fix the cause and use
  "Re-run failed jobs" on the failed run: it rebuilds from the same commit and tag.
  When a file for the version is already listed, the release went out; fix nothing
  and do not re-run.
- Something in the repository: the toc's version, the notes, the project ID. A
  re-run would use the same commit, so the fix has to be on the tag: delete the tag
  locally and on GitHub, tag the fixed commit, and push the tag again. That is a
  release step, so it happens only on Remco's word.

Do not re-run a run that already published: it is green, and a second run puts a second
file for that version in the players' list.

A pull request into `main` and "Run workflow" (a hand start) both build the ZIP and stop
before the upload, so the way a release is built can be checked without publishing
anything. "Run workflow" never publishes, even when it runs on a version tag: only a
tag push does.

### The file and its changelog

| Field | Value |
| --- | --- |
| File | `NeoHeal-v<version>.zip`, built by the BigWigs packager from the tagged commit |
| Release type | Release |
| Game version | Only Forever (1.60.1); no Retail or Classic. The workflow reads the Interface from `NeoHeal.toc` (`## Interface: 16001`) and stops when CurseForge has no Forever version for it, so keep the two in line. |
| Changelog | The `### <version>` section of this file, sent as Markdown |

### 0.8.0

- New: the cancel cue. While you cast a heal on a member by clicking their NeoHeal frame (or with a hover key), a thin band along the bottom of that frame's health bar shows gold while the heal is still needed, and turns red once the member is back above 90% health: cancel the cast and keep the mana, without restarting the five-second rule. It shows for heals on one member with a cast time, not for a res, a group heal or a cast from your action bar. "Show cancel cue" on the Layout page turns it off (on by default), and test mode shows both colours.
- Known limit: a click the game refuses (out of range, say), followed within half a second by the same heal cast from your action bar on someone else (any spell, if the game hides that cast's details), shows the band on the frame you clicked until that cast ends.

### 0.7.1

- Changed: the five-second bar no longer covers your mana. The resource bar is a bit higher (6 pixels instead of 4) and the five-second bar runs along its bottom, so your mana stays visible above it while it runs.
- Changed: mana is a lighter blue that is easier to see on the thin bar, close to the game's own mana bar under your portrait. Rage, energy and focus keep the game's colours.

### 0.7.0

- New: the five-second rule. After a spell that costs mana, a thin bar on your own frame's mana strip starts full and runs empty in 5 seconds; when it is gone, your mana regeneration is back. A new spell that costs mana fills it again. It shows on every frame that shows you, also the target or focus frame, and only while that frame shows a mana strip. "Show five-second rule" on the Layout page turns it off (on by default).

### 0.6.2

- Fixed: a shield on your left click other than Power Word: Shield (such as Ice Barrier) showed its blue shield bar on every frame you hovered, and Weakened Soul or a Power Word: Shield on you hid it. It now shows only on a frame that is you, and not while that shield is already up on you. Power Word: Shield shows as before.

### 0.6.1

- Fixed: a hover key's "Set key" button could keep taking your keys after it stopped reading "Press a key" (after a right-click on it, Set key on another hover key, a modifier button, an action choice or Reset), so W showed the "moves your character" warning instead of walking. A button now takes keys only while it reads "Press a key", and entering combat ends a wait.

### 0.6.0

- New: frames for your target and your focus ("Show target frame" and "Show focus frame" on the Layout page, off by default). Heal someone you have targeted or focused with your click casting, also when they are not in your group. They show above the NeoHeal frames while that unit is friendly.
- New: the missing-buff icon also shows when a member's raid buff from your class has 10% or less of its duration left (3 minutes of a 30-minute buff), so you can rebuff before the pull.
- New: a healer at 20% mana or less shows a blue "OOM" on their frame ("Show low mana" on the Layout page).
- The options window shows the NeoHeal version in its title.

### 0.5.0

- New: NeoHeal is listed in the addon compartment, the addon list beside the minimap. Click it to open the options window, and again to close it.
- Fix: with the options window open, keys that move your character, such as W, work again. The first time you opened the window after logging in or a /reload, W showed the "moves your character" warning instead of walking. That warning now only appears after you click Set key.

### 0.4.1

- Fix: a hover key on a key that moves you, such as W, could keep your character walking once the mouse was over a frame. A hover key now only takes its key while it has an action, and never a key that moves you: setting one is refused, and one set before shows as "W (moves you)" and does nothing until that key no longer moves you.

### 0.4.0

- Heal prediction: the frame under your mouse shows how much your left click would heal, as a lighter bar after the incoming heals. It follows Shift, Ctrl and Alt, and "Show left-click heal prediction" (Layout) turns it off. A shield on the left click shows its absorb in blue, out of combat and only when the member can take a new shield.
- Tip: if a click casts something other than you bound, check the game's own Click Casting window (/run ToggleClickBindingFrame()). A spell bound there wins over NeoHeal's binding.

### 0.3.0

First release on CurseForge.

- Click casting with five mouse buttons, three hover keys and Shift/Ctrl/Alt; highest rank, "Highest rank -1" or a fixed rank; cast on the unit, its target or its target's target.
- A tooltip that lists your bindings and how much each heal or shield heals or absorbs.
- Party and raid frames with size presets, HoT timers, debuffs, a dispel strip, missing raid buffs, role icons and test mode.

## Building the ZIP by hand

The fallback route, for a test build to install in game before a release has notes and
a version tag (the in-game checks of a fix, say). The workflow above needs neither of
you; for a normal release, do not use this route.

The ZIP must hold one folder, `NeoHeal/`, with the `.toc`, the `.lua` files,
`Locales/` and `LICENSE`. `.gitattributes` keeps `docs/`, `spec/`, `CLAUDE.md`, `.github`,
`.pkgmeta` and the git files out, but only for what is committed: `git archive` reads
the tagged commit, and it does not build from a working tree. So commit everything
first, then build the ZIP outside the AddOns folder:

```sh
git commit ...                      # the version in NeoHeal.toc and everything else
git archive --format=zip --prefix=NeoHeal/ -o "<outside the repo>/NeoHeal-<version>.zip" HEAD
```

`.pkgmeta` holds the same list for the automatic route, because the packager never
reads `.gitattributes`; `lua spec/run.lua` fails when the two lists differ, so add an
entry to both. Before installing a hand-built ZIP, list its contents and check the
version in its `NeoHeal.toc`.

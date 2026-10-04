# Saved variables

| Variable | Scope | Accessed as |
| --- | --- | --- |
| `NeoHealDB` | account | `NeoHeal.db` |
| `NeoHealCharDB` | character | `NeoHeal.charDB` |

Both exist only after `PLAYER_LOGIN`. Event handlers guard with
`if not self.db then return end`.

## `NeoHealDB.layout`

Defaults live in `DEFAULTS` at the top of `Core.lua`. `ApplyDefaults` copies
missing keys recursively, so **a new setting only needs a default there** and
reaches existing installs automatically.

| Key | Default | Values |
| --- | --- | --- |
| `sizes.party` / `sizes.raid` | 110×44 / 80×36 | `{ buttonWidth, buttonHeight, spacing, scale, position = { point, relativePoint, x, y } }` |
| `showSolo` | `true` | |
| `healthText` | `"percent"` | `"percent"`, `"deficit"`, `"none"` |
| `powerBar` | `"all"` | `"all"`, `"healers"`, `"none"` |
| `showRaidDebuffs` | `true` | |
| `showMissingBuffs` | `true` | |
| `showHotTimers` | `true` | countdown numbers; the swipe always shows |
| `healthColor` | `"class"` | `"class"`, `"health"` |
| `frameStyle` | `"forever"` | `"forever"`, `"classic"` |
| `showIncomingHeals` | `true` | |
| `showHealPrediction` | `true` | the frame under the mouse shows what your left click heals |
| `showAggro` | `true` | |
| `showTooltips` | `true` | |
| `showPets` | `false` | |
| `mainTankPosition` | `"none"` | `"none"`, `"first"`, `"last"` |
| `hideBlizzardFrames` | `false` | |
| `sortOrder` | `"index"` | `"index"`, `"name"`, `"role"`, `"class"` |

Read the active size preset through `NeoHeal.Layout:GetSize()`, never
`sizes.party` directly. The preset follows the group (and test mode), and only
switches out of combat.

## `NeoHealCharDB`

| Key | Shape |
| --- | --- |
| `bindings` | `[bindingKey] = binding`. Key = modifier prefix + button id: `"1"`, `"shift-2"`, `"alt-3"`, `"ctrl--neokey1"` |
| `hoverKeys` | `[slot 1..3] = "Q"` |

Binding shapes:

```lua
{ action = "spell", spellID = 2061, highestRank = true, target = "unit", alsoTarget = false }
{ action = "target", target = "unit" | "target" | "targettarget" }
{ action = "menu" }
{ action = "buff" }
```

With `highestRank = true`, `spellID` is any rank of the spell (it is matched by
name) and the rank cast is resolved when bindings are applied. An optional
`rankOffset` (default `0`, "Highest rank -1" stores `1`) counts down from the
highest known rank, stopping at rank 1. Without `highestRank`, `spellID` is the
exact rank.

The saved `spellID` is also what gets cast when the spell can't be found in the
spellbook scan. That's why, in the options menu, "Highest rank -1" saves the rank
below the highest and "Highest rank" saves the highest. Class defaults save rank 1.

## Migrations (in `NeoHeal:PLAYER_LOGIN`)

Old settings are converted once, then removed:

| Old key | Became |
| --- | --- |
| `showMainTanks = false` | `mainTankPosition = "none"` |
| `showPowerBar = false` | `powerBar = "none"` |
| `showHealthText = false` | `healthText = "none"` |
| `buttonWidth/Height`, `spacing`, `scale`, `position` | copied into both `sizes.party` and `sizes.raid` |
| `orientation`, `showTitleBar` | dropped |

When you rename or reshape a setting, add a block here in the same style: read
the old key, write the new one, set the old one to `nil`.

# Delivery: NeoHeal

The project file for the `delivery:delivering-a-story` skill: what that skill leaves to this repository. The product
owner reads it whole at the start of every story; the skill's `check-gate.mjs` reads only the JSON block.

## End state

NeoHeal gives healers on WoW: Forever simple but effective click-cast party and raid frames: everything a healer needs
to see and to cast on, without the setup burden of HealBot (Remco, 2026-11-15: "simple but effective. not as
complicated as Healbot").

## Backlog

- Adapter: `github`.
- Target: `AzureStackNerd/NeoHeal`. Stories carry the label `enhancement`, bugs `bug`; `in-game check` marks a check
  only Remco can do in the game, `tests` a test gap. The GitHub project number 5 of owner `AzureStackNerd` ("NeoHeal")
  holds the fields Status (Todo, In Progress, Done) and Priority (High, Medium, Low).
- Hierarchy: flat; an issue has no sub-issues.
- Started and done: started is the project Status "In Progress"; done is the issue closed as `completed`.
- Who may write: Remco's own repository. The product owner files and comments issues, sets labels, Status and
  Priority, and closes an issue once the done rule below holds.

## Commands, paths and rules

`lua spec/run.lua` runs every test file in about two seconds, so the named-files command runs the whole suite.
`-p <pattern>` (LuaUnit's own filter) selects tests by name; a pattern that matches nothing still exits 0 with
"Ran 0 tests" (measured 2026-11-15), so every pass line requires at least one test.

```json
{
  "commands": {
    "quick": [
      {
        "name": "all tests",
        "run": "lua spec/run.lua",
        "passLine": "^Ran [1-9]\\d* tests in [\\d.]+ seconds, \\d+ successes, 0 failures$"
      }
    ],
    "tests": "lua spec/run.lua",
    "row": "lua spec/run.lua -p {row}",
    "suite": {
      "name": "all tests",
      "run": "lua spec/run.lua",
      "passLine": "^Ran [1-9]\\d* tests in [\\d.]+ seconds, \\d+ successes, 0 failures$"
    }
  },
  "paths": {
    "source": ["*.lua in the repository root", "Locales/", "NeoHeal.toc"],
    "tests": ["spec/"],
    "docs": ["docs/", "CLAUDE.md"],
    "refinements": "docs/refinements/",
    "scratch": "C:/CODE/scratch/neoheal-{story}"
  },
  "provingTest": "(^|/)spec/[^/]*_test\\.lua$",
  "briefRules": [
    "Read the repository's CLAUDE.md first: its hard rules (combat lockdown, secret values, auras in combat, click types, event guards, new settings) bind every change.",
    "The tests run against a fake WoW API (spec/support.lua) under Lua 5.4; the game runs Lua 5.1. A test proves NeoHeal's logic, never that Forever's client accepts a call: say what is not checked in game.",
    "A Forever API call or behaviour nobody can check here (there is no game client in these sessions) is worded as not checked in game in the code and docs, and listed in the gate file's Not done; the product owner adds it to an open issue labelled 'in-game check' for the release it ships in, or files one. Each check states what Remco does and what he should see, as a checkbox; the issues are split by the situation a check needs (solo, in or out of combat; in a party or raid), one issue per situation per release, so the solo checks don't wait for a group (Remco, 2026-11-15).",
    "A new spec file is added to the list in spec/run.lua, or it never runs.",
    "The addon's .lua files are CRLF: keep each file's line endings as they are.",
    "Mutations run in a copy of the addon files, Locales/ and spec/ under the scratch path, restored by copying the saved file back, never in the repository and never with git.",
    "Never read ~/.claude/settings.json."
  ],
  "done": "Committed and pushed to main, and its issue closed as completed with a comment naming the commit. A release (version, tag, ZIP, CurseForge) only on Remco's word."
}
```

# Gate 3 tests: #14 Automatic packaging for CurseForge (TestWriter)

Mutation copy: `C:/CODE/scratch/neoheal-14/mut/`, refreshed from the working tree (everything but `.git`) by
`C:/CODE/scratch/neoheal-14/refresh-mut.sh` before each site. Baseline in the copy before any change: `Ran 251 tests,
251 successes, 0 failures`.

## Stops table (48 cells)

Dimensions, from the How lines (lines 146 to 163 of the refinement) and the scenario rows:

- Tag form (6), what `GITHUB_REF` and the event give the code:
  1. `v0.7.0`: a release tag on a tag push (S1).
  2. `v0.7.0-beta1`: a pre-release tag (S3; answered: publishes nothing).
  3. `vtest`: a v-tag that is no version (S4; How: ends green with a `::warning::`, nothing published).
  4. `v0.7`: a v-tag shaped almost like a version (S4; the typo case of the How line on `::warning::`).
  5. pull request, `refs/pull/<n>/merge`, no tag (How: never publishes; version from the toc, no version-match stop).
  6. run started by hand, `refs/heads/main`, no tag (S24; same as 5).
- Version match (2): the tag's version equals the toc's `## Version`, or differs (S13, S14).
- Notes present (2): `docs/curseforge.md` holds exactly one non-blank `### <version>` section, or not (S11, S12).
- Version listed (2): the toc's Interface maps to a Forever version CurseForge lists, or not (S15, S16).

Expected verdict, derived (not read from the code):

| Tag form | Version match | Notes | Listed | Expected |
| --- | --- | --- | --- | --- |
| `v0.7.0` | equal | yes | yes | publish (S1) |
| `v0.7.0` | any other of the 7 combinations | | | fail, naming every failed stop: both versions (S14), the missing notes (S12), the game version (S16) |
| `v0.7.0-beta1`, `vtest`, `v0.7` | any (8 each, 24) | | | skip: green, nothing published, a warning saying it is not a release tag (S3, S4); no other stop reached, because only a release tag reaches the other dimensions (Dimensions note) |
| pull request, by hand | any match | yes | yes | proof: green, never publishes (S24, How 161) |
| pull request, by hand | any match | no or not listed | | fail naming the missing notes and/or the game version; never a version-match verdict, the version comes from the toc (How 163) |

Totals: 1 publish, 7 fail (release tag), 24 skip, 4 proof, 12 fail (no tag) = 48.

Settled with the Developer: a run with several failed stops names all of them (gate3 file, Contract).

Update (2026-11-15, later): the Architect's ruling (relay 14) and the Developer's new contract (relay 16) say the
stops run on every start, and only the version match is skipped without a release tag. A non-release run with
problems is red; a clean one is green. The 40 cells are now coded in `test_non_release_stops_table`, and the exit codes
of a clean and a red pull request are in `test_the_entry_point_tells_the_workflow_whether_to_publish`. Both pass. They
With the product owner's yes to 2 runs beyond the 15, both were seen red: M15a and M16b in "Site to test". The
Developer reworded How line 158, and the Architect agreed. The entry-point test's pull-request checks were proved later by
M19b.

Earlier state, kept for the record: the 8 release-tag cells are coded and proved (`test_release_tag_stops_table`). The
other 40 cells were held on the product owner's word until the Architect and the Developer settled which stops a
non-release run makes. The Developer's current contract runs the notes, project-ID and Forever-version stops on every start and fails
red on any of them. That matches How line 163 for a pull request and a hand start. It does not match How line 158 for
`v0.7.0-beta1`, `vtest` and `v0.7`, which says such a tag "ends green with a `::warning::`": under the current code a
beta tag whose toc version has no notes is red. For those tags, only `publish == false` and `action == "build-only"`
are asserted today (`test_only_a_release_version_tag_starts_a_release`), which both readings agree on.

## Site to test

All mutations ran in `C:/CODE/scratch/neoheal-14/mut/`. Each row was run alone with `lua spec/run.lua -p <row>`, and
each red is the row's own assertion line. "Proved on" is the `git hash-object --no-filters` of the file in the copy
after the restore, equal to the working tree's at the time.

| Site (file:line) | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `.github/workflows/release.yml:99` (`-d` unless publish) | `test_the_workflow_as_written` | M1c: line deleted; `release_test.lua:205: Could not find substring` | `1117ace` |
| `.pkgmeta` `manual-changelog: filename:` | `test_pkgmeta_names_the_written_changelog` | M2: path `CHANGELOG.md`; `release_test.lua:176: Could not find substring` | `11b6a76` |
| `.pkgmeta` `ignore:` | `test_both_ship_lists_leave_out_the_same_entries` | M3: `- .github` deleted; `release_test.lua:138: ... '.pkgmeta does not ignore ".github", which .gitattributes leaves out'` | `11b6a76` |
| `.gitattributes:9` (`/.github`) | `test_both_ship_lists_leave_out_the_same_entries` | M4b: line deleted; `release_test.lua:138: ... '.gitattributes does not leave out ".github", which .pkgmeta ignores'` | `1e11c83` |
| `.gitignore` (`.release/`) | `test_gitignore_leaves_out_the_packager_folder` | M5: line deleted; `release_test.lua:182: Could not find substring` | `556d3ac` |
| `NeoHeal.toc:10` (`X-Curse-Project-ID`) | `test_the_toc_names_NeoHeals_CurseForge_project` | M6: line deleted; `release_test.lua:131: expected: "1726356"` | `638f1dc` |
| `spec/release.lua:268` (`publish` gating) | `test_release_tag_stops_table` | M7b: `and result.problems[1] == nil` dropped; `release_test.lua:62: cell match=true notes=true listed=false: publish` | `1261c74` |
| `spec/release.lua` version-match stop | `test_release_tag_stops_table` | M8: `if version ~= tocVersion` → `if false`; `release_test.lua:62: cell match=false notes=true listed=true: publish` | `1261c74` |
| `spec/release.lua:220` (two sections stop) | `test_the_changelog_is_the_tagged_versions_notes` | M9: `elseif sections > 1` → `elseif false`; `release_test.lua:117: ### 0.7.0` | `1261c74` |
| `spec/release.lua` Forever-version stop | `test_release_tag_stops_table` | M10b: `if not listed` → `if false`; `release_test.lua:62: cell match=true notes=true listed=false: publish` | `1261c74` |
| `spec/release.lua:228` (missing project id) | `test_project_id_stop` | M11b: the problem line removed; `release_test.lua:87: project line ''` | `1261c74` |
| `spec/release.lua:192` (ship rule prefix) | `test_the_ship_rule_on_synthetic_lists` | M12b: prefix without `/`; `release_test.lua:154: docsx/a.md` | `1261c74` |
| `spec/release.lua` `ReleaseTagVersion` | `test_only_a_release_version_tag_starts_a_release` | M13: `$` dropped; `release_test.lua:100: refs/tags/v0.7.0-beta1` | `1261c74` |
| `spec/release.lua:267` (stops on every start) | `test_non_release_stops_table` | M15a: `; if not releaseVersion then result.problems = {} end` appended; `release_test.lua:109: refs/tags/v0.7.0-beta1 match=true notes=true listed=false: problems` | `1261c74` |
| `spec/release.lua:265` (version from the toc without a release tag) | `test_non_release_stops_table` | M16b: `releaseVersion or "0.7.0"`; `release_test.lua:107: refs/tags/v0.7.0-beta1 match=false notes=true listed=true: version from the toc` | `1261c74` |
| `.gitattributes:12` (`/.pkgmeta`) | `test_both_ship_lists_leave_out_the_same_entries` | M18: line deleted; `release_test.lua:181: expected: nil, actual: '.gitattributes does not leave out ".pkgmeta", which .pkgmeta ignores'` | `1e11c83` |
| `spec/release.lua` `Release.Main` (`publish=` output) | `test_the_entry_point_tells_the_workflow_whether_to_publish` | M19b: `file:write("publish=true\n")`; `release_test.lua:310: ./spec/release_test.lua:303: expected:` (303 is `lu.assertEquals(Read(output), "publish=false\n")` for a clean pull request, re-raised by the test's `assert(ok, err)` after it restores `os.getenv`) | `1261c74` |
| `spec/run.lua:10` (`release_test` in the list) | `TestSuiteList.test_release_tests_are_registered` (`spec/run.lua:16`) | M17b: `"release_test"` dropped from the list; `spec/run.lua:18: spec/release_test.lua is not in run.lua's list` | `fb092fb` |
| `docs/curseforge.md:86` (`### 0.6.0` contract) | `test_the_real_notes_hold_the_toc_versions_section` | M14: `### 0.6.0 notes`; `release_test.lua:190: ### 0.6.0 sections` | `877f411` |
| `docs/README.md:14` | none: a doc row, no behaviour | not mutated | n/a |

Not proved by mutation: `test_the_shipped_files_are_the_toc_what_it_loads_and_LICENSE` needs `git ls-files`, so it
cannot run in the copy (no `.git`). In the copy it fails on its own guard (`release_test.lua:168: git ls-files did not
list NeoHeal.toc (0 files)`), which shows that an empty git output fails the row. Its rule is proved on synthetic lists
by M12b. `Release.Main` was proved later by M19b, after the Scrum Master's gate-3 check (relay 19).

## Mutations

Script: `C:/CODE/scratch/neoheal-14/mutate.sh`. It saves the file, changes exactly one whole line (the anchor must
match one line), runs the row, then restores by copying the saved file back. It never uses git. 15 test runs, plus 2
(M15a, M16b) on a refreshed copy with the product owner's yes, plus 4 for the Scrum Master's gaps (relay 19):
M17, M17b, M18, M19b. M17 went red, but the script's output filter hid its `run.lua` failure line, so M17b re-ran it
with the filter widened. M19 ran no test: its anchor matched no line. Total: 21 test runs. Every site file's
working-tree hash equals its Proved-on hash at the end (rechecked after M19b). The suite passes: 267 tests, 0 failures.
Anchors that matched no line or did not change the file ran no test: M1, M1b, M4, M7, M10, M12. The causes were Git
Bash path conversion of a leading `/`, and lines the Developer moved. M11 was discarded: it went red with a Lua error
(a nil concatenation), not on its assertion, and was redone as M11b.

## Fix round 1

Findings (`brief-fix1.md`):

1. The `-d` expression always gave `-d`.
2. A hand start on a release tag published.
3. The recovery docs re-ran the same commit.

My old test pinned the broken expression string (former `release_test.lua:248`). That pin is removed.

Unproved, site edited (Developer, fix round 1): `.github/workflows/release.yml` (packager args, now line 107, and the
check step's `--event`); `spec/release.lua` (`Release.Check` event rule, `Release.Main` `--event`);
`docs/curseforge.md` (recovery). Every earlier row on these three files reads `unproved: site edited` until it is
re-proved below.

New tests:

- `test_the_expression_evaluator`: a small GitHub-expression evaluator in the test file (`&&`/`||` return operands;
  `false`, `0`, `''` and `null` are falsy; `==` ignores case), checked on its own cases.
- `test_the_event_table_from_check_to_packager`: the brief's six rows end to end. `Release.Main` runs with
  `--event`/`--ref`, its `GITHUB_OUTPUT` is parsed, and the packager's `args:` block is evaluated from those outputs.
  The test asserts the exit code and whether `-d` is present. A further row holds How line 160: no outputs, or
  anything but `publish=true`, still gives `-d`.
- `test_the_workflow_as_written` additionally asserts the check step passes `--event "$GITHUB_EVENT_NAME"` (without
  it `Check` never publishes, and a release builds green).

Seen red before any mutation: the behavioural `-d` test, run against today's broken string
(`${{ steps.check.outputs.publish == 'true' && '' || '-d' }}`, release.yml at `1117ace`), failed on its own assertion:
`release_test.lua:391: push, publish=true must upload (no -d): -n "{package-name}-{project-version}:{package-name}-{project-version}"`.
That test has since become `test_the_event_table_from_check_to_packager`.

### Fix round 1: site to test

The Developer declared these sites final (relay 24). The copy was refreshed, and 8 mutation runs were used. The
anchor for F2 broke on a trailing backslash and ran no test; F2b redid it.

| Site (file:line) | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `.github/workflows/release.yml:107` packager args | `test_the_event_table_from_check_to_packager` | F1: the old `publish == 'true' && '' \|\| '-d'` put back; `release_test.lua:469: push refs/tags/v0.7.0 clean: packager args '... -n "{package-name}-..."` (`-d` present) | `a12d083` |
| `.github/workflows/release.yml` check step `--event` | `test_the_workflow_as_written` | F2b: line deleted; `release_test.lua:271: Could not find substring` | `a12d083` |
| `spec/release.lua` `Check` publish needs `push` | `test_the_event_table_from_check_to_packager` | F3: `event == "push" and` dropped; `release_test.lua:469: workflow_dispatch refs/tags/v0.7.0 clean: packager args` (no `-d`) | `3eb01ba` |
| `spec/release.lua` `Main` passes `--event` | `test_the_event_table_from_check_to_packager` | F4: `event = options.event` dropped; `release_test.lua:469: push refs/tags/v0.7.0 clean: packager args` (`-d` present) | `3eb01ba` |
| `docs/curseforge.md:93` recovery | `test_the_recovery_docs_name_both_routes` | F5: "tag the fixed commit, and push the tag again" cut; `release_test.lua:252: Could not find substring "tag the fixed commit, and push the tag again"` | `f25765e` |
| `spec/release.lua` `Main` `publish=` output (re-proof of M19b) | `test_the_entry_point_tells_the_workflow_whether_to_publish` | R19: `publish=true` hardcoded; `release_test.lua:495: expected: "false"` | `3eb01ba` |
| `spec/release.lua` stops on every start (re-proof of M15a) | `test_non_release_stops_table` | R15; `release_test.lua:116: refs/tags/v0.7.0-beta1 match=true notes=true listed=false: problems` | `3eb01ba` |
| `spec/release.lua` version from the toc (re-proof of M16b) | `test_non_release_stops_table` | R16; `release_test.lua:114: refs/tags/v0.7.0-beta1 match=false notes=true listed=true: version from the toc` | `3eb01ba` |

Superseded: M1c (the `-d` line, now F1) and M7b (the `publish` line, now F3).

`unproved: site edited` (file hash changed by the fix, and the line itself is not in the fix diff; no runs left): M8, M9,
M10b, M11b, M12b, M13 (`spec/release.lua` was `1261c74`, now `3eb01ba`) and M14 (`docs/curseforge.md` was `877f411`,
now `f25765e`). Their tests pass on the new files. Sites on unedited files keep their proofs: `.pkgmeta`,
`.gitattributes`, `.gitignore`, `NeoHeal.toc` and `spec/run.lua`, whose hashes are unchanged.

The suite passes: `lua spec/run.lua` gives 270 tests, 0 failures.

### Fix round 1: re-proof of the stale rows

These 7 rows replace the `unproved: site edited` line above. They used 7 runs on a copy refreshed from the final
fix-round tree. The mutations are the same as the originals, and each red is the row's own assertion.

| Site | Test | Seen red how | Proved on |
| --- | --- | --- | --- |
| `spec/release.lua` version-match stop (M8r) | `test_release_tag_stops_table` | `release_test.lua:69: cell match=false notes=true listed=true: publish` | `3eb01ba` |
| `spec/release.lua` two sections stop (M9r) | `test_the_changelog_is_the_tagged_versions_notes` | `release_test.lua:168: ### 0.7.0` | `3eb01ba` |
| `spec/release.lua` Forever-version stop (M10r) | `test_release_tag_stops_table` | `release_test.lua:69: cell match=true notes=true listed=false: publish` | `3eb01ba` |
| `spec/release.lua` missing project id (M11r) | `test_project_id_stop` | `release_test.lua:138: project line ''` | `3eb01ba` |
| `spec/release.lua` ship rule prefix (M12r) | `test_the_ship_rule_on_synthetic_lists` | `release_test.lua:205: docsx/a.md` | `3eb01ba` |
| `spec/release.lua` `ReleaseTagVersion` (M13r) | `test_only_a_release_version_tag_starts_a_release` | `release_test.lua:151: refs/tags/v0.7.0-beta1` | `3eb01ba` |
| `docs/curseforge.md` `### 0.6.0` contract (M14r) | `test_the_real_notes_hold_the_toc_versions_section` | `release_test.lua:241: ### 0.6.0 sections` | `f25765e` |

No row now reads unproved. Working-tree hashes after the runs: `spec/release.lua` `3eb01ba`, `docs/curseforge.md`
`f25765e`.

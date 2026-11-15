# Gate 3: build, story #14

The Developer's state file for gate 3, appended after each area. The TestWriter's
counterpart is `14-curseforge-packaging.md.gate3-tests.md`.

## Contract for the TestWriter

`spec/release.lua` (the stops, run by the workflow and by the suite through the tests):

| Function | Takes | Returns |
| --- | --- | --- |
| `Release.Check(input)` | `{ ref, toc, notes, versions }`: `ref` the `GITHUB_REF` string, `toc` and `notes` the file text, `versions` the Forever version names CurseForge listed | `{ action, publish, version, problems, notice }`: `action` is `"release"` or `"build-only"`, `publish` true only for a release tag with no problems, `problems` every reason it cannot publish, `notice` why a run publishes nothing without being in error |
| `Release.Problems(input)` | `{ tagVersion, version, toc, notes, versions }` | every reason, in a fixed order: tag against the toc's version (only when `tagVersion` is given), the notes, the project id, the game version |
| `Release.TagAction(tag)` | a tag name | `"release"` for `vX.Y.Z`, else `"build-only"` |
| `Release.ReleaseTagVersion(tag)` | a tag name | the version string, or nil |
| `Release.TagOf(ref)` | a `GITHUB_REF` | the tag name, or nil |
| `Release.Notes(text, version)` | the notes file's text and the version | the section's text or nil, and how many sections matched |
| `Release.VersionFromInterface(s)` | an Interface value | `"1.60.1"` for `"16001"` |
| `Release.ShipListsProblem(pkgmeta, gitattributes)` | both files' text | a problem string, or nil |
| `Release.ShipListProblem(files, tocLoads, ignored?)` | tracked paths, the toc's load list | the first file that ships unnoticed, or nil |
| `Release.TocField(toc, key)`, `Release.TocInterface(toc)`, `Release.TocLoads(toc)` | toc text | the field's value, the Interface, the loaded files |
| `Release.PkgmetaIgnore(text)`, `Release.GitattributesIgnore(text)` | a file's text | the entries as plain names |

Several stops failing at once: `problems` names **all** of them, in the order above, never
only the first.

**The stops run on every start**, including `refs/heads/…`, `refs/pull/<n>/merge` and a
`v*` tag that is not `vX.Y.Z`. The one stop skipped without a release tag is the version
match, so a non-release cell's `problems` holds the notes, project-ID and listed-version
reasons its inputs set, and never a version-match reason. A build-only run is
`publish = false` with a non-nil `notice`; when its `problems` is empty it is green, and
when it is not, the run fails red exactly as a release would.

Tag forms `Release.Check` is built for: `refs/tags/v0.7.0` (publish when clean),
`refs/tags/v0.7.0-beta1` and `refs/tags/vtest` and `refs/tags/v0.7` (build-only, notice),
`refs/heads/main` and `refs/pull/7/merge` (build-only, notice). Any other `refs/tags/…`
form is also covered by the same rule: `vX.Y.Z` publishes, everything else builds only.

## Sites

| Site (file:line) | What it changes | Serves | Docs that describe it |
| --- | --- | --- | --- |
| `.github/workflows/release.yml:1` | the release workflow: three starts, the Lua install, the suite, the token/versions step (which passes `GITHUB_EVENT_NAME`), the stops, the packager with `-d` unless publishing, the ZIP listing | S1, S5, S23, S24, AC1, AC5, AC6 | `docs/curseforge.md` ("Publishing a release"), `docs/README.md` |
| `.github/workflows/release.yml:99` | the packager's `-d` expression, `publish != 'true' && '-d' \|\| ''`, so anything but a literal `true` gives `-d` | S1, S24, AC1, AC5 | `docs/curseforge.md` ("Publishing a release") |
| `.pkgmeta:1` | the packager's ship list (`ignore:`), the manual changelog path and its Markdown markup | S8, S9, S11, AC2, AC3 | `docs/curseforge.md` ("Building the ZIP by hand") |
| `.gitattributes:1` | the header comment says the automatic release uses `.pkgmeta` instead, and `/.github` joins the hand route's ship list at line 9 | S9, AC2 | `docs/curseforge.md` ("Building the ZIP by hand") |
| `.gitattributes:12` | `/.pkgmeta export-ignore`: the hand route must leave out the packager's config, which `git archive` ships otherwise | S9, AC2 | `docs/curseforge.md` ("Building the ZIP by hand") |
| `.gitignore:1` | `.release/`, the packager's build folder | S8 | `docs/curseforge.md` ("Building the ZIP by hand") |
| `NeoHeal.toc:10` | `## X-Curse-Project-ID: 1726356` for the upload and the stop | S18, AC1 | `docs/curseforge.md` ("Publishing a release") |
| `spec/release.lua:1` | the stops as code: tag action, tag against toc, notes, project id, game version, both ship lists, the workflow's entry point | S1, S3, S4, S6, S10, S11, S12, S13, S14, S15, S16, S17, S18, AC2, AC3, AC4, AC5, AC6 | `docs/curseforge.md` ("Publishing a release"), `docs/README.md` |
| `spec/release.lua:252` | the publish decision takes the event as well as the ref: a hand start on a version tag publishes nothing | S1, S24, AC1, AC5 | `docs/curseforge.md` ("Publishing a release") |
| `spec/run.lua:10` | `release_test` joins the suite's file list, so the tests run at all (a spec file missing from that list never runs) | AC1 to AC6, S23 | `CLAUDE.md` (the test command), `docs/extending.md` (a new spec file is listed in `spec/run.lua`) |
| `docs/curseforge.md:76` | the release procedure, the notes' heading contract, the file and its changelog, the hand route as fallback | S22, AC1, AC3 | `docs/README.md` |
| `docs/curseforge.md:93` | recovery: re-run for a cause outside the repository, move the tag to the fixed commit for one inside it; "Run workflow" never publishes | S20, AC6 | `docs/README.md` |
| `docs/curseforge.md:99` | the outside-the-repository route checks the CurseForge files page first and re-runs only when no file for the version is listed, because a network failure can follow a completed upload | S19, S20, AC6 | `docs/README.md` |
| `docs/README.md:14` | the row for curseforge.md | S22 | itself |

## Done and verified

- **The stops and the ship-list rule** (`spec/release.lua`): exercised from
  `C:/CODE/scratch/neoheal-14/check-release.lua`, which prints a verdict per case: release
  tag clean (publish), release tag with a wrong version, no notes and an unlisted Forever
  version (all three reasons named), beta tag / `vtest` / branch / pull request (build-only,
  no problems), notes slicing, both ship lists. Run: `lua check-release.lua`.
- **The entry point** (`spec/release.lua` run as a script): `lua spec/release.lua --ref
  refs/pull/7/merge --versions … --out .release/CHANGELOG.md` wrote the 0.6.0 notes and
  exited 0; the same with `refs/tags/v0.6.0` and a versions list without 1.60.1 exited 1
  with two `::error::` lines.
- **The stops on a build-only start** (after the architect's finding): a pull-request ref
  with 1.60.1 not in the versions list printed `Forever 1.60.1 (not listed)` and exited 1
  with the game-version `::error::`; a pull-request ref with the toc temporarily at 0.9.9,
  which has no notes section, exited 1 naming the missing `### 0.9.9` (toc restored from a
  saved copy, verified byte-identical).
- **The two ship lists and the real file list** (`check-ships.lua`): `.pkgmeta` and
  `.gitattributes` hold the same eight entries; `git ls-files` returns 47 paths, holds
  `NeoHeal.toc`, and `ShipListProblem` returns nil over them.
- **The packager honours the list** (`-d -z`, no upload, no ZIP because this machine has
  no `zip`): the package folder held the 14 addon files, `LICENSE` and `Locales/`, and no
  `CHANGELOG.md`, `.pkgmeta` or `.github`; it used the manual changelog.
- **The hand route** (`git archive --worktree-attributes HEAD`): the archive holds the
  same 16 top-level entries and no `docs/`, `spec/`, `.github/`, `.pkgmeta`, `CLAUDE.md`
  or git files.
- **The suite**: `lua spec/run.lua` → 251 tests, 0 failures.
- **The workflow's shell**: every `run:` block passes `bash -n`; the YAML parses and
  resolves to three triggers, seven steps and the packager args string.

## Not done

- **The trigger, the token step, the packager's ZIP and the upload**: shown by the proof
  run on the pull request, not verified here. A first run needs the workflow file on the
  default branch before `workflow_dispatch` exists, and the pull-request run only starts
  for a pull request whose branch has it.
- **`## X-Curse-Project-ID` in the toc**: not checked in game; the next release's in-game
  check covers that the addon still loads.
- **A ZIP built with `zip`**: this machine has no `zip`, so the archive was not made
  locally. The runner has it (Ubuntu 24.04 image), and the proof run's `unzip -l` shows
  the result.
- **`docs/architecture.md` and `docs/extending.md`**: grepped for `curseforge`, `ZIP`,
  `release`, with no hit, so neither needed a change.

## AC table

As of `cc41672`. Test row and Seen red are taken from
`14-curseforge-packaging.md.gate3-tests.md`; the red lines in that file quote the test's own
assertion. The mutation runs behind each "Seen red" are that file's. The suite measured in
this working tree (that commit plus the TestWriter's one uncommitted row,
`test_a_hand_start_on_a_release_tag_builds_only`): `lua spec/run.lua` → 271 tests, 0
failures.

| AC | Test row | Seen red | Met |
| --- | --- | --- | --- |
| AC1 | `test_the_event_table_from_check_to_packager`, `test_the_workflow_as_written`, `test_the_toc_names_NeoHeals_CurseForge_project` | F1: the old `publish == 'true' && '' \|\| '-d'` put back; `release_test.lua:469: push refs/tags/v0.7.0 clean: packager args '... -n "{package-name}-..."`. M6: project line deleted; `release_test.lua:131: expected: "1726356"` | yes |
| AC2 | `test_both_ship_lists_leave_out_the_same_entries`, `test_the_ship_rule_on_synthetic_lists`, `test_the_shipped_files_are_the_toc_what_it_loads_and_LICENSE` | M3: `- .github` dropped from `.pkgmeta`; `release_test.lua:138: '.pkgmeta does not ignore ".github", which .gitattributes leaves out'`. M18: `/.pkgmeta` dropped from `.gitattributes`; `release_test.lua:181: expected: nil, actual: '.gitattributes does not leave out ".pkgmeta"'`. M12b: `release_test.lua:154: docsx/a.md` | yes |
| AC3 | `test_the_changelog_is_the_tagged_versions_notes`, `test_pkgmeta_names_the_written_changelog`, `test_the_real_notes_hold_the_toc_versions_section` | M9: `elseif sections > 1` → `elseif false`; `release_test.lua:117: ### 0.7.0`. M2: `release_test.lua:176: Could not find substring`. M14: `release_test.lua:190: ### 0.6.0 sections` | yes |
| AC4 | `test_release_tag_stops_table` (version-match and listed-version columns) | M8: `if version ~= tocVersion` → `if false`; `release_test.lua:62: cell match=false notes=true listed=true: publish`. M13: `$` dropped in the tag pattern; `release_test.lua:100: refs/tags/v0.7.0-beta1` | yes |
| AC5 | `test_the_event_table_from_check_to_packager`, `test_only_a_release_version_tag_starts_a_release`, `test_non_release_stops_table` | F3: `event == "push" and` dropped; `release_test.lua:469: workflow_dispatch refs/tags/v0.7.0 clean: packager args` (no `-d`). M13 as above. M15a: `release_test.lua:109: refs/tags/v0.7.0-beta1` | yes |
| AC6 | `test_the_event_table_from_check_to_packager`, `test_project_id_stop`, `test_non_release_stops_table`, `test_the_recovery_docs_name_both_routes` | M11b: `release_test.lua:87: project line ''`. F4: `event = options.event` dropped; `release_test.lua:469: push refs/tags/v0.7.0 clean: packager args` (`-d` present). D1b: `release_test.lua:261: the re-run route does not check the files page first: ...`. D2: `release_test.lua:264: Could not find pattern "When no file for this version is listed there"` | yes |

"Met" is what this gate can show: everything except the real trigger, token call, upload and
the game-side load, which are the `## Not done` items above (S1, S2, S15 to S19 and S7 on a
real release).

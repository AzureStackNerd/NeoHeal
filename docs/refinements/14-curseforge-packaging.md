# Refinement: #14 Automatic packaging for CurseForge

## User value

As the maintainer of NeoHeal, I want a release to appear on CurseForge when I push its version tag, so that I no
longer build the ZIP and upload it by hand.

When this is done, the maintainer sees the release's file on NeoHeal's CurseForge page, for WoW: Forever, once the run
his tag push started has finished, and healers get the update in the CurseForge app without waiting for a hand upload.

## Delivers value alone

yes: the next release the maintainer tags reaches CurseForge without a hand-built ZIP; nothing else has to land first.
Waits on: none

## Acceptance criteria

| AC | Criterion | Scenarios | Proving test |
| --- | --- | --- | --- |
| AC1 | When the maintainer pushes a release's version tag, that release appears on NeoHeal's CurseForge page as a Release for WoW: Forever only, and his release instructions no longer ask him to build or upload a ZIP by hand. | S1, S2, S15, S22 | `spec/release_test.lua` "the toc names NeoHeal's CurseForge project" proves only what the repository holds; no Lua test can show a file on CurseForge or the game version it got: an upload-less run before done and the first real release show it (Notes for gate 2, open point on proof) |
| AC2 | Players who install the release get one NeoHeal folder holding what the addon needs to run, and none of the maintainer's docs, tests or tools. | S7, S8, S9, S10 | `spec/release_test.lua` "the shipped files are the toc, what it loads and LICENSE" proves the repository's ship lists against the toc's load list; that the packager applies its list only an upload-less run's file list shows, and that the game loads the installed folder only the next release in game shows |
| AC3 | The changelog of the release on CurseForge shows the notes the maintainer wrote for that version, and nothing else. | S11, S12 | `spec/release_test.lua` "the changelog is the tagged version's notes" proves the choice of the notes only if gate 2 makes that choice code the suite runs; the text on CurseForge only a real run shows |
| AC4 | The version a player downloads from CurseForge is the version the addon shows in game. | S13, S14 | `spec/release_test.lua` "a tag that differs from the toc's version publishes nothing" proves the comparison only if gate 2 makes it code the suite runs, and only in the form the open point on versions settles |
| AC5 | Pushing anything other than a release's version tag publishes nothing on CurseForge. | S3, S4, S5, S6, S24 | `spec/release_test.lua` "only a release version tag starts a release" can check the trigger only as the repository writes it; that GitHub starts no release for a branch, another tag or an old commit only real pushes show (Notes for gate 2) |
| AC6 | When a release cannot be published, nothing wrong reaches players, the maintainer is told why, and once the cause is fixed he can publish that release without building a ZIP by hand. | S12, S14, S16, S17, S18, S19, S20, S21, S23 | `spec/release_test.lua` "a stop before the upload names its reason" proves only the stops the suite can run (S12, S14, and the project ID of S18); that a failing suite stops the release (S23), a refused token, a refused game version or a network error only a real run shows (Notes for gate 2) |

## Dimensions

| Dimension | Values | Rows |
| --- | --- | --- |
| What starts a run | a release version tag on a commit that holds the automation, a pre-release tag, a tag that is no version, a version tag on a commit from before the automation, a branch push, a pull request, a run started by hand | S1, S3, S4, S6, S5, S24 |
| Moment | the first release after this story lands, any later release | S2, S1 |
| Release type on CurseForge | Release, Beta, Alpha | S1, S3, S5 |
| A file in the tagged commit | needed by the game (S7 names them), left out of the ZIP today (S8 names them), added by this story for the automation, added later and not loaded by the toc | S7, S8, S9, S10 |
| Changelog source | the tagged version's notes, no notes for the tagged version, other versions' notes, the commit log | S11, S12 |
| Tag version against the toc's version | equal, different | S13, S14 |
| Game version | the toc's Interface matches a Forever version CurseForge lists, it matches none, Retail or Classic | S15, S16 |
| Run outcome | accepted, the suite fails, token missing or refused, project ID missing, game version refused, CurseForge or network error | S1, S23, S17, S18, S16, S19 |
| Runs for one tag | first run, re-run after a failure, re-run after a success | S1, S20, S21 |
| Ship route | the published ZIP, a ZIP built by the hand route in docs/curseforge.md | S7, S9 |

The product of these is large, but it collapses: only the first value of "What starts a run" reaches any other
dimension, the release type follows from what starts the run, and each stop (S12, S14, S16, S17, S18, S19, S23) ends the run before the
upload whatever the other dimensions hold. The live cells are one success path, one row per stop, and the ZIP's
contents on that path. If gate 2 makes the stops before the upload code the suite runs, a table over tag form x
version match x notes present (6 x 2 x 2 = 24 cells) is cheap to test whole.

## States, moments and places

| Id | State, moment or place | Operation | Expected |
| --- | --- | --- | --- |
| S1 | A release version tag (as v0.7.0) on a commit of main that holds the automation; the toc says 0.7.0, the notes for 0.7.0 are written, the token is accepted, CurseForge lists the Forever version | the maintainer pushes the tag | A file for 0.7.0 appears on NeoHeal's CurseForge project (1726356) as type Release, its name carries the version, and the run is green; the maintainer built and uploaded no ZIP |
| S2 | The first release after this story lands | the maintainer pushes its tag | As S1, and the CurseForge app offers the new file to a Forever install as the update; it is the first real upload and the first time a ZIP built this way is installed in game (open point on proof). That the app serves the newest Release without a main-file mark is not checked |
| S3 | A pre-release tag (as v0.7.0-beta1); none exists in the repository today | the maintainer pushes it | As the open point on pre-release tags settles: a Beta file, or nothing on CurseForge |
| S4 | A tag that is no version (as test or backup-1) | it is pushed | Nothing appears on CurseForge and no upload runs |
| S5 | A push to main or another branch without a tag; a pull request opened or updated | it is pushed or opened | Nothing appears on CurseForge, also no Alpha file |
| S6 | A version tag on a commit from before the automation: v0.3.0 to v0.6.0 pushed again, or a new tag on an old commit | it is pushed | Nothing appears on CurseForge; the files already there (0.3.0 to 0.6.0) stay as they are |
| S7 | The files the game needs: NeoHeal.toc, every file it loads (Locales/enUS.lua and 13 .lua files) and LICENSE | the release ZIP is built from the tag | The ZIP holds one folder, NeoHeal/, with exactly these files; installed from CurseForge, the game loads NeoHeal from it (not checked in game until the next release) |
| S8 | The files left out today: docs/ (with images/ and refinements/), spec/, CLAUDE.md, .claude/, .gitignore, .gitattributes | the release ZIP is built from the tag | None of them is in the ZIP; the packager does not read .gitattributes (release.sh, measured by the Developer), so the hand route's list does not cover it |
| S9 | The files this story adds for the automation (under .github/, a packager config such as .pkgmeta at the top level, any helper) | the release ZIP is built, and a ZIP by the hand route (git archive, which ships any of them .gitattributes does not list; it lists neither .github/ nor .pkgmeta today) | Neither ZIP holds them |
| S10 | A file added to the repository later that the toc does not load (a new doc, a dev script at the top level) | the next release is built | It does not reach players unnoticed: the suite fails until it is either loaded by the toc or left out of both ZIPs, and a release with a failing suite publishes nothing (S23) |
| S11 | The notes for the tagged version are written in the release notes (docs/curseforge.md, "### 0.7.0") | the release is published | The changelog on CurseForge shows that version's notes as Markdown, as the hand-pasted ones did; not the other versions' notes, not the commit log |
| S12 | The tagged version has no notes | the maintainer pushes the tag | As the open point on missing notes settles; proposed: nothing appears on CurseForge and the run fails naming the missing notes |
| S13 | The tag's version equals the toc's "## Version" | the release is published | The file's name on CurseForge is NeoHeal-v0.7.0: the version the options window title shows (0.7.0), written with the tag's v |
| S14 | The tag's version differs from the toc's "## Version" (as tag v0.7.0, toc 0.6.0) | the maintainer pushes the tag | As the open point on versions settles; proposed: nothing appears on CurseForge and the run fails naming both versions |
| S15 | The toc's Interface 16001; CurseForge lists Forever 1.60.1 (id 17053, the only one on 2026-11-15) | the release is uploaded | The file is offered to Forever installs only (1.60.1), never to Retail or Classic; the packager turns 16001 into 1.60.1 (release.sh:1377, read this session) |
| S16 | The toc's Interface matches no Forever version CurseForge lists (a new Interface before CurseForge adds its version) | the maintainer pushes the tag | Nothing appears on CurseForge; the run fails naming the game version; the hand route in docs/curseforge.md stays available |
| S17 | The token is missing, revoked or refused (HTTP 403) | the maintainer pushes the tag | Nothing appears on CurseForge; the run fails, its log names the token, and GitHub notifies the maintainer of the failed run |
| S18 | NeoHeal's CurseForge project ID is missing | the maintainer pushes the tag | Nothing appears on CurseForge; the run fails naming the project ID |
| S19 | CurseForge or the network fails during the run (server error, time-out) | the release is uploaded | The run fails and the maintainer is notified; whether a file appeared is visible on the project's files page before he runs it again |
| S20 | A run for a tag failed and its cause is fixed (S16 to S19) | the maintainer runs it again for the same tag | One file for that version appears, as S1, without a hand-built ZIP |
| S21 | A run for a tag already put its file on CurseForge | the run is started again for the same tag | As the open point on re-runs settles; proposed: a second file appears, and the instructions tell the maintainer not to re-run a green run |
| S22 | The maintainer's release instructions (docs/curseforge.md, and its row in docs/README.md) | the maintainer releases a version | They say what he does now (notes, toc version, commit, tag, push the tag, check the run and the file); no step builds or uploads the ZIP for a normal release; the hand route stays as the fallback and for test builds |
| S23 | A release version tag on a commit where the suite fails (as S10's unshipped file) | the maintainer pushes the tag | Nothing appears on CurseForge; the run fails naming the failing tests. Today nothing runs the suite on GitHub: the repository has no .github/ |
| S24 | A run started by hand, if gate 2 adds one (for the upload-less proof) | the maintainer starts it on a branch or a tag | Nothing appears on CurseForge; a release only follows a tag push |

## Conflicts and unclear points

- [x] Pre-release tags (S3): should a tag such as v0.7.0-beta1 publish, and as what? Options: (a) nothing is published, only a plain vX.Y.Z publishes; (b) a Beta file, which CurseForge app users on the Beta channel get; (c) an Alpha file. Proposed: (a), since no pre-release tag exists in the repository and it keeps the release path to one form. Against (a): there is no way to put a build in players' hands before its Release, such as for in-game checks. Answer: (a), only a plain vX.Y.Z tag publishes; a pre-release tag publishes nothing. Reason: test builds for in-game checks already take the hand route (Not in this story), so a Beta channel adds a second release path nobody uses yet. Against: no build reaches Beta-channel players before its Release. Residual risk: none for players; a Beta path is a new issue if wanted. Serves: own judgement (product owner, 2026-11-15)
- [x] Tag against the toc's version (S14, AC4): what happens when the tag's version differs from the toc's "## Version"? Options: (a) nothing is published and the run fails naming both, as the hand check "check the version in its NeoHeal.toc" does today; (b) the tag sets the version in the published file, so the maintainer no longer edits the version line. Proposed: (a). Against (a): the version bump stays a hand step that (b) removes. Answer: (a), nothing is published and the run fails naming both versions. Reason: it keeps the check docs/curseforge.md asks of the maintainer today ("check the version in its NeoHeal.toc"), and the toc version is what the options title shows. Against: the version bump stays a hand step. Residual risk: a forgotten bump costs one re-tag, never a wrong file. Serves: own judgement (product owner, 2026-11-15)
- [x] Missing notes (S12, AC3): what happens when the tagged version has no notes in the release notes? Options: (a) nothing is published and the run fails naming the missing notes; (b) the file is published with a fixed text or an empty changelog. Proposed: (a), so players never get a file without its notes. Against (a): a forgotten notes section holds a hotfix back until it is written. Answer: (a), nothing is published and the run fails naming the missing notes. Reason: every release so far shipped with its notes, and a file without them tells players nothing. Against: a forgotten notes section holds a hotfix back. Residual risk: minutes of delay while the notes are written. Serves: own judgement (product owner, 2026-11-15)
- [x] Re-run after a success (S21): is a second file for the same version acceptable? Options: (a) yes, the instructions say not to re-run a green run and a duplicate is deleted by hand; (b) a re-run never publishes the same version twice. Proposed: (a). Against (a): one careless click puts a duplicate in the players' file list; whether (b) is feasible at all is not checked. Answer: (a), a duplicate is accepted; the instructions say not to re-run a green run, and a duplicate is deleted by hand. Reason: (b) rests on an API behaviour nobody has checked, and a re-run of a green run has no reason to happen. Against: one careless click puts a duplicate in the file list. Residual risk: a duplicate file until deleted by hand. Serves: own judgement (product owner, 2026-11-15)
- [x] Who pushes a release tag (Remco's release rule): after this story the tag push is the CurseForge upload, and the maintainer's last look before it (listing the ZIP, checking the toc version: docs/curseforge.md) goes away. For 0.6.0 the product owner pushed the tag on Remco's word and Remco uploaded by hand. Options: (a) a version tag is pushed only on Remco's word, by whoever he names, as for 0.6.0, and the stops this story adds replace his last look; (b) only Remco pushes a version tag, himself. Proposed: (a), since the rule already lists the tag as part of the release. Against (a): a tag pushed by mistake (a git push --tags with a stray local tag) now puts a file in front of players within one run, where before nothing reached them until Remco uploaded. Answer: (a), a version tag is pushed only on Remco's word, by whoever he names, and the stops this story adds replace the hand look before the upload. Reason: the project file already names the tag as part of a release. Against: a stray git push --tags now publishes within one run. Residual risk: covered by S14 and S12 (a stray tag whose version or notes do not match publishes nothing). Serves: ".claude/delivery.md: A release (version, tag, ZIP, CurseForge) only on Remco's word." (product owner, 2026-11-15)
- [x] Proof at done (AC1, AC6): nobody in this story pushes a tag or uploads a file (common.md), so the file on CurseForge is first seen at the next release. Options: (a) the story is done on the Lua tests plus an upload-less run (a ZIP built, its file list, the Forever version, the changelog and an accepted token shown, nothing uploaded), and the first real release gets a check on an open issue, as in-game checks do; (b) Remco allows one test upload in this story (an Alpha file he deletes afterwards); (c) the story stays open until the next real release. Proposed: (a). Against (a): the upload itself (project, game version, changelog sent to CurseForge) stays unproven until a release real players install. Narrows what AC1 promises at done, so it is Remco's. Answer: (a), done on the Lua tests plus an upload-less run whose log shows the ZIP's files, Forever 1.60.1, the changelog and the token accepted; the first real release gets a check on an open issue. Serves: Remco's pick "Dry run + check" when asked on 2026-11-15 (Remco, 2026-11-15)
- [x] File name on CurseForge (S13, AC4): release tags are written v0.7.0 and the packager names the file after the tag, with no token that drops the v (release.sh lines 375 to 381 and 647), so the name cannot be exactly the 0.7.0 the options title shows; the hand-uploaded files show on CurseForge as NeoHeal-0.6.0.zip to NeoHeal-0.3.0.zip, with 1.60.1 and Forever in their own columns (files page, read 2026-11-15). Options: (a) NeoHeal-v0.7.0; (b) the packager's default, v0.7.0-forever; (c) release tags without the v from 0.7.0 on, so S13 stays as written. Answer: (a), the file is named NeoHeal-v0.7.0, and S13's Expected now reads "The file's name on CurseForge is NeoHeal-v0.7.0: the version the options window title shows (0.7.0), written with the tag's v". Serves: Remco's pick (a) when asked on 2026-11-15 (Remco, 2026-11-15)
- [x] Where the upload-less proof runs (S24, proof at done): a run started by hand only starts once the workflow file is on the default branch (GitHub docs, read 2026-11-15), so a pushed feature branch cannot start it. Options: (a) the workflow also runs, never uploading, on a pull request into main, so the proof runs on this story's pull request before the review and the merge; (b) merge first, then a hand-started run on main before the issue closes. Answer: (a); if the run does not start for the pull request that adds the workflow, fall back to (b). Serves: own judgement (product owner, 2026-11-15)

## Not in this story

- GitHub Releases: there are none today (`gh release list` is empty, 2026-11-15); the packager could make them. A new issue if wanted.
- Uploads to Wago Addons or WoWInterface.
- Writing a version's notes and bumping the toc's version: they stay by hand (unless the open point on versions picks (b)).
- The project page's texts and images on CurseForge: they stay pasted by hand.
- Test builds for in-game checks before a release: they keep the hand route in docs/curseforge.md, "Building the ZIP".

## Estimate

**5 points.** Basis: the Architect and the Developer each counted 5. The Developer's count from the code: 8 files, 3
new (a workflow, a packager ignore list, spec/release_test.lua) and 5 changed (NeoHeal.toc +1 line, .gitattributes +2,
spec/run.lua +1 entry, docs/curseforge.md, docs/README.md +1 row); 5 config sites, 6 test functions, 2 doc sections;
2 contracts changed (how a release is published, which files ship); 6 test rows, a 7th if the two ship lists get
separate tests; lines: config 55 to 65, tests 130 to 180, docs 40 to 50; plus one helper and its rows if gate 2 makes
the stops code the suite runs. No open point moves it past 5. S23 and S24 came after that count, from the Developer's
own gaps: a suite step and a hand start, a few lines of config and no new test row. The Architect adds two proof runs
(upload-less, refused token) whose outcome rests on packager behaviour nobody here has run.

## Notes for gate 2

- Packager facts (BigWigsMods/packager `release.sh`, scratch copy of 2026-11-15, read by the Developer; the first three
  re-read by the Architect): it never reads `.gitattributes` (0 hits), so its ZIP needs its own ignore list (S8, S9);
  it keeps the tag's `v` (`si_project_version="$si_tag"`, line 647), so tag v0.7.0 gives `NeoHeal-v0.7.0-forever.zip`
  and the label `v0.7.0-forever` by default, where the hand-built files were `NeoHeal-<version>.zip` (S1); it turns
  Interface 16001 into 1.60.1 (line 1377); it prunes dotfiles, takes the ZIP's top folder from the toc's name, reads the
  project ID from `## X-Curse-Project-ID`, and `-d` skips the upload.
- Two ship lists then exist, the packager's and `.gitattributes` for the hand route: both must agree with the toc's load
  list (S9, S10), and `.gitattributes` does not list `.github/` today.
- The changelog: how the tagged version's notes reach the upload, and whether they stay a section of
  `docs/curseforge.md` or move to their own file; the commit log must not reach players (S11).
- Where the stops before the upload run (S12, S14, S18): code the suite runs, or workflow steps no Lua test reaches.
- The trigger: which tag forms start a run (S3 to S6). v0.3.0 to v0.4.1 are annotated tags, v0.5.0 and v0.6.0
  lightweight (`git ls-remote --tags origin`).
- Proof without a release (open point on proof): an upload-less run, on a branch or started by hand, whose log shows the
  ZIP's file list, the Forever version 1.60.1, the changelog text and the token accepted by the versions endpoint; and a
  run with a refused token that stops before any upload. Nobody pushes a version tag or uploads in this story.
- A new `## X-Curse-Project-ID` line in the toc is not checked in game; the next release's in-game check covers that the
  addon still loads (S7).
- Re-runs (S21): whether the upload API can tell that a file for the version exists is not checked.
- The checkout: the packager runs `git describe` and `git tag --points-at` (release.sh:626 to 644, read by the
  Developer) for the version and the changelog range, so the run needs the full history and the tags (S1, S11).
- The entry point of the upload-less proof run (S24): without a hand start the only start is a tag push, which nobody in
  this story may do.
- The suite in the release run (S23): the suite runs under Lua 5.4 with LuaUnit from `spec/`; how the runner gets Lua is
  open.
- The notes' heading form: if the notes are taken from a section of `docs/curseforge.md`, `### 0.7.0` becomes a contract
  the instructions must state (S22), and a heading in another form must end in S12's stop, never in the wrong notes.
- The CurseForge app and the newest file (S2): the upload carries no main-file mark (release.sh:2953 to 2962, read by the
  Developer); that the app offers the newest Release is not checked, and the first real release shows it.

## How

- The packager builds and uploads the ZIP (`BigWigsMods/packager`): its upload code is exercised by every addon that uses it, where an upload of our own would first run on a live release (architect and developer, 2026-11-15)
- Two ship lists, one per route, because the packager never reads `.gitattributes` (no hit in `release.sh`) and its list has to be written next to it; `.pkgmeta`'s `ignore:` for the packager holds `docs`, `spec`, `CLAUDE.md`, `.claude`, `.github`, `.gitattributes`, `.gitignore` and `.pkgmeta`, `.gitattributes` gains `/.github` and `/.pkgmeta` (git archive ships both today), and `.gitignore` gains `.release/`, the packager's own scratch folder (architect and developer, 2026-11-15)
- `ShipListProblem(files, tocLoads)` in `spec/release.lua` holds both lists to one rule, over every tracked file and not only the top-level ones: a file is the toc, `LICENSE`, a file the toc loads, or under an entry both lists name — otherwise a `Locales/deDE.lua` the toc does not load ships unnoticed (architect and developer, 2026-11-15)
- `ShipListProblem` takes the file list as an argument rather than reading git itself: a pure function, so a synthetic list tests it without git, which the mutation copies under scratch have none of (architect and developer, 2026-11-15)
- One test row feeds it the real `git ls-files` and first asserts `NeoHeal.toc` is in the list: a `git` that returns nothing then fails the test instead of passing it (architect and developer, 2026-11-15)
- The stops before the upload are code in `spec/release.lua`, run by `lua spec/run.lua` like the rest of the suite: inside the workflow alone they would be reachable only by a real tag push (architect and developer, 2026-11-15)
- The stops are tested as a table over tag form x version match x notes present x version listed (48 cells), whole: the cells are cheap and a stop missed in one column is exactly the case that reaches players (architect and developer, 2026-11-15)
- `Notes(text, version)` slices the tagged version's notes out of `docs/curseforge.md`: a section starts at a line that is exactly `### X.Y.Z` (trailing spaces or CR allowed) and ends at the next heading of level 1 to 3 or at the end of the file, in LF or CRLF; no section, one with only blank lines, or two matching sections is the missing-notes stop, because the heading form is the contract the instructions state and any other form must stop rather than publish the wrong notes (architect and developer, 2026-11-15)
- The notes reach the upload as `.release/CHANGELOG.md`, named by `.pkgmeta`'s `manual-changelog: filename:` with `markup-type: markdown`, which is what makes CurseForge show Markdown instead of raw text (architect and developer, 2026-11-15)
- A test row reads `.pkgmeta` as text and asserts it names that same path: when the path drifts the packager warns, writes a commit-log `CHANGELOG.md` into the package folder, ships it and uploads it, all green (architect and developer, 2026-11-15)
- The missing-notes stop runs before the packager, not instead of its own changelog handling: without it `release.sh` falls back to a changelog of commits and that is what players would read (architect and developer, 2026-11-15)
- The token and versions step calls `/api/game/wow/versions` on every run, tag or dispatch, because `-d` makes no API call and the proof needs "the token accepted" from something (architect and developer, 2026-11-15)
- That step fails on an empty secret ("CF_API_TOKEN is not set") and on any status other than 200 ("token refused, HTTP 403"): `upload_curseforge` returns 0 when the token or the project id is missing, so a lost secret would otherwise be a green run that uploaded nothing (architect and developer, 2026-11-15)
- It writes the Forever version names (type 88568) as plain text and `spec/release.lua` checks the toc's Interface against them through `VersionFromInterface`, mirroring the packager's 16001 to 1.60.1: the packager does not stop on a version CurseForge lacks, it uploads tagged as the next-highest one (architect and developer, 2026-11-15)
- `ProjectId(toc)` must equal 1726356 and the test pins that value, for the same reason: a missing project id is a green no-op in the packager (architect and developer, 2026-11-15)
- The workflow has exactly three starts: `on: push: tags: v*`, `on: pull_request: branches: [main]` and `on: workflow_dispatch`; only a push of a release version tag can publish, and a hand start on that same tag publishes nothing, which is why the event reaches `spec/release.lua` next to the ref (architect and developer, 2026-11-15)
- `TagAction` decides publish or skip on a tag push, because GitHub's filter `?` and `+` mean "zero or one" and "one or more of the preceding character", which makes a version-shaped filter pattern fragile (architect and developer, 2026-11-15)
- A v-tag that is not a plain `vX.Y.Z` publishes nothing and says so with a `::warning::` "not a release tag, nothing published", so a typo in a release tag does not pass for a release that went out; because the stops run on every start, such a run is green only when its notes, project ID and Forever version are all fine, and red otherwise (architect and developer, 2026-11-15)
- The packager runs with `-n "{package-name}-{project-version}:{package-name}-{project-version}"`, giving `NeoHeal-v0.7.0.zip` with the label `NeoHeal-v0.7.0`: the packager's default names the file `NeoHeal-v0.7.0-forever.zip` and the label `v0.7.0-forever`, and CurseForge's files page lists every hand-uploaded file under its file name with Forever in its own column, so the file name, not a `-forever` suffix, is what keeps that list consistent (architect and developer, 2026-11-15; file name chosen by Remco, 2026-11-15)
- There is no `dry_run` input: a `-d` default with an input that turns it off still lets one click upload from a branch, so `-d` is the fail-safe default and only the `push` event on a `refs/tags/` release tag whose stops are clean omits it — the event is an input as much as the ref is, since "Run workflow" on a version tag gives the same `GITHUB_REF` as a tag push (architect and developer, 2026-11-15)
- The packager's flag comes from the workflow expression `steps.check.outputs.publish != 'true' && '-d' || ''`: `-d` sits in the truthy middle position, so anything but a literal `true`, a missing output included, gives `-d`; the first form, `publish == 'true' && '' || '-d'`, gave `-d` on both branches because the empty string is falsy in GitHub's expression language, and a clean release tag then uploaded nothing and ended green (architect and developer, 2026-11-15)
- The pull-request start exists so the proof run happens on this story's own pull request before the review and the merge, and it can never publish: its `GITHUB_REF` is `refs/pull/<n>/merge`, which is no tag ref at all (architect and developer, 2026-11-15; product owner, 2026-11-15)
- The token step runs on a pull request too and is not skipped when no secret is present: a pull request from a fork fails red with "CF_API_TOKEN is not set", since GitHub passes no secrets to fork-triggered runs, and skipping the step would also skip the exact-version stop (architect and developer, 2026-11-15)
- The stops run on every start: a run without a release tag takes the version from the toc and skips only the version-match stop, and any other problem fails the run red whatever started it, so the upload-less proof exercises the same notes, project ID and Forever version stops a release does, and a green run never carries an error line (architect and developer, 2026-11-15)
- If a pull request does not start the run, the fallback is a run started by hand on `main` after the merge and before the issue closes; `workflow_dispatch` only receives events once the workflow file is on the default branch (architect and developer, 2026-11-15; product owner, 2026-11-15)
- The env holds no `GH_API_TOKEN`, `GITHUB_API_TOKEN`, `GITHUB_OAUTH`, `WOWI_API_TOKEN` or `WAGO_API_TOKEN`: with none set the packager makes no GitHub Release and no WoWInterface or Wago upload, which this story leaves out (`GITHUB_OAUTH` is the deprecated third fallback for `github_token`, release.sh:508–510) (architect and developer, 2026-11-15)
- `actions/checkout` is pinned to `11d5960a326750d5838078e36cf38b85af677262` (v4.4.0) and `BigWigsMods/packager` to `01e8631a69c69d7654c788d152630d5fed9e3812` (v2), each with its tag in a comment, and the job runs `permissions: contents: read`: the packager runs with `CF_API_TOKEN` in its env, so a moved `@v2` tag would run new code with the token (architect and developer, 2026-11-15)
- The job runs `ubuntu-24.04` with `lua5.4` installed from the distribution, since the runner image carries no Lua and `lua5.4` is in noble (architect and developer, 2026-11-15)
- The steps run in this order: checkout at `fetch-depth: 0` (the packager's `git describe` and `git tag --points-at` need the history and the tags), install Lua, the suite, the token and versions step, `spec/release.lua`, the packager, then `unzip -l` on the archive: the packager never prints what it zipped, so the file list in the proof is our own step (architect and developer, 2026-11-15)

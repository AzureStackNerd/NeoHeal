-- spec/release.lua and the release config (.github/workflows/release.yml, .pkgmeta,
-- .gitattributes, .gitignore, NeoHeal.toc): the stops that run before a release
-- reaches CurseForge, and the two ship lists. Each expected verdict here comes from
-- the refinement's scenario rows and How lines (docs/refinements/14-...), not from
-- what the code prints. The workflow itself only a GitHub run executes: these tests
-- read its text, so they prove what the repository holds, never that GitHub starts
-- the run or that CurseForge accepts the upload.
local lu = require("luaunit")
local Support = require("support")

local Release = dofile(Support.root .. "/spec/release.lua")

local function ReadFile(name)
    local file = assert(io.open(Support.root .. "/" .. name, "r"), "cannot read " .. name)
    local text = file:read("*a")
    file:close()
    return text
end

-- A toc like the real one, with the version and project id a case needs.
local function Toc(version, projectLine)
    return "## Interface: 16001\n## Title: NeoHeal\n## Version: " .. version .. "\n" ..
        (projectLine or "## X-Curse-Project-ID: 1726356") .. "\n\nCore.lua\n"
end

local NOTES_070 = "# Texts\n\n### 0.7.0\n\n- Fixed the frames.\n\n### 0.6.0\n\n- Older notes.\n"
local NOTES_NO_070 = "# Texts\n\n### 0.6.0\n\n- Older notes.\n"

local function AnyContains(list, ...)
    for _, item in ipairs(list) do
        local all = true
        for _, needle in ipairs({ ... }) do
            if not item:find(needle, 1, true) then all = false end
        end
        if all then return true end
    end
    return false
end

TestRelease = {}

-- The stops table, release-tag rows: tag v0.7.0 x version match x notes present x
-- version listed (8 of the 48 cells). Publish only when all three hold (S1); otherwise
-- nothing is published and every failed stop is named: both versions (S14), the
-- missing notes (S12), the game version (S16). The other 40 cells are in
-- test_non_release_stops_table.
function TestRelease:test_release_tag_stops_table()
    local cells = 0
    for _, match in ipairs({ true, false }) do
        for _, notesPresent in ipairs({ true, false }) do
            for _, listed in ipairs({ true, false }) do
                cells = cells + 1
                local label = ("cell match=%s notes=%s listed=%s"):format(tostring(match), tostring(notesPresent), tostring(listed))
                local result = Release.Check({
                    ref = "refs/tags/v0.7.0",
                    toc = Toc(match and "0.7.0" or "0.6.0"),
                    notes = notesPresent and NOTES_070 or NOTES_NO_070,
                    versions = listed and { "1.60.1" } or { "1.59.0" },
                })
                local expectPublish = match and notesPresent and listed
                lu.assertEquals(result.publish, expectPublish, label .. ": publish")
                lu.assertEquals(result.action, "release", label .. ": action")
                lu.assertEquals(result.version, "0.7.0", label .. ": version from the tag")
                local expectedCount = (match and 0 or 1) + (notesPresent and 0 or 1) + (listed and 0 or 1)
                lu.assertEquals(#result.problems, expectedCount, label .. ": problems " .. table.concat(result.problems, " | "))
                if not match then
                    lu.assertTrue(AnyContains(result.problems, "0.7.0", "0.6.0"), label .. ": names both versions")
                end
                if not notesPresent then
                    lu.assertTrue(AnyContains(result.problems, "### 0.7.0"), label .. ": names the missing notes")
                end
                if not listed then
                    lu.assertTrue(AnyContains(result.problems, "1.60.1"), label .. ": names the game version")
                end
            end
        end
    end
    lu.assertEquals(cells, 8)
end

-- The stops table, non-release rows: 5 starts x version match x notes present x
-- version listed (40 of the 48 cells). Settled by the Architect (2026-11-15): the
-- stops run on every start; without a release tag the version comes from the toc
-- and only the version-match stop is skipped. So: never publish, always a notice,
-- and the problems are exactly the missing notes (S12) and the unlisted game version
-- (S16) the inputs set, never a version-match reason (S14). A run with problems is
-- red, a clean one green (the entry point test checks the exit code).
function TestRelease:test_non_release_stops_table()
    local cells = 0
    for _, ref in ipairs({ "refs/tags/v0.7.0-beta1", "refs/tags/vtest", "refs/tags/v0.7", "refs/pull/7/merge", "refs/heads/main" }) do
        for _, match in ipairs({ true, false }) do
            for _, notesPresent in ipairs({ true, false }) do
                for _, listed in ipairs({ true, false }) do
                    cells = cells + 1
                    local label = ("%s match=%s notes=%s listed=%s"):format(ref, tostring(match), tostring(notesPresent), tostring(listed))
                    local tocVersion = match and "0.7.0" or "0.6.0"
                    -- Notes present means a section for the version this run uses, the toc's;
                    -- absent means the file holds only another version's notes.
                    local other = tocVersion == "0.7.0" and "0.5.0" or "0.4.0"
                    local notes = "# Texts\n\n### " .. (notesPresent and tocVersion or other) .. "\n\n- Notes.\n"
                    local result = Release.Check({ ref = ref, toc = Toc(tocVersion), notes = notes,
                        versions = listed and { "1.60.1" } or { "1.59.0" } })
                    lu.assertFalse(result.publish, label .. ": publish")
                    lu.assertEquals(result.action, "build-only", label .. ": action")
                    lu.assertNotNil(result.notice, label .. ": notice")
                    lu.assertEquals(result.version, tocVersion, label .. ": version from the toc")
                    local expectedCount = (notesPresent and 0 or 1) + (listed and 0 or 1)
                    lu.assertEquals(#result.problems, expectedCount, label .. ": problems " .. table.concat(result.problems, " | "))
                    if not notesPresent then
                        lu.assertTrue(AnyContains(result.problems, "### " .. tocVersion), label .. ": names the missing notes")
                    end
                    if not listed then
                        lu.assertTrue(AnyContains(result.problems, "1.60.1"), label .. ": names the game version")
                    end
                    if not match then
                        lu.assertFalse(AnyContains(result.problems, "0.7.0"), label .. ": no version-match reason")
                    end
                end
            end
        end
    end
    lu.assertEquals(cells, 40)
end

-- S18: a missing or wrong project id stops a release tag, naming the project id.
function TestRelease:test_project_id_stop()
    for _, line in ipairs({ "", "## X-Curse-Project-ID: 999" }) do
        local result = Release.Check({ ref = "refs/tags/v0.7.0", toc = Toc("0.7.0", line),
            notes = NOTES_070, versions = { "1.60.1" } })
        lu.assertFalse(result.publish, "project line '" .. line .. "'")
        lu.assertTrue(AnyContains(result.problems, "X-Curse-Project-ID"), "project line '" .. line .. "'")
    end
end

-- S3, S4, S5, S24, AC5: only refs/tags/vX.Y.Z can publish. Asserted here: publish and
-- the action only; which stops those runs make is not settled yet.
function TestRelease:test_only_a_release_version_tag_starts_a_release()
    lu.assertEquals(Release.TagAction("v0.7.0"), "release")
    lu.assertEquals(Release.TagAction("v10.20.30"), "release")
    for _, ref in ipairs({ "refs/tags/v0.7.0-beta1", "refs/tags/vtest", "refs/tags/v0.7", "refs/tags/v0.7.0.1",
        "refs/tags/0.7.0", "refs/tags/xv0.7.0", "refs/heads/main", "refs/heads/v0.7.0", "refs/pull/7/merge" }) do
        local result = Release.Check({ ref = ref, toc = Toc("0.7.0"), notes = NOTES_070, versions = { "1.60.1" } })
        lu.assertFalse(result.publish, ref)
        lu.assertEquals(result.action, "build-only", ref)
    end
end

-- How: Notes slices one section, its heading exactly "### X.Y.Z" (trailing spaces or
-- CR allowed), ending at the next heading of level 1 to 3 or the end of the file.
-- No section, a blank one or two matching ones is the missing-notes stop (S12).
function TestRelease:test_the_changelog_is_the_tagged_versions_notes()
    local text = "### 0.7.0  \r\n- One.\r\n#### Detail\r\n- Two.\r\n## Next\r\n- Not this.\r\n"
    lu.assertEquals((Release.Notes(text, "0.7.0")), "- One.\n#### Detail\n- Two.")
    lu.assertEquals((Release.Notes("### 0.7.0\n- Last.", "0.7.0")), "- Last.")
    lu.assertEquals((Release.Notes("# A\n### 0.7.0\n\n- One.\n\n# B\n- No.", "0.7.0")), "- One.")
    lu.assertNil((Release.Notes("### 0.7.01\n- No.\n### v0.7.0\n- No.\n#### 0.7.0\n- No.\n", "0.7.0")))
    for _, notes in ipairs({ "### 0.7.0\n\n  \n### 0.6.0\n- Old.\n", "### 0.7.0\n- A.\n### 0.7.0\n- B.\n",
        "### 0.7.0.1\n- No.\n", "### 0.7.0 beta\n- No.\n" }) do
        local result = Release.Check({ ref = "refs/tags/v0.7.0", toc = Toc("0.7.0"), notes = notes, versions = { "1.60.1" } })
        lu.assertFalse(result.publish, notes)
        lu.assertTrue(AnyContains(result.problems, "### 0.7.0"), notes)
    end
end

-- S15: the packager turns Interface 16001 into Forever 1.60.1.
function TestRelease:test_the_game_version_mirrors_the_packager()
    lu.assertEquals(Release.VersionFromInterface("16001"), "1.60.1")
    lu.assertEquals(Release.VersionFromInterface("110200"), "11.2.0")
    lu.assertEquals(Release.VersionFromInterface(Release.TocInterface(ReadFile("NeoHeal.toc"))), "1.60.1")
end

-- AC1, S18: the real toc names NeoHeal's CurseForge project.
function TestRelease:test_the_toc_names_NeoHeals_CurseForge_project()
    lu.assertEquals(Release.TocField(ReadFile("NeoHeal.toc"), "X-Curse-Project-ID"), "1726356")
end

-- AC2, S8, S9: both ship lists leave out the same entries, and those are exactly the
-- maintainer's docs, tests and tools.
function TestRelease:test_both_ship_lists_leave_out_the_same_entries()
    local pkgmeta, gitattributes = ReadFile(".pkgmeta"), ReadFile(".gitattributes")
    lu.assertNil(Release.ShipListsProblem(pkgmeta, gitattributes))
    local expected = { "docs", "spec", "CLAUDE.md", ".claude", ".github", ".gitattributes", ".gitignore", ".pkgmeta" }
    local function Sorted(list) local copy = { table.unpack(list) } table.sort(copy) return copy end
    lu.assertEquals(Sorted(Release.PkgmetaIgnore(pkgmeta)), Sorted(expected))
    lu.assertEquals(Sorted(Release.GitattributesIgnore(gitattributes)), Sorted(expected))
end

-- S10, How: a tracked file ships only when it is the toc, LICENSE, a file the toc
-- loads or under an entry both lists leave out. Synthetic lists: no git needed.
function TestRelease:test_the_ship_rule_on_synthetic_lists()
    local loads = { "Locales/enUS.lua", "Core.lua" }
    local ignored = { "docs", "spec", ".pkgmeta" }
    lu.assertNil(Release.ShipListProblem({ "NeoHeal.toc", "LICENSE", "Core.lua", "Locales/enUS.lua",
        "docs/a.md", "docs/images/b.png", "spec/run.lua", ".pkgmeta" }, loads, ignored))
    for _, stray in ipairs({ "Locales/deDE.lua", "tool.sh", "docsx/a.md", "spec.lua", "README.md" }) do
        local problem = Release.ShipListProblem({ "NeoHeal.toc", "Core.lua", stray }, loads, ignored)
        lu.assertNotNil(problem, stray)
        lu.assertStrContains(problem, stray)
    end
end

-- AC2, How: the real tracked files against the real toc. Needs git, so it cannot run
-- in a copy without .git; asserting NeoHeal.toc is listed makes an empty git output fail.
function TestRelease:test_the_shipped_files_are_the_toc_what_it_loads_and_LICENSE()
    local pipe = assert(io.popen('git -C "' .. Support.root .. '" ls-files'))
    local files = {}
    for line in pipe:lines() do files[#files + 1] = line end
    pipe:close()
    local hasToc = false
    for _, file in ipairs(files) do if file == "NeoHeal.toc" then hasToc = true end end
    lu.assertTrue(hasToc, "git ls-files did not list NeoHeal.toc (" .. #files .. " files)")
    lu.assertNil(Release.ShipListProblem(files, Release.TocLoads(ReadFile("NeoHeal.toc")), Release.PkgmetaIgnore(ReadFile(".pkgmeta"))))
end

-- AC3, How: .pkgmeta names the changelog the workflow writes, as Markdown; a drifted
-- path makes the packager ship a commit-log changelog, all green.
function TestRelease:test_pkgmeta_names_the_written_changelog()
    local pkgmeta, workflow = ReadFile(".pkgmeta"), ReadFile(".github/workflows/release.yml")
    lu.assertStrContains(pkgmeta, "\nmanual-changelog:\n  filename: .release/CHANGELOG.md\n  markup-type: markdown\n")
    lu.assertStrContains(workflow, "--out .release/CHANGELOG.md")
end

-- How: the packager's scratch folder is never committed.
function TestRelease:test_gitignore_leaves_out_the_packager_folder()
    lu.assertStrContains("\n" .. ReadFile(".gitignore") .. "\n", "\n.release/\n")
end

-- S11, S22: the notes contract holds for the real file: the toc's version has its
-- "### X.Y.Z" section in docs/curseforge.md.
function TestRelease:test_the_real_notes_hold_the_toc_versions_section()
    local version = Release.TocField(ReadFile("NeoHeal.toc"), "Version")
    local notes, sections = Release.Notes(ReadFile("docs/curseforge.md"), version)
    lu.assertEquals(sections, 1, "### " .. version .. " sections")
    lu.assertNotNil(notes)
end

-- AC5, AC6, S23, How: the workflow as written. Its three starts, its order (tests,
-- token, stops, packager, ZIP list), -d unless the stops say publish, the pinned
-- actions, read-only permissions and no token for other upload targets.
function TestRelease:test_the_workflow_as_written()
    local workflow = ReadFile(".github/workflows/release.yml"):gsub("\r\n", "\n")
    lu.assertStrContains(workflow, '\non:\n  push:\n    tags:\n      - "v*"\n  pull_request:\n    branches:\n      - main\n  workflow_dispatch:\n\n')
    lu.assertStrContains(workflow, "\npermissions:\n  contents: read\n")
    lu.assertStrContains(workflow, "uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262")
    lu.assertStrContains(workflow, "uses: BigWigsMods/packager@01e8631a69c69d7654c788d152630d5fed9e3812")
    lu.assertStrContains(workflow, "fetch-depth: 0")
    lu.assertStrContains(workflow, '-n "{package-name}-{project-version}:{package-name}-{project-version}"')
    lu.assertStrContains(workflow, "${{ steps.check.outputs.publish == 'true' && '' || '-d' }}")
    lu.assertStrContains(workflow, 'echo "::error::CF_API_TOKEN is not set"')
    lu.assertStrContains(workflow, 'if [ "$status" != "200" ]; then')
    local order = { "run: lua5.4 spec/run.lua", "https://wow.curseforge.com/api/game/wow/versions",
        "lua5.4 spec/release.lua", "uses: BigWigsMods/packager@", "unzip -l .release/*.zip" }
    local last = 0
    for _, step in ipairs(order) do
        local at = workflow:find(step, 1, true)
        lu.assertNotNil(at, step)
        lu.assertTrue(at > last, step .. " runs out of order")
        last = at
    end
    for _, token in ipairs({ "GH_API_TOKEN", "GITHUB_API_TOKEN", "GITHUB_OAUTH", "WOWI_API_TOKEN", "WAGO_API_TOKEN" }) do
        lu.assertNil(workflow:find(token, 1, true), token)
    end
end

-- The entry point the workflow runs: on a release tag with a failed stop it exits 1
-- and writes no publish=true; on a clean release tag it writes the notes and
-- publish=true. os.getenv is swapped for GITHUB_OUTPUT and restored.
function TestRelease:test_the_entry_point_tells_the_workflow_whether_to_publish()
    local base = os.tmpname()
    local function Write(path, text) local f = assert(io.open(path, "w")) f:write(text) f:close() end
    local function Read(path)
        local f = io.open(path, "r")
        if not f then return nil end
        local text = f:read("*a")
        f:close()
        return text
    end
    local toc, notes, versions, out, output = base .. "-toc", base .. "-notes", base .. "-versions", base .. "-out", base .. "-output"
    Write(toc, Toc("0.7.0"))
    Write(notes, NOTES_070)
    local function Run(listed, ref, notesText)
        Write(versions, listed .. "\n")
        Write(notes, notesText or NOTES_070)
        Write(output, "")
        os.remove(out)
        return Release.Main({ "--ref", ref or "refs/tags/v0.7.0", "--toc", toc, "--notes", notes,
            "--versions", versions, "--out", out })
    end
    local realGetenv, realPrint, realStderr = os.getenv, print, io.stderr
    os.getenv = function(name) if name == "GITHUB_OUTPUT" then return output end return realGetenv(name) end
    print = function() end
    io.stderr = { write = function() end }
    local ok, err = pcall(function()
        lu.assertEquals(Run("1.60.1"), 0, "a clean release tag")
        lu.assertEquals(Read(output), "publish=true\n")
        lu.assertEquals(Read(out), "- Fixed the frames.\n")
        lu.assertEquals(Run("1.59.0"), 1, "a release tag whose game version is not listed")
        lu.assertEquals(Read(output), "", "a failed stop writes no publish line")
        lu.assertNil(Read(out), "a failed stop writes no changelog")
        -- A pull request (build-only): green and publish=false when clean, red when
        -- the toc version's notes are missing (Architect's ruling, 2026-11-15).
        lu.assertEquals(Run("1.60.1", "refs/pull/7/merge"), 0, "a clean pull request")
        lu.assertEquals(Read(output), "publish=false\n")
        lu.assertEquals(Read(out), "- Fixed the frames.\n")
        lu.assertEquals(Run("1.60.1", "refs/pull/7/merge", NOTES_NO_070), 1, "a pull request without the toc version's notes")
        lu.assertEquals(Read(output), "", "a red pull request writes no publish line")
    end)
    os.getenv, print, io.stderr = realGetenv, realPrint, realStderr
    for _, path in ipairs({ base, toc, notes, versions, out, output }) do os.remove(path) end
    assert(ok, err)
end

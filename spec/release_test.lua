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

-- The event GitHub gives each kind of ref in these tables: a tag or branch is pushed,
-- a merge ref comes from a pull request. A hand start is its own row in the event table.
local function EventFor(ref)
    if ref:match("^refs/pull/") then return "pull_request" end
    return "push"
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
                    event = "push",
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
                    local result = Release.Check({ event = EventFor(ref), ref = ref, toc = Toc(tocVersion), notes = notes,
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
        local result = Release.Check({ event = "push", ref = "refs/tags/v0.7.0", toc = Toc("0.7.0", line),
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
        local result = Release.Check({ event = EventFor(ref), ref = ref, toc = Toc("0.7.0"), notes = NOTES_070, versions = { "1.60.1" } })
        lu.assertFalse(result.publish, ref)
        lu.assertEquals(result.action, "build-only", ref)
    end
end

-- S24, AC5 (fix round 1): a hand start on a release tag has the same ref as a tag
-- push, so the event alone makes it build-only. Its run must say so: action
-- build-only and a notice that only a tag push publishes, not a release that
-- silently did not go out.
function TestRelease:test_a_hand_start_on_a_release_tag_builds_only()
    local result = Release.Check({ event = "workflow_dispatch", ref = "refs/tags/v0.7.0", toc = Toc("0.7.0"),
        notes = NOTES_070, versions = { "1.60.1" } })
    lu.assertFalse(result.publish)
    lu.assertEquals(result.action, "build-only")
    lu.assertNotNil(result.notice, "a hand start on a release tag gives no notice")
    lu.assertStrContains(result.notice, "push")
    lu.assertEquals(#result.problems, 0, "a clean hand start is green")
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
        local result = Release.Check({ event = "push", ref = "refs/tags/v0.7.0", toc = Toc("0.7.0"), notes = notes, versions = { "1.60.1" } })
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

-- AC6, S20 (fix round 1, finding 3): the recovery instructions. A re-run uses the
-- failed run's commit and tag, so it only fixes causes outside the repository; a
-- fix in a commit needs the tag pushed again on that commit. "Run workflow" never
-- publishes. Whitespace is folded so a re-wrapped line does not fail the test.
function TestRelease:test_the_recovery_docs_name_both_routes()
    local docs = ReadFile("docs/curseforge.md"):gsub("%s+", " ")
    lu.assertStrContains(docs, '"Re-run failed jobs" on the failed run')
    lu.assertStrContains(docs, "tag the fixed commit, and push the tag again")
    lu.assertStrContains(docs, '"Run workflow" never publishes')
    lu.assertNil(docs:find("run the workflow again for the same tag", 1, true),
        "the docs still tell the maintainer to re-run for the same tag after a fix in the repository")
    -- S19 (fix round 2): a network failure can come after the upload went through, so
    -- the re-run route must send the maintainer to the files page before the re-run.
    local rerunBullet = docs:match("%- The token, CurseForge's version list, or the network:(.-) %- ")
    lu.assertNotNil(rerunBullet, "no re-run bullet for causes outside the repository")
    local filesPage = rerunBullet:find("files page", 1, true)
    lu.assertNotNil(filesPage, "the re-run route does not check the files page first: " .. rerunBullet)
    lu.assertTrue(filesPage < rerunBullet:find('"Re-run failed jobs"', 1, true),
        "the files page check comes after the re-run: " .. rerunBullet)
    lu.assertStrContains(rerunBullet, "When no file for this version is listed there",
        "the re-run is not limited to a version with no file listed")
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
    -- Without the event Check sees "unknown" and never publishes: a release would
    -- build green and upload nothing (fix round 1, finding 2).
    lu.assertStrContains(workflow, 'lua5.4 spec/release.lua \\\n            --event "$GITHUB_EVENT_NAME" \\\n            --ref "$GITHUB_REF" \\\n')
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

-- A small evaluator for GitHub Actions expressions (`${{ ... }}`), enough for the
-- packager's args: literals ('text', true, false, null, numbers), dotted context
-- names, !, ==, !=, &&, || and parentheses. Rules from GitHub's expressions docs:
-- && and || return one of their operands, the falsy values are false, 0, '' and
-- null, == compares strings ignoring case, and a missing context value is null.
-- This is what makes `cond && '' || '-d'` always '-d': '' is falsy.
local function EvalExpression(source, context)
    local tokens, at = {}, 1
    while at <= #source do
        local c = source:sub(at, at)
        if c:match("%s") then
            at = at + 1
        elseif c == "'" then
            local text, stop = "", at + 1
            while true do
                local quote = assert(source:find("'", stop, true), "unterminated string in " .. source)
                text = text .. source:sub(stop, quote - 1)
                if source:sub(quote + 1, quote + 1) == "'" then text, stop = text .. "'", quote + 2 else at = quote + 1 break end
            end
            tokens[#tokens + 1] = { kind = "value", value = text }
        elseif source:sub(at, at + 1):match("^[=!]=") or source:sub(at, at + 1) == "&&" or source:sub(at, at + 1) == "||" then
            tokens[#tokens + 1] = { kind = source:sub(at, at + 1) }
            at = at + 2
        elseif c == "!" or c == "(" or c == ")" then
            tokens[#tokens + 1] = { kind = c }
            at = at + 1
        else
            local word = assert(source:match("^[%w_%.%-]+", at), "cannot read expression at: " .. source:sub(at))
            at = at + #word
            if word == "true" then tokens[#tokens + 1] = { kind = "value", value = true }
            elseif word == "false" then tokens[#tokens + 1] = { kind = "value", value = false }
            elseif word == "null" then tokens[#tokens + 1] = { kind = "value", value = nil }
            elseif tonumber(word) then tokens[#tokens + 1] = { kind = "value", value = tonumber(word) }
            else tokens[#tokens + 1] = { kind = "value", value = context[word] } end
        end
    end
    local pos = 1
    local function Truthy(v) return not (v == nil or v == false or v == 0 or v == "") end
    local function Equal(a, b)
        if type(a) == "string" and type(b) == "string" then return a:lower() == b:lower() end
        return a == b
    end
    local Or
    local function Primary()
        local token = assert(tokens[pos], "expression ends early: " .. source)
        pos = pos + 1
        if token.kind == "value" then return token.value end
        if token.kind == "!" then return not Truthy(Primary()) end
        if token.kind == "(" then
            local v = Or()
            assert(tokens[pos] and tokens[pos].kind == ")", "missing ) in " .. source)
            pos = pos + 1
            return v
        end
        error("unexpected " .. token.kind .. " in " .. source)
    end
    local function Compare()
        local left = Primary()
        while tokens[pos] and (tokens[pos].kind == "==" or tokens[pos].kind == "!=") do
            local op = tokens[pos].kind
            pos = pos + 1
            local right = Primary()
            if op == "==" then left = Equal(left, right) else left = not Equal(left, right) end
        end
        return left
    end
    local function And()
        local left = Compare()
        while tokens[pos] and tokens[pos].kind == "&&" do
            pos = pos + 1
            local right = Compare()
            if Truthy(left) then left = right end
        end
        return left
    end
    function Or()
        local left = And()
        while tokens[pos] and tokens[pos].kind == "||" do
            pos = pos + 1
            local right = And()
            if not Truthy(left) then left = right end
        end
        return left
    end
    local result = Or()
    assert(pos == #tokens + 1, "trailing tokens in " .. source)
    return result
end

-- What the packager step receives as args for a run, with every ${{ }} evaluated.
local function PackagerArgs(context)
    local workflow = ReadFile(".github/workflows/release.yml"):gsub("\r\n", "\n")
    local step = assert(workflow:match("uses: BigWigsMods/packager@.-\n(.-)\n%s*\n"), "no packager step")
    local args = assert(step:match("args:%s*>%-?\n(.*)$"), "no args block in the packager step")
    return (args:gsub("%${{(.-)}}", function(expr)
        local value = EvalExpression(expr, context)
        if value == nil then return "" end
        return tostring(value)
    end))
end

local function HasDryRunFlag(args)
    for word in args:gmatch("%S+") do if word == "-d" then return true end end
    return false
end

-- The evaluator itself, on GitHub's documented examples of && and || returning operands.
function TestRelease:test_the_expression_evaluator()
    lu.assertEquals(EvalExpression("true && '' || '-d'", {}), "-d")
    lu.assertEquals(EvalExpression("'a' == 'A' && 'yes' || 'no'", {}), "yes")
    lu.assertEquals(EvalExpression("x.y != 'true' && '-d' || ''", { ["x.y"] = "false" }), "-d")
    lu.assertEquals(EvalExpression("x.y != 'true' && '-d' || ''", { ["x.y"] = "true" }), "")
    lu.assertEquals(EvalExpression("!(a == 'push') && 'n' || 'p'", { a = "push" }), "p")
    lu.assertNil(EvalExpression("missing.value", {}))
end

-- Runs Release.Main the way the workflow's check step does, on temp files, and returns
-- its exit code, the outputs it wrote to GITHUB_OUTPUT (as a table) and the changelog
-- it wrote. print, stderr and os.getenv are swapped for the call and restored.
local function RunMain(event, ref, listed, notesText)
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
    Write(notes, notesText or NOTES_070)
    Write(versions, listed .. "\n")
    Write(output, "")
    local realGetenv, realPrint, realStderr = os.getenv, print, io.stderr
    os.getenv = function(name) if name == "GITHUB_OUTPUT" then return output end return realGetenv(name) end
    print = function() end
    io.stderr = { write = function() end }
    local ok, code = pcall(Release.Main, { "--event", event, "--ref", ref, "--toc", toc, "--notes", notes,
        "--versions", versions, "--out", out })
    os.getenv, print, io.stderr = realGetenv, realPrint, realStderr
    local outputs, changelog = {}, Read(out)
    for line in (Read(output) or ""):gmatch("[^\n]+") do
        local key, value = line:match("^([%w_]+)=(.*)$")
        if key then outputs[key] = value end
    end
    for _, path in ipairs({ base, toc, notes, versions, out, output }) do os.remove(path) end
    assert(ok, code)
    return code, outputs, changelog
end

-- What the packager step receives after the check step wrote `outputs`.
local function ArgsAfter(event, ref, outputs)
    local context = { ["github.event_name"] = event, ["github.ref"] = ref }
    for key, value in pairs(outputs) do context["steps.check.outputs." .. key] = value end
    return PackagerArgs(context)
end

-- Fix round 1, the event table: the check step (Release.Main with the event and ref
-- the workflow passes) and the packager's args evaluated from its outputs, end to end.
-- Only a pushed release tag with clean stops uploads (S1, AC1); a hand start on the
-- same tag (S24, AC5), another v-tag, a pull request and a branch build with -d; a
-- release tag with a failed stop goes red before the packager (AC6).
function TestRelease:test_the_event_table_from_check_to_packager()
    local rows = {
        { event = "push", ref = "refs/tags/v0.7.0", clean = true, exit = 0, dryRun = false },
        { event = "push", ref = "refs/tags/v0.7.0", clean = false, exit = 1 },
        { event = "push", ref = "refs/tags/v0.7.0-beta1", clean = true, exit = 0, dryRun = true },
        { event = "pull_request", ref = "refs/pull/7/merge", clean = true, exit = 0, dryRun = true },
        { event = "workflow_dispatch", ref = "refs/tags/v0.7.0", clean = true, exit = 0, dryRun = true },
        { event = "workflow_dispatch", ref = "refs/heads/main", clean = true, exit = 0, dryRun = true },
    }
    for _, row in ipairs(rows) do
        local label = row.event .. " " .. row.ref .. (row.clean and " clean" or " with a failed stop")
        local code, outputs = RunMain(row.event, row.ref, row.clean and "1.60.1" or "1.59.0")
        lu.assertEquals(code, row.exit, label .. ": exit code")
        if row.exit ~= 0 then
            -- The step fails, so the packager never runs; nothing may say publish either.
            lu.assertNotEquals(outputs.publish, "true", label .. ": publish output")
        else
            local args = ArgsAfter(row.event, row.ref, outputs)
            lu.assertEquals(HasDryRunFlag(args), row.dryRun, label .. ": packager args '" .. args .. "'")
        end
    end
    -- How line 160: -d is the fail-safe default. A check step that wrote no outputs at
    -- all (or anything but publish=true) must still leave the packager on -d.
    for _, outputs in ipairs({ {}, { publish = "false" }, { publish = "" } }) do
        local args = ArgsAfter("push", "refs/tags/v0.7.0", outputs)
        lu.assertTrue(HasDryRunFlag(args), "outputs without publish=true must give -d: '" .. args .. "'")
    end
end

-- The check step's other outputs: the changelog it writes for the packager and the
-- publish flag, on a clean release tag, a red one and a clean and a red pull request.
function TestRelease:test_the_entry_point_tells_the_workflow_whether_to_publish()
    local code, outputs, changelog = RunMain("push", "refs/tags/v0.7.0", "1.60.1")
    lu.assertEquals(code, 0, "a clean release tag")
    lu.assertEquals(outputs.publish, "true")
    lu.assertEquals(changelog, "- Fixed the frames.\n")
    code, outputs, changelog = RunMain("push", "refs/tags/v0.7.0", "1.59.0")
    lu.assertEquals(code, 1, "a release tag whose game version is not listed")
    lu.assertNil(outputs.publish, "a failed stop writes no publish line")
    lu.assertNil(changelog, "a failed stop writes no changelog")
    -- A pull request (build-only): green and publish=false when clean, red when the
    -- toc version's notes are missing (Architect's ruling, 2026-11-15).
    code, outputs, changelog = RunMain("pull_request", "refs/pull/7/merge", "1.60.1")
    lu.assertEquals(code, 0, "a clean pull request")
    lu.assertEquals(outputs.publish, "false")
    lu.assertEquals(changelog, "- Fixed the frames.\n")
    code, outputs = RunMain("pull_request", "refs/pull/7/merge", "1.60.1", NOTES_NO_070)
    lu.assertEquals(code, 1, "a pull request without the toc version's notes")
    lu.assertNil(outputs.publish, "a red pull request writes no publish line")
end

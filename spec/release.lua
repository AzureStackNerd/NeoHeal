-- The release stops, as code the suite runs: what a pushed ref means, whether the
-- release may be published, and the notes the upload carries. spec/run.lua loads
-- this like any test file through spec/release_test.lua; the release workflow
-- (.github/workflows/release.yml) runs it as a script before the packager, so a
-- stop that fails ends the run before anything reaches CurseForge.
--
-- Every check here is a pure function of text the caller reads: the workflow
-- passes in the ref, the toc, docs/curseforge.md and the Forever version names
-- CurseForge lists, and the tests pass made-up text. That keeps each stop
-- testable without GitHub, a token or a tag.
local Release = {}

-- NeoHeal's CurseForge project, confirmed on the project page on 2026-11-15.
Release.PROJECT_ID = "1726356"

-- The game type CurseForge lists WoW: Forever under (release.sh:2909), and the
-- Interface value the client reports for it (NeoHeal.toc).
Release.FOREVER_GAME_VERSION_TYPE = "88568"
Release.INTERFACE = "16001"

-- What each ship list leaves out, as plain names: the packager's .pkgmeta
-- `ignore:` and .gitattributes' `export-ignore` must name the same entries, since
-- release.sh never reads .gitattributes and each route needs its own list.
-- A test reads both files and holds them to this table.
Release.SHIP_LISTS = {
    pkgmeta = { "docs", "spec", "CLAUDE.md", ".claude", ".github", ".gitattributes", ".gitignore", ".pkgmeta" },
    gitattributes = { "docs", "spec", "CLAUDE.md", ".claude", ".github", ".gitattributes", ".gitignore", ".pkgmeta" },
}

-- Splits text into lines without their line ending, CRLF and LF alike.
local function Lines(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = (line:gsub("\r$", ""))
    end
    return lines
end

-- The value of a toc line such as `## Version: 0.7.0`, or nil when it has none.
-- The key is compared as plain text: a pattern match would read the hyphens in
-- "X-Curse-Project-ID" as lazy repetition markers (X- means "zero or more X").
function Release.TocField(toc, key)
    for _, line in ipairs(Lines(toc)) do
        local foundKey, value = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if foundKey and (foundKey:gsub("%s+$", "")) == key then return value end
    end
    return nil
end

-- The Interface value without its trailing spaces, as the packager reads it.
function Release.TocInterface(toc)
    return Release.TocField(toc, "Interface")
end

-- The files the toc loads, in order, with forward slashes: the game loads exactly
-- these and nothing else.
function Release.TocLoads(toc)
    local loads = {}
    for _, line in ipairs(Lines(toc)) do
        local name = line:match("^%s*([^%s#].*%S)%s*$")
        if name and not name:match("^##") then
            loads[#loads + 1] = (name:gsub("\\", "/"))
        end
    end
    return loads
end

-- The version the packager compares on CurseForge, from the toc's Interface:
-- release.sh turns 16001 into 1.60.1 (printf "%d.%d.%d" of 16, 00 and 01), and the
-- upload looks that name up among the Forever versions CurseForge lists.
function Release.VersionFromInterface(interface)
    assert(type(interface) == "string" and interface:match("^%d%d%d%d%d+$"),
        "an Interface value needs five or more digits, got " .. tostring(interface))
    local major = tonumber(interface:sub(1, #interface - 4))
    local minor = tonumber(interface:sub(#interface - 3, #interface - 2))
    local patch = tonumber(interface:sub(#interface - 1))
    return string.format("%d.%d.%d", major, minor, patch)
end

-- The version a tag names when it is a release tag (v0.7.0), else nil. Anything
-- else, a pre-release tag included, publishes nothing.
function Release.ReleaseTagVersion(tag)
    return tag and tag:match("^v(%d+%.%d+%.%d+)$") or nil
end

-- The tag a GITHUB_REF points at, or nil when it is not a tag ref.
function Release.TagOf(ref)
    return ref and ref:match("^refs/tags/(.+)$") or nil
end

-- What a pushed tag starts: a release, or a run that builds and publishes nothing.
-- A v-tag that is not vX.Y.Z is the second: a pre-release tag, or a typo, which must
-- not look like a release that went out.
function Release.TagAction(tag)
    if Release.ReleaseTagVersion(tag) then return "release" end
    return "build-only"
end

local function IsHeading(line)
    return line:match("^#%s") ~= nil or line:match("^##%s") ~= nil or line:match("^###%s") ~= nil
end

-- The notes for one version out of docs/curseforge.md. A section starts at a line
-- that is exactly `### <version>`, trailing spaces aside, and ends at the next
-- heading of level 1 to 3 or at the end of the file. Returns the section's text
-- (nil when it holds nothing but blank lines) and how many sections matched, so
-- the caller can tell "no section" from "two sections" from "an empty section".
function Release.Notes(text, version)
    local heading = "### " .. version
    local sections, current = {}, nil
    for _, line in ipairs(Lines(text)) do
        local trimmed = (line:gsub("%s+$", ""))
        if IsHeading(trimmed) then
            current = nil
            if trimmed == heading then
                current = {}
                sections[#sections + 1] = current
            end
        elseif current then
            current[#current + 1] = trimmed
        end
    end
    if #sections == 0 then return nil, 0 end
    -- Blank lines around the body are layout, not notes.
    local body = sections[1]
    while #body > 0 and body[1] == "" do table.remove(body, 1) end
    while #body > 0 and body[#body] == "" do table.remove(body) end
    if #body == 0 then return nil, #sections end
    return table.concat(body, "\n"), #sections
end

-- The entries a .pkgmeta `ignore:` list holds, in order, as plain names.
function Release.PkgmetaIgnore(text)
    local entries, inList = {}, false
    for _, line in ipairs(Lines(text)) do
        if line:match("^%S") then
            inList = line:match("^ignore%s*:") ~= nil
        elseif inList then
            local item = line:match("^%s*%-%s*(.-)%s*$")
            if item then entries[#entries + 1] = (item:gsub("^[\"']", ""):gsub("[\"']$", "")) end
        end
    end
    return entries
end

-- The entries a .gitattributes' `export-ignore` lines hold, as plain names.
function Release.GitattributesIgnore(text)
    local entries = {}
    for _, line in ipairs(Lines(text)) do
        local path = line:match("^%s*([^#%s][^%s]*)%s+export%-ignore%s*$")
        if path then entries[#entries + 1] = (path:gsub("^/", "")) end
    end
    return entries
end

-- A problem when a ship list holds an entry the other does not, else nil. Both
-- lists exist because the packager and the hand route are two builds of the same
-- ZIP; an entry in only one of them leaks whatever it names through that route.
function Release.ShipListsProblem(pkgmetaText, gitattributesText)
    local inPkgmeta, inGitattributes = Release.PkgmetaIgnore(pkgmetaText), Release.GitattributesIgnore(gitattributesText)
    local known, problems = {}, {}
    for _, name in ipairs(inPkgmeta) do known[name] = known[name] or {} known[name].pkgmeta = true end
    for _, name in ipairs(inGitattributes) do known[name] = known[name] or {} known[name].gitattributes = true end
    for _, name in ipairs(inPkgmeta) do
        if not known[name].gitattributes then
            problems[#problems + 1] = ".gitattributes does not leave out \"" .. name .. "\", which .pkgmeta ignores"
        end
    end
    for _, name in ipairs(inGitattributes) do
        if not known[name].pkgmeta then
            problems[#problems + 1] = ".pkgmeta does not ignore \"" .. name .. "\", which .gitattributes leaves out"
        end
    end
    if #problems == 0 then return nil end
    return table.concat(problems, "; ")
end

-- The first tracked file that would reach players without being meant to, else
-- nil. A file may ship when it is the toc, LICENSE, a file the toc loads, or under
-- an entry both ship lists name. `ignored` is that shared set, so a synthetic list
-- tests the rule without a repository; it defaults to the entries both real lists
-- hold.
function Release.ShipListProblem(files, tocLoads, ignored)
    local leaves = ignored or Release.SHIP_LISTS.pkgmeta
    local loaded, left = {}, {}
    for _, name in ipairs(tocLoads) do loaded[name] = true end
    for _, name in ipairs(leaves) do left[name] = true end
    for _, file in ipairs(files) do
        if file ~= "NeoHeal.toc" and file ~= "LICENSE" and not loaded[file] then
            local covered = false
            for name in pairs(left) do
                if file == name or file:sub(1, #name + 1) == name .. "/" then covered = true end
            end
            if not covered then
                return file .. " is tracked but the toc does not load it and both ship lists " ..
                    "leave it in the ZIP; load it in NeoHeal.toc or add it to .pkgmeta and .gitattributes"
            end
        end
    end
    return nil
end

-- Every reason the release cannot be published, in a fixed order, so a failed run
-- names all of them at once instead of one per attempt: the tag against the toc's
-- version (only when a tag version is passed), the notes, the project id, and the
-- game version CurseForge lists. Each reason is a sentence the maintainer can act on.
function Release.Problems(input)
    local problems = {}
    local version = input.version
    if input.tagVersion then
        local tocVersion = Release.TocField(input.toc, "Version")
        if version ~= tocVersion then
            problems[#problems + 1] = "the tag names " .. tostring(version) ..
                ", but NeoHeal.toc says Version " .. tostring(tocVersion)
        end
    end
    local notes, sections = Release.Notes(input.notes or "", version)
    if sections == 0 then
        problems[#problems + 1] = "docs/curseforge.md has no \"### " .. version .. "\" section for this version's notes"
    elseif sections > 1 then
        problems[#problems + 1] = "docs/curseforge.md has " .. sections .. " \"### " .. version ..
            "\" sections, so which notes belong to the release is unclear"
    elseif not notes then
        problems[#problems + 1] = "the \"### " .. version .. "\" section in docs/curseforge.md holds no notes"
    end
    local projectId = Release.TocField(input.toc, "X-Curse-Project-ID")
    if not projectId then
        problems[#problems + 1] = "NeoHeal.toc has no X-Curse-Project-ID line, so the upload has no project"
    elseif projectId ~= Release.PROJECT_ID then
        problems[#problems + 1] = "NeoHeal.toc's X-Curse-Project-ID is " .. projectId .. ", not " .. Release.PROJECT_ID
    end
    local interface = Release.TocInterface(input.toc)
    local gameVersion = interface and Release.VersionFromInterface(interface)
    local listed = false
    for _, name in ipairs(input.versions or {}) do
        if name == gameVersion then listed = true end
    end
    if not listed then
        problems[#problems + 1] = "CurseForge calls this release's game version " .. tostring(gameVersion) ..
            " (NeoHeal.toc's Interface " .. tostring(interface) .. "), which it does not list"
    end
    return problems
end

-- What one run does: publish, or build and stop. `publish` is true only for a release
-- version tag pushed as a tag (`event` "push"); a hand start on the same ref, a pull
-- request and every other tag publish nothing, and `notice` says why. The checks run
-- on every start, not only on a release tag: a pull request and a hand start exist to
-- prove the release path without publishing, and a stop that only ran for real would
-- first be exercised by a live release. A run with a problem is red whatever started
-- it, so a green run never carries an error.
--
-- The event is an input as much as the ref is: "Run workflow" on a version tag gives
-- the same GITHUB_REF as a tag push and must not publish.
function Release.Check(input)
    local result = { action = "build-only", publish = false, problems = {}, notice = nil }
    local event = input.event or "unknown"
    local tag = Release.TagOf(input.ref)
    local releaseVersion = Release.ReleaseTagVersion(tag)
    if not tag then
        result.notice = "a run without a release tag publishes nothing"
    elseif not releaseVersion then
        result.notice = "not a release tag, nothing published"
    elseif event ~= "push" then
        result.notice = "only a tag push publishes; nothing published for a " .. event .. " run"
    else
        result.action = Release.TagAction(tag)
    end
    -- Only a release tag has a version to compare against the toc's; a pull request
    -- merges into a commit no tag names, so that one stop is skipped there.
    result.version = releaseVersion or Release.TocField(input.toc, "Version")
    result.problems = Release.Problems({ tagVersion = releaseVersion, version = result.version,
        toc = input.toc, notes = input.notes, versions = input.versions })
    result.publish = event == "push" and releaseVersion ~= nil and result.problems[1] == nil
    return result
end

local function ReadFile(path)
    local file = assert(io.open(path, "r"), "cannot read " .. path)
    local text = file:read("*a")
    file:close()
    return text
end

-- The release workflow's entry point: read the files, print every reason the
-- release cannot be published, write the notes the upload carries, and tell the
-- workflow whether to let the packager upload. Exits non-zero when a stop fails.
function Release.Main(argv)
    local options = { toc = "NeoHeal.toc", notes = "docs/curseforge.md" }
    local index = 1
    while argv[index] do
        local key, value = argv[index]:match("^%-%-(.+)$"), argv[index + 1]
        if not key or not value then
            io.stderr:write("usage: lua spec/release.lua --event <event> --ref <ref> --versions <file> --out <file>\n")
            return 2
        end
        options[key] = value
        index = index + 2
    end
    local versions = {}
    if options.versions then
        for _, line in ipairs(Lines(ReadFile(options.versions))) do
            if line:match("%S") then versions[#versions + 1] = (line:gsub("%s+$", "")) end
        end
    end
    local result = Release.Check({ event = options.event, ref = options.ref, toc = ReadFile(options.toc),
        notes = ReadFile(options.notes), versions = versions })
    local interface = Release.TocInterface(ReadFile(options.toc))
    local gameVersion = interface and Release.VersionFromInterface(interface)
    -- Say which Forever version the upload would carry and whether the versions the
    -- token step fetched actually list it; the stop below fails when they do not,
    -- so this line cannot claim a match it did not check.
    local listed = false
    for _, name in ipairs(versions) do
        if name == gameVersion then listed = true end
    end
    print("NeoHeal " .. tostring(result.version) .. ", Forever " .. tostring(gameVersion) ..
        (listed and " (listed)" or " (not listed)") .. ", " .. #versions .. " Forever version(s) fetched")
    if result.notice then print("::warning::" .. result.notice) end
    if #result.problems > 0 then
        for _, problem in ipairs(result.problems) do
            io.stderr:write("::error::" .. problem .. "\n")
        end
        print("::error::nothing was published")
        return 1
    end
    -- No problem above means Notes() found exactly one non-empty section for this
    -- version, so the packager gets a real changelog instead of its commit-log
    -- fallback (which would otherwise ship in the ZIP, with the run still green).
    if options.out then
        local notes = assert(Release.Notes(ReadFile(options.notes), result.version),
            "no notes for " .. tostring(result.version) .. " after a clean check")
        local file = assert(io.open(options.out, "w"), "cannot write " .. options.out)
        file:write(notes, "\n")
        file:close()
        print("changelog written to " .. options.out)
    end
    if os.getenv("GITHUB_OUTPUT") then
        local file = assert(io.open(os.getenv("GITHUB_OUTPUT"), "a"))
        file:write("publish=" .. tostring(result.publish) .. "\n")
        file:close()
    end
    print(result.publish and "publishing " .. result.version or "building only, nothing published")
    return 0
end

-- Run as a script (the release workflow does), not required by a test. The check is
-- the whole file name: a pattern like "release.lua$" also matches a helper script
-- such as check-release.lua, which then runs Main with no arguments.
local scriptName = arg and arg[0] and arg[0]:match("([^/\\]+)$")
if scriptName == "release.lua" then
    os.exit(Release.Main(arg))
end

return Release

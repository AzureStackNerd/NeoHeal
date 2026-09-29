-- Raid frame layout: one secure group header per raid group (1-8), chained side
-- by side, with two optional extra headers: main tanks before the groups and pets
-- after them. Only groups with members take up room, so a party shows one column
-- and a full raid eight. Every group is a column; its members are the rows.
--
-- Secure group headers are Blizzard's own building block. They add, remove and
-- reorder unit buttons by themselves, including in combat when addons can't.
local _, NeoHeal = ...
local L = NeoHeal.L
local IsSecret = NeoHeal.IsSecret

local NUM_GROUPS = 8
local MAX_GROUP_SIZE = 5

-- The unit button, plus the secure handlers that run the hover-key snippets
-- (_onenter / _onleave / _onhide, see ClickCast.lua).
local BUTTON_TEMPLATE = "SecureUnitButtonTemplate,SecureHandlerEnterLeaveTemplate,SecureHandlerShowHideTemplate"

local Layout = {
    headers = {},          -- [group] = header
    mainTankHeader = nil,  -- raid members marked as Main Tank (they also stay in their group)
    petHeader = nil,
    testSize = nil,        -- number of fake members while test mode is on
}
NeoHeal.Layout = Layout

-- Runs in the secure environment each time a header creates a button (possibly in
-- combat). It sizes the button and copies the click bindings from the header's
-- attributes (kept current by ClickCast:Apply), then lets Lua add the visuals.
local INITIAL_CONFIG = [[
    local header = self:GetParent()
    self:SetWidth(header:GetAttribute("neoWidth"))
    self:SetHeight(header:GetAttribute("neoHeight"))
    for index = 1, header:GetAttribute("neoClickCount") or 0 do
        self:SetAttribute(header:GetAttribute("neoClickName" .. index), header:GetAttribute("neoClickValue" .. index))
    end
    header:CallMethod("InitUnitButton", self:GetName())
]]

-- Sort orders within a group, as secure header attributes. Roles and classes
-- are grouped in the order given; players without one come last.
local SORT_ORDERS = {
    index = { sortMethod = "INDEX" },
    name  = { sortMethod = "NAME" },
    role  = { sortMethod = "INDEX", groupBy = "ASSIGNEDROLE", groupingOrder = "TANK,HEALER,DAMAGER,NONE" },
    class = { sortMethod = "NAME", groupBy = "CLASS",
              groupingOrder = "WARRIOR,PALADIN,PRIEST,DRUID,SHAMAN,MONK,EVOKER,DEATHKNIGHT,DEMONHUNTER,ROGUE,HUNTER,MAGE,WARLOCK" },
}

Layout.SORT_ORDERS = SORT_ORDERS   -- the test mode preview sorts the same way

local function GetGroupMemberCounts()
    local counts = { 0, 0, 0, 0, 0, 0, 0, 0 }
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            local _, _, subgroup = GetRaidRosterInfo(index)
            if subgroup and not IsSecret(subgroup) then
                counts[subgroup] = counts[subgroup] + 1
            end
        end
    elseif IsInGroup() then
        counts[1] = GetNumGroupMembers()   -- a party is group 1, you included
    elseif NeoHeal.db.layout.showSolo then
        counts[1] = 1
    end
    return counts
end

local function MainTanksShown(settings) return settings.mainTankPosition ~= "none" end
local function PetsShown(settings) return settings.showPets end

local function CountMainTanks()
    if not MainTanksShown(NeoHeal.db.layout) or not IsInRaid() then return 0 end
    local count = 0
    for index = 1, GetNumGroupMembers() do
        local role = select(10, GetRaidRosterInfo(index))
        if role == "MAINTANK" then count = count + 1 end   -- a secret value never equals it
    end
    return count
end

local function CountPets()
    if not NeoHeal.db.layout.showPets then return 0 end
    local count = 0
    if IsInRaid() then
        for index = 1, GetNumGroupMembers() do
            if UnitExists("raidpet" .. index) then count = count + 1 end
        end
    else
        if UnitExists("pet") then count = count + 1 end
        for index = 1, GetNumSubgroupMembers() do
            if UnitExists("partypet" .. index) then count = count + 1 end
        end
    end
    return count
end

local function CreateHeader(container, name, template)
    local header = CreateFrame("Frame", name, container, template)
    header:Hide()   -- no layout passes while we set it up
    header:SetAttribute("template", BUTTON_TEMPLATE)
    header:SetAttribute("showRaid", true)
    header:SetAttribute("initialConfigFunction", INITIAL_CONFIG)
    header.InitUnitButton = function(_, buttonName)
        NeoHeal.UnitButton.Init(_G[buttonName])
    end
    return header
end

local function CreateGroupHeader(container, group)
    local header = CreateHeader(container, "NeoHealGroup" .. group, "SecureGroupHeaderTemplate")
    header:SetAttribute("groupFilter", tostring(group))
    -- Outside a raid the game treats the party (you included) as group 1.
    header:SetAttribute("showParty", group == 1)
    header:SetAttribute("showPlayer", group == 1)
    return header
end

-- Main tanks and pets each get one extra header that wraps into columns of five,
-- like a group.
local function CreateExtraHeader(container, name, template, isShown)
    local header = CreateHeader(container, name, template)
    header.isShown = isShown   -- function(layoutSettings): does this header show at all?
    header:SetAttribute("unitsPerColumn", MAX_GROUP_SIZE)
    header:SetAttribute("maxColumns", NUM_GROUPS)
    return header
end

-- "MAINTANK" is a raid role the header can filter on, like a group number.
local function CreateMainTankHeader(container)
    local header = CreateExtraHeader(container, "NeoHealMainTanks", "SecureGroupHeaderTemplate", MainTanksShown)
    header:SetAttribute("groupFilter", "MAINTANK")
    return header
end

local function CreatePetHeader(container)
    local header = CreateExtraHeader(container, "NeoHealPets", "SecureGroupPetHeaderTemplate", PetsShown)
    header:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    header:SetAttribute("showParty", true)
    header:SetAttribute("showPlayer", true)
    return header
end

-- Every header (main tanks, groups 1-8, pets), for loops that treat them all the
-- same. Not the screen order; that depends on the settings (see Arrange).
-- (Before Create() it only holds the groups.)
function Layout:AllHeaders()
    local all = { self.mainTankHeader }
    for _, header in ipairs(self.headers) do table.insert(all, header) end
    table.insert(all, self.petHeader)
    return all
end

---------------------------------------------------------------------------
-- Moving the frames. Two things can be dragged:
--   * the titles (bar or group labels), with Ctrl held, so a stray click never
--     moves the raid frames. Hovering explains it; holding Ctrl lights them up.
--   * the move-mode overlay (while the options window is open), with a plain drag.
---------------------------------------------------------------------------
local MOVE_COLOR = { 0.2, 1, 0.2 }

function Layout:MakeDraggable(frame, needsCtrl)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        if InCombatLockdown() or (needsCtrl and not IsControlKeyDown()) then return end
        self.container:StartMoving()
        self.isMoving = true
    end)
    frame:SetScript("OnDragStop", function()
        if not self.isMoving then return end   -- the drag never started (no Ctrl)
        self.isMoving = false
        self.container:StopMovingOrSizing()
        self:SavePosition()
    end)
    if needsCtrl then self:AddMoveHint(frame) end
end

-- A small one-line hint above a title. Our own frame, because changing the
-- font of the shared GameTooltip would change every tooltip in the game.
function Layout:GetMoveHint()
    if not self.moveHint then
        local hint = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        hint:SetFrameStrata("TOOLTIP")
        hint:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
        hint:SetBackdropColor(0, 0, 0, 0.85)
        hint.text = hint:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        hint.text:SetPoint("CENTER")
        hint.text:SetText(L.MOVE_HINT)
        hint:SetSize(hint.text:GetStringWidth() + 8, hint.text:GetStringHeight() + 4)
        hint:Hide()
        self.moveHint = hint
    end
    return self.moveHint
end

-- "Ctrl + drag to move" on hover, and a green border while Ctrl is held.
function Layout:AddMoveHint(title)
    local function UpdateHighlight()
        local canMove = IsControlKeyDown() and not InCombatLockdown()
        title:SetBackdropBorderColor(MOVE_COLOR[1], MOVE_COLOR[2], MOVE_COLOR[3], canMove and 0.9 or 0)
    end
    title:SetScript("OnEnter", function()
        local hint = self:GetMoveHint()
        hint:ClearAllPoints()
        hint:SetPoint("BOTTOM", title, "TOP", 0, 2)
        hint:Show()
        title:RegisterEvent("MODIFIER_STATE_CHANGED")   -- only while hovered
        UpdateHighlight()
    end)
    title:SetScript("OnLeave", function()
        self:GetMoveHint():Hide()
        title:UnregisterEvent("MODIFIER_STATE_CHANGED")
        title:SetBackdropBorderColor(MOVE_COLOR[1], MOVE_COLOR[2], MOVE_COLOR[3], 0)
    end)
    title:SetScript("OnEvent", UpdateHighlight)
end

---------------------------------------------------------------------------
-- Titles above the frames. Solo or in a party: one "NeoHeal" bar across all
-- frames. In a raid: a label above every column instead,
-- "Group 1", "Main tanks", ... All of them can be Ctrl-dragged to move the frames.
---------------------------------------------------------------------------
local TITLE_HEIGHT = 16

function Layout:CreateTitleFrame()
    local title = CreateFrame("Frame", nil, self.container, "BackdropTemplate")
    title:SetHeight(TITLE_HEIGHT)
    -- The border stays invisible until Ctrl is held over the title (AddMoveHint).
    title:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    title:SetBackdropColor(0, 0, 0, 0.7)
    title:SetBackdropBorderColor(0, 0, 0, 0)

    title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title.text:SetPoint("LEFT", 2, 0)
    title.text:SetPoint("RIGHT", -2, 0)
    title.text:SetWordWrap(false)

    self:MakeDraggable(title, true)
    return title
end

-- The bar spans the container, which is sized to the frames (see FitToContent).
function Layout:CreateTitleBar()
    local titleBar = self:CreateTitleFrame()
    titleBar:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", 0, 2)
    titleBar:SetPoint("BOTTOMRIGHT", self.container, "TOPRIGHT", 0, 2)
    titleBar.text:SetText(L.ADDON_NAME)
    self.titleBar = titleBar
end

-- Group labels are created as needed and reused.
function Layout:GetGroupLabel(index)
    self.groupLabels = self.groupLabels or {}
    if not self.groupLabels[index] then
        self.groupLabels[index] = self:CreateTitleFrame()
    end
    return self.groupLabels[index]
end

-- Move mode: while the options window is open, a see-through overlay covers the
-- frames and can be dragged. It works even when no frames (and so no titles) show.
function Layout:CreateMover()
    local mover = CreateFrame("Frame", nil, self.container, "BackdropTemplate")
    mover:SetAllPoints(self.container)
    mover:SetFrameStrata("HIGH")   -- above the unit buttons, so it gets the mouse
    mover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    mover:SetBackdropColor(0.1, 0.6, 0.1, 0.35)
    mover:SetBackdropBorderColor(0.2, 1, 0.2, 0.9)

    local text = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint("CENTER")
    text:SetText(L.MOVER_TEXT)

    self:MakeDraggable(mover)
    mover:Hide()
    self.mover = mover
end

-- The overlay would block clicks on the frames, so it never shows in combat.
function Layout:SetMoveMode(enabled)
    if not self.mover then return end
    self.mover:SetShown(enabled and not InCombatLockdown())
end

---------------------------------------------------------------------------
-- Test mode: the real headers are hidden and Preview.lua draws fake members,
-- so the layout can be tuned without a raid. Out of combat only; it is switched
-- off when combat starts (Core.lua) and when the options window closes.
---------------------------------------------------------------------------
function Layout:SetTestMode(size)
    if not self.container or self.testSize == size then return end
    self.testSize = size
    for _, header in ipairs(self:AllHeaders()) do
        header:SetShown(size == nil)
    end
    if size then
        self:FitToContent(NeoHeal.Preview:Show(size))   -- the preview's groups, and "is it a raid"
    else
        NeoHeal.Preview:Hide()
        self:Refresh()
    end
end

---------------------------------------------------------------------------
-- Creating and arranging the headers
---------------------------------------------------------------------------
function Layout:Create()
    local container = CreateFrame("Frame", "NeoHealFrame", UIParent)
    container:SetSize(1, 1)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    self.container = container
    self:CreateTitleBar()
    self:CreateMover()

    self.mainTankHeader = CreateMainTankHeader(container)
    for group = 1, NUM_GROUPS do
        self.headers[group] = CreateGroupHeader(container, group)
    end
    self.petHeader = CreatePetHeader(container)
    self:Refresh()
    self:PreCreateButtons()
end

-- Headers normally create a button when a member first joins, and in combat such a
-- button can't finish its setup (registering clicks is protected). So create all
-- five per group now: a negative startingIndex makes a header lay out placeholder
-- slots. showSolo is forced on because an idle header skips its layout entirely.
function Layout:PreCreateButtons()
    local showSolo = NeoHeal.db.layout.showSolo
    for group, header in ipairs(self.headers) do
        header:SetAttribute("showSolo", true)
        header:SetAttribute("startingIndex", 1 - MAX_GROUP_SIZE)
        header:SetAttribute("startingIndex", 1)
        header:SetAttribute("showSolo", group == 1 and showSolo)
    end
end

-- Applies all layout settings. Out of combat only (callers use RunOutOfCombat).
function Layout:Refresh()
    if not self.container then return end
    local settings = NeoHeal.db.layout
    local sortOrder = SORT_ORDERS[settings.sortOrder] or SORT_ORDERS.index

    self:ApplyScale(settings.scale)
    self:RestorePosition()

    -- In test mode only the preview follows the settings; the headers catch up later.
    if self.testSize then
        self:FitToContent(NeoHeal.Preview:Show(self.testSize))
        return
    end

    for _, header in ipairs(self:AllHeaders()) do
        -- A visible header re-runs its layout on every attribute change, so it would
        -- see half-applied settings (e.g. groupBy without its groupingOrder, which
        -- errors). Hidden, it lays out once, when shown again at the end.
        header:Hide()
        for _, button in ipairs({ header:GetChildren() }) do
            button:SetSize(settings.buttonWidth, settings.buttonHeight)
        end
        local showsPlayerSolo = header == self.headers[1] or header == self.petHeader
        header:SetAttribute("neoWidth", settings.buttonWidth)
        header:SetAttribute("neoHeight", settings.buttonHeight)
        header:SetAttribute("showSolo", showsPlayerSolo and settings.showSolo)
        header:SetAttribute("point", "TOP")   -- members stack downwards
        header:SetAttribute("xOffset", 0)
        header:SetAttribute("yOffset", -settings.spacing)
        header:SetAttribute("sortMethod", sortOrder.sortMethod)
        header:SetAttribute("groupBy", sortOrder.groupBy)
        header:SetAttribute("groupingOrder", sortOrder.groupingOrder)
        if header.isShown then
            -- Extra headers wrap into further columns of five, to the right.
            header:SetAttribute("columnAnchorPoint", "LEFT")
            header:SetAttribute("columnSpacing", settings.spacing)
            header:SetShown(header.isShown(settings))
        else
            header:Show()
        end
    end

    self:Arrange()
    NeoHeal.Hots.RefreshSizes()
    NeoHeal.UnitButton:RefreshDispelContainers()
    NeoHeal.Blizzard:ApplyHiding()
    NeoHeal.UnitButton:UpdateAllButtons()
end

-- The number of columns a group of `count` units takes (five units per column).
local function ColumnsFor(count)
    return math.ceil(count / MAX_GROUP_SIZE)
end

-- Places every header at a computed position, in screen order. Each header with
-- units takes as many columns as it needs; an empty or hidden header takes none.
-- Positions come from member counts only, never from Blizzard's header sizes, so
-- an empty header can't leave a gap.
--
-- It runs out of combat after roster changes. Should an empty group get members
-- during combat, it appears at the end of the frames until combat ends.
function Layout:Arrange()
    if not self.container or self.testSize then return end
    local settings = NeoHeal.db.layout
    local memberCounts = GetGroupMemberCounts()
    local mainTankCount = CountMainTanks()
    local petCount = CountPets()

    -- Screen order: { header, count = units it shows, label = its title in a raid }.
    local order = {}
    local mainTanks = { header = self.mainTankHeader, count = mainTankCount, label = L.MAIN_TANKS }
    local mainTanksFirst = settings.mainTankPosition == "first"
    if mainTanksFirst then table.insert(order, mainTanks) end
    for group, header in ipairs(self.headers) do
        table.insert(order, { header = header, count = memberCounts[group], label = format(L.GROUP_NUMBER, group) })
    end
    table.insert(order, { header = self.petHeader, count = petCount, label = L.PETS })
    if not mainTanksFirst then table.insert(order, mainTanks) end   -- "last" means after the pets too

    local columnStep = settings.buttonWidth + settings.spacing
    local column = 0
    for _, entry in ipairs(order) do
        entry.header:ClearAllPoints()
        entry.header:SetPoint("TOPLEFT", self.container, "TOPLEFT", column * columnStep, 0)
        column = column + ColumnsFor(entry.count)
    end

    self:FitToContent(order, IsInRaid())
end

-- Sizes the container to the frames on screen and puts the titles above them.
-- `order` lists what is shown, in screen order: { count = units, label = title }.
-- The real layout (Arrange) and the test mode preview both call this.
function Layout:FitToContent(order, isRaid)
    local settings = NeoHeal.db.layout
    local columns, rows = 0, 0   -- columns in use, and the most units in one column
    for _, entry in ipairs(order) do
        columns = columns + ColumnsFor(entry.count)
        rows = math.max(rows, math.min(entry.count, MAX_GROUP_SIZE))
    end

    local width = columns * settings.buttonWidth + math.max(columns - 1, 0) * settings.spacing
    local height = rows * settings.buttonHeight + math.max(rows - 1, 0) * settings.spacing
    -- At least one button in size, so move mode has something to grab when no frames show.
    self.container:SetSize(math.max(width, settings.buttonWidth), math.max(height, settings.buttonHeight))

    local showTitles = columns > 0
    local labelPerGroup = showTitles and isRaid
    self.titleBar:SetShown(showTitles and not labelPerGroup)
    self:PlaceGroupLabels(labelPerGroup and order or {})
end

-- One label above each group that has units, as wide as the group's columns.
function Layout:PlaceGroupLabels(order)
    local settings = NeoHeal.db.layout
    local step = settings.buttonWidth + settings.spacing
    local column, used = 0, 0
    for _, entry in ipairs(order) do
        local groupColumns = ColumnsFor(entry.count)
        if groupColumns > 0 then
            used = used + 1
            local label = self:GetGroupLabel(used)
            label.text:SetText(entry.label)
            label:ClearAllPoints()
            label:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", column * step, 2)
            label:SetWidth(groupColumns * settings.buttonWidth + (groupColumns - 1) * settings.spacing)
            label:Show()
            column = column + groupColumns
        end
    end
    for index = used + 1, #(self.groupLabels or {}) do
        self.groupLabels[index]:Hide()
    end
end

---------------------------------------------------------------------------
-- Position. The frames are pinned by their top-left corner, so they only ever
-- grow to the right and down: group 1 stays where you put it, however many
-- groups (or main tanks, or pets) show up.
---------------------------------------------------------------------------
function Layout:SavePosition()
    local left, top = self.container:GetLeft(), self.container:GetTop()
    if not left or not top then return end
    local position = NeoHeal.db.layout.position
    -- Relative to the screen's bottom-left, in the container's own (scaled) units.
    position.point, position.relativePoint, position.x, position.y = "TOPLEFT", "BOTTOMLEFT", left, top
end

function Layout:RestorePosition()
    local position = NeoHeal.db.layout.position
    self.container:ClearAllPoints()
    self.container:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
    -- Positions saved before top-left pinning (and the default) are converted once.
    if position.point ~= "TOPLEFT" then
        self:SavePosition()
        if position.point == "TOPLEFT" then   -- only if the conversion worked
            self.container:ClearAllPoints()
            self.container:SetPoint(position.point, UIParent, position.relativePoint, position.x, position.y)
        end
    end
end

-- Position offsets are in the container's scaled units, so a new scale would move
-- the frames. Converting the saved offsets keeps the top-left corner in place.
function Layout:ApplyScale(scale)
    local oldScale = self.container:GetScale()
    if oldScale == scale then return end
    local position = NeoHeal.db.layout.position
    if position.point == "TOPLEFT" then
        position.x = position.x * oldScale / scale
        position.y = position.y * oldScale / scale
    end
    self.container:SetScale(scale)
end

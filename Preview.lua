-- Test mode preview: fake raid members drawn with the same visuals as the real
-- unit buttons, laid out and sorted like the real layout (including the main
-- tank group and pets, when enabled). They are plain frames (nothing to click),
-- so they can be shown, hidden and rebuilt freely.
local _, NeoHeal = ...

local Preview = {
    frames = {},   -- reused between Show calls
}
NeoHeal.Preview = Preview

local MAX_GROUP_SIZE = 5
local MAX_MAIN_TANKS = 2
local CLASSES = { "WARRIOR", "PRIEST", "DRUID", "PALADIN", "SHAMAN", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
local POWER_BY_CLASS = { WARRIOR = "RAGE", ROGUE = "ENERGY" }   -- everyone else uses mana

-- Roles the fake members would have picked, for the "tanks, healers, damage" sort.
local FAKE_ROLES = { WARRIOR = "TANK", PRIEST = "HEALER", DRUID = "HEALER", PALADIN = "HEALER", SHAMAN = "HEALER" }

local function GetClass(member)
    return CLASSES[(member - 1) % #CLASSES + 1]
end

-- Fake names per class. Classes rotate through CLASSES, so member 1 is the first
-- warrior, member 10 the second warrior, and so on: 40 members, 40 names.
local FAKE_NAMES = {
    WARRIOR = { "Grimthorn", "Brakka", "Thuldrin", "Korvash", "Ironhelm" },
    PRIEST  = { "Seraphine", "Aldwyn", "Lumara", "Vaelith", "Solenne" },
    DRUID   = { "Thornwood", "Elunara", "Mossbrook", "Faelan", "Wildmane" },
    PALADIN = { "Aurelion", "Brightward", "Valorian", "Lightbourne", "Castellan" },
    SHAMAN  = { "Stormhoof", "Zul'katar", "Thunderhide", "Earthcaller" },
    ROGUE   = { "Shadeveil", "Nixra", "Quickblade", "Vesper" },
    MAGE    = { "Frostwyn", "Arcanis", "Emberlyn", "Quillon" },
    WARLOCK = { "Morvoren", "Hexxus", "Nightbane", "Soulreave" },
    HUNTER  = { "Talonfeather", "Wolfsbane", "Arrowind", "Keeneye" },
}

local function GetName(member)
    local class = GetClass(member)
    local names = FAKE_NAMES[class]
    return names[math.ceil(member / #CLASSES)] or format("%s %d", names[1], member)
end

---------------------------------------------------------------------------
-- Sorting, following the same header settings as the real frames
-- (Layout.SORT_ORDERS): an optional grouping (by role or class, in the order
-- given), then raid order or name.
---------------------------------------------------------------------------
local GROUPING_KEYS = {
    ASSIGNEDROLE = function(member) return FAKE_ROLES[GetClass(member)] or "DAMAGER" end,
    CLASS = GetClass,
}

-- "TANK,HEALER,DAMAGER" -> { TANK = 1, HEALER = 2, DAMAGER = 3 }
local function RankTable(groupingOrder)
    local ranks, rank = {}, 0
    for token in groupingOrder:gmatch("[^,]+") do
        rank = rank + 1
        ranks[token] = rank
    end
    return ranks
end

local function SortMembers(members, sortOrder)
    local groupingKey = sortOrder.groupBy and GROUPING_KEYS[sortOrder.groupBy]
    local ranks = groupingKey and RankTable(sortOrder.groupingOrder)
    local byName = sortOrder.sortMethod == "NAME"

    table.sort(members, function(a, b)
        if groupingKey then
            local rankA = ranks[groupingKey(a)] or math.huge
            local rankB = ranks[groupingKey(b)] or math.huge
            if rankA ~= rankB then return rankA < rankB end
        end
        if byName then return GetName(a) < GetName(b) end
        return a < b   -- raid order
    end)
end

local function GetFrame(index)
    local frame = Preview.frames[index]
    if not frame then
        frame = CreateFrame("Frame", nil, NeoHeal.Layout.container)
        NeoHeal.UnitButton.CreateVisuals(frame)
        Preview.frames[index] = frame
    end
    return frame
end

-- "Health bar color: Health" colours by health, like the real frames.
local function SetHealthColor(frame, fraction, classColor)
    if NeoHeal.db.layout.healthColor == "health" then
        frame.health:SetStatusBarColor(NeoHeal.UnitButton.HealthFractionColor(fraction))
    else
        frame.health:SetStatusBarColor(classColor.r, classColor.g, classColor.b)
    end
end

-- Member 1 leads the fake raid, member 2 assists.
local LEADER_ICONS = { "Interface\\GroupFrame\\UI-Group-LeaderIcon", "Interface\\GroupFrame\\UI-Group-AssistantIcon" }

-- Raid target markers on a few members: [member] = marker (1 star ... 8 skull).
-- Member 1 also leads and tanks, so one frame shows every top icon at once.
local FAKE_MARKERS = { [1] = 8, [4] = 1, [10] = 7, [15] = 5 }

-- Raid marker, role icon (from the fake roles) and leader icon, right of the name.
local function SetStatusIcons(frame, member)
    local marker = FAKE_MARKERS[member]
    frame.raidIcon:SetShown(marker ~= nil and NeoHeal.UnitButton.ShowExactMarker(frame.raidIcon, marker))
    NeoHeal.UnitButton.SetStatusIcons(frame, FAKE_ROLES[GetClass(member)], LEADER_ICONS[member])
end

-- Fake maximum health, for "Health text: Health missing".
local FAKE_MAX_HEALTH = { WARRIOR = 5500 }
local DEFAULT_FAKE_MAX_HEALTH = 3800
local PET_MAX_HEALTH = 2500

-- Fake raid debuffs below the name, like the Blizzard-drawn ones on the real frames.
local FAKE_DEBUFF_ICONS = { "Interface\\Icons\\Spell_Fire_Immolation", "Interface\\Icons\\Spell_Shadow_ShadowWordPain" }

local function ShowFakeDebuffs(frame, count)
    local holder = frame.fakeDebuffs
    if not holder then
        holder = CreateFrame("Frame", nil, frame.health)
        holder:SetFrameLevel(frame.health:GetFrameLevel() + 2)
        holder:SetPoint("TOP", 0, -NeoHeal.UnitButton.RAID_DEBUFF_TOP)
        holder.icons = {}
        for index, file in ipairs(FAKE_DEBUFF_ICONS) do
            local icon = holder:CreateTexture(nil, "ARTWORK")
            icon:SetTexture(file)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            holder.icons[index] = icon
        end
        frame.fakeDebuffs = holder
    end
    if not NeoHeal.db.layout.showRaidDebuffs or count == 0 then
        holder:Hide()
        return
    end
    local size = NeoHeal.UnitButton.GetRaidDebuffSize()
    holder:SetSize(count * (size + 1) - 1, size)
    for index, icon in ipairs(holder.icons) do
        icon:SetSize(size, size)
        icon:SetPoint("LEFT", (index - 1) * (size + 1), 0)
        icon:SetShown(index <= count)
    end
    holder:Show()
end

-- A fake dispel strip in the colour of a debuff type you can remove (none for
-- classes without a cure spell).
local DISPEL_TYPE_ORDER = { "Poison", "Magic", "Curse", "Disease" }

local function ShowFakeDispel(frame, show)
    local Dispel = NeoHeal.Dispel
    local debuffType
    for _, candidate in ipairs(DISPEL_TYPE_ORDER) do
        if Dispel.known[candidate] then debuffType = candidate break end
    end
    if show and debuffType then
        local color = Dispel.COLORS[debuffType]
        frame.dispelStrip.texture:SetVertexColor(color[1], color[2], color[3])
        frame.dispelStrip:Show()
    else
        frame.dispelStrip:Hide()
    end
end

-- Fills a frame with believable fake data. The same member always looks the same,
-- so a main tank looks identical in the main tank group and in their own group.
local function Decorate(frame, member)
    local class = GetClass(member)
    local healthFraction = 0.25 + ((member * 37) % 75) / 100
    local powerColor = PowerBarColor[POWER_BY_CLASS[class] or "MANA"]

    NeoHeal.UnitButton.ApplyStyle(frame)
    NeoHeal.UnitButton.LayoutBars(frame, NeoHeal.UnitButton.ShowsPowerBar(FAKE_ROLES[class] or "DAMAGER", class))
    frame.nameText:SetText(GetName(member))
    SetStatusIcons(frame, member)
    SetHealthColor(frame, healthFraction, RAID_CLASS_COLORS[class])
    frame.health:SetValue(healthFraction)
    NeoHeal.UnitButton.ShowLowHealth(frame, healthFraction)
    -- Every seventh member (the first tank among them) wears a shield.
    frame.absorb:SetValue(0.2)
    frame.absorb:SetShown(member % 7 == 1)
    frame.power:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b)
    frame.power:SetValue(0.3 + ((member * 53) % 70) / 100)
    NeoHeal.UnitButton.ShowHealthText(frame, healthFraction, FAKE_MAX_HEALTH[class] or DEFAULT_FAKE_MAX_HEALTH)
    ShowFakeDebuffs(frame, ({ [4] = 1, [9] = 2 })[member % 11] or 0)   -- a few members carry boss debuffs
    NeoHeal.Hots.ShowPreview(frame, ({ [1] = 2, [2] = 1, [4] = 3 })[member % 5] or 0, member)
    ShowFakeDispel(frame, member % 6 == 3)
    frame.aggro:SetShown(NeoHeal.db.layout.showAggro and member == 1)   -- the first tank has aggro
end

-- The fake main tanks: the first warriors of the fake raid.
local function GetMainTanks(size)
    local mainTanks = {}
    for member = 1, size do
        if GetClass(member) == "WARRIOR" and #mainTanks < MAX_MAIN_TANKS then
            table.insert(mainTanks, member)
        end
    end
    return mainTanks
end

-- Pets of the fake hunters and warlocks, shown in the 40 player test mode when
-- "Show pets" is on. Six pets fill one column and start a second, as real pets do.
local PET_TEST_SIZE = 40
local FAKE_PETS = {
    { name = "Shadowmaw",   power = "FOCUS" },   -- hunter pets
    { name = "Fang",        power = "FOCUS" },
    { name = "Rattlecrest", power = "FOCUS" },
    { name = "Zhaazar",     power = "MANA" },    -- warlock pets
    { name = "Grothak",     power = "MANA" },
    { name = "Xanrith",     power = "MANA" },
}
local PET_COLOR = { r = 0.2, g = 0.8, b = 0.2 }   -- as on the real frames

local function DecoratePet(frame, pet)
    local data = FAKE_PETS[pet]
    local healthFraction = 0.4 + ((pet * 29) % 60) / 100
    local powerColor = PowerBarColor[data.power]

    NeoHeal.UnitButton.ApplyStyle(frame)
    NeoHeal.UnitButton.LayoutBars(frame, NeoHeal.UnitButton.ShowsPowerBar(nil, nil))   -- pets: no role or class
    frame.nameText:SetText(data.name)
    frame.raidIcon:Hide()
    NeoHeal.UnitButton.SetStatusIcons(frame, nil, nil)   -- pets: no marker or role, never a leader
    SetHealthColor(frame, healthFraction, PET_COLOR)
    frame.health:SetValue(healthFraction)
    NeoHeal.UnitButton.ShowLowHealth(frame, healthFraction)
    frame.absorb:Hide()
    frame.power:SetStatusBarColor(powerColor.r, powerColor.g, powerColor.b)
    frame.power:SetValue(0.5 + ((pet * 17) % 50) / 100)
    NeoHeal.UnitButton.ShowHealthText(frame, healthFraction, PET_MAX_HEALTH)
    ShowFakeDebuffs(frame, 0)
    NeoHeal.Hots.ShowPreview(frame, 0, pet)
    ShowFakeDispel(frame, false)
    frame.aggro:Hide()
end

-- Shows `size` fake members in groups of five, plus the main tank group and pets
-- when enabled. Returns the groups in screen order ({ count, label }, like the
-- real layout builds them) and whether this counts as a raid (more than one
-- group), for Layout:FitToContent.
function Preview:Show(size)
    local settings = NeoHeal.db.layout
    local L = NeoHeal.L
    -- In test mode Layout:Refresh stops before the HoT refresh, so "Show HoT timers"
    -- and the countdown font size are applied here.
    NeoHeal.AuraContainer.ApplyTimerSetting()

    -- Groups in screen order: { members = { ids }, label = title, decorate = function }.
    local groups = {}
    for member = 1, size do
        local number = math.ceil(member / MAX_GROUP_SIZE)
        groups[number] = groups[number] or { members = {}, label = format(L.GROUP_NUMBER, number), decorate = Decorate }
        table.insert(groups[number].members, member)
    end
    local isRaid = #groups > 1

    local mainTanks = { members = settings.mainTankPosition ~= "none" and GetMainTanks(size) or {},
                        label = L.MAIN_TANKS, decorate = Decorate }

    -- Every group, the main tank group included, is sorted like the real headers.
    local sortOrder = NeoHeal.Layout.SORT_ORDERS[settings.sortOrder] or NeoHeal.Layout.SORT_ORDERS.index
    for _, group in ipairs(groups) do SortMembers(group.members, sortOrder) end
    SortMembers(mainTanks.members, sortOrder)

    if settings.showPets and size == PET_TEST_SIZE then
        local pets = { members = {}, label = L.PETS, decorate = DecoratePet }
        for pet = 1, #FAKE_PETS do table.insert(pets.members, pet) end
        table.insert(groups, pets)
    end
    -- Like the real header, main tanks only show in a raid. "Last" means after
    -- the pets too.
    if isRaid and #mainTanks.members > 0 then
        local position = settings.mainTankPosition == "first" and 1 or #groups + 1
        table.insert(groups, position, mainTanks)
    end

    -- Each group starts a new column and wraps into further columns of five.
    local width, height, spacing = settings.buttonWidth, settings.buttonHeight, settings.spacing
    local frameIndex, column = 0, 0
    local order = {}
    for _, group in ipairs(groups) do
        table.insert(order, { count = #group.members, label = group.label })
        for slot, id in ipairs(group.members) do
            local x = column + math.floor((slot - 1) / MAX_GROUP_SIZE)
            local y = (slot - 1) % MAX_GROUP_SIZE
            frameIndex = frameIndex + 1
            local frame = GetFrame(frameIndex)
            frame:SetSize(width, height)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", x * (width + spacing), -y * (height + spacing))
            group.decorate(frame, id)
            frame:Show()
        end
        column = column + math.ceil(#group.members / MAX_GROUP_SIZE)
    end
    for index = frameIndex + 1, #self.frames do
        self.frames[index]:Hide()
    end
    return order, isRaid
end

function Preview:Hide()
    for _, frame in ipairs(self.frames) do
        frame:Hide()
    end
end

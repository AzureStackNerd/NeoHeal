-- Blizzard-drawn aura icons, for combat. On WoW: Forever an addon may not read any
-- aura data in combat ("Auras cannot be accessed when secret while tainted"), but
-- it may *display* auras through Blizzard's AuraContainer: we hand it a filter,
-- and Blizzard's own code fills our icon textures and cooldowns without us ever
-- seeing the data. (Technique as in HealBot_CombatAuras / DandersFrames.)
--
-- Hard rules for containers:
--   * never create or enable one in combat (a client error pcall can't catch);
--   * build order: create -> anchor -> SetUnit -> AddAuraGroup -> SetEnabled last;
--   * showing and hiding is fine in combat.
local _, NeoHeal = ...

local AuraContainer = {
    timedCooldowns = {},   -- [cooldown] = true: HoT cooldowns whose numbers follow "Show HoT timers"
}
NeoHeal.AuraContainer = AuraContainer

local supported   -- nil until probed

function AuraContainer.IsSupported()
    if supported == nil and not InCombatLockdown() then
        local ok, probe = pcall(CreateFrame, "AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
        supported = (ok and probe and type(probe.AddAuraGroup) == "function") or false
        if ok and probe then probe:Hide() end
    end
    return supported
end

-- The cooldown swipe always shows; "Show HoT timers" only switches the countdown numbers.
local function StyleTimer(cooldown, showNumbers)
    cooldown:SetHideCountdownNumbers(not showNumbers)
    cooldown:SetDrawBling(false)
end

-- The countdown font scales with the icons, so the numbers never hide the icon:
-- the same typeface and outline as NumberFontNormalSmall, at 60% of the icon size.
local COUNTDOWN_FONT = "NeoHealCountdownFont"
local COUNTDOWN_FONT_SCALE = 0.6
local MIN_COUNTDOWN_FONT_SIZE = 6
local countdownFont = CreateFont(COUNTDOWN_FONT)
local countdownFontSize

local function UpdateCountdownFont()
    local size = math.max(MIN_COUNTDOWN_FONT_SIZE, math.floor(NeoHeal.Hots.GetIconSize() * COUNTDOWN_FONT_SCALE))
    if size == countdownFontSize then return false end
    countdownFontSize = size
    local file, _, flags = NumberFontNormalSmall:GetFont()
    countdownFont:SetFont(file or "Fonts\\ARIALN.TTF", size, flags or "OUTLINE")
    return true
end

-- Makes a cooldown's countdown small and follow "Show HoT timers". Used for the
-- Blizzard-drawn icons below and for NeoHeal's own HoT icons (Hots.lua), so both
-- look and behave the same, in and out of combat.
function AuraContainer.AddTimedCooldown(cooldown)
    UpdateCountdownFont()
    if cooldown.SetCountdownFont then cooldown:SetCountdownFont(COUNTDOWN_FONT) end
    StyleTimer(cooldown, NeoHeal.db.layout.showHotTimers)
    AuraContainer.timedCooldowns[cooldown] = true
end

-- Styles each icon Blizzard creates: click-through, with our texture and cooldown,
-- which Blizzard then fills with the (hidden) aura.
local function MakeIconInit(size, timed)
    return function(auraButton)
        pcall(function()
            if auraButton.SetMouseClickEnabled then auraButton:SetMouseClickEnabled(false) end
            if auraButton.SetMouseMotionEnabled then auraButton:SetMouseMotionEnabled(false) end
            auraButton:SetSize(size, size)
            if auraButton.neoIcon then return end

            local texture = auraButton:CreateTexture(nil, "ARTWORK")
            texture:SetAllPoints()
            texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)   -- trim the icon border
            local cooldown = CreateFrame("Cooldown", nil, auraButton, "CooldownFrameTemplate")
            cooldown:SetAllPoints()
            cooldown:SetReverse(true)
            cooldown:SetDrawEdge(false)
            if timed then
                AuraContainer.AddTimedCooldown(cooldown)
            else
                StyleTimer(cooldown, false)
            end

            auraButton.neoIcon = texture
            if auraButton.SetIcon then auraButton:SetIcon(texture) end
            if auraButton.SetDurationCooldown then auraButton:SetDurationCooldown(cooldown) end
        end)
    end
end

-- Builds a hidden container on `parent` (out of combat only). Returns it, or nil
-- if this client can't. options:
--   filter      aura filter, e.g. "HELPFUL|PLAYER"
--   corner      "BOTTOMRIGHT" (icons grow to the left), "BOTTOM" or "TOP" (grow to the right)
--   offsetY     optional: vertical offset from that point (default 1)
--   maxIcons, size
--   maxDuration optional: only auras whose *total* duration is at most this (seconds)
--   timed       true: countdown numbers follow the "Show HoT timers" setting; else none
function AuraContainer.Create(parent, unit, options)
    if InCombatLockdown() or not AuraContainer.IsSupported() then return nil end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, parent, "CustomAuraContainerTemplate")
    if not ok or not container then return nil end

    local size = options.size
    local built = pcall(function()
        local growLeft = options.corner == "BOTTOMRIGHT"
        container:SetPoint(options.corner, parent, options.corner, growLeft and -1 or 0, options.offsetY or 1)
        if container.SetFlowLayoutAnchorPoint then container:SetFlowLayoutAnchorPoint(options.corner) end
        local flow = AnchorUtil and AnchorUtil.FlowDirection
        if container.SetFlowLayoutGrowthDirection and flow then
            container:SetFlowLayoutGrowthDirection(growLeft and flow.Left or flow.Right, flow.Up)
        end
        container:SetFrameLevel(parent:GetFrameLevel() + 2)
        if container.SetMouseClickEnabled then container:SetMouseClickEnabled(false) end
        if container.SetMouseMotionEnabled then container:SetMouseMotionEnabled(false) end
        container:SetUnit(unit)
        container:AddAuraGroup("NeoHeal", options.filter, {
            maxFrameCount = options.maxIcons,
            initializeFrame = MakeIconInit(size, options.timed),
            -- both field sets: the names changed between client builds
            layout = { elementWidth = size, elementHeight = size, elementSpacing = 1, lineSpacing = 1,
                       groupSpacing = 0, elementSpacingX = 1, elementSpacingY = 1, gapX = 0 },
            candidateFilters = options.maxDuration and { maxDuration = options.maxDuration } or nil,
        })
        container:SetEnabled(true)
    end)
    container:Hide()
    if not built then return nil end
    container.neoUnit = unit
    container.neoSize = size
    return container
end

-- A strip along the left edge of `frame` in the colour of a debuff you can dispel,
-- drawn by the game in and out of combat (technique as in Decursive's micro unit
-- frames). One aura slot covers the frame; the game colours the strip with `curve`
-- by the debuff's dispel type, and `filters` decide which debuffs count
-- (Dispel.lua). Out of combat only, like every container.
local DISPEL_SLOT = "NeoHealDispel"

local function MakeStripInit(frame, level, curve, width)
    return function(auraButton)
        pcall(function()
            if auraButton.SetMouseClickEnabled then auraButton:SetMouseClickEnabled(false) end
            if auraButton.SetMouseMotionEnabled then auraButton:SetMouseMotionEnabled(false) end
            auraButton:ClearAllPoints()
            auraButton:SetAllPoints(frame)
            auraButton:SetFrameLevel(level)
            if auraButton.neoStrip then return end

            local strip = auraButton:CreateTexture(nil, "OVERLAY")
            strip:SetColorTexture(1, 1, 1, 1)   -- the game tints it
            strip:SetPoint("TOPLEFT")
            strip:SetPoint("BOTTOMLEFT")
            strip:SetWidth(width)
            auraButton:ClearDispelTypeTextures()
            auraButton:AddDispelTypeTexture(strip, {
                showIcon = false, showWhenHarmful = true, showWhenHelpful = false, showWithoutDispelType = false,
                style = Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset,
                customDispelColorCurve = curve,
            })
            auraButton.neoStrip = strip
        end)
    end
end

function AuraContainer.CreateDispelStrip(frame, unit, level, filters, curve, width)
    if InCombatLockdown() or not curve or not AuraContainer.IsSupported() then return nil end
    local ok, container = pcall(CreateFrame, "AuraContainer", nil, frame, "CustomAuraContainerTemplate")
    if not ok or not container then return nil end

    local built = pcall(function()
        container:SetAllPoints(frame)
        container:SetFrameLevel(level)
        if container.SetMouseClickEnabled then container:SetMouseClickEnabled(false) end
        if container.SetMouseMotionEnabled then container:SetMouseMotionEnabled(false) end
        container:SetUnit(unit)
        container:AddAuraSlot(DISPEL_SLOT, "HARMFUL", {
            sortMethod = 0, sortDirection = 0,
            candidateFilters = filters,
            initializeFrame = MakeStripInit(frame, level, curve, width),
        })
        container:SetEnabled(true)
    end)
    container:Hide()
    if not built then return nil end
    container.neoUnit = unit
    return container
end

-- After learning a cure spell: which dispel types the strip shows.
function AuraContainer.SetDispelFilters(container, filters)
    if container then pcall(container.SetAuraSlotCandidateFilters, container, DISPEL_SLOT, filters) end
end

-- Points a container at another unit. If the game refuses, it stays hidden.
function AuraContainer.SetUnit(container, unit)
    if container and unit and pcall(container.SetUnit, container, unit) then
        container.neoUnit = unit
    end
end

-- Shows the container only while it follows the button's current unit.
function AuraContainer.SetShown(container, show, unit)
    if not container then return end
    show = show and container.neoUnit == unit
    if show and not container:IsShown() then
        container:Show()
        if container.UpdateAllAuras then pcall(container.UpdateAllAuras, container) end
    elseif not show then
        container:Hide()
    end
end

-- After a layout change ("Show HoT timers", button size): restyle every timed
-- cooldown, ours and Blizzard's, and resize the countdown font.
function AuraContainer.ApplyTimerSetting()
    local showTimer = NeoHeal.db.layout.showHotTimers
    local fontChanged = UpdateCountdownFont()
    for cooldown in pairs(AuraContainer.timedCooldowns) do
        StyleTimer(cooldown, showTimer)
        -- Set it again so cooldowns that copied the old size pick up the new one.
        if fontChanged and cooldown.SetCountdownFont then cooldown:SetCountdownFont(COUNTDOWN_FONT) end
    end
end

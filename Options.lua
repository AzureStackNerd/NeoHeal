-- The options window (/neoheal): a "Click Casting" page and a "Layout" page.
-- The window is built on first open, so it costs nothing until then.
local _, NeoHeal = ...
local L = NeoHeal.L
local ClickCast = NeoHeal.ClickCast

local Options = {
    selectedModifier = "",   -- modifier prefix being edited on the click casting page
}
NeoHeal.Options = Options

local PADDING = 16
local ROW_HEIGHT = 34
local CHECKBOX_ROW_HEIGHT = 28
local SECOND_COLUMN_X = 320     -- Layout page: choices and sliders left, checkboxes right
local LABEL_WIDTH = 110         -- label in front of a slider or dropdown

---------------------------------------------------------------------------
-- Small widget helpers. Every widget has a Refresh() that re-reads its value.
---------------------------------------------------------------------------
local function CreateLabel(parent, text, fontObject)
    local label = parent:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlight")
    label:SetText(text)
    return label
end

local function CreateDropdown(parent, width)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetWidth(width)
    return dropdown
end

local function CreateButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

local function CreateCheckbox(parent, label, getValue, setValue)
    local checkbox = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    checkbox:SetSize(26, 26)
    CreateLabel(checkbox, label):SetPoint("LEFT", checkbox, "RIGHT", 4, 0)
    checkbox:SetScript("OnClick", function(self) setValue(self:GetChecked()) end)
    function checkbox:Refresh() self:SetChecked(getValue()) end
    return checkbox
end

local function CreateSlider(parent, label, minValue, maxValue, step, getValue, setValue)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(300, 26)
    CreateLabel(holder, label):SetPoint("LEFT")

    local slider = CreateFrame("Slider", nil, holder, "MinimalSliderWithSteppersTemplate")
    slider:SetPoint("LEFT", LABEL_WIDTH, 0)
    slider:SetSize(170, 20)
    local rightLabel = MinimalSliderWithSteppersMixin.Label.Right
    local formatters = {
        [rightLabel] = CreateMinimalSliderFormatter(rightLabel, function(value)
            return step < 1 and format("%.2f", value) or format("%d", value)
        end),
    }
    slider:Init(getValue(), minValue, maxValue, Round((maxValue - minValue) / step), formatters)
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        setValue(Round(value / step) * step)
    end, holder)

    function holder:Refresh() slider:SetValue(getValue()) end
    return holder
end

-- A dropdown with one radio choice per { value, label }.
local function CreateChoice(parent, label, choices, getValue, setValue)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(300, 28)
    CreateLabel(holder, label):SetPoint("LEFT")

    local dropdown = CreateDropdown(holder, 180)
    dropdown:SetPoint("LEFT", LABEL_WIDTH, 0)
    dropdown:SetupMenu(function(_, root)
        for _, choice in ipairs(choices) do
            root:CreateRadio(choice.label,
                function() return getValue() == choice.value end,
                function() setValue(choice.value) end)
        end
    end)

    function holder:Refresh() dropdown:GenerateMenu() end
    return holder
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local function CreatePage(frame)
    local page = CreateFrame("Frame", nil, frame)
    page:SetPoint("TOPLEFT", PADDING, -64)
    page:SetPoint("BOTTOMRIGHT", -PADDING, PADDING)
    page.widgets = {}
    function page:Refresh()
        for _, widget in ipairs(self.widgets) do widget:Refresh() end
    end
    page:SetScript("OnShow", function(self) self:Refresh() end)   -- pages may replace Refresh
    return page
end

-- Test mode is not a saved setting: it lasts while the options window is open.
local function GetTestMode() return NeoHeal.Layout.testSize or 0 end
local function SetTestMode(size)
    if InCombatLockdown() then return end
    NeoHeal.Layout:SetTestMode(size > 0 and size or nil)
    Options:RefreshLayoutPage()   -- the test size may pick the other size preset
end

-- Sizes are kept per preset (party / raid, Layout:GetPresetName); the sliders edit
-- the one in use, which test mode picks: 5 players is Party, 10 or more is Raid.
local function GetSizeSetting(key) return NeoHeal.Layout:GetSize()[key] end
local function SetSizeSetting(key, value)
    local size = NeoHeal.Layout:GetSize()
    if size[key] == value then return end
    size[key] = value
    NeoHeal:RunOutOfCombat("layout", function() NeoHeal.Layout:Refresh() end)
end

-- "Sizes for: Party" above the sliders.
local function CreatePresetLabel(page)
    local holder = CreateFrame("Frame", nil, page)
    holder:SetSize(300, 20)
    local label = CreateLabel(holder, "", "GameFontNormal")
    label:SetPoint("LEFT")
    local hint = CreateLabel(holder, L.SIZES_HINT, "GameFontDisableSmall")
    hint:SetPoint("LEFT", label, "RIGHT", 8, 0)
    function holder:Refresh()
        local preset = NeoHeal.Layout:GetPresetName()
        label:SetText(format(L.SIZES_FOR, preset == "raid" and L.PRESET_RAID or L.PRESET_PARTY))
    end
    return holder
end

-- The whole Layout page is described here; add a line to add a setting.
-- Choices and sliders go in the left column, checkboxes in the right one.
local LAYOUT_SETTINGS = {
    { kind = "choice", key = "frameStyle", label = L.FRAME_STYLE, choices = {
        { value = "forever", label = L.FRAME_STYLE_FOREVER },
        { value = "classic", label = L.FRAME_STYLE_CLASSIC },
    } },
    { kind = "choice", key = "healthColor", label = L.HEALTH_COLOR, choices = {
        { value = "class",  label = L.HEALTH_COLOR_CLASS },
        { value = "health", label = L.HEALTH_COLOR_HEALTH },
    } },
    { kind = "choice", key = "sortOrder", label = L.SORT_ORDER, choices = {
        { value = "index", label = L.SORT_INDEX },
        { value = "name",  label = L.SORT_NAME },
        { value = "role",  label = L.SORT_ROLE },
        { value = "class", label = L.SORT_CLASS },
    } },
    { kind = "choice", key = "mainTankPosition", label = L.MAIN_TANK_POSITION, choices = {
        { value = "none",  label = L.MAIN_TANKS_NONE },
        { value = "first", label = L.MAIN_TANKS_FIRST },
        { value = "last",  label = L.MAIN_TANKS_LAST },
    } },
    { kind = "choice", key = "healthText", label = L.HEALTH_TEXT, choices = {
        { value = "percent", label = L.HEALTH_TEXT_PERCENT },
        { value = "deficit", label = L.HEALTH_TEXT_DEFICIT },
        { value = "none",    label = L.HEALTH_TEXT_NONE },
    } },
    { kind = "choice", key = "powerBar", label = L.POWER_BAR, choices = {
        { value = "all",     label = L.POWER_BAR_ALL },
        { value = "healers", label = L.POWER_BAR_HEALERS },
        { value = "none",    label = L.POWER_BAR_NONE },
    } },
    { kind = "choice", label = L.TEST_MODE, get = GetTestMode, set = SetTestMode, choices = {
        { value = 0,  label = L.TEST_MODE_OFF },
        { value = 5,  label = format(L.TEST_MODE_SIZE, 5) },
        { value = 10, label = format(L.TEST_MODE_SIZE, 10) },
        { value = 25, label = format(L.TEST_MODE_SIZE, 25) },
        { value = 40, label = format(L.TEST_MODE_SIZE, 40) },
    } },
    { kind = "presetLabel" },
    { kind = "slider",   key = "buttonWidth",  size = true, label = L.BUTTON_WIDTH,  min = 40,  max = 160, step = 1 },
    { kind = "slider",   key = "buttonHeight", size = true, label = L.BUTTON_HEIGHT, min = 24,  max = 80,  step = 1 },
    { kind = "slider",   key = "spacing",      size = true, label = L.SPACING,       min = 0,   max = 10,  step = 1 },
    { kind = "slider",   key = "scale",        size = true, label = L.SCALE,         min = 0.5, max = 2,   step = 0.05 },
    { kind = "checkbox", key = "showSolo",           label = L.SHOW_SOLO },
    { kind = "checkbox", key = "showRaidDebuffs",    label = L.SHOW_RAID_DEBUFFS },
    { kind = "checkbox", key = "showMissingBuffs",   label = L.SHOW_MISSING_BUFFS },
    { kind = "checkbox", key = "showHotTimers",      label = L.SHOW_HOT_TIMERS },
    { kind = "checkbox", key = "showIncomingHeals",  label = L.SHOW_INCOMING_HEALS },
    { kind = "checkbox", key = "showAggro",          label = L.SHOW_AGGRO },
    { kind = "checkbox", key = "showTooltips",       label = L.SHOW_TOOLTIPS },
    { kind = "checkbox", key = "showPets",           label = L.SHOW_PETS },
    { kind = "checkbox", key = "hideBlizzardFrames", label = L.HIDE_BLIZZARD_FRAMES },
}

local WIDGET_BUILDERS = {
    choice = function(page, setting, get, set) return CreateChoice(page, setting.label, setting.choices, get, set) end,
    slider = function(page, setting, get, set) return CreateSlider(page, setting.label, setting.min, setting.max, setting.step, get, set) end,
    checkbox = function(page, setting, get, set) return CreateCheckbox(page, setting.label, get, set) end,
    presetLabel = function(page) return CreatePresetLabel(page) end,
}

local function SetLayoutSetting(key, value)
    local settings = NeoHeal.db.layout
    if settings[key] == value then return end
    settings[key] = value
    NeoHeal:RunOutOfCombat("layout", function() NeoHeal.Layout:Refresh() end)
end

local function CreateLayoutPage(frame)
    local page = CreatePage(frame)
    local leftY, rightY = 0, 0
    for _, setting in ipairs(LAYOUT_SETTINGS) do
        local get, set = setting.get, setting.set
        if setting.size then
            get = function() return GetSizeSetting(setting.key) end
            set = function(value) SetSizeSetting(setting.key, value) end
        end
        get = get or function() return NeoHeal.db.layout[setting.key] end
        set = set or function(value) SetLayoutSetting(setting.key, value) end
        local widget = WIDGET_BUILDERS[setting.kind](page, setting, get, set)
        if setting.kind == "checkbox" then
            widget:SetPoint("TOPLEFT", SECOND_COLUMN_X, rightY)
            rightY = rightY - CHECKBOX_ROW_HEIGHT
        else
            widget:SetPoint("TOPLEFT", 0, leftY)
            leftY = leftY - ROW_HEIGHT
        end
        table.insert(page.widgets, widget)
    end
    Options.layoutPage = page
    return page
end

-- After the size preset changed (test mode, or joining / leaving a raid): the
-- sliders show the other preset's values.
function Options:RefreshLayoutPage()
    if self.layoutPage and self.layoutPage:IsVisible() then self.layoutPage:Refresh() end
end

-- The action menu: None / Target / Menu, then spells grouped by spellbook tab.
-- Spells with several ranks get a submenu: "Highest rank", "Rank 1", "Rank 2", ...
local function BuildActionMenu(root, key)
    -- Keep the row's "cast on" and "also target" choices when switching spells.
    local current = ClickCast:Get(key)
    local target = current and current.target or "unit"
    local alsoTarget = current and current.alsoTarget or false

    local function Choose(binding)
        ClickCast:Set(key, binding)
        Options:RefreshBindingRows()
    end
    local function SpellBinding(spellID, highestRank)
        return { action = "spell", spellID = spellID, highestRank = highestRank, target = target, alsoTarget = alsoTarget }
    end

    root:CreateButton(L.ACTION_NONE, function() Choose(nil) end)
    root:CreateButton(L.ACTION_TARGET, function() Choose({ action = "target", target = target }) end)
    root:CreateButton(L.ACTION_MENU, function() Choose({ action = "menu" }) end)
    root:CreateButton(L.ACTION_BUFF, function() Choose({ action = "buff" }) end)
    root:CreateDivider()

    local skillLines = NeoHeal.Spells.skillLines
    if #skillLines == 0 then
        root:CreateTitle(L.NO_SPELLS)
    end
    for _, skillLine in ipairs(skillLines) do
        local lineMenu = root:CreateButton(skillLine.name)
        if lineMenu.SetScrollMode then lineMenu:SetScrollMode(400) end   -- long spell lists scroll
        for _, spell in ipairs(skillLine.spells) do
            local highest = spell.ranks[#spell.ranks].spellID
            if #spell.ranks == 1 then
                lineMenu:CreateButton(spell.name, function() Choose(SpellBinding(highest, true)) end)
            else
                local spellMenu = lineMenu:CreateButton(spell.name)
                spellMenu:CreateButton(L.HIGHEST_RANK, function() Choose(SpellBinding(highest, true)) end)
                for _, rank in ipairs(spell.ranks) do
                    spellMenu:CreateButton(rank.text, function() Choose(SpellBinding(rank.spellID, false)) end)
                end
            end
        end
    end
end

-- The label of a hover-key row: a button that captures the next key pressed.
-- Left click to set (Escape cancels), right click to clear.
local MODIFIER_KEYS = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true }

local function CreateKeyCaptureButton(row, slot)
    local button = CreateButton(row, "", 100, nil)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    function button:Refresh()
        local key = ClickCast:GetHoverKey(slot)
        self:SetText(key and format(L.HOVER_KEY, key) or L.SET_HOVER_KEY)
    end
    local function StopCapture()
        button:EnableKeyboard(false)
        button:Refresh()
    end

    button:SetScript("OnClick", function(self, mouseButton)
        if InCombatLockdown() then return end
        if mouseButton == "RightButton" then
            ClickCast:SetHoverKey(slot, nil)
            Options:RefreshBindingRows()
            return
        end
        self:SetText(L.PRESS_A_KEY)
        self:EnableKeyboard(true)
        self:SetPropagateKeyboardInput(false)   -- the key must not also trigger its normal binding
    end)
    button:SetScript("OnKeyDown", function(_, key)
        if MODIFIER_KEYS[key] then return end   -- wait for the real key
        if key ~= "ESCAPE" then ClickCast:SetHoverKey(slot, key) end
        StopCapture()
        Options:RefreshBindingRows()   -- another slot may have lost this key
    end)
    button:SetScript("OnHide", StopCapture)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.HOVER_KEY_TOOLTIP, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", GameTooltip_Hide)
    return button
end

-- One row per mouse button or hover key: [label] [action dropdown] [cast on dropdown] [also target]
local function CreateBindingRow(page, mouseButton)
    local row = CreateFrame("Frame", nil, page)
    row:SetSize(620, 30)
    local keyCapture
    if mouseButton.hoverKey then
        keyCapture = CreateKeyCaptureButton(row, mouseButton.hoverKey)
        keyCapture:SetPoint("LEFT")
    else
        CreateLabel(row, mouseButton.label):SetPoint("LEFT")
    end

    local action = CreateDropdown(row, 250)
    action:SetPoint("LEFT", 110, 0)
    local target = CreateDropdown(row, 170)
    target:SetPoint("LEFT", action, "RIGHT", 10, 0)
    target:SetDefaultText("-")

    local function Key() return Options.selectedModifier .. mouseButton.id end

    action:SetupMenu(function(_, root) BuildActionMenu(root, Key()) end)
    target:SetupMenu(function(_, root)
        for _, choice in ipairs(ClickCast.TARGETS) do
            root:CreateRadio(choice.label,
                function()
                    local binding = ClickCast:Get(Key())
                    return binding ~= nil and binding.target == choice.value
                end,
                function() ClickCast:SetTarget(Key(), choice.value) end)
        end
    end)

    -- Only spells can "also target": the Target action already does, the menu can't.
    local alsoTarget = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    alsoTarget:SetSize(26, 26)
    alsoTarget:SetPoint("LEFT", target, "RIGHT", 30, 0)
    alsoTarget:SetScript("OnClick", function(self) ClickCast:SetAlsoTarget(Key(), self:GetChecked()) end)

    function row:Refresh()
        local binding = ClickCast:Get(Key())
        local isSpell = binding ~= nil and binding.action == "spell"
        action:OverrideText(ClickCast:Describe(binding))
        target:SetEnabled(binding ~= nil and binding.action ~= "menu" and binding.action ~= "buff")
        target:GenerateMenu()
        alsoTarget:SetEnabled(isSpell)
        alsoTarget:SetChecked(isSpell and binding.alsoTarget or false)
        if keyCapture then keyCapture:Refresh() end
    end
    return row
end

local function CreateClickCastingPage(frame)
    local page = CreatePage(frame)

    local hint = CreateLabel(page, L.CLICK_CASTING_HINT, "GameFontNormal")
    hint:SetPoint("TOPLEFT")

    Options.modifierButtons = {}
    for index, modifier in ipairs(ClickCast.MODIFIERS) do
        local button = CreateButton(page, modifier.label, 110, function()
            Options.selectedModifier = modifier.prefix
            Options:RefreshBindingRows()
        end)
        button:SetPoint("TOPLEFT", (index - 1) * 114, -24)
        button.prefix = modifier.prefix
        Options.modifierButtons[index] = button
    end

    CreateLabel(page, L.COLUMN_ACTION, "GameFontNormalSmall"):SetPoint("TOPLEFT", 110, -60)
    CreateLabel(page, L.COLUMN_TARGET, "GameFontNormalSmall"):SetPoint("TOPLEFT", 370, -60)
    CreateLabel(page, L.COLUMN_ALSO_TARGET, "GameFontNormalSmall"):SetPoint("TOPLEFT", 550, -60)

    Options.bindingRows = {}
    for index, mouseButton in ipairs(ClickCast.BUTTONS) do
        local row = CreateBindingRow(page, mouseButton)
        row:SetPoint("TOPLEFT", 0, -74 - (index - 1) * ROW_HEIGHT)
        Options.bindingRows[index] = row
    end

    local reset = CreateButton(page, L.RESET_BINDINGS, 180, function()
        ClickCast:ResetToDefaults()
        Options:RefreshBindingRows()
    end)
    reset:SetPoint("BOTTOMLEFT")

    function page:Refresh() Options:RefreshBindingRows() end
    return page
end

function Options:RefreshBindingRows()
    for _, button in ipairs(self.modifierButtons) do
        button:SetEnabled(button.prefix ~= self.selectedModifier)   -- the disabled one is selected
    end
    for _, row in ipairs(self.bindingRows) do
        row:Refresh()
    end
end

---------------------------------------------------------------------------
-- The window
---------------------------------------------------------------------------
function Options:ShowPage(index)
    for pageIndex, page in ipairs(self.pages) do
        page:SetShown(pageIndex == index)
        self.pageTabs[pageIndex]:SetEnabled(pageIndex ~= index)
    end
end

-- While the window is open the raid frames are in move mode (see Layout.lua).
-- Closing the window or entering combat ends move mode and test mode; combat
-- also shows a line explaining why changes wait.
local function TrackCombatAndModes(frame)
    local notice = CreateLabel(frame, L.APPLY_AFTER_COMBAT, "GameFontRed")
    notice:SetPoint("BOTTOMRIGHT", -PADDING, PADDING + 4)
    notice:SetShown(InCombatLockdown())

    frame:SetScript("OnShow", function() NeoHeal.Layout:SetMoveMode(true) end)
    frame:SetScript("OnHide", function()
        NeoHeal.Layout:SetMoveMode(false)
        if not InCombatLockdown() then NeoHeal.Layout:SetTestMode(nil) end
    end)

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")
    frame:SetScript("OnEvent", function(_, event)
        local enteringCombat = event == "PLAYER_REGEN_DISABLED"
        notice:SetShown(enteringCombat)
        -- REGEN_DISABLED fires just before lockdown starts: the last moment the real
        -- frames can be shown again.
        if enteringCombat then NeoHeal.Layout:SetTestMode(nil) end
        NeoHeal.Layout:SetMoveMode(not enteringCombat and frame:IsShown())
    end)
end

function Options:Create()
    local frame = CreateFrame("Frame", "NeoHealOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(660, 540)   -- room for the Layout page's left column
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:Hide()
    table.insert(UISpecialFrames, frame:GetName())   -- Escape closes it

    local title = frame.TitleText
    if not title then
        title = CreateLabel(frame, "")
        title:SetPoint("TOP", 0, -5)
    end
    title:SetText(L.OPTIONS_TITLE)

    self.pages = { CreateClickCastingPage(frame), CreateLayoutPage(frame) }
    self.pageTabs = {}
    for index, label in ipairs({ L.PAGE_CLICK_CASTING, L.PAGE_LAYOUT }) do
        local tab = CreateButton(frame, label, 120, function() self:ShowPage(index) end)
        tab:SetPoint("TOPLEFT", PADDING + (index - 1) * 124, -32)
        self.pageTabs[index] = tab
    end
    TrackCombatAndModes(frame)

    self.frame = frame
    self:ShowPage(1)
end

function Options:Show()
    if not self.frame then self:Create() end
    self.frame:Show()
end

function Options:Toggle()
    if self.frame and self.frame:IsShown() then
        self.frame:Hide()
    else
        self:Show()
    end
end

-- A small entry under Esc > Options > AddOns that opens the real window.
function Options:RegisterSettingsCategory()
    local panel = CreateFrame("Frame")
    local title = CreateLabel(panel, L.ADDON_NAME, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    local open = CreateButton(panel, L.OPEN_OPTIONS, 200, function()
        HideUIPanel(SettingsPanel)
        self:Show()
    end)
    open:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)

    local category = Settings.RegisterCanvasLayoutCategory(panel, L.ADDON_NAME)
    Settings.RegisterAddOnCategory(category)
end

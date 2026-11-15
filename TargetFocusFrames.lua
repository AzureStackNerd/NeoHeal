-- One frame for your target and one for your focus, above the group frames, so a
-- healer can click-cast on someone outside the group, or without finding them in
-- the raid. Each is an ordinary NeoHeal unit button (UnitButton.Init: the same
-- look, bindings, hover keys and res on a dead unit), but not made by a group
-- header: its unit attribute is fixed to "target" or "focus", and a state driver
-- lets the game itself show it only while that unit exists and is friendly. The
-- game runs a state driver in combat too, where addons can't show or hide a
-- secure frame. That the focus unit and these macro conditions work on Forever
-- isn't checked in game yet.
--
-- As the unit attribute never changes, the header never reports a new unit:
-- Core.lua reloads the button on PLAYER_TARGET_CHANGED and PLAYER_FOCUS_CHANGED
-- (UnitButton:ReloadUnitButtons).
local _, NeoHeal = ...
local L = NeoHeal.L

local TargetFocusFrames = {
    buttons = {},    -- [unit] = the secure unit button
    previews = {},   -- [unit] = plain frame with a fake member, for test mode
}
NeoHeal.TargetFocusFrames = TargetFocusFrames

-- Left to right: the target first, the focus to its right. `member` is the fake
-- raid member test mode shows in it (Preview.Decorate): a healer as the target,
-- the first tank as the focus.
local FRAMES = {
    { unit = "target", setting = "showTargetFrame", label = L.TARGET_FRAME, name = "NeoHealTarget", member = 2 },
    { unit = "focus",  setting = "showFocusFrame",  label = L.FOCUS_FRAME,  name = "NeoHealFocus",  member = 1 },
}

-- The title bar and the group labels sit 2 pixels above the group frames
-- (Layout.lua); these frames go above them, with a small gap.
local TITLE_GAP = 2
local FRAME_GAP = 4

-- A label like the raid group labels (Ctrl-drag moves the frames), on top of the
-- frame. As the frame's child it shows and hides with it.
local function AddLabel(frame, text)
    local label = NeoHeal.Layout:CreateTitleFrame()
    label:SetParent(frame)
    label:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, TITLE_GAP)
    label:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, TITLE_GAP)
    label.text:SetText(text)
    frame.label = label
end

-- Sizes a frame like the group frames and puts it in its slot (0 = leftmost),
-- pinned to the container, so it moves and scales with the frames.
local function Place(frame, slot, size)
    local layout = NeoHeal.Layout
    frame:SetSize(size.buttonWidth, size.buttonHeight)
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", layout.container, "TOPLEFT", slot * (size.buttonWidth + size.spacing),
        TITLE_GAP + layout.titleBar:GetHeight() + FRAME_GAP)
end

-- Out of combat only (Layout:Create). `template` is the one the group headers
-- give their buttons. Layout:Refresh follows and places them.
function TargetFocusFrames:Create(container, template)
    for _, entry in ipairs(FRAMES) do
        local button = CreateFrame("Button", entry.name, container, template)
        button:SetAttribute("unit", entry.unit)
        NeoHeal.UnitButton.Init(button)
        AddLabel(button, entry.label)
        self.buttons[entry.unit] = button
    end
end

-- Test mode: a plain frame with a fake member where the real one goes, while its
-- option is on. Built on first use; Place and Decorate cost nothing when hidden.
local function ShowPreview(entry, slot, size, show)
    local frame = TargetFocusFrames.previews[entry.unit]
    if show and not frame then
        frame = CreateFrame("Frame", nil, NeoHeal.Layout.container)
        NeoHeal.UnitButton.CreateVisuals(frame)
        AddLabel(frame, entry.label)
        TargetFocusFrames.previews[entry.unit] = frame
    end
    if not frame then return end
    Place(frame, slot, size)
    NeoHeal.Preview.Decorate(frame, entry.member)
    frame:SetShown(show)
end

-- Applies the settings. Out of combat only (Layout:Refresh). A frame whose option
-- is off, or any real frame in test mode, loses its state driver and hides.
function TargetFocusFrames:Refresh()
    local settings, layout = NeoHeal.db.layout, NeoHeal.Layout
    local size, testMode = layout:GetSize(), layout.testSize ~= nil
    for index, entry in ipairs(FRAMES) do
        local enabled = settings[entry.setting]
        local button = self.buttons[entry.unit]
        Place(button, index - 1, size)
        if enabled and not testMode then
            RegisterStateDriver(button, "visibility", format("[@%s,help] show; hide", entry.unit))
        else
            UnregisterStateDriver(button, "visibility")
            button:Hide()
        end
        ShowPreview(entry, index - 1, size, enabled and testMode)
    end
end

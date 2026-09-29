-- Optionally hides Blizzard's own party and raid frames, so they don't show twice.
--
-- The frames are moved into a hidden parent instead of being hidden directly:
-- Blizzard code shows them again on many occasions, but a frame whose parent is
-- hidden stays invisible whatever it does. Out of combat only (they are secure).
-- Turning the option off again needs a /reload.
local _, NeoHeal = ...

local Blizzard = {}
NeoHeal.Blizzard = Blizzard

local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

-- Global names of the frames to hide. Some are created lazily by the game (e.g.
-- raid-style party frames), so this runs again after roster changes.
local FRAME_NAMES = { "PartyFrame", "CompactPartyFrame", "CompactRaidFrameContainer", "CompactRaidFrameManager" }

function Blizzard:ApplyHiding()
    if not NeoHeal.db.layout.hideBlizzardFrames then return end
    for _, name in ipairs(FRAME_NAMES) do
        local frame = _G[name]
        if frame and frame:GetParent() ~= hiddenParent then
            frame:SetParent(hiddenParent)
        end
    end
end

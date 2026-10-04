-- Missing buffs: out of combat, a small icon on members who lack the raid buff
-- your class gives (Fortitude, Mark of the Wild, Arcane Intellect), cast by
-- anyone. It is for buffing before a pull, and aura data is readable then; in
-- combat it goes away. It sits in the third HoT slot (bottom right): out of combat
-- a priest or druid has at most two HoTs of their own there.
-- Paladin blessings are left out: who gets which is decided per class, so
-- "missing" has no single meaning.
local _, NeoHeal = ...
local IsSecret = NeoHeal.IsSecret

local MissingBuffs = {
    inCombat = false,   -- set by Core.lua's PLAYER_REGEN events
    known = {},         -- the player's buffs: { names = { [name] = true }, icon, manaOnly }
}
NeoHeal.MissingBuffs = MissingBuffs

-- Per class: each buff with every spell that counts as it (rank 1 IDs; matched by
-- name, so every rank counts, and the group version too). `group` is the group
-- version (one cast buffs the target's whole party or raid group, costs `reagent`).
local SACRED_CANDLE, WILD_THORNROOT, ARCANE_POWDER = 17029, 17026, 17020
local CLASS_BUFFS = {
    PRIEST = {
        { spells = { 1243, 21562 }, group = 21562, reagent = SACRED_CANDLE },   -- Power Word / Prayer of Fortitude
        { spells = { 14752, 27681 }, group = 27681, reagent = SACRED_CANDLE },  -- Divine / Prayer of Spirit (talent)
    },
    DRUID = {
        { spells = { 1126, 21849 }, group = 21849, reagent = WILD_THORNROOT },  -- Mark / Gift of the Wild
    },
    MAGE = {
        { spells = { 1459, 23028 }, group = 23028, reagent = ARCANE_POWDER,    -- Arcane Intellect / Brilliance
          manaOnly = true },
    },
}
-- Classes without mana, who don't need Arcane Intellect.
local NO_MANA_CLASSES = { WARRIOR = true, ROGUE = true }

local ICON_SLOT = 3      -- counted from the right, like the HoT icons
local BORDER_SIZE = 1
local BORDER_COLOR = { 1, 0.1, 0.1, 1 }

-- Learning or losing a spell changes what you can give.
function MissingBuffs:UpdateKnownBuffs()
    wipe(self.known)
    local _, class = UnitClass("player")
    for _, buff in ipairs(CLASS_BUFFS[class] or {}) do
        if IsPlayerSpell(buff.spells[1]) then   -- the single-target rank 1 comes first
            local entry = { names = {}, manaOnly = buff.manaOnly, spellID = buff.spells[1],
                            groupSpellID = buff.group, reagent = buff.reagent,
                            icon = C_Spell.GetSpellTexture(buff.spells[1]) }
            for _, spellID in ipairs(buff.spells) do
                local name = C_Spell.GetSpellName(spellID)
                if name then entry.names[name] = true end
            end
            table.insert(self.known, entry)
        end
    end
end

local function Place(button)
    local size = NeoHeal.Hots.GetIconSize()
    local icon = button.missingBuffIcon
    icon:SetSize(size, size)
    icon:ClearAllPoints()
    icon:SetPoint("BOTTOMRIGHT", button.health, "BOTTOMRIGHT", -1 - (ICON_SLOT - 1) * (size + 1), 1)
end

-- Grey with a thin red edge, so it never reads as a buff that is there: grey is
-- WoW's own look for "not active", and the HoT icons next to it are in colour.
function MissingBuffs.Attach(button)
    local holder = CreateFrame("Frame", nil, button.health, "BackdropTemplate")
    holder:SetFrameLevel(button.health:GetFrameLevel() + 2)   -- as the HoT icons
    holder:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = BORDER_SIZE })
    holder:SetBackdropBorderColor(unpack(BORDER_COLOR))
    holder.texture = holder:CreateTexture(nil, "ARTWORK")
    holder.texture:SetPoint("TOPLEFT", BORDER_SIZE, -BORDER_SIZE)
    holder.texture:SetPoint("BOTTOMRIGHT", -BORDER_SIZE, BORDER_SIZE)
    holder.texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    holder.texture:SetDesaturated(true)
    holder:Hide()
    button.missingBuffIcon = holder
end

-- Collects the names of the unit's buffs into `found`. Returns false if the game
-- hides aura data right now.
local function ReadBuffNames(unit, found)
    wipe(found)
    for index = 1, 40 do
        local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, "HELPFUL")
        if not ok or IsSecret(aura) then return false end
        if not aura then return true end
        if IsSecret(aura.name) then return false end
        found[aura.name] = true
    end
    return true
end

-- The first of your buffs this unit lacks, or nil.
local found = {}

local function FindMissing(unit)
    if not ReadBuffNames(unit, found) then return nil end
    local _, class = UnitClass(unit)
    for _, buff in ipairs(MissingBuffs.known) do
        local wanted = not (buff.manaOnly and not IsSecret(class) and NO_MANA_CLASSES[class])
        if wanted then
            local has = false
            for name in pairs(buff.names) do
                if found[name] then has = true break end
            end
            if not has then return buff end
        end
    end
end

local function CanBeBuffed(unit)
    return NeoHeal.IsTrue(UnitIsConnected(unit)) and NeoHeal.IsFalse(UnitIsDeadOrGhost(unit))
        and NeoHeal.IsTrue(UnitIsPlayer(unit))   -- pets don't count
end

---------------------------------------------------------------------------
-- The "Cast missing buff" click binding (ClickCast.lua): each button carries the
-- spell to cast in "*spell-neobuff", set only while it is safe to buff:
--   * the icon shows: what you see is what the click does;
--   * out of combat: cleared when combat starts, and the click snippet checks
--     [nocombat] itself as well;
--   * no ready check icons show: a pull is coming, keep your mana.
-- Without the attribute the click does nothing. (Whether the member is at full
-- health can't be part of this: health is always secret to addons.)
-- Secure attributes can only change out of combat, which is all this needs.
---------------------------------------------------------------------------
local function GetReagentCount(itemID)
    local count = (C_Item and C_Item.GetItemCount or GetItemCount)(itemID)
    return not IsSecret(count) and count or 0
end

-- In a raid: the group version if you know it and carry its reagent (it buffs the
-- member's whole raid group at once), else the single one, so a click never fails
-- for a missing reagent.
local function ChooseSpell(buff)
    local spellID = buff.spellID
    if IsInRaid() and buff.groupSpellID and IsPlayerSpell(buff.groupSpellID)
            and GetReagentCount(buff.reagent) > 0 then
        spellID = buff.groupSpellID
    end
    return NeoHeal.Spells:GetHighestRank(spellID) or spellID
end

function MissingBuffs.UpdateClick(button)
    if InCombatLockdown() then return end   -- attributes are locked; the snippet refuses anyway
    local buff = button.missingBuff
    local spell
    if buff and not MissingBuffs.inCombat and not NeoHeal.UnitButton.readyCheckActive then
        spell = ChooseSpell(buff)
    end
    if button:GetAttribute("*spell-neobuff") ~= spell then
        button:SetAttribute("*spell-neobuff", spell)
    end
end

-- After a "Cast missing buff" click that didn't buff: why not, in red at the top
-- of the screen like the game's own errors. It only reads; what the click did was
-- already decided by the secure snippet (ClickCast.lua), with the same conditions.
local CLICK_SUFFIXES = { LeftButton = "1", RightButton = "2", MiddleButton = "3" }

function MissingBuffs.ExplainClick(button, mouseButton)
    local prefix = NeoHeal.ClickCast.GetModifierPrefix()
    local suffix = CLICK_SUFFIXES[mouseButton] or mouseButton:match("^Button(%d+)$") or ("-" .. mouseButton)
    if button:GetAttribute(prefix .. "type" .. suffix) ~= "neobuff" then return end

    local reason
    if MissingBuffs.inCombat or InCombatLockdown() then
        reason = NeoHeal.L.BUFF_IN_COMBAT
    elseif NeoHeal.UnitButton.readyCheckActive then
        reason = NeoHeal.L.BUFF_READY_CHECK
    elseif not button.missingBuff then
        reason = NeoHeal.L.BUFF_NOTHING_MISSING
    end
    if reason then UIErrorsFrame:AddMessage(reason, 1, 0.1, 0.1) end
end

function MissingBuffs.Update(button)
    local icon = button.missingBuffIcon
    local buff = NeoHeal.db.layout.showMissingBuffs and not MissingBuffs.inCombat and not InCombatLockdown()
        and #MissingBuffs.known > 0 and CanBeBuffed(button.unit) and FindMissing(button.unit)
    button.missingBuff = buff or nil
    if buff then
        Place(button)
        icon.texture:SetTexture(buff.icon)
        icon:Show()
    else
        icon:Hide()
    end
    MissingBuffs.UpdateClick(button)
end

-- Test mode: the icon of your first buff on a preview frame (none for classes
-- without one).
function MissingBuffs.ShowPreview(frame, show)
    local buff = MissingBuffs.known[1]
    if show and buff and NeoHeal.db.layout.showMissingBuffs then
        Place(frame)
        frame.missingBuffIcon.texture:SetTexture(buff.icon)
        frame.missingBuffIcon:Show()
    else
        frame.missingBuffIcon:Hide()
    end
end

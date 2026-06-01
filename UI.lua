local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests = addon.state.priests or {}
addon.state.assignments = addon.state.assignments or {}

local FEAR_WARD_SPELL = GetSpellInfo(6346) or "Fear Ward"

--------------------------------------------------
-- MAIN SMALL WINDOW
--------------------------------------------------

local frame = CreateFrame("Button", "FWCFrame", UIParent, "BackdropTemplate")
frame:SetSize(190, 60)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
frame:SetBackdropColor(0, 0.35, 0, 0.9)

addon.uiFrame = frame

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetSize(32, 32)
icon:SetPoint("LEFT", frame, "LEFT", 8, 0)
icon:SetTexture("Interface\\Icons\\Spell_Holy_Excorcism")

local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 48, -10)

local groupText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
groupText:SetPoint("LEFT", frame, "LEFT", 48, -10)

--------------------------------------------------
-- POPOUT WINDOW
--------------------------------------------------

local popout = CreateFrame("Frame", "FWCPopoutFrame", UIParent, "BasicFrameTemplateWithInset")
popout:SetSize(320, 380)
popout:SetPoint("LEFT", frame, "RIGHT", 8, 0)
popout:Hide()
popout:SetAlpha(1)

table.insert(UISpecialFrames, "FWCPopoutFrame")

popout.title = popout:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
popout.title:SetPoint("CENTER", popout.TitleBg, "CENTER")
popout.title:SetText("My Fear Ward Groups")

--------------------------------------------------
-- DATA HELPERS
--------------------------------------------------

local popoutObjects = {}
local playerRows = {}

local function NormalizeName(name)
    if not name then return nil end
    return Ambiguate(name, "short")
end

local function GetMyGroups()
    local player = NormalizeName(UnitName("player"))
    local groups = {}

    if addon.state.assignments then
        for priest, assignedGroups in pairs(addon.state.assignments) do
            if NormalizeName(priest) == player then
                for g = 1, 8 do
                    if assignedGroups[g] then
                        table.insert(groups, g)
                    end
                end
            end
        end
    end

    table.sort(groups)
    return groups
end

local function ClearPopout()
    if InCombatLockdown() then
        return
    end

    for _, obj in pairs(popoutObjects) do
        obj:Hide()
    end

    wipe(popoutObjects)
    wipe(playerRows)
end

local function AddText(text, x, y, template)
    local fs = popout:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", popout, "TOPLEFT", x, y)
    fs:SetText(text)

    table.insert(popoutObjects, fs)

    return fs
end

--------------------------------------------------
-- SECURE FEAR WARD BUTTON
-- IMPORTANT:
-- These must be created OUT OF COMBAT.
--------------------------------------------------

local function AddPlayerButton(member, x, y)
    local btn = CreateFrame("Button", nil, popout, "SecureActionButtonTemplate")
    btn:SetSize(140, 22)
    btn:SetPoint("TOPLEFT", popout, "TOPLEFT", x, y)

    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", FEAR_WARD_SPELL)
    btn:SetAttribute("unit", member.unit)

    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", btn, "LEFT", 0, 0)
    name:SetText(member.name)

    local status = popout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", popout, "TOPLEFT", 185, y + 2)
    status:SetText("Checking")

    table.insert(popoutObjects, btn)
    table.insert(popoutObjects, status)

    table.insert(playerRows, {
        button = btn,
        status = status,
        unit = member.unit,
        name = member.name
    })

    return btn
end

--------------------------------------------------
-- STATUS UPDATE ONLY
-- SAFE IN COMBAT
--------------------------------------------------

function addon:RefreshPopoutStatusOnly()
    for _, row in ipairs(playerRows) do
        local unit = row.unit
        local statusText

        if not UnitExists(unit) then
            statusText = "|cff888888Gone|r"
        elseif UnitIsDeadOrGhost(unit) then
            statusText = "|cff888888Dead|r"
        elseif not UnitIsConnected(unit) then
            statusText = "|cff888888Offline|r"
        else
            local hasBuff, remaining = addon:GetFearWardInfo(unit)

            if hasBuff then
                if remaining > 0 and remaining < 30 then
                    statusText = "|cffffff00FW " .. addon:FormatTime(remaining) .. "|r"
                else
                    statusText = "|cff00ff00FW " .. addon:FormatTime(remaining) .. "|r"
                end
            else
                statusText = "|cffff0000Missing|r"
            end
        end

        row.status:SetText(statusText)
    end
end

--------------------------------------------------
-- FULL POPOUT BUILD
-- OUT OF COMBAT ONLY
--------------------------------------------------

function addon:BuildPopout()
    if InCombatLockdown() then
        print("|cffff0000FWC: Cannot build click-cast buttons during combat. Open this before the pull.|r")
        return
    end

    ClearPopout()

    local groups = GetMyGroups()

    popout.title:SetText("My Fear Ward Groups")

    if #groups == 0 then
        AddText("No groups assigned to you.", 16, -45)
        return
    end

    AddText("Click player name to cast Fear Ward", 16, -38, "GameFontDisableSmall")

    local line = 0

    for _, groupNumber in ipairs(groups) do
        AddText("Group " .. groupNumber, 16, -65 - (line * 24), "GameFontHighlight")
        line = line + 1

        local members = addon:GetGroupMembers(groupNumber)

        if #members == 0 then
            AddText("No members", 32, -65 - (line * 24), "GameFontDisableSmall")
            line = line + 1
        else
            for _, member in ipairs(members) do
                local y = -65 - (line * 24)

                AddPlayerButton(member, 32, y)

                line = line + 1
            end
        end
    end

    addon:RefreshPopoutStatusOnly()
end

--------------------------------------------------
-- TOGGLE POPOUT
--------------------------------------------------

local function TogglePopout()
    if popout:IsShown() then
        if InCombatLockdown() then
            print("|cffffff00FWC: Popout will close after combat. Secure frames cannot always be hidden in combat.|r")
            return
        end

        popout:Hide()
    else
        if InCombatLockdown() and #playerRows == 0 then
            print("|cffff0000FWC: Open the Fear Ward popout before combat to enable click-casting.|r")
            return
        end

        popout:Show()

        if not InCombatLockdown() then
            addon:BuildPopout()
        else
            addon:RefreshPopoutStatusOnly()
        end
    end
end

frame:SetScript("OnClick", TogglePopout)

--------------------------------------------------
-- MAIN UI REFRESH
--------------------------------------------------

function addon:RefreshUI()
    if not frame:IsShown() then return end

    if addon.ScanRaid then
        addon:ScanRaid()
    end

    local player = NormalizeName(UnitName("player"))
    local groups = GetMyGroups()

    nameText:SetText(player or "Me")

    if #groups == 0 then
        groupText:SetText("Groups: -")
        frame:SetBackdropColor(0.45, 0, 0, 0.9)
    else
        groupText:SetText("Groups: " .. table.concat(groups, ","))
        frame:SetBackdropColor(0, 0.35, 0, 0.9)
    end

    if popout:IsShown() then
        addon:RefreshPopoutStatusOnly()
    end
end

function addon:ToggleUI()
    if frame:IsShown() then
        if InCombatLockdown() then
            print("|cffffff00FWC: Cannot safely close secure click-cast frames in combat.|r")
            return
        end

        frame:Hide()
        popout:Hide()
    else
        frame:Show()
        addon:RefreshUI()
    end
end

--------------------------------------------------
-- LIVE TIMER UPDATE
--------------------------------------------------

local updater = CreateFrame("Frame")
local elapsed = 0

updater:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta

    if elapsed >= 1 then
        elapsed = 0

        if frame:IsShown() then
            addon:RefreshUI()
        end

        if popout:IsShown() then
            addon:RefreshPopoutStatusOnly()
        end
    end
end)

--------------------------------------------------
-- REBUILD AFTER COMBAT
--------------------------------------------------

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

combatFrame:SetScript("OnEvent", function()
    if popout:IsShown() then
        addon:BuildPopout()
    end
end)

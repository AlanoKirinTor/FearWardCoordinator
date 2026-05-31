local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests = addon.state.priests or {}
addon.state.assignments = addon.state.assignments or {}

local FEAR_WARD_SPELL = GetSpellInfo(6346) or "Fear Ward"

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

local popoutRows = {}

local popout = CreateFrame("Frame", "FWCPopoutFrame", UIParent, "BasicFrameTemplateWithInset")
popout:SetSize(300, 360)
popout:SetPoint("LEFT", frame, "RIGHT", 8, 0)
popout:Hide()
popout:SetAlpha(1)

table.insert(UISpecialFrames, "FWCPopoutFrame")

popout.title = popout:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
popout.title:SetPoint("CENTER", popout.TitleBg, "CENTER")
popout.title:SetText("My Fear Ward Groups")

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetSize(32, 32)
icon:SetPoint("LEFT", frame, "LEFT", 8, 0)
icon:SetTexture("Interface\\Icons\\Spell_Holy_Excorcism")

local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 48, -10)

local groupText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
groupText:SetPoint("LEFT", frame, "LEFT", 48, -10)

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
    for _, r in pairs(popoutRows) do
        r:Hide()
    end
    wipe(popoutRows)
end

local function AddPopoutText(text, x, y, template)
    local fs = popout:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", popout, "TOPLEFT", x, y)
    fs:SetText(text)
    table.insert(popoutRows, fs)
    return fs
end

local function AddPlayerButton(member, x, y)
    local btn = CreateFrame("Button", nil, popout, "SecureActionButtonTemplate")
    btn:SetSize(140, 22)
    btn:SetPoint("TOPLEFT", popout, "TOPLEFT", x, y)

    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", FEAR_WARD_SPELL)
    btn:SetAttribute("unit", member.unit)

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", btn, "LEFT", 0, 0)
    text:SetText(member.name)

    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    table.insert(popoutRows, btn)
    return btn
end

function addon:RefreshPopout()
    ClearPopout()

    local groups = GetMyGroups()
    popout.title:SetText("My Fear Ward Groups")

    if #groups == 0 then
        AddPopoutText("No groups assigned to you.", 16, -45)
        return
    end

    AddPopoutText("Click player name to cast Fear Ward", 16, -38, "GameFontDisableSmall")

    local line = 0

    for _, groupNumber in ipairs(groups) do
        AddPopoutText("Group " .. groupNumber, 16, -65 - (line * 24), "GameFontHighlight")
        line = line + 1

        local members = addon:GetGroupMembers(groupNumber)

        if #members == 0 then
            AddPopoutText("No members", 32, -65 - (line * 24), "GameFontDisableSmall")
            line = line + 1
        else
            for _, member in ipairs(members) do
                local y = -65 - (line * 24)

                local hasBuff, remaining = addon:GetFearWardInfo(member.unit)

                local status
                if UnitIsDeadOrGhost(member.unit) then
                    status = "|cff888888Dead|r"
                elseif not UnitIsConnected(member.unit) then
                    status = "|cff888888Offline|r"
                elseif hasBuff then
                    if remaining > 0 and remaining < 30 then
                        status = "|cffffff00FW " .. addon:FormatTime(remaining) .. "|r"
                    else
                        status = "|cff00ff00FW " .. addon:FormatTime(remaining) .. "|r"
                    end
                else
                    status = "|cffff0000Missing|r"
                end

                AddPlayerButton(member, 32, y)
                AddPopoutText(status, 175, y + 2, "GameFontNormalSmall")

                line = line + 1
            end
        end
    end
end

local function TogglePopout()
    if popout:IsShown() then
        popout:Hide()
    else
        popout:Show()
        addon:RefreshPopout()
    end
end

frame:SetScript("OnClick", TogglePopout)

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
        addon:RefreshPopout()
    end
end

function addon:ToggleUI()
    frame:SetShown(not frame:IsShown())

    if frame:IsShown() then
        addon:RefreshUI()
    else
        popout:Hide()
    end
end

local updater = CreateFrame("Frame")
local elapsed = 0

updater:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta

    if elapsed >= 1 then
        elapsed = 0

        if frame:IsShown() then
            addon:RefreshUI()
        end
    end
end)
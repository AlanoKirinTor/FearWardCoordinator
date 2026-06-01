local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests = addon.state.priests or {}
addon.state.assignments = addon.state.assignments or {}

local FEAR_WARD_SPELL = GetSpellInfo(6346) or "Fear Ward"

local function MakeMovable(f)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
end

local frame = CreateFrame("Button", "FWCFrame", UIParent, "BackdropTemplate")
frame:SetSize(190, 60)
frame:SetPoint("CENTER")
frame:Hide()
MakeMovable(frame)

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

local popout = CreateFrame("Frame", "FWCPopoutFrame", UIParent, "BasicFrameTemplateWithInset")
popout:SetSize(260, 240)
popout:SetPoint("TOP", frame, "BOTTOM", 0, -4)
popout:Hide()
popout:SetAlpha(1)
MakeMovable(popout)

table.insert(UISpecialFrames, "FWCPopoutFrame")

popout.title = popout:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
popout.title:SetPoint("CENTER", popout.TitleBg, "CENTER")
popout.title:SetText("My Fear Ward Groups")

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
    if InCombatLockdown() then return end

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

local function AddPlayerButton(member, x, y)
    local btn = CreateFrame("Button", nil, popout, "SecureActionButtonTemplate")
    btn:SetSize(115, 18)
    btn:SetPoint("TOPLEFT", popout, "TOPLEFT", x, y)

    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", FEAR_WARD_SPELL)
    btn:SetAttribute("unit", member.unit)

    btn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

    local name = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    name:SetPoint("LEFT", btn, "LEFT", 0, 0)
    name:SetText(member.name)

    local status = popout:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", popout, "TOPLEFT", 145, y + 1)
    status:SetText("...")

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

function addon:BuildPopout()
    if InCombatLockdown() then
        print("|cffff0000FWC: Cannot rebuild buttons during combat. Open before pull.|r")
        return
    end

    ClearPopout()

    local groups = GetMyGroups()

    popout.title:SetText("My Fear Ward Groups")

    if #groups == 0 then
        AddText("No groups assigned.", 12, -34)
        return
    end

    AddText("Click name to cast Fear Ward", 12, -32, "GameFontDisableSmall")

    local line = 0

    for _, groupNumber in ipairs(groups) do
        AddText("Group " .. groupNumber, 12, -52 - (line * 20), "GameFontHighlight")
        line = line + 1

        local members = addon:GetGroupMembers(groupNumber)

        if #members == 0 then
            AddText("No members", 26, -52 - (line * 20), "GameFontDisableSmall")
            line = line + 1
        else
            for _, member in ipairs(members) do
                local y = -52 - (line * 20)
                AddPlayerButton(member, 26, y)
                line = line + 1
            end
        end
    end

    addon:RefreshPopoutStatusOnly()
end

local function TogglePopout()
    if popout:IsShown() then
        if InCombatLockdown() then
            print("|cffffff00FWC: Cannot safely close secure frame in combat.|r")
            return
        end

        popout:Hide()
    else
        if InCombatLockdown() and #playerRows == 0 then
            print("|cffff0000FWC: Open before combat to enable click-casting.|r")
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
            print("|cffffff00FWC: Cannot safely close secure frames in combat.|r")
            return
        end

        frame:Hide()
        popout:Hide()
    else
        frame:Show()
        addon:RefreshUI()
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

        if popout:IsShown() then
            addon:RefreshPopoutStatusOnly()
        end
    end
end)

local combatFrame = CreateFrame("Frame")
combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

combatFrame:SetScript("OnEvent", function()
    if popout:IsShown() then
        addon:BuildPopout()
    end
end)

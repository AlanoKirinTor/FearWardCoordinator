local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests = addon.state.priests or {}
addon.state.assignments = addon.state.assignments or {}

local FEAR_WARD_SPELL = GetSpellInfo(6346) or "Fear Ward"

--------------------------------------------------
-- MOVING / RESIZING HELPERS
--------------------------------------------------

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

local function AddResizeCorners(targetFrame, minW, minH, maxW, maxH, onResizeDone)
    targetFrame:SetResizable(true)
    targetFrame:SetResizeBounds(minW, minH, maxW, maxH)

    local corners = {
        { point = "TOPLEFT", cursor = "TOPLEFT" },
        { point = "TOPRIGHT", cursor = "TOPRIGHT" },
        { point = "BOTTOMLEFT", cursor = "BOTTOMLEFT" },
        { point = "BOTTOMRIGHT", cursor = "BOTTOMRIGHT" },
    }

    for _, data in ipairs(corners) do
        local grip = CreateFrame("Button", nil, targetFrame)
        grip:SetSize(18, 18)
        grip:SetPoint(data.point, targetFrame, data.point, 0, 0)
        grip:RegisterForClicks("RightButtonDown", "RightButtonUp")

        grip:SetScript("OnMouseDown", function()
            if InCombatLockdown() then return end

            if IsShiftKeyDown() and IsMouseButtonDown("RightButton") then
                targetFrame:StartSizing(data.cursor)
            end
        end)

        grip:SetScript("OnMouseUp", function()
            targetFrame:StopMovingOrSizing()

            if onResizeDone then
                onResizeDone()
            end
        end)
    end
end

--------------------------------------------------
-- ALERT FRAME
--------------------------------------------------

local alertEnabled = true
local alertTestMode = false
local alertWatchState = {}

local alertFrame = CreateFrame("Frame", "FWCAlertFrame", UIParent)
alertFrame:SetSize(600, 80)
alertFrame:SetPoint("TOP", UIParent, "TOP", 0, -180)
alertFrame:Hide()

MakeMovable(alertFrame)

alertFrame.text = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alertFrame.text:SetPoint("CENTER")
alertFrame.text:SetTextColor(1, 0.15, 0.15, 1)

local function UpdateAlertFont()
    local h = alertFrame:GetHeight()
    local size = math.max(18, math.min(44, math.floor(h * 0.45)))
    alertFrame.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
end

AddResizeCorners(alertFrame, 260, 50, 1200, 220, UpdateAlertFont)
UpdateAlertFont()

local function ShowFWCAlert(msg)
    if not alertEnabled then return end

    alertTestMode = false
    alertFrame.text:SetText(msg)
    alertFrame:Show()

    C_Timer.After(3, function()
        if not alertTestMode then
            alertFrame:Hide()
        end
    end)
end

SLASH_FWCALERT1 = "/fwcalert"
SlashCmdList["FWCALERT"] = function()
    if alertFrame:IsShown() and alertTestMode then
        alertTestMode = false
        alertFrame:Hide()
        print("|cffffff00FWC Alert test hidden.|r")
        return
    end

    alertEnabled = true
    alertTestMode = true

    alertFrame.text:SetText("TANK! Fear Ward fell off Testtank")
    alertFrame:Show()

    FearWardCoordinatorDB = FearWardCoordinatorDB or {}
    FearWardCoordinatorDB.alertEnabled = true

    print("|cff00ff00FWC Alert test shown.|r Left-drag to move. Shift + right-drag corner to resize. Run /fwcalert again to hide.")
end

SLASH_FWCALERTOFF1 = "/fwcalertoff"
SlashCmdList["FWCALERTOFF"] = function()
    alertEnabled = false
    alertTestMode = false
    alertFrame:Hide()

    FearWardCoordinatorDB = FearWardCoordinatorDB or {}
    FearWardCoordinatorDB.alertEnabled = false

    print("|cffffff00FWC alerts disabled.|r")
end

SLASH_FWCALERTON1 = "/fwcalerton"
SlashCmdList["FWCALERTON"] = function()
    alertEnabled = true

    FearWardCoordinatorDB = FearWardCoordinatorDB or {}
    FearWardCoordinatorDB.alertEnabled = true

    print("|cff00ff00FWC alerts enabled.|r")
end

--------------------------------------------------
-- MAIN BAR
--------------------------------------------------

local frame = CreateFrame("Button", "FWCFrame", UIParent, "BackdropTemplate")
frame:SetSize(145, 45)
frame:SetPoint("CENTER")
frame:Hide()

MakeMovable(frame)
AddResizeCorners(frame, 120, 40, 400, 120)

frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
frame:SetBackdropColor(0, 0.35, 0, 0.9)

addon.uiFrame = frame

local icon = frame:CreateTexture(nil, "ARTWORK")
icon:SetSize(24, 24)
icon:SetPoint("LEFT", frame, "LEFT", 6, 0)
icon:SetTexture("Interface\\Icons\\Spell_Holy_Excorcism")

local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 36, -7)

local groupText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
groupText:SetPoint("LEFT", frame, "LEFT", 36, -9)

--------------------------------------------------
-- POPOUT
--------------------------------------------------

local popout = CreateFrame("Frame", "FWCPopoutFrame", UIParent, "BasicFrameTemplateWithInset")
popout:SetSize(230, 180)
popout:SetPoint("TOP", frame, "BOTTOM", 0, -4)
popout:Hide()
popout:SetAlpha(1)

MakeMovable(popout)
AddResizeCorners(popout, 190, 120, 520, 650)

popout.title = popout:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
popout.title:SetPoint("CENTER", popout.TitleBg, "CENTER")
popout.title:SetText("My Fear Ward Groups")

-- Important:
-- Do NOT enable keyboard input on this frame.
-- That keeps Escape working for normal game menus/macros/keybinds,
-- while also preventing Escape from closing this popout.

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

local function IsUnitInFearWardRange(unit)
    if not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost(unit) then return false end
    if not UnitIsConnected(unit) then return false end

    local inRange = IsSpellInRange(FEAR_WARD_SPELL, unit)

    return inRange == 1
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

--------------------------------------------------
-- ALERT WATCHER
--------------------------------------------------

local function AddAlertWatchTarget(targets, name, unit, isTank)
    if not name or not unit then return end

    local key = NormalizeName(name)
    if not key then return end

    if not targets[key] then
        targets[key] = {
            name = name,
            unit = unit,
            isTank = isTank or false
        }
    elseif isTank then
        targets[key].isTank = true
    end
end

local function AddAssignedGroupAlertTargets(targets)
    local groups = GetMyGroups()

    for _, groupNumber in ipairs(groups) do
        local members = addon:GetGroupMembers(groupNumber)

        for _, member in ipairs(members) do
            AddAlertWatchTarget(targets, member.name, member.unit, false)
        end
    end
end

local function AddMainTankAlertTargets(targets)
    if not IsInRaid() then return end

    for i = 1, 40 do
        local unit = "raid" .. i
        local name, _, _, _, _, _, _, _, _, raidMainTankRole = GetRaidRosterInfo(i)

        if name then
            local assignedRole = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"

            if raidMainTankRole == "MAINTANK" or assignedRole == "TANK" then
                AddAlertWatchTarget(targets, name, unit, true)
            end
        end
    end
end

local function RefreshFearWardAlerts()
    if not IsInGroup() then return end

    local targets = {}
    local currentlyTracked = {}

    AddAssignedGroupAlertTargets(targets)
    AddMainTankAlertTargets(targets)

    for key, target in pairs(targets) do
        currentlyTracked[key] = true

        local hasBuff = false

        if UnitExists(target.unit)
            and UnitIsConnected(target.unit)
            and not UnitIsDeadOrGhost(target.unit)
        then
            hasBuff = addon:GetFearWardInfo(target.unit)
        end

        if alertWatchState[key] == true and hasBuff == false then
            if target.isTank then
                ShowFWCAlert("TANK! Fear Ward fell off " .. target.name)
            else
                ShowFWCAlert("Fear Ward fell off " .. target.name)
            end
        end

        alertWatchState[key] = hasBuff
    end

    for key in pairs(alertWatchState) do
        if not currentlyTracked[key] then
            alertWatchState[key] = nil
        end
    end
end

--------------------------------------------------
-- SECURE CLICK BUTTONS
--------------------------------------------------

local function CreateFearWardButton(member, x, y, width, labelText)
    local btn = CreateFrame("Button", nil, popout, "SecureActionButtonTemplate")
    btn:SetSize(width, 16)
    btn:SetPoint("TOPLEFT", popout, "TOPLEFT", x, y)

    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", FEAR_WARD_SPELL)
    btn:SetAttribute("unit", member.unit)

    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\WHITE8x8")
    highlight:SetPoint("LEFT", btn, "LEFT", 0, 0)
    highlight:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
    highlight:SetHeight(16)
    highlight:SetVertexColor(1, 1, 1, 0.18)
    btn:SetHighlightTexture(highlight)

    local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", btn, "LEFT", 0, 0)
    text:SetPoint("RIGHT", btn, "RIGHT", 0, 0)
    text:SetJustifyH("LEFT")
    text:SetText(labelText)

    btn.text = text

    btn:SetScript("PreClick", function()
        if not IsUnitInFearWardRange(member.unit) then
            print("|cffff0000FWC: " .. member.name .. " is out of range for Fear Ward.|r")
        end
    end)

    table.insert(popoutObjects, btn)

    return btn
end

local function AddPlayerRow(member, x, y)
    local nameBtn = CreateFearWardButton(member, x, y, 86, member.name)
    local statusBtn = CreateFearWardButton(member, x + 112, y, 72, "...")

    table.insert(playerRows, {
        name = member.name,
        unit = member.unit,
        nameButton = nameBtn,
        statusButton = statusBtn,
        statusText = statusBtn.text
    })
end

--------------------------------------------------
-- STATUS UPDATE ONLY
--------------------------------------------------

function addon:RefreshPopoutStatusOnly()
    for _, row in ipairs(playerRows) do
        local unit = row.unit
        local statusText
        local hasBuff = false
        local remaining = 0
        local inRange = IsUnitInFearWardRange(unit)

        if not UnitExists(unit) then
            statusText = "|cff888888Gone|r"
        elseif UnitIsDeadOrGhost(unit) then
            statusText = "|cff888888Dead|r"
        elseif not UnitIsConnected(unit) then
            statusText = "|cff888888Offline|r"
        else
            hasBuff, remaining = addon:GetFearWardInfo(unit)

            if hasBuff then
                if remaining > 0 and remaining < 300 then
                    statusText = "|cffffff00FW " .. addon:FormatTime(remaining) .. "|r"
                else
                    statusText = "|cff00ff00FW " .. addon:FormatTime(remaining) .. "|r"
                end
            else
                statusText = "|cffff0000Missing|r"
            end
        end

        row.statusText:SetText(statusText)

        if inRange then
            row.statusButton:SetAlpha(1)
            row.nameButton:SetAlpha(1)
        else
            row.statusButton:SetAlpha(0.8)
            row.nameButton:SetAlpha(0.8)
        end

        -- Do not disable secure buttons. Range is visual/warning only.
        row.nameButton:Enable()
        row.statusButton:Enable()
    end
end

--------------------------------------------------
-- BUILD POPOUT
--------------------------------------------------

function addon:BuildPopout()
    if InCombatLockdown() then
        print("|cffff0000FWC: Cannot rebuild buttons during combat. Open before pull.|r")
        return
    end

    ClearPopout()

    local groups = GetMyGroups()

    popout.title:SetText("My Fear Ward Groups")

    if #groups == 0 then
        AddText("No groups assigned.", 10, -32)
        popout:SetSize(230, 95)
        return
    end

    AddText("Click name or status to cast", 10, -30, "GameFontDisableSmall")

    local line = 0

    for _, groupNumber in ipairs(groups) do
        AddText("Group " .. groupNumber, 10, -48 - (line * 19), "GameFontHighlight")
        line = line + 1

        local members = addon:GetGroupMembers(groupNumber)

        if #members == 0 then
            AddText("No members", 24, -48 - (line * 19), "GameFontDisableSmall")
            line = line + 1
        else
            for _, member in ipairs(members) do
                local y = -48 - (line * 19)
                AddPlayerRow(member, 24, y)
                line = line + 1
            end
        end
    end

    local neededHeight = 70 + (line * 19)
    neededHeight = math.max(120, math.min(neededHeight, 650))

    popout:SetHeight(neededHeight)

    addon:RefreshPopoutStatusOnly()
end

--------------------------------------------------
-- TOGGLE POPOUT
--------------------------------------------------

local function TogglePopout()
    if popout:IsShown() then
        if InCombatLockdown() then
            print("|cffffff00FWC: Cannot close secure popout during combat.|r")
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

--------------------------------------------------
-- MAIN UI
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

--------------------------------------------------
-- LOAD SAVED ALERT SETTING
--------------------------------------------------

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("PLAYER_LOGIN")

loadFrame:SetScript("OnEvent", function()
    FearWardCoordinatorDB = FearWardCoordinatorDB or {}

    if FearWardCoordinatorDB.alertEnabled == nil then
        FearWardCoordinatorDB.alertEnabled = true
    end

    alertEnabled = FearWardCoordinatorDB.alertEnabled
end)

--------------------------------------------------
-- LIVE UPDATE
--------------------------------------------------

local updater = CreateFrame("Frame")
local elapsed = 0

updater:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta

    if elapsed >= 1 then
        elapsed = 0

        RefreshFearWardAlerts()

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

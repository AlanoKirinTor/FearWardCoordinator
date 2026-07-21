local addonName, addon = ...
local DB = addon.GetDB
local SPELL_NAME = addon:GetFearWardSpellName()
local SPELL_ID = addon:GetFearWardSpellID()

local function SavePosition(frame, key)
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local db = DB()
    db.positions[key] = {
        point = point, relativePoint = relativePoint, x = x, y = y,
        width = frame:GetWidth(), height = frame:GetHeight(), scale = frame:GetScale(),
    }
end

local function RestorePosition(frame, key, point, relativePoint, x, y)
    local p = DB().positions[key]
    frame:ClearAllPoints()
    if p then
        frame:SetPoint(p.point or point, UIParent, p.relativePoint or relativePoint, p.x or x, p.y or y)
        if p.width and p.height then frame:SetSize(p.width, p.height) end
        if p.scale then frame:SetScale(p.scale) end
    else
        frame:SetPoint(point, UIParent, relativePoint, x, y)
    end
end

local function AddTitleDrag(frame, dragRegion, key)
    dragRegion:EnableMouse(true)
    dragRegion:RegisterForDrag("LeftButton")
    dragRegion:SetScript("OnDragStart", function()
        if not InCombatLockdown() then frame:StartMoving() end
    end)
    dragRegion:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition(frame, key)
    end)
end

local function AddResizeCorners(frame, key, minW, minH, maxW, maxH, onDone)
    frame:SetResizable(true)
    if frame.SetResizeBounds then frame:SetResizeBounds(minW, minH, maxW, maxH)
    else frame:SetMinResize(minW, minH); frame:SetMaxResize(maxW, maxH) end

    for _, data in ipairs({
        {"TOPLEFT", "TOPLEFT"}, {"TOPRIGHT", "TOPRIGHT"},
        {"BOTTOMLEFT", "BOTTOMLEFT"}, {"BOTTOMRIGHT", "BOTTOMRIGHT"},
    }) do
        local grip = CreateFrame("Button", nil, frame)
        grip:SetSize(16, 16)
        grip:SetPoint(data[1])
        grip:RegisterForClicks("RightButtonDown", "RightButtonUp")
        grip:SetFrameLevel(frame:GetFrameLevel() + 100)
        grip:SetScript("OnMouseDown", function()
            if not InCombatLockdown() and IsShiftKeyDown() then frame:StartSizing(data[2]) end
        end)
        grip:SetScript("OnMouseUp", function()
            frame:StopMovingOrSizing()
            SavePosition(frame, key)
            if onDone then onDone() end
        end)
    end
end

-- Alert frame
local alertFrame = CreateFrame("Frame", "FWCAlertFrame2", UIParent)
alertFrame:SetSize(600, 80)
alertFrame:SetFrameStrata("HIGH")
alertFrame:SetMovable(true)
alertFrame:SetClampedToScreen(true)
alertFrame:Hide()
RestorePosition(alertFrame, "alert", "TOP", "TOP", 0, -180)
alertFrame.text = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alertFrame.text:SetPoint("CENTER")
alertFrame.text:SetTextColor(1, .15, .15, 1)
AddTitleDrag(alertFrame, alertFrame, "alert")

local function AlertFont()
    alertFrame.text:SetFont(STANDARD_TEXT_FONT, math.max(18, math.min(44, math.floor(alertFrame:GetHeight() * .45))), "OUTLINE")
end
AddResizeCorners(alertFrame, "alert", 260, 50, 1200, 220, AlertFont)
AlertFont()

local alertState = {}
local alertGeneration = 0
local alertTest = false

local function ShowAlert(text)
    if not DB().alertEnabled then return end
    alertTest = false
    alertGeneration = alertGeneration + 1
    local generation = alertGeneration
    alertFrame.text:SetText(text)
    alertFrame:Show()
    C_Timer.After(3, function()
        if generation == alertGeneration and not alertTest then alertFrame:Hide() end
    end)
end

SLASH_FWCALERT1 = "/fwcalert"
SlashCmdList.FWCALERT = function()
    if alertTest and alertFrame:IsShown() then
        alertTest = false; alertFrame:Hide(); return
    end
    DB().alertEnabled = true
    alertTest = true
    alertGeneration = alertGeneration + 1
    alertFrame.text:SetText("TANK! Fear Ward missing on Testtank")
    alertFrame:Show()
    print("|cff00ff00FWC alert test shown.|r Drag to move; Shift + right-drag a corner to resize.")
end
SLASH_FWCALERTOFF1 = "/fwcalertoff"
SlashCmdList.FWCALERTOFF = function() DB().alertEnabled = false; alertTest = false; alertFrame:Hide(); print("|cffffff00FWC alerts disabled.|r") end
SLASH_FWCALERTON1 = "/fwcalerton"
SlashCmdList.FWCALERTON = function() DB().alertEnabled = true; print("|cff00ff00FWC alerts enabled.|r") end

-- Main launcher
local main = CreateFrame("Button", "FWCMainFrame2", UIParent, "BackdropTemplate")
main:SetSize(145, 45)
main:SetMovable(true)
main:SetClampedToScreen(true)
main:RegisterForClicks("AnyUp")
main:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=10, insets={left=2,right=2,top=2,bottom=2}})
main:SetBackdropColor(0, .35, 0, .9)
main:Hide()
RestorePosition(main, "main", "CENTER", "CENTER", 0, 0)

local icon = main:CreateTexture(nil, "ARTWORK")
icon:SetSize(24,24); icon:SetPoint("LEFT", 6, 0); icon:SetTexture(135955)
local nameText = main:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetPoint("TOPLEFT", 36, -7)
local groupText = main:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
groupText:SetPoint("LEFT", 36, -9)

main:SetScript("OnDragStart", function(self) if not InCombatLockdown() then self:StartMoving() end end)
main:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); SavePosition(self, "main") end)
main:RegisterForDrag("LeftButton")

-- Popout. Only the title strip drags; the body never registers for drag.
local popout = CreateFrame("Frame", "FWCPopoutFrame2", UIParent, "BackdropTemplate")
popout:SetSize(250, 180)
popout:SetMovable(true)
popout:SetClampedToScreen(true)
popout:SetFrameStrata("DIALOG")
popout:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=20, insets={left=5,right=5,top=5,bottom=5}})
popout:Hide()
RestorePosition(popout, "popout", "CENTER", "CENTER", 0, -130)

local titleBar = CreateFrame("Frame", nil, popout, "BackdropTemplate")
titleBar:SetPoint("TOPLEFT", 8, -7); titleBar:SetPoint("TOPRIGHT", -8, -7); titleBar:SetHeight(24)
titleBar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8x8"}); titleBar:SetBackdropColor(.12,.12,.12,.95)
local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("CENTER"); title:SetText("My Fear Ward Groups")
AddTitleDrag(popout, titleBar, "popout")

local close = CreateFrame("Button", nil, popout, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)
close:SetScript("OnClick", function()
    if InCombatLockdown() then print("|cffffff00FWC: Secure popout stays open during combat.|r") else popout:Hide() end
end)

local content = CreateFrame("Frame", nil, popout)
content:SetPoint("TOPLEFT", 12, -35); content:SetPoint("BOTTOMRIGHT", -12, 12)
content:EnableMouse(false)

-- Permanent secure button pool. These are created once at file load and never destroyed.
local MAX_ROWS = 40
local rows = {}
for i = 1, MAX_ROWS do
    local nameButton = CreateFrame("Button", "FWCSecureNameButton" .. i, popout, "SecureActionButtonTemplate")
    local statusButton = CreateFrame("Button", "FWCSecureStatusButton" .. i, popout, "SecureActionButtonTemplate")

    for _, button in ipairs({nameButton, statusButton}) do
        button:SetSize(100, 18)
        button:SetFrameLevel(popout:GetFrameLevel() + 50)
        button:EnableMouse(true)
        if button.SetMouseClickEnabled then button:SetMouseClickEnabled(true) end
        if button.SetMouseMotionEnabled then button:SetMouseMotionEnabled(true) end
        button:RegisterForClicks("AnyDown", "AnyUp")
        button:SetAttribute("type", "spell")
        button:SetAttribute("type1", "spell")
        button:SetAttribute("spell", SPELL_NAME)
        button:SetAttribute("spell1", SPELL_NAME)
        button:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2")
        button:Hide()
    end

    nameButton.text = nameButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameButton.text:SetAllPoints(); nameButton.text:SetJustifyH("LEFT")
    statusButton.text = statusButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusButton.text:SetAllPoints(); statusButton.text:SetJustifyH("RIGHT")

    rows[i] = {nameButton=nameButton, statusButton=statusButton, unit=nil, name=nil}
end

local labels = {}
local activeRowCount = 0
local popoutBuilt = false
local popoutDirty = true

local function HideLabels()
    for _, label in ipairs(labels) do label:Hide() end
    wipe(labels)
end

local function NewLabel(text, x, y, template)
    local fs = content:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", x, y)
    fs:SetText(text)
    labels[#labels + 1] = fs
    return fs
end

local function MyGroups()
    local groups = {}
    local mine = addon.state.assignments[addon:GetPlayerName()]
    for g=1,8 do if mine and mine[g] then groups[#groups+1]=g end end
    return groups
end

local function DeactivateRows(from)
    for i = from, MAX_ROWS do
        local row = rows[i]
        row.unit = nil; row.name = nil
        row.nameButton:Hide(); row.statusButton:Hide()
        if not InCombatLockdown() then
            row.nameButton:SetAttribute("unit", nil); row.nameButton:SetAttribute("unit1", nil)
            row.statusButton:SetAttribute("unit", nil); row.statusButton:SetAttribute("unit1", nil)
        end
    end
end

function addon:BuildPopout()
    if InCombatLockdown() then
        popoutDirty = true
        print("|cffffff00FWC: Roster changed in combat; popout will rebuild after combat.|r")
        return
    end

    HideLabels()
    activeRowCount = 0
    local groups = MyGroups()
    local y = -2

    NewLabel("Click name or status to cast", 0, y, "GameFontDisableSmall")
    y = y - 21

    if #groups == 0 then
        NewLabel("No groups assigned.", 0, y, "GameFontNormal")
        DeactivateRows(1)
        popout:SetHeight(100)
        popoutBuilt = true; popoutDirty = false
        return
    end

    for _, group in ipairs(groups) do
        NewLabel("Group " .. group, 0, y, "GameFontHighlight")
        y = y - 19
        local members = addon:GetGroupMembers(group)
        for _, member in ipairs(members) do
            activeRowCount = activeRowCount + 1
            if activeRowCount > MAX_ROWS then break end
            local row = rows[activeRowCount]
            row.unit = member.unit; row.name = member.name

            row.nameButton:ClearAllPoints(); row.nameButton:SetPoint("TOPLEFT", content, "TOPLEFT", 12, y)
            row.nameButton:SetWidth(math.max(90, popout:GetWidth() - 140))
            row.statusButton:ClearAllPoints(); row.statusButton:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, y)
            row.statusButton:SetWidth(92)

            row.nameButton.text:SetText(member.name)
            row.statusButton.text:SetText("...")

            -- Canonical secure spell action. Attributes are only changed out of combat.
            row.nameButton:SetAttribute("unit", member.unit)
            row.nameButton:SetAttribute("unit1", member.unit)
            row.statusButton:SetAttribute("unit", member.unit)
            row.statusButton:SetAttribute("unit1", member.unit)
            row.nameButton:Show(); row.statusButton:Show()
            y = y - 19
        end
    end

    DeactivateRows(activeRowCount + 1)
    popout:SetHeight(math.max(115, math.min(650, 55 + math.abs(y))))
    SavePosition(popout, "popout")
    popoutBuilt = true; popoutDirty = false
    self:RefreshStatusOnly()
end

function addon:RefreshStatusOnly()
    for i=1,activeRowCount do
        local row = rows[i]
        local unit = row.unit
        local status
        local alpha = .8
        if not unit or not UnitExists(unit) then
            status = "|cff888888Gone|r"
        elseif UnitIsDeadOrGhost(unit) then
            status = "|cff888888Dead|r"
        elseif not UnitIsConnected(unit) then
            status = "|cff888888Offline|r"
        else
            local has, remaining = self:GetFearWardInfo(unit)
            if has then
                local color = remaining > 0 and remaining < 300 and "|cffffff00" or "|cff00ff00"
                status = color .. "FW " .. self:FormatTime(remaining) .. "|r"
            else
                status = "|cffff0000Missing|r"
            end
            if self:IsFearWardInRange(unit) then alpha = 1 end
        end
        row.statusButton.text:SetText(status)
        row.nameButton:SetAlpha(alpha); row.statusButton:SetAlpha(alpha)
    end
end

local function TogglePopout()
    if popout:IsShown() then
        if InCombatLockdown() then print("|cffffff00FWC: Secure popout stays open during combat.|r") else popout:Hide() end
        return
    end
    if not popoutBuilt or popoutDirty then addon:BuildPopout() end
    popout:Show()
end

main:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then TogglePopout() end
end)

function addon:RefreshUI()
    local me = self:GetPlayerName()
    nameText:SetText(me or "Priest")
    local groups = MyGroups()
    groupText:SetText(#groups > 0 and ("Groups: " .. table.concat(groups, ", ")) or "No groups assigned")
    popoutDirty = true
    if not InCombatLockdown() then self:BuildPopout() end
end

function addon:ToggleUI()
    main:SetShown(not main:IsShown())
    if main:IsShown() then self:RefreshUI() end
end

function addon:PrintDiagnostics()
    print("|cff00ff00FWC diagnostics v" .. addon.version .. "|r")
    print("Spell: " .. tostring(SPELL_NAME) .. " (" .. tostring(SPELL_ID) .. ")")
    print("Combat: " .. tostring(InCombatLockdown()) .. ", popout shown: " .. tostring(popout:IsShown()) .. ", rows: " .. activeRowCount)
    if activeRowCount > 0 then
        local row = rows[1]
        print("First row: " .. tostring(row.name) .. " / " .. tostring(row.unit) .. ", exists=" .. tostring(UnitExists(row.unit)))
        print("type1=" .. tostring(row.nameButton:GetAttribute("type1")) .. ", spell1=" .. tostring(row.nameButton:GetAttribute("spell1")) .. ", unit1=" .. tostring(row.nameButton:GetAttribute("unit1")))
        print("mouse=" .. tostring(row.nameButton:IsMouseEnabled()) .. ", shown=" .. tostring(row.nameButton:IsShown()) .. ", protected=" .. tostring(row.nameButton:IsProtected()))
    end
end

local ticker = C_Timer.NewTicker(.5, function()
    if popout:IsShown() then addon:RefreshStatusOnly() end

    local targets = {}
    for _, group in ipairs(MyGroups()) do
        for _, member in ipairs(addon:GetGroupMembers(group)) do
            targets[addon:ShortName(member.name)] = {name=member.name, unit=member.unit, tank=false}
        end
    end
    if IsInRaid() then
        for i=1,40 do
            local unit = "raid" .. i
            local name, _, _, _, _, _, _, _, _, raidRole = GetRaidRosterInfo(i)
            if name and UnitExists(unit) then
                local tank = (GetPartyAssignment and GetPartyAssignment("MAINTANK", unit)) or raidRole == "MAINTANK" or (UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == "TANK")
                if tank then targets[addon:ShortName(name)] = {name=addon:ShortName(name), unit=unit, tank=true} end
            end
        end
    end

    local present = {}
    for key, target in pairs(targets) do
        present[key] = true
        if addon:CanSafelyCheckFearWard(target.unit) then
            local has = addon:GetFearWardInfo(target.unit)
            if has then alertState[key] = true
            else
                if alertState[key] == true then ShowAlert((target.tank and "TANK! " or "") .. "Fear Ward missing on " .. target.name) end
                alertState[key] = false
            end
        end
    end
    for key in pairs(alertState) do if not present[key] then alertState[key] = nil end end
end)

AddResizeCorners(popout, "popout", 210, 110, 520, 650, function()
    if not InCombatLockdown() then addon:BuildPopout() end
end)

addon.uiFrame = main
addon.popoutFrame = popout

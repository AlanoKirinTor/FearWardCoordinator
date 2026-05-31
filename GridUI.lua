local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests = addon.state.priests or {}
addon.state.assignments = addon.state.assignments or {}

local frame = CreateFrame("Frame", "FWCGridFrame", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(600, 400)
frame:SetPoint("CENTER")
frame:Hide()
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER")
frame.title:SetText("Fear Ward Assignment Grid")

addon.gridFrame = frame

local objects = {}

local function ClearGrid()
    for _, obj in ipairs(objects) do
        obj:Hide()
    end
    wipe(objects)
end

local function AddText(text, x, y)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    fs:SetText(text)
    table.insert(objects, fs)
    return fs
end

local function AddButton(priest, group, x, y)
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetSize(36, 24)
    btn:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)

    local assigned = addon:GetAssignment(priest, group)
    btn:SetText(assigned and "X" or "")

    if not addon:IsLeader() then
        btn:Disable()
        btn:SetAlpha(0.4)
    end

    btn:SetScript("OnClick", function()
        if not addon:IsLeader() then return end

        addon:SetAssignment(priest, group)

        addon:RefreshGridUI()

        if addon.RefreshUI then
            addon:RefreshUI()
        end
    end)

    table.insert(objects, btn)
    return btn
end

function addon:RefreshGridUI()
    if not frame:IsShown() then return end

    ClearGrid()

    if addon.ScanRaid then
        addon:ScanRaid()
    end

    AddText("Priest", 20, -40)

    for group = 1, 8 do
        AddText("G" .. group, 130 + ((group - 1) * 48), -40)
    end

    if not addon.state.priests or #addon.state.priests == 0 then
        AddText("No priests found. Join a raid with priests, then reopen /fwcgrid.", 20, -90)
        return
    end

    for row, priest in ipairs(addon.state.priests) do
        local y = -70 - ((row - 1) * 30)

        AddText(priest, 20, y)

        for group = 1, 8 do
            local x = 130 + ((group - 1) * 48)
            AddButton(priest, group, x, y + 4)
        end
    end

    if addon:IsLeader() then
        AddText("You have raid lead/assist. Click boxes to assign groups.", 20, -360)
    else
        AddText("View only. Raid leader or assist required to edit.", 20, -360)
    end
end

function addon:ToggleGridUI()
    frame:SetShown(not frame:IsShown())

    if frame:IsShown() then
        addon:RefreshGridUI()
    end
end
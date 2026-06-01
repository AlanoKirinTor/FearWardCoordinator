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
frame:SetResizable(true)
frame:SetResizeBounds(420, 260, 1000, 800)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER")
frame.title:SetText("Fear Ward Assignment Grid")

addon.gridFrame = frame

local objects = {}

local function AddResizeCorners(targetFrame)
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
            if IsShiftKeyDown() and IsMouseButtonDown("RightButton") then
                targetFrame:StartSizing(data.cursor)
            end
        end)

        grip:SetScript("OnMouseUp", function()
            targetFrame:StopMovingOrSizing()

            if addon.RefreshGridUI then
                addon:RefreshGridUI()
            end
        end)
    end
end

AddResizeCorners(frame)

local function ClearGrid()
    for _, obj in ipairs(objects) do
        obj:Hide()
    end
    wipe(objects)
end

local function AddText(text, x, y, template)
    local fs = frame:CreateFontString(nil, "OVERLAY", template or "GameFontNormal")
    fs:SetPoint("CENTER", frame, "TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetJustifyH("CENTER")
    table.insert(objects, fs)
    return fs
end

local function AddButton(priest, group, x, y)
    local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    btn:SetSize(36, 24)
    btn:SetPoint("CENTER", frame, "TOPLEFT", x, y)

    local assigned = addon:GetAssignment(priest, group)
    btn:SetText(assigned and "X" or "")

    local canEdit = addon:CanEditPriest(priest)

    if not canEdit then
        btn:Disable()

        if assigned then
            btn:SetAlpha(0.75)
        else
            btn:SetAlpha(0.25)
        end
    else
        btn:Enable()
        btn:SetAlpha(1)
    end

    btn:SetScript("OnClick", function()
        if not addon:CanEditPriest(priest) then
            print("|cffff0000FWC: You can only edit your own assignments unless you have raid lead or assist.|r")
            return
        end

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

    local width = frame:GetWidth()
    local height = frame:GetHeight()

    local leftPad = 95
    local rightPad = 30
    local topY = -45
    local rowStartY = -78
    local rowHeight = 30

    local usableWidth = width - leftPad - rightPad
    local colWidth = usableWidth / 8

    AddText("Priest", 48, topY, "GameFontNormal")

    for group = 1, 8 do
        local x = leftPad + ((group - 0.5) * colWidth)
        AddText("G" .. group, x, topY, "GameFontNormal")
    end

    if not addon.state.priests or #addon.state.priests == 0 then
        AddText("No priests found.", width / 2, -110, "GameFontNormal")
        return
    end

    for row, priest in ipairs(addon.state.priests) do
        local y = rowStartY - ((row - 1) * rowHeight)

        if math.abs(y) < height - 35 then
            local template

            if addon:CanEditPriest(priest) then
                template = "GameFontNormal"
            else
                template = "GameFontDisable"
            end

            AddText(priest, 48, y, template)

            for group = 1, 8 do
                local x = leftPad + ((group - 0.5) * colWidth)
                AddButton(priest, group, x, y)
            end
        end
    end

    if addon:IsLeader() then
        AddText("Lead/assist mode: you can edit everyone.", width / 2, -(height - 32), "GameFontNormal")
    else
        AddText("Normal mode: viewing everyone, editing yourself only.", width / 2, -(height - 32), "GameFontNormal")
    end
end

function addon:ToggleGridUI()
    frame:SetShown(not frame:IsShown())

    if frame:IsShown() then
        addon:RefreshGridUI()
    end
end

frame:SetScript("OnSizeChanged", function()
    if addon.RefreshGridUI then
        addon:RefreshGridUI()
    end
end)

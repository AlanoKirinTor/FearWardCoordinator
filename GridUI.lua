local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests =
    addon.state.priests or {}
addon.state.assignments =
    addon.state.assignments or {}

local function EnsureDB()
    FearWardCoordinatorDB =
        FearWardCoordinatorDB or {}

    FearWardCoordinatorDB.positions =
        FearWardCoordinatorDB.positions or {}

    return FearWardCoordinatorDB
end

local function SaveGridPosition(frame)
    local point,
        _,
        relativePoint,
        x,
        y = frame:GetPoint(1)

    local db = EnsureDB()

    db.positions.grid =
        db.positions.grid or {}

    db.positions.grid.point = point

    db.positions.grid.relativePoint =
        relativePoint

    db.positions.grid.x = x
    db.positions.grid.y = y

    db.positions.grid.width =
        frame:GetWidth()

    db.positions.grid.height =
        frame:GetHeight()

    db.positions.grid.scale =
        frame:GetScale()
end

local function RestoreGridPosition(frame)
    local db = EnsureDB()
    local saved = db.positions.grid

    frame:ClearAllPoints()

    if saved then
        frame:SetPoint(
            saved.point or "CENTER",
            UIParent,
            saved.relativePoint or "CENTER",
            saved.x or 0,
            saved.y or 0
        )

        if saved.width and saved.height then
            frame:SetSize(
                saved.width,
                saved.height
            )
        end

        if saved.scale then
            frame:SetScale(saved.scale)
        end
    else
        frame:SetPoint(
            "CENTER",
            UIParent,
            "CENTER",
            0,
            0
        )
    end

    frame:SetUserPlaced(true)
end

local frame = CreateFrame(
    "Frame",
    "FWCGridFrame",
    UIParent,
    "BasicFrameTemplateWithInset"
)

frame:SetSize(600, 400)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:SetResizable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:Hide()

if frame.SetResizeBounds then
    frame:SetResizeBounds(
        420,
        260,
        1000,
        800
    )
else
    frame:SetMinResize(
        420,
        260
    )

    frame:SetMaxResize(
        1000,
        800
    )
end

RestoreGridPosition(frame)

frame:SetScript(
    "OnDragStart",
    function(self)
        if not InCombatLockdown() then
            self:StartMoving()
        end
    end
)

frame:SetScript(
    "OnDragStop",
    function(self)
        self:StopMovingOrSizing()
        SaveGridPosition(self)
    end
)

frame.title =
    frame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )

frame.title:SetPoint(
    "CENTER",
    frame.TitleBg,
    "CENTER"
)

frame.title:SetText(
    "Fear Ward Assignment Grid"
)

addon.gridFrame = frame

local objects = {}

local function AddResizeCorners(
    targetFrame
)
    local corners = {
        {
            point = "TOPLEFT",
            cursor = "TOPLEFT",
        },
        {
            point = "TOPRIGHT",
            cursor = "TOPRIGHT",
        },
        {
            point = "BOTTOMLEFT",
            cursor = "BOTTOMLEFT",
        },
        {
            point = "BOTTOMRIGHT",
            cursor = "BOTTOMRIGHT",
        },
    }

    for _, data in ipairs(corners) do
        local grip = CreateFrame(
            "Button",
            nil,
            targetFrame
        )

        grip:SetSize(18, 18)

        grip:SetPoint(
            data.point,
            targetFrame,
            data.point,
            0,
            0
        )

        grip:RegisterForClicks(
            "RightButtonDown",
            "RightButtonUp"
        )

        grip:SetScript(
            "OnMouseDown",
            function()
                if InCombatLockdown() then
                    return
                end

                if IsShiftKeyDown()
                    and IsMouseButtonDown(
                        "RightButton"
                    )
                then
                    targetFrame:StartSizing(
                        data.cursor
                    )
                end
            end
        )

        grip:SetScript(
            "OnMouseUp",
            function()
                targetFrame:
                    StopMovingOrSizing()

                SaveGridPosition(
                    targetFrame
                )

                if addon.RefreshGridUI then
                    addon:RefreshGridUI()
                end
            end
        )
    end
end

AddResizeCorners(frame)

local function ClearGrid()
    for _, object in ipairs(objects) do
        object:Hide()
        object:SetParent(nil)
    end

    wipe(objects)
end

local function AddText(
    text,
    x,
    y,
    template
)
    local fontString =
        frame:CreateFontString(
            nil,
            "OVERLAY",
            template or "GameFontNormal"
        )

    fontString:SetPoint(
        "CENTER",
        frame,
        "TOPLEFT",
        x,
        y
    )

    fontString:SetText(text)
    fontString:SetJustifyH("CENTER")

    table.insert(
        objects,
        fontString
    )

    return fontString
end

local function AddButton(
    priest,
    group,
    x,
    y
)
    local button = CreateFrame(
        "Button",
        nil,
        frame,
        "UIPanelButtonTemplate"
    )

    button:SetSize(36, 24)

    button:SetPoint(
        "CENTER",
        frame,
        "TOPLEFT",
        x,
        y
    )

    local assigned =
        addon:GetAssignment(
            priest,
            group
        )

    button:SetText(
        assigned and "X" or ""
    )

    local canEdit =
        addon:CanEditPriest(priest)

    if not canEdit
        or InCombatLockdown()
    then
        button:Disable()

        button:SetAlpha(
            assigned and 0.75 or 0.25
        )
    else
        button:Enable()
        button:SetAlpha(1)
    end

    button:SetScript(
        "OnClick",
        function()
            if InCombatLockdown() then
                print(
                    "|cffff0000FWC: "
                        .. "Assignments cannot "
                        .. "be changed during "
                        .. "combat.|r"
                )

                return
            end

            if not addon:CanEditPriest(
                priest
            ) then
                print(
                    "|cffff0000FWC: You can "
                        .. "only edit your own "
                        .. "assignments unless "
                        .. "you have raid lead "
                        .. "or assist.|r"
                )

                return
            end

            addon:SetAssignment(
                priest,
                group
            )

            addon:RefreshGridUI()

            if addon.RefreshUI then
                addon:RefreshUI()
            end
        end
    )

    table.insert(objects, button)

    return button
end

function addon:RefreshGridUI()
    if not frame:IsShown() then
        return
    end

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

    local usableWidth =
        width - leftPad - rightPad

    local colWidth =
        usableWidth / 8

    AddText(
        "Priest",
        48,
        topY,
        "GameFontNormal"
    )

    for group = 1, 8 do
        local x =
            leftPad
            + ((group - 0.5) * colWidth)

        AddText(
            "G" .. group,
            x,
            topY,
            "GameFontNormal"
        )
    end

    if not addon.state.priests
        or #addon.state.priests == 0
    then
        AddText(
            "No priests found.",
            width / 2,
            -110,
            "GameFontNormal"
        )

        return
    end

    for row, priest in ipairs(
        addon.state.priests
    ) do
        local y =
            rowStartY
            - ((row - 1) * rowHeight)

        if math.abs(y) < height - 35 then
            local template =
                addon:CanEditPriest(priest)
                and "GameFontNormal"
                or "GameFontDisable"

            AddText(
                priest,
                48,
                y,
                template
            )

            for group = 1, 8 do
                local x =
                    leftPad
                    + (
                        (group - 0.5)
                        * colWidth
                    )

                AddButton(
                    priest,
                    group,
                    x,
                    y
                )
            end
        end
    end

    if InCombatLockdown() then
        AddText(
            "Combat: assignments are locked.",
            width / 2,
            -(height - 32),
            "GameFontDisable"
        )

    elseif addon:IsLeader() then
        AddText(
            "Lead/assist mode: "
                .. "you can edit everyone.",
            width / 2,
            -(height - 32),
            "GameFontNormal"
        )
    else
        AddText(
            "Normal mode: viewing everyone, "
                .. "editing yourself only.",
            width / 2,
            -(height - 32),
            "GameFontNormal"
        )
    end
end

function addon:ToggleGridUI()
    frame:SetShown(
        not frame:IsShown()
    )

    if frame:IsShown() then
        addon:RefreshGridUI()
    end
end

frame:SetScript(
    "OnSizeChanged",
    function()
        SaveGridPosition(frame)

        if addon.RefreshGridUI then
            addon:RefreshGridUI()
        end
    end
)

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent(
    "PLAYER_LOGIN"
)

eventFrame:RegisterEvent(
    "PLAYER_REGEN_DISABLED"
)

eventFrame:RegisterEvent(
    "PLAYER_REGEN_ENABLED"
)

eventFrame:RegisterEvent(
    "GROUP_ROSTER_UPDATE"
)

eventFrame:SetScript(
    "OnEvent",
    function(_, event)
        if event == "PLAYER_LOGIN" then
            RestoreGridPosition(frame)
        end

        if frame:IsShown()
            and addon.RefreshGridUI
        then
            addon:RefreshGridUI()
        end
    end
)

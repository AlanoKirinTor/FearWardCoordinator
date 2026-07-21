local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests =
    addon.state.priests or {}
addon.state.assignments =
    addon.state.assignments or {}

local FEAR_WARD_SPELL_ID =
    addon.GetFearWardSpellID
    and addon:GetFearWardSpellID()
    or 6346

local FEAR_WARD_SPELL_NAME =
    addon.GetFearWardSpellName
    and addon:GetFearWardSpellName()
    or "Fear Ward"

local function EnsureDB()
    FearWardCoordinatorDB =
        FearWardCoordinatorDB or {}

    FearWardCoordinatorDB.positions =
        FearWardCoordinatorDB.positions or {}

    return FearWardCoordinatorDB
end

local function SaveFramePosition(frame, key)
    if not frame or not key then
        return
    end

    local point,
        _,
        relativePoint,
        x,
        y = frame:GetPoint(1)

    local db = EnsureDB()

    db.positions[key] =
        db.positions[key] or {}

    db.positions[key].point = point
    db.positions[key].relativePoint =
        relativePoint
    db.positions[key].x = x
    db.positions[key].y = y
    db.positions[key].width =
        frame:GetWidth()
    db.positions[key].height =
        frame:GetHeight()
    db.positions[key].scale =
        frame:GetScale()
end

local function RestoreFramePosition(
    frame,
    key,
    defaultPoint,
    defaultRelativePoint,
    defaultX,
    defaultY
)
    local db = EnsureDB()
    local saved = db.positions[key]

    frame:ClearAllPoints()

    if saved then
        frame:SetPoint(
            saved.point or defaultPoint,
            UIParent,
            saved.relativePoint
                or defaultRelativePoint,
            saved.x or defaultX,
            saved.y or defaultY
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
            defaultPoint,
            UIParent,
            defaultRelativePoint,
            defaultX,
            defaultY
        )
    end

    frame:SetUserPlaced(true)
end

local function MakeMovable(frame, key)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

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
            SaveFramePosition(self, key)
        end
    )
end

local function AddResizeCorners(
    targetFrame,
    key,
    minW,
    minH,
    maxW,
    maxH,
    onResizeDone
)
    targetFrame:SetResizable(true)

    if targetFrame.SetResizeBounds then
        targetFrame:SetResizeBounds(
            minW,
            minH,
            maxW,
            maxH
        )
    else
        targetFrame:SetMinResize(
            minW,
            minH
        )

        targetFrame:SetMaxResize(
            maxW,
            maxH
        )
    end

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

                SaveFramePosition(
                    targetFrame,
                    key
                )

                if onResizeDone then
                    onResizeDone()
                end
            end
        )
    end
end

local alertEnabled = true
local alertTestMode = false
local alertWatchState = {}
local alertHideGeneration = 0

local alertFrame = CreateFrame(
    "Frame",
    "FWCAlertFrame",
    UIParent
)

alertFrame:SetSize(600, 80)
alertFrame:SetFrameStrata("HIGH")
alertFrame:SetClampedToScreen(true)
alertFrame:Hide()

RestoreFramePosition(
    alertFrame,
    "alert",
    "TOP",
    "TOP",
    0,
    -180
)

MakeMovable(alertFrame, "alert")

alertFrame.text =
    alertFrame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalHuge"
    )

alertFrame.text:SetPoint("CENTER")

alertFrame.text:SetTextColor(
    1,
    0.15,
    0.15,
    1
)

local function UpdateAlertFont()
    local height = alertFrame:GetHeight()

    local size = math.max(
        18,
        math.min(
            44,
            math.floor(height * 0.45)
        )
    )

    alertFrame.text:SetFont(
        STANDARD_TEXT_FONT,
        size,
        "OUTLINE"
    )
end

AddResizeCorners(
    alertFrame,
    "alert",
    260,
    50,
    1200,
    220,
    UpdateAlertFont
)

UpdateAlertFont()

local function ShowFWCAlert(message)
    if not alertEnabled then
        return
    end

    alertTestMode = false

    alertHideGeneration =
        alertHideGeneration + 1

    local myGeneration =
        alertHideGeneration

    alertFrame.text:SetText(message)
    alertFrame:Show()

    C_Timer.After(
        3,
        function()
            if myGeneration
                    == alertHideGeneration
                and not alertTestMode
            then
                alertFrame:Hide()
            end
        end
    )
end

SLASH_FWCALERT1 = "/fwcalert"

SlashCmdList["FWCALERT"] = function()
    if alertFrame:IsShown()
        and alertTestMode
    then
        alertTestMode = false
        alertFrame:Hide()

        print(
            "|cffffff00FWC Alert test hidden.|r"
        )

        return
    end

    alertEnabled = true
    alertTestMode = true

    alertHideGeneration =
        alertHideGeneration + 1

    alertFrame.text:SetText(
        "TANK! Fear Ward missing on Testtank"
    )

    alertFrame:Show()

    local db = EnsureDB()
    db.alertEnabled = true

    print(
        "|cff00ff00FWC Alert test shown.|r "
            .. "Left-drag to move."
    )

    print(
        "|cff00ff00Shift + right-drag "
            .. "a corner to resize.|r"
    )

    print(
        "|cff00ff00Run /fwcalert again "
            .. "to hide.|r"
    )
end

SLASH_FWCALERTOFF1 =
    "/fwcalertoff"

SlashCmdList["FWCALERTOFF"] = function()
    alertEnabled = false
    alertTestMode = false

    alertHideGeneration =
        alertHideGeneration + 1

    alertFrame:Hide()

    local db = EnsureDB()
    db.alertEnabled = false

    print(
        "|cffffff00FWC alerts disabled.|r"
    )
end

SLASH_FWCALERTON1 =
    "/fwcalerton"

SlashCmdList["FWCALERTON"] = function()
    alertEnabled = true

    local db = EnsureDB()
    db.alertEnabled = true

    print(
        "|cff00ff00FWC alerts enabled.|r"
    )
end

local frame = CreateFrame(
    "Button",
    "FWCFrame",
    UIParent,
    "BackdropTemplate"
)

frame:SetSize(145, 45)
frame:SetClampedToScreen(true)
frame:Hide()

RestoreFramePosition(
    frame,
    "main",
    "CENTER",
    "CENTER",
    0,
    0
)

MakeMovable(frame, "main")

AddResizeCorners(
    frame,
    "main",
    120,
    40,
    400,
    120
)

frame:SetBackdrop({
    bgFile =
        "Interface\\Buttons\\WHITE8x8",

    edgeFile =
        "Interface\\Tooltips\\"
        .. "UI-Tooltip-Border",

    edgeSize = 10,

    insets = {
        left = 2,
        right = 2,
        top = 2,
        bottom = 2,
    },
})

frame:SetBackdropColor(
    0,
    0.35,
    0,
    0.9
)

addon.uiFrame = frame

local icon =
    frame:CreateTexture(
        nil,
        "ARTWORK"
    )

icon:SetSize(24, 24)

icon:SetPoint(
    "LEFT",
    frame,
    "LEFT",
    6,
    0
)

icon:SetTexture(135955)

local nameText =
    frame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontNormalSmall"
    )

nameText:SetPoint(
    "TOPLEFT",
    frame,
    "TOPLEFT",
    36,
    -7
)

local groupText =
    frame:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )

groupText:SetPoint(
    "LEFT",
    frame,
    "LEFT",
    36,
    -9
)

local popout = CreateFrame(
    "Frame",
    "FWCPopoutFrame",
    UIParent,
    "BasicFrameTemplateWithInset"
)

popout:SetSize(230, 180)
popout:SetClampedToScreen(true)
popout:SetAlpha(1)
popout:Hide()

RestoreFramePosition(
    popout,
    "popout",
    "CENTER",
    "CENTER",
    0,
    -130
)

MakeMovable(popout, "popout")

AddResizeCorners(
    popout,
    "popout",
    190,
    120,
    520,
    650
)

popout.title =
    popout:CreateFontString(
        nil,
        "OVERLAY",
        "GameFontHighlight"
    )

popout.title:SetPoint(
    "CENTER",
    popout.TitleBg,
    "CENTER"
)

popout.title:SetText(
    "My Fear Ward Groups"
)

local popoutObjects = {}
local playerRows = {}

local function NormalizeName(name)
    if not name then
        return nil
    end

    return Ambiguate(name, "short")
end

local function GetMyGroups()
    local player =
        NormalizeName(UnitName("player"))

    local groups = {}

    if addon.state.assignments then
        for priest, assignedGroups in pairs(
            addon.state.assignments
        ) do
            if NormalizeName(priest) == player then
                for group = 1, 8 do
                    if assignedGroups[group] then
                        table.insert(
                            groups,
                            group
                        )
                    end
                end
            end
        end
    end

    table.sort(groups)

    return groups
end

local function IsUnitInFearWardRange(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    if UnitIsDeadOrGhost(unit)
        or not UnitIsConnected(unit)
    then
        return false
    end

    if addon.IsFearWardInRange then
        return addon:IsFearWardInRange(unit)
    end

    return false
end

local function ClearPopout()
    if InCombatLockdown() then
        return
    end

    for _, object in ipairs(
        popoutObjects
    ) do
        object:Hide()
        object:SetParent(nil)
    end

    wipe(popoutObjects)
    wipe(playerRows)
end

local function AddText(
    text,
    x,
    y,
    template
)
    local fontString =
        popout:CreateFontString(
            nil,
            "OVERLAY",
            template or "GameFontNormal"
        )

    fontString:SetPoint(
        "TOPLEFT",
        popout,
        "TOPLEFT",
        x,
        y
    )

    fontString:SetText(text)

    table.insert(
        popoutObjects,
        fontString
    )

    return fontString
end

local function AddAlertWatchTarget(
    targets,
    name,
    unit,
    isTank
)
    if not name or not unit then
        return
    end

    local key = NormalizeName(name)

    if not key then
        return
    end

    if not targets[key] then
        targets[key] = {
            name = name,
            unit = unit,
            isTank = isTank or false,
        }
    elseif isTank then
        targets[key].isTank = true
    end
end

local function AddAssignedGroupAlertTargets(
    targets
)
    for _, groupNumber in ipairs(
        GetMyGroups()
    ) do
        local members =
            addon:GetGroupMembers(
                groupNumber
            )

        for _, member in ipairs(members) do
            AddAlertWatchTarget(
                targets,
                member.name,
                member.unit,
                false
            )
        end
    end
end

local function AddMainTankAlertTargets(
    targets
)
    if not IsInRaid() then
        return
    end

    for i = 1, 40 do
        local unit = "raid" .. i

        local name,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            _,
            raidRole =
            GetRaidRosterInfo(i)

        if name and UnitExists(unit) then
            local isMainTank =
                GetPartyAssignment
                and GetPartyAssignment(
                    "MAINTANK",
                    unit
                )

            local assignedRole =
                UnitGroupRolesAssigned
                and UnitGroupRolesAssigned(
                    unit
                )
                or "NONE"

            if isMainTank
                or raidRole == "MAINTANK"
                or assignedRole == "TANK"
            then
                AddAlertWatchTarget(
                    targets,
                    name,
                    unit,
                    true
                )
            end
        end
    end
end

local function RefreshFearWardAlerts()
    if not IsInGroup() then
        wipe(alertWatchState)
        return
    end

    local targets = {}
    local currentlyTracked = {}

    AddAssignedGroupAlertTargets(targets)
    AddMainTankAlertTargets(targets)

    for key, target in pairs(targets) do
        currentlyTracked[key] = true

        if addon.CanSafelyCheckFearWard
            and addon:CanSafelyCheckFearWard(
                target.unit
            )
        then
            local hasBuff =
                addon:GetFearWardInfo(
                    target.unit
                )

            if hasBuff then
                alertWatchState[key] = true
            else
                if alertWatchState[key] == true then
                    if target.isTank then
                        ShowFWCAlert(
                            "TANK! Fear Ward missing on "
                                .. target.name
                        )
                    else
                        ShowFWCAlert(
                            "Fear Ward missing on "
                                .. target.name
                        )
                    end
                end

                alertWatchState[key] = false
            end
        end
    end

    for key in pairs(alertWatchState) do
        if not currentlyTracked[key] then
            alertWatchState[key] = nil
        end
    end
end

local function CreateFearWardButton(
    member,
    x,
    y,
    width,
    labelText
)
    local button = CreateFrame(
        "Button",
        nil,
        popout,
        "SecureActionButtonTemplate"
    )

    button:SetSize(width, 16)

    button:SetPoint(
        "TOPLEFT",
        popout,
        "TOPLEFT",
        x,
        y
    )

    button:SetAttribute("type", "spell")

    button:SetAttribute(
        "spell",
        FEAR_WARD_SPELL_NAME
            or FEAR_WARD_SPELL_ID
    )

    button:SetAttribute(
        "unit",
        member.unit
    )

    local highlight =
        button:CreateTexture(
            nil,
            "HIGHLIGHT"
        )

    highlight:SetTexture(
        "Interface\\Buttons\\WHITE8x8"
    )

    highlight:SetAllPoints(button)

    highlight:SetVertexColor(
        1,
        1,
        1,
        0.18
    )

    button:SetHighlightTexture(
        highlight
    )

    local text =
        button:CreateFontString(
            nil,
            "OVERLAY",
            "GameFontNormalSmall"
        )

    text:SetPoint(
        "LEFT",
        button,
        "LEFT",
        0,
        0
    )

    text:SetPoint(
        "RIGHT",
        button,
        "RIGHT",
        0,
        0
    )

    text:SetJustifyH("LEFT")
    text:SetText(labelText)

    button.text = text

    button:SetScript(
        "PreClick",
        function()
            if not IsUnitInFearWardRange(
                member.unit
            ) then
                print(
                    "|cffff0000FWC: "
                        .. member.name
                        .. " is out of range "
                        .. "for Fear Ward.|r"
                )
            end
        end
    )

    table.insert(
        popoutObjects,
        button
    )

    return button
end

local function AddPlayerRow(
    member,
    x,
    y
)
    local nameButton =
        CreateFearWardButton(
            member,
            x,
            y,
            86,
            member.name
        )

    local statusButton =
        CreateFearWardButton(
            member,
            x + 112,
            y,
            72,
            "..."
        )

    table.insert(
        playerRows,
        {
            name = member.name,
            unit = member.unit,
            nameButton = nameButton,
            statusButton = statusButton,
            statusText = statusButton.text,
        }
    )
end

function addon:RefreshPopoutStatusOnly()
    for _, row in ipairs(playerRows) do
        local unit = row.unit
        local statusText

        local inRange =
            IsUnitInFearWardRange(unit)

        if not UnitExists(unit) then
            statusText =
                "|cff888888Gone|r"

        elseif UnitIsDeadOrGhost(unit) then
            statusText =
                "|cff888888Dead|r"

        elseif not UnitIsConnected(unit) then
            statusText =
                "|cff888888Offline|r"

        else
            local hasBuff, remaining =
                addon:GetFearWardInfo(unit)

            if hasBuff then
                if remaining > 0
                    and remaining < 300
                then
                    statusText =
                        "|cffffff00FW "
                        .. addon:FormatTime(
                            remaining
                        )
                        .. "|r"
                else
                    statusText =
                        "|cff00ff00FW "
                        .. addon:FormatTime(
                            remaining
                        )
                        .. "|r"
                end
            else
                statusText =
                    "|cffff0000Missing|r"
            end
        end

        row.statusText:SetText(statusText)

        local alpha =
            inRange and 1 or 0.8

        row.statusButton:SetAlpha(alpha)
        row.nameButton:SetAlpha(alpha)

        row.nameButton:Enable()
        row.statusButton:Enable()
    end
end

function addon:BuildPopout()
    if InCombatLockdown() then
        print(
            "|cffff0000FWC: Cannot rebuild "
                .. "secure buttons during combat. "
                .. "Open before pull.|r"
        )

        return
    end

    ClearPopout()

    local groups = GetMyGroups()

    popout.title:SetText(
        "My Fear Ward Groups"
    )

    if #groups == 0 then
        AddText(
            "No groups assigned.",
            10,
            -32
        )

        popout:SetSize(230, 95)

        SaveFramePosition(
            popout,
            "popout"
        )

        return
    end

    AddText(
        "Click name or status to cast",
        10,
        -30,
        "GameFontDisableSmall"
    )

    local line = 0

    for _, groupNumber in ipairs(groups) do
        AddText(
            "Group " .. groupNumber,
            10,
            -48 - (line * 19),
            "GameFontHighlight"
        )

        line = line + 1

        local members =
            addon:GetGroupMembers(
                groupNumber
            )

        if #members == 0 then
            AddText(
                "No members",
                24,
                -48 - (line * 19),
                "GameFontDisableSmall"
            )

            line = line + 1
        else
            for _, member in ipairs(
                members
            ) do
                local y =
                    -48 - (line * 19)

                AddPlayerRow(
                    member,
                    24,
                    y
                )

                line = line + 1
            end
        end
    end

    local neededHeight = math.max(
        120,
        math.min(
            70 + (line * 19),
            650
        )
    )

    popout:SetHeight(neededHeight)

    SaveFramePosition(
        popout,
        "popout"
    )

    addon:RefreshPopoutStatusOnly()
end

local function TogglePopout()
    if popout:IsShown() then
        if InCombatLockdown() then
            print(
                "|cffffff00FWC: Cannot close "
                    .. "secure popout during "
                    .. "combat.|r"
            )

            return
        end

        popout:Hide()
        return
    end

    if InCombatLockdown()
        and #playerRows == 0
    then
        print(
            "|cffff0000FWC: Open the "
                .. "popout before combat "
                .. "to enable click-casting.|r"
        )

        return
    end

    popout:Show()

    if not InCombatLockdown() then
        addon:BuildPopout()
    else
        addon:RefreshPopoutStatusOnly()
    end
end

frame:SetScript(
    "OnClick",
    TogglePopout
)

function addon:RefreshUI()
    if not frame:IsShown() then
        return
    end

    if addon.ScanRaid then
        addon:ScanRaid()
    end

    local player =
        NormalizeName(UnitName("player"))

    local groups = GetMyGroups()

    nameText:SetText(player or "Me")

    if #groups == 0 then
        groupText:SetText("Groups: -")

        frame:SetBackdropColor(
            0.45,
            0,
            0,
            0.9
        )
    else
        groupText:SetText(
            "Groups: "
                .. table.concat(groups, ",")
        )

        frame:SetBackdropColor(
            0,
            0.35,
            0,
            0.9
        )
    end

    if popout:IsShown() then
        addon:RefreshPopoutStatusOnly()
    end
end

function addon:ToggleUI()
    if frame:IsShown() then
        if InCombatLockdown() then
            print(
                "|cffffff00FWC: Cannot safely "
                    .. "close secure frames "
                    .. "during combat.|r"
            )

            return
        end

        frame:Hide()
        popout:Hide()
    else
        frame:Show()
        addon:RefreshUI()
    end
end

local loadFrame = CreateFrame("Frame")

loadFrame:RegisterEvent("PLAYER_LOGIN")

loadFrame:SetScript(
    "OnEvent",
    function()
        local db = EnsureDB()

        if db.alertEnabled == nil then
            db.alertEnabled = true
        end

        alertEnabled =
            db.alertEnabled

        RestoreFramePosition(
            alertFrame,
            "alert",
            "TOP",
            "TOP",
            0,
            -180
        )

        RestoreFramePosition(
            frame,
            "main",
            "CENTER",
            "CENTER",
            0,
            0
        )

        RestoreFramePosition(
            popout,
            "popout",
            "CENTER",
            "CENTER",
            0,
            -130
        )

        UpdateAlertFont()
    end
)

local updater = CreateFrame("Frame")
local elapsed = 0

updater:SetScript(
    "OnUpdate",
    function(_, delta)
        elapsed = elapsed + delta

        if elapsed < 1 then
            return
        end

        elapsed = 0

        RefreshFearWardAlerts()

        if frame:IsShown() then
            addon:RefreshUI()
        end

        if popout:IsShown() then
            addon:RefreshPopoutStatusOnly()
        end
    end
)

local eventFrame = CreateFrame("Frame")

eventFrame:RegisterEvent(
    "PLAYER_REGEN_ENABLED"
)

eventFrame:RegisterEvent(
    "GROUP_ROSTER_UPDATE"
)

eventFrame:RegisterEvent(
    "PLAYER_ROLES_ASSIGNED"
)

eventFrame:RegisterEvent(
    "PLAYER_ENTERING_WORLD"
)

eventFrame:SetScript(
    "OnEvent",
    function(_, event)
        if event == "PLAYER_REGEN_ENABLED" then
            if popout:IsShown() then
                addon:BuildPopout()
            end

            return
        end

        if not InCombatLockdown()
            and popout:IsShown()
        then
            addon:BuildPopout()
        end

        wipe(alertWatchState)
    end
)

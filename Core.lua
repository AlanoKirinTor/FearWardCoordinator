local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests = addon.state.priests or {}
addon.state.assignments = addon.state.assignments or {}

local frame = CreateFrame("Frame")

local wasGrouped = false
local lastGroupType = "solo"

local function GetGroupType()
    if IsInRaid() then
        return "raid"
    elseif IsInGroup() then
        return "party"
    end

    return "solo"
end

local function RefreshAll()
    if addon.ScanRaid then
        addon:ScanRaid()
    end

    if addon.RefreshUI then
        addon:RefreshUI()
    end

    if addon.RefreshGridUI then
        addon:RefreshGridUI()
    end
end

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        FearWardCoordinatorDB = FearWardCoordinatorDB or {}
        FearWardCoordinatorDB.assignments = FearWardCoordinatorDB.assignments or {}

        addon.state.assignments = FearWardCoordinatorDB.assignments

        wasGrouped = IsInGroup()
        lastGroupType = GetGroupType()

        print("|cff00ff00FearWardCoordinator loaded.|r Type |cffffff00/fwc|r or |cffffff00/fwcgrid|r")

        RefreshAll()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        local isGrouped = IsInGroup()
        local groupType = GetGroupType()

        if not wasGrouped and isGrouped then
            if addon.ClearAssignments then
                addon:ClearAssignments()
                print("|cffffff00FWC: New group detected. Previous assignments cleared.|r")
            end
        elseif wasGrouped and not isGrouped then
            if addon.ClearAssignments then
                addon:ClearAssignments()
            end
        elseif wasGrouped and isGrouped and lastGroupType ~= groupType then
            if addon.ClearAssignments then
                addon:ClearAssignments()
                print("|cffffff00FWC: Group type changed. Previous assignments cleared.|r")
            end
        end

        wasGrouped = isGrouped
        lastGroupType = groupType

        RefreshAll()
    end
end)

SLASH_FWC1 = "/fwc"
SLASH_FWC2 = "/fearward"

SlashCmdList["FWC"] = function()
    if addon.ToggleUI then
        addon:ToggleUI()
    else
        print("FWC: UI.lua is not loaded.")
    end
end

SLASH_FWCGRID1 = "/fwcgrid"

SlashCmdList["FWCGRID"] = function()
    if addon.ToggleGridUI then
        addon:ToggleGridUI()
    else
        print("FWC: GridUI.lua is not loaded.")
    end
end

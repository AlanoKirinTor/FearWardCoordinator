local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests = addon.state.priests or {}
addon.state.assignments = addon.state.assignments or {}

local frame = CreateFrame("Frame")

local wasGrouped = false

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

local function ClearAllData()
    addon.state.assignments = {}
    addon.state.priests = {}

    FearWardCoordinatorDB = FearWardCoordinatorDB or {}
    FearWardCoordinatorDB.assignments = addon.state.assignments

    if addon.RefreshUI then
        addon:RefreshUI()
    end

    if addon.RefreshGridUI then
        addon:RefreshGridUI()
    end

    print("|cffffff00FWC: Group left. Assignments cleared.|r")
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

        print("|cff00ff00FearWardCoordinator loaded.|r Type |cffffff00/fwc|r or |cffffff00/fwcgrid|r")

        RefreshAll()
        return
    end

    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        local isGrouped = IsInGroup()

        if wasGrouped and not isGrouped then
            ClearAllData()
        else
            RefreshAll()
        end

        wasGrouped = isGrouped
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

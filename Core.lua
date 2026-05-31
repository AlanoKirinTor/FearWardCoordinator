local addonName, addon = ...

addon.state = addon.state or {}
addon.state.priests = addon.state.priests or {}
addon.state.assignments = addon.state.assignments or {}

local frame = CreateFrame("Frame")

frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("RAID_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        FearWardCoordinatorDB = FearWardCoordinatorDB or {}

        addon.state.assignments = FearWardCoordinatorDB.assignments or {}
        FearWardCoordinatorDB.assignments = addon.state.assignments

        print("|cff00ff00FearWardCoordinator loaded.|r Type |cffffff00/fwc|r or |cffffff00/fwcgrid|r")

        if addon.ScanRaid then
            addon:ScanRaid()
        end

    elseif event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" then
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
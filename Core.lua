local addonName, addon = ...

addon.name = addonName
addon.version = "2.0.0"
addon.state = addon.state or {}
addon.state.priests = addon.state.priests or {}
addon.state.assignments = addon.state.assignments or {}

local eventFrame = CreateFrame("Frame")
local wasGrouped = false
local pendingRefresh = false

local function DB()
    FearWardCoordinatorDB = FearWardCoordinatorDB or {}
    FearWardCoordinatorDB.assignments = FearWardCoordinatorDB.assignments or {}
    FearWardCoordinatorDB.positions = FearWardCoordinatorDB.positions or {}
    if FearWardCoordinatorDB.alertEnabled == nil then
        FearWardCoordinatorDB.alertEnabled = true
    end
    return FearWardCoordinatorDB
end

addon.GetDB = DB

function addon:ShortName(name)
    if not name then return nil end
    return Ambiguate(name, "short")
end

function addon:GetPlayerName()
    return self:ShortName(UnitName("player"))
end

function addon:RefreshAll()
    if InCombatLockdown() then
        pendingRefresh = true
        if self.RefreshStatusOnly then
            self:RefreshStatusOnly()
        end
        return
    end

    pendingRefresh = false
    if self.ScanGroup then self:ScanGroup() end
    if self.RefreshUI then self:RefreshUI() end
    if self.RefreshGridUI then self:RefreshGridUI() end
end

function addon:ClearGroupData()
    wipe(self.state.assignments)
    wipe(self.state.priests)
    DB().assignments = self.state.assignments
    if self.RefreshUI then self:RefreshUI() end
    if self.RefreshGridUI then self:RefreshGridUI() end
    print("|cffffff00FWC: Group left. Assignments cleared.|r")
end

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= addonName then return end
        addon.state.assignments = DB().assignments
        return
    end

    if event == "PLAYER_LOGIN" then
        addon.state.assignments = DB().assignments
        wasGrouped = IsInGroup()
        addon:RefreshAll()
        print("|cff00ff00FearWardCoordinator " .. addon.version .. " loaded.|r Type |cffffff00/fwc|r or |cffffff00/fwcgrid|r")
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        if pendingRefresh then addon:RefreshAll() end
        return
    end

    if event == "PLAYER_REGEN_DISABLED" then
        if addon.RefreshStatusOnly then addon:RefreshStatusOnly() end
        return
    end

    local grouped = IsInGroup()
    if wasGrouped and not grouped then
        addon:ClearGroupData()
    else
        addon:RefreshAll()
    end
    wasGrouped = grouped
end)

SLASH_FWC1 = "/fwc"
SLASH_FWC2 = "/fearward"
SlashCmdList.FWC = function()
    if addon.ToggleUI then addon:ToggleUI() else print("FWC: UI.lua is not loaded.") end
end

SLASH_FWCGRID1 = "/fwcgrid"
SlashCmdList.FWCGRID = function()
    if addon.ToggleGridUI then addon:ToggleGridUI() else print("FWC: GridUI.lua is not loaded.") end
end

SLASH_FWCDIAG1 = "/fwcdiag"
SlashCmdList.FWCDIAG = function()
    if addon.PrintDiagnostics then addon:PrintDiagnostics() end
end

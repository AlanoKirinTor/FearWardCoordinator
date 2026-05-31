local addonName, addon = ...

addon.state = addon.state or {}
addon.state.assignments = addon.state.assignments or {}
addon.state.priests = addon.state.priests or {}

local function ShortName(name)
    if not name then return nil end
    return Ambiguate(name, "short")
end

function addon:GetPlayerName()
    return ShortName(UnitName("player"))
end

function addon:IsLeader()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function addon:CanEditPriest(priest)
    if self:IsLeader() then
        return true
    end

    return ShortName(priest) == self:GetPlayerName()
end

function addon:IsPriest(unit)
    local _, class = UnitClass(unit)
    return class == "PRIEST"
end

function addon:ScanRaid()
    wipe(self.state.priests)

    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and self:IsPriest(unit) then
                local name = UnitName(unit)
                table.insert(self.state.priests, ShortName(name))
            end
        end
    else
        if self:IsPriest("player") then
            table.insert(self.state.priests, self:GetPlayerName())
        end
    end
end

function addon:SetAssignment(priest, group)
    priest = ShortName(priest)

    if not self:CanEditPriest(priest) then
        print("|cffff0000FWC: You can only edit your own assignments unless you have raid lead or assist.|r")
        return
    end

    self.state.assignments[priest] = self.state.assignments[priest] or {}
    self.state.assignments[priest][group] = not self.state.assignments[priest][group]

    FearWardCoordinatorDB = FearWardCoordinatorDB or {}
    FearWardCoordinatorDB.assignments = self.state.assignments

    if self.SendUpdate then
        self:SendUpdate()
    end
end

function addon:GetAssignment(priest, group)
    priest = ShortName(priest)

    return self.state.assignments[priest]
        and self.state.assignments[priest][group]
end

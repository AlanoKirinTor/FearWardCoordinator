local addonName, addon = ...

addon.state = addon.state or {}
addon.state.assignments = addon.state.assignments or {}
addon.state.priests = addon.state.priests or {}

-- check priest role (simple heuristic)
function addon:IsPriest(unit)
    local _, class = UnitClass(unit)
    return class == "PRIEST"
end

function addon:ScanRaid()
    wipe(self.state.priests)

    if not IsInRaid() then return end

    for i = 1, 40 do
        local unit = "raid"..i
        if UnitExists(unit) and self:IsPriest(unit) then
            local name = UnitName(unit)
            table.insert(self.state.priests, name)
        end
    end
end

function addon:SetAssignment(priest, group)
    self.state.assignments[priest] = self.state.assignments[priest] or {}
    self.state.assignments[priest][group] = not self.state.assignments[priest][group]

    if addon.SendUpdate then
        addon:SendUpdate()
    end
end

function addon:GetAssignment(priest, group)
    return self.state.assignments[priest]
        and self.state.assignments[priest][group]
end
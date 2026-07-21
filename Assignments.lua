local addonName, addon = ...

function addon:IsLeader()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function addon:IsPriest(unit)
    local _, class = UnitClass(unit)
    return class == "PRIEST"
end

function addon:CanEditPriest(priest)
    return self:IsLeader() or self:ShortName(priest) == self:GetPlayerName()
end

function addon:ScanGroup()
    wipe(self.state.priests)

    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and self:IsPriest(unit) then
                self.state.priests[#self.state.priests + 1] = self:ShortName(UnitName(unit))
            end
        end
    elseif IsInGroup() then
        if self:IsPriest("player") then
            self.state.priests[#self.state.priests + 1] = self:GetPlayerName()
        end
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and self:IsPriest(unit) then
                self.state.priests[#self.state.priests + 1] = self:ShortName(UnitName(unit))
            end
        end
    elseif self:IsPriest("player") then
        self.state.priests[1] = self:GetPlayerName()
    end

    table.sort(self.state.priests)
    local present = {}
    for _, priest in ipairs(self.state.priests) do present[priest] = true end
    for priest in pairs(self.state.assignments) do
        if not present[priest] then self.state.assignments[priest] = nil end
    end
end

function addon:SetAssignment(priest, group)
    if InCombatLockdown() then
        print("|cffff0000FWC: Assignments are locked during combat.|r")
        return
    end

    priest = self:ShortName(priest)
    if not self:CanEditPriest(priest) then
        print("|cffff0000FWC: You can only edit yourself unless you have raid lead or assist.|r")
        return
    end

    self.state.assignments[priest] = self.state.assignments[priest] or {}
    self.state.assignments[priest][group] = not self.state.assignments[priest][group]
    self.GetDB().assignments = self.state.assignments

    if self.SendUpdate then self:SendUpdate() end
    if self.RefreshUI then self:RefreshUI() end
    if self.RefreshGridUI then self:RefreshGridUI() end
end

function addon:GetAssignment(priest, group)
    priest = self:ShortName(priest)
    return self.state.assignments[priest] and self.state.assignments[priest][group]
end

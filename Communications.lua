local addonName, addon = ...

C_ChatInfo.RegisterAddonMessagePrefix("FWC")

function addon:IsLeader()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

function addon:SendUpdate()
    if not IsInRaid() then return end

    local msg = self:Serialize(self.state.assignments)

    C_ChatInfo.SendAddonMessage("FWC", msg, "RAID")
end

function addon:Serialize(table)
    return tostring(table and tostring(SerializeTable) or "")
end

-- simplified serializer
function addon:Deserialize(msg)
    -- NOTE: simplified v1 (upgrade later)
    return loadstring("return "..msg)()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")

frame:SetScript("OnEvent", function(_, _, prefix, message)
    if prefix ~= "FWC" then return end

    local data = addon:Deserialize(message)
    if data then
        addon.state.assignments = data
        if addon.RefreshUI then
            addon:RefreshUI()
        end
    end
end)
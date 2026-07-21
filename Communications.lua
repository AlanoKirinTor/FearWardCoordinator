local addonName, addon = ...
local PREFIX = "FWC2"

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
local frame = CreateFrame("Frame")
frame:RegisterEvent("CHAT_MSG_ADDON")

local function GroupsToString(groups)
    local out = {}
    for g = 1, 8 do if groups and groups[g] then out[#out + 1] = tostring(g) end end
    return table.concat(out, ",")
end

local function StringToGroups(text)
    local groups = {}
    for token in string.gmatch(text or "", "([^,]+)") do
        local g = tonumber(token)
        if g and g >= 1 and g <= 8 then groups[g] = true end
    end
    return groups
end

local function GetUnitByName(name)
    name = addon:ShortName(name)
    if addon:GetPlayerName() == name then return "player" end
    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and addon:ShortName(UnitName(unit)) == name then return unit end
        end
    else
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and addon:ShortName(UnitName(unit)) == name then return unit end
        end
    end
end

local function SenderCanBroadcastFull(sender)
    local unit = GetUnitByName(sender)
    return unit and (UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit))
end

local function SerializeAll()
    local rows = {}
    for priest, groups in pairs(addon.state.assignments) do
        rows[#rows + 1] = priest .. "=" .. GroupsToString(groups)
    end
    table.sort(rows)
    return table.concat(rows, ";")
end

local function DeserializeAll(text)
    local result = {}
    for row in string.gmatch(text or "", "([^;]+)") do
        local priest, groups = string.match(row, "([^=]+)=?(.*)")
        if priest then result[addon:ShortName(priest)] = StringToGroups(groups) end
    end
    return result
end

function addon:SendUpdate()
    if not IsInGroup() then return end
    local channel = IsInRaid() and "RAID" or "PARTY"
    local message
    if self:IsLeader() then
        message = "FULL|" .. SerializeAll()
    else
        local me = self:GetPlayerName()
        message = "SELF|" .. me .. "|" .. GroupsToString(self.state.assignments[me])
    end
    C_ChatInfo.SendAddonMessage(PREFIX, message, channel)
end

frame:SetScript("OnEvent", function(_, _, prefix, message, _, sender)
    if prefix ~= PREFIX or not message then return end
    sender = addon:ShortName(sender)

    local kind, rest = string.match(message, "([^|]+)|(.+)")
    if kind == "FULL" then
        if not SenderCanBroadcastFull(sender) then return end
        addon.state.assignments = DeserializeAll(rest)
    elseif kind == "SELF" then
        local priest, groups = string.match(rest, "([^|]+)|?(.*)")
        priest = addon:ShortName(priest)
        if priest ~= sender then return end
        addon.state.assignments[priest] = StringToGroups(groups)
    else
        return
    end

    addon.GetDB().assignments = addon.state.assignments
    addon:RefreshAll()
end)

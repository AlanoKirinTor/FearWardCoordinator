local addonName, addon = ...

local PREFIX = "FWC"

C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)

local commFrame = CreateFrame("Frame")
commFrame:RegisterEvent("CHAT_MSG_ADDON")

local function ShortName(name)
    if not name then return nil end
    return Ambiguate(name, "short")
end

local function GetUnitForName(name)
    name = ShortName(name)

    if ShortName(UnitName("player")) == name then
        return "player"
    end

    if IsInRaid() then
        for i = 1, 40 do
            local unit = "raid" .. i
            if UnitExists(unit) and ShortName(UnitName(unit)) == name then
                return unit
            end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and ShortName(UnitName(unit)) == name then
                return unit
            end
        end
    end

    return nil
end

local function SenderIsLeadOrAssist(sender)
    local unit = GetUnitForName(sender)
    if not unit then return false end

    return UnitIsGroupLeader(unit) or UnitIsGroupAssistant(unit)
end

local function GroupsToString(groups)
    local nums = {}

    if groups then
        for g = 1, 8 do
            if groups[g] then
                table.insert(nums, tostring(g))
            end
        end
    end

    return table.concat(nums, ",")
end

local function StringToGroups(str)
    local groups = {}

    for g in string.gmatch(str or "", "([^,]+)") do
        local num = tonumber(g)
        if num and num >= 1 and num <= 8 then
            groups[num] = true
        end
    end

    return groups
end

local function SerializeFull(assignments)
    local chunks = {}

    for priest, groups in pairs(assignments or {}) do
        table.insert(chunks, priest .. "=" .. GroupsToString(groups))
    end

    return table.concat(chunks, ";")
end

local function DeserializeFull(msg)
    local assignments = {}

    for chunk in string.gmatch(msg or "", "([^;]+)") do
        local priest, groupsString = string.match(chunk, "([^=]+)=?(.*)")

        if priest and priest ~= "" then
            assignments[ShortName(priest)] = StringToGroups(groupsString)
        end
    end

    return assignments
end

function addon:SendUpdate()
    if not IsInGroup() then return end

    local channel = IsInRaid() and "RAID" or "PARTY"
    local player = self:GetPlayerName()

    local msg

    if self:IsLeader() then
        -- Raid lead / assist broadcasts the full assignment table.
        msg = "FULL|" .. SerializeFull(self.state.assignments)
    else
        -- Normal priests broadcast only their own row.
        msg = "SELF|" .. player .. "|" .. GroupsToString(self.state.assignments[player])
    end

    C_ChatInfo.SendAddonMessage(PREFIX, msg, channel)
end

commFrame:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)
    if prefix ~= PREFIX then return end
    if not message or message == "" then return end

    sender = ShortName(sender)

    local msgType, rest = string.match(message, "([^|]+)|(.+)")

    if msgType == "FULL" then
        -- Only accept full raid-wide assignment updates from raid lead / assist.
        if not SenderIsLeadOrAssist(sender) then
            return
        end

        addon.state.assignments = DeserializeFull(rest)

    elseif msgType == "SELF" then
        -- Normal priests may update only their own assignment row.
        local priest, groupsString = string.match(rest, "([^|]+)|?(.*)")
        priest = ShortName(priest)

        if priest ~= sender then
            return
        end

        addon.state.assignments[priest] = StringToGroups(groupsString)
    end

    FearWardCoordinatorDB = FearWardCoordinatorDB or {}
    FearWardCoordinatorDB.assignments = addon.state.assignments

    if addon.RefreshUI then
        addon:RefreshUI()
    end

    if addon.RefreshGridUI then
        addon:RefreshGridUI()
    end
end)

local addonName, addon = ...

local FEAR_WARD = GetSpellInfo(6346) or "Fear Ward"

function addon:GetGroupMembers(groupNumber)
    local members = {}

    if not IsInRaid() then return members end

    for i = 1, 40 do
        local name, _, subgroup = GetRaidRosterInfo(i)
        if name and subgroup == groupNumber then
            table.insert(members, {
                name = name,
                unit = "raid" .. i,
                group = subgroup
            })
        end
    end

    return members
end

function addon:GetFearWardInfo(unit)
    if not UnitExists(unit) then
        return false, 0
    end

    for i = 1, 40 do
        local name, _, _, _, duration, expirationTime = UnitBuff(unit, i)

        if not name then break end

        if name == FEAR_WARD or name == "Fear Ward" then
            local remaining = 0

            if expirationTime and expirationTime > 0 then
                remaining = expirationTime - GetTime()
            end

            return true, math.max(0, remaining)
        end
    end

    return false, 0
end

function addon:FormatTime(seconds)
    if not seconds or seconds <= 0 then
        return "active"
    end

    local min = math.floor(seconds / 60)
    local sec = math.floor(seconds % 60)

    if min > 0 then
        return string.format("%dm %02ds", min, sec)
    else
        return string.format("%ds", sec)
    end
end
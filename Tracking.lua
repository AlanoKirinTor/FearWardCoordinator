local addonName, addon = ...

local FEAR_WARD_NAME = GetSpellInfo(6346) or "Fear Ward"

function addon:GetGroupMembers(groupNumber)
    local members = {}

    if not IsInRaid() then
        return members
    end

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
    if not unit or not UnitExists(unit) then
        return false, 0
    end

    for i = 1, 40 do
        local name, _, _, _, duration, expirationTime = UnitBuff(unit, i)

        if not name then
            break
        end

        -- IMPORTANT:
        -- Check by buff NAME only.
        -- This prevents false alerts when another priest's Fear Ward overwrites yours.
        if name == FEAR_WARD_NAME or name == "Fear Ward" then
            local remaining = 0

            if expirationTime and expirationTime > 0 then
                remaining = expirationTime - GetTime()
            end

            return true, math.max(0, remaining)
        end
    end

    return false, 0
end

function addon:CanSafelyCheckFearWard(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    if UnitIsDeadOrGhost(unit) then
        return false
    end

    if not UnitIsConnected(unit) then
        return false
    end

    -- If the game cannot see the unit, do NOT treat that as missing Fear Ward.
    if UnitIsVisible and not UnitIsVisible(unit) then
        return false
    end

    -- Only alert when they are actually in Fear Ward range.
    -- 1 = in range, 0 = out of range, nil = unknown.
    local inRange = IsSpellInRange(FEAR_WARD_NAME, unit)

    if inRange ~= 1 then
        return false
    end

    return true
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

local addonName, addon = ...

local FEAR_WARD_SPELL_ID = 6346

local function GetSpellNameCompat(spellID)
    if C_Spell and C_Spell.GetSpellName then
        return C_Spell.GetSpellName(spellID)
    end

    if C_Spell and C_Spell.GetSpellInfo then
        local spellInfo = C_Spell.GetSpellInfo(spellID)

        if spellInfo then
            return spellInfo.name
        end
    end

    if GetSpellInfo then
        return GetSpellInfo(spellID)
    end

    return nil
end

local FEAR_WARD_NAME =
    GetSpellNameCompat(FEAR_WARD_SPELL_ID)
    or "Fear Ward"

local function GetHelpfulAuraByIndex(unit, index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        return C_UnitAuras.GetAuraDataByIndex(
            unit,
            index,
            "HELPFUL"
        )
    end

    if UnitBuff then
        local name,
            icon,
            count,
            debuffType,
            duration,
            expirationTime,
            source,
            isStealable,
            nameplateShowPersonal,
            spellId = UnitBuff(unit, index)

        if not name then
            return nil
        end

        return {
            name = name,
            icon = icon,
            applications = count,
            dispelName = debuffType,
            duration = duration,
            expirationTime = expirationTime,
            sourceUnit = source,
            isStealable = isStealable,
            nameplateShowPersonal = nameplateShowPersonal,
            spellId = spellId,
        }
    end

    return nil
end

local function IsSpellInRangeCompat(
    spellID,
    spellName,
    unit
)
    if C_Spell and C_Spell.IsSpellInRange then
        local result =
            C_Spell.IsSpellInRange(spellID, unit)

        if result == nil and spellName then
            result =
                C_Spell.IsSpellInRange(
                    spellName,
                    unit
                )
        end

        if result == true or result == 1 then
            return 1
        end

        if result == false or result == 0 then
            return 0
        end

        return nil
    end

    if IsSpellInRange then
        return IsSpellInRange(
            spellName or spellID,
            unit
        )
    end

    return nil
end

function addon:GetFearWardSpellID()
    return FEAR_WARD_SPELL_ID
end

function addon:GetFearWardSpellName()
    return FEAR_WARD_NAME
end

function addon:IsFearWardInRange(unit)
    if not unit or not UnitExists(unit) then
        return false
    end

    local result = IsSpellInRangeCompat(
        FEAR_WARD_SPELL_ID,
        FEAR_WARD_NAME,
        unit
    )

    return result == 1
end

function addon:GetGroupMembers(groupNumber)
    local members = {}

    if not IsInRaid() then
        return members
    end

    for i = 1, 40 do
        local name, _, subgroup =
            GetRaidRosterInfo(i)

        if name and subgroup == groupNumber then
            table.insert(members, {
                name = name,
                unit = "raid" .. i,
                group = subgroup,
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
        local aura =
            GetHelpfulAuraByIndex(unit, i)

        if not aura then
            break
        end

        local auraSpellID =
            aura.spellId or aura.spellID

        if auraSpellID == FEAR_WARD_SPELL_ID
            or aura.name == FEAR_WARD_NAME
            or aura.name == "Fear Ward"
        then
            local remaining = 0

            if aura.expirationTime
                and aura.expirationTime > 0
            then
                remaining =
                    aura.expirationTime - GetTime()
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

    if UnitIsVisible
        and not UnitIsVisible(unit)
    then
        return false
    end

    return self:IsFearWardInRange(unit)
end

function addon:FormatTime(seconds)
    if not seconds or seconds <= 0 then
        return "active"
    end

    local minutes =
        math.floor(seconds / 60)

    local remainingSeconds =
        math.floor(seconds % 60)

    if minutes > 0 then
        return string.format(
            "%dm %02ds",
            minutes,
            remainingSeconds
        )
    end

    return string.format(
        "%ds",
        remainingSeconds
    )
end

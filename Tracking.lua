local addonName, addon = ...

local FEAR_WARD_ID = 6346

local function SpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name then return name end
    end
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name then return info.name end
    end
    if GetSpellInfo then return GetSpellInfo(spellID) end
end

local FEAR_WARD_NAME = SpellName(FEAR_WARD_ID) or "Fear Ward"

function addon:GetFearWardSpellID() return FEAR_WARD_ID end
function addon:GetFearWardSpellName() return FEAR_WARD_NAME end

function addon:GetHelpfulAura(unit, index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        return C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
    end
    if UnitBuff then
        local name, icon, count, debuffType, duration, expirationTime, sourceUnit,
            isStealable, nameplateShowPersonal, spellId = UnitBuff(unit, index)
        if not name then return nil end
        return {
            name = name,
            icon = icon,
            applications = count,
            dispelName = debuffType,
            duration = duration,
            expirationTime = expirationTime,
            sourceUnit = sourceUnit,
            isStealable = isStealable,
            nameplateShowPersonal = nameplateShowPersonal,
            spellId = spellId,
        }
    end
end

function addon:GetFearWardInfo(unit)
    if not unit or not UnitExists(unit) then return false, 0 end
    for i = 1, 40 do
        local aura = self:GetHelpfulAura(unit, i)
        if not aura then break end
        if aura.spellId == FEAR_WARD_ID or aura.name == FEAR_WARD_NAME or aura.name == "Fear Ward" then
            local remaining = 0
            if aura.expirationTime and aura.expirationTime > 0 then
                remaining = math.max(0, aura.expirationTime - GetTime())
            end
            return true, remaining
        end
    end
    return false, 0
end

function addon:IsFearWardInRange(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then return false end

    local result
    if C_Spell and C_Spell.IsSpellInRange then
        result = C_Spell.IsSpellInRange(FEAR_WARD_ID, unit)
        if result == nil then result = C_Spell.IsSpellInRange(FEAR_WARD_NAME, unit) end
    elseif IsSpellInRange then
        result = IsSpellInRange(FEAR_WARD_NAME, unit)
    end

    return result == true or result == 1
end

function addon:CanSafelyCheckFearWard(unit)
    if not unit or not UnitExists(unit) then return false end
    if UnitIsDeadOrGhost(unit) or not UnitIsConnected(unit) then return false end
    if UnitIsVisible and not UnitIsVisible(unit) then return false end
    return self:IsFearWardInRange(unit)
end

function addon:GetGroupMembers(groupNumber)
    local members = {}
    if IsInRaid() then
        for i = 1, 40 do
            local name, _, subgroup = GetRaidRosterInfo(i)
            local unit = "raid" .. i
            if name and subgroup == groupNumber and UnitExists(unit) then
                members[#members + 1] = { name = self:ShortName(name), unit = unit, group = subgroup }
            end
        end
    elseif IsInGroup() and groupNumber == 1 then
        members[#members + 1] = { name = self:GetPlayerName(), unit = "player", group = 1 }
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) then
                members[#members + 1] = { name = self:ShortName(UnitName(unit)), unit = unit, group = 1 }
            end
        end
    end
    return members
end

function addon:FormatTime(seconds)
    if not seconds or seconds <= 0 then return "active" end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    if m > 0 then return string.format("%dm %02ds", m, s) end
    return string.format("%ds", s)
end

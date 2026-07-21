local addonName, addon = ...
local DB = addon.GetDB

local frame = CreateFrame("Frame", "FWCGridFrame2", UIParent, "BasicFrameTemplateWithInset")
frame:SetSize(600, 400)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:SetResizable(true)
frame:SetClampedToScreen(true)
frame:Hide()
if frame.SetResizeBounds then frame:SetResizeBounds(420,260,1000,800) else frame:SetMinResize(420,260); frame:SetMaxResize(1000,800) end

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
frame.title:SetPoint("CENTER", frame.TitleBg, "CENTER")
frame.title:SetText("Fear Ward Assignment Grid")
frame.TitleBg:EnableMouse(true)
frame.TitleBg:RegisterForDrag("LeftButton")
frame.TitleBg:SetScript("OnDragStart", function() if not InCombatLockdown() then frame:StartMoving() end end)
frame.TitleBg:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

local objects = {}
local function Clear()
    for _, obj in ipairs(objects) do obj:Hide(); obj:SetParent(nil) end
    wipe(objects)
end
local function Text(text,x,y,template)
    local fs=frame:CreateFontString(nil,"OVERLAY",template or "GameFontNormal")
    fs:SetPoint("CENTER",frame,"TOPLEFT",x,y); fs:SetText(text); fs:SetJustifyH("CENTER")
    objects[#objects+1]=fs; return fs
end
local function Button(priest,group,x,y)
    local b=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    b:SetSize(36,24); b:SetPoint("CENTER",frame,"TOPLEFT",x,y)
    local assigned=addon:GetAssignment(priest,group)
    b:SetText(assigned and "X" or "")
    if InCombatLockdown() or not addon:CanEditPriest(priest) then b:Disable(); b:SetAlpha(assigned and .75 or .25) end
    b:SetScript("OnClick",function() addon:SetAssignment(priest,group) end)
    objects[#objects+1]=b
end

function addon:RefreshGridUI()
    if not frame:IsShown() then return end
    Clear(); self:ScanGroup()
    local w,h=frame:GetWidth(),frame:GetHeight()
    local left,right,top,rowY,rowH=95,30,-45,-78,30
    local col=(w-left-right)/8
    Text("Priest",48,top)
    for g=1,8 do Text("G"..g,left+((g-.5)*col),top) end
    if #self.state.priests==0 then Text("No priests found.",w/2,-110); return end
    for r,priest in ipairs(self.state.priests) do
        local y=rowY-((r-1)*rowH)
        if math.abs(y)<h-35 then
            Text(priest,48,y,self:CanEditPriest(priest) and "GameFontNormal" or "GameFontDisable")
            for g=1,8 do Button(priest,g,left+((g-.5)*col),y) end
        end
    end
    Text(self:IsLeader() and "Lead/assist mode: you can edit everyone." or "Normal mode: viewing everyone, editing yourself only.",w/2,-(h-32),"GameFontNormal")
end

function addon:ToggleGridUI()
    frame:SetShown(not frame:IsShown())
    if frame:IsShown() then self:RefreshGridUI() end
end

frame:SetScript("OnSizeChanged",function() if frame:IsShown() then addon:RefreshGridUI() end end)
addon.gridFrame=frame

local name, TTT = ...;

--@debug@
_G.TalentTreeTweaks = TTT;
if not _G.TTT then _G.TTT = TTT; end
--@end-debug@

--- @class Main
local Main = {}
if not Main then return; end
TTT.Main = Main;

function Main:AlreadyAdded(textLine, tooltip)
    if textLine == nil then
        return false
    end

    for i = 1,15 do
        local tooltipFrame = _G[tooltip:GetName() .. "TextLeft" .. i]
        local textRight = _G[tooltip:GetName().."TextRight"..i]
        local text, right
        if tooltipFrame then text = tooltipFrame:GetText() end
        if text and string.find(text, textLine, 1, true) then return true end
        if textRight then right = textRight:GetText() end
        if right and string.find(right, textLine, 1, true) then return true end
    end
end

function Main:AddItemToTooltip(name, value, tooltip)
    local text = "|cFFEE6161"..name.."|r " .. (value or 'nil')
    if(not self:AlreadyAdded(text, tooltip)) then
        tooltip:AddLine(text)
    end
    tooltip:Show()
end

EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", function(self, button, tooltip)
    self:AddItemToTooltip('NodeId', button.GetNodeID and button:GetNodeID() or button:GetNodeInfo().ID, tooltip)
    self:AddItemToTooltip('EntryId', button:GetEntryID(), tooltip)
    self:AddItemToTooltip('SpellId', button:GetSpellID(), tooltip)
end, Main)

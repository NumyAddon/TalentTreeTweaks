local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
local L = TTT.L;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
--- @type LibTalentTree
local LTT = Util.LibTalentTree;

local Module = Main:NewModule('TooltipIds');

function Module:OnEnable()
    EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", self.OnTalentTooltipCreated, self)
    EventRegistry:RegisterCallback("ProfessionSpecs.SpecPerkEntered", self.OnProfessionPerkEntered, self)
    EventRegistry:RegisterCallback("ProfessionSpecs.SpecPathEntered", self.OnProfessionPathEntered, self)
end

function Module:OnDisable()
    EventRegistry:UnregisterCallback("TalentDisplay.TooltipCreated", self)
    EventRegistry:UnregisterCallback("ProfessionSpecs.SpecPerkEntered", self)
    EventRegistry:UnregisterCallback("ProfessionSpecs.SpecPathEntered", self)
end

function Module:GetDescription()
    return L['Adds spell id and more to the various talent tree tooltips.'];
end

function Module:GetName()
    return L['Tooltip IDs'];
end

function Module:GetOptions(defaultOptionsTable, db)
    local defaultDb = {
        talentTooltip = {
            enabled = true,
            nodeId = true,
            entryId = true,
            definitionId = false,
            spellId = true,
            rowColInfo = false,
        },
        professionTooltip = {
            enabled = true,
            nodeId = true,
            entryId = true,
            definitionId = false,
            spellId = true,
        },
    }
    self.db = db;
    for k, v in pairs(defaultDb) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    local increment = CreateCounter(5);

    local getter = function(info, key)
        return self.db[info[#info]][key];
    end;
    local setter = function(info, key, value)
        self.db[info[#info]][key] = value;
    end;

    defaultOptionsTable.args.talentTooltip = {
        order = increment(),
        type = 'multiselect',
        name = L['Talent Tooltip'],
        desc = L['Toggles for the Talent Tooltips.'],
        values = {
            enabled = L['Talent Tooltip'],
            nodeId = 'Node ID', -- don't translate
            entryId = 'Entry ID', -- don't translate
            definitionId = 'Definition ID', -- don't translate
            spellId = L['Spell ID'],
            rowColInfo = L['Row/Col Info'],
        },
        get = getter,
        set = setter,
    };
    defaultOptionsTable.args.professionTooltip = {
        order = increment(),
        type = 'multiselect',
        name = L['Talent Tooltip'],
        desc = L['Toggles for the Professions Tooltips.'],
        values = {
            enabled = L['Professions Tooltip'],
            nodeId = 'Node ID', -- don't translate
            entryId = 'Entry ID', -- don't translate
            definitionId = 'Definition ID', -- don't translate
            spellId = L['Spell ID'],
        },
        get = getter,
        set = setter,
    };

    return defaultOptionsTable;
end

function Module:AlreadyAdded(textLine, tooltip)
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

function Module:AddItemToTooltip(idName, value, tooltip)
    if value == nil then
        return
    end
    local text = "|cFFEE6161" .. idName .. "|r " .. value
    if(not self:AlreadyAdded(text, tooltip)) then
        tooltip:AddLine(text)
    end
    tooltip:Show()
end

function Module:AddGenericTraitButtonTooltips(button, tooltip, settings)
    if settings.entryId then
        self:AddItemToTooltip('Entry ID', button:GetEntryID(), tooltip)
    end
    if settings.spellId then
        self:AddItemToTooltip(L['Spell ID'], button:GetSpellID(), tooltip)
    end
    if settings.definitionId then
        self:AddItemToTooltip('Definition ID', button.GetDefinitionID and button:GetDefinitionID() or nil, tooltip)
    end
end

function Module:OnTalentTooltipCreated(button, tooltip)
    if not self.db.talentTooltip.enabled then return end
    local settings = self.db.talentTooltip
    if settings.nodeId then
        self:AddItemToTooltip('Node ID', button.GetNodeID and button:GetNodeID() or button:GetNodeInfo().ID, tooltip)
    end
    self:AddGenericTraitButtonTooltips(button, tooltip, settings)
    if settings.rowColInfo then
        local nodeID = button.GetNodeID and button:GetNodeID() or button:GetNodeInfo().ID
        if nodeID then
            local column, row = LTT:GetNodeGridPosition(nodeID)
            if column and row then
                self:AddItemToTooltip(L['Row/Col'], string.format('%d / %.1f', row, column):gsub('%.0', ''), tooltip)
            end
        end
    end
end

function Module:OnProfessionPerkEntered(perkId)
    if not self.db.professionTooltip.enabled then return end

    local tooltip = GameTooltip
    if not tooltip:IsShown() then return end
    local button = tooltip:GetOwner()
    if not button or button.perkID ~= perkId then return end

    local settings = self.db.professionTooltip
    if settings.nodeId then
        self:AddItemToTooltip(L['Perk NodeId'], perkId, tooltip)
    end
    self:AddGenericTraitButtonTooltips(button, tooltip, settings)
end

function Module:OnProfessionPathEntered(nodeId)
    if not self.db.professionTooltip.enabled then return end

    local tooltip = GameTooltip
    if not tooltip:IsShown() then return end
    local button = tooltip:GetOwner()
    if not button or not button.nodeInfo or button.nodeInfo.ID ~= nodeId then return end

    local settings = self.db.professionTooltip
    if settings.nodeId then
        self:AddItemToTooltip(L['Path NodeId'], nodeId, tooltip)
    end
    self:AddGenericTraitButtonTooltips(button, tooltip, settings)
end

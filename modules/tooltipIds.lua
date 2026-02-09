--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local L = TTT.L;
local Util = TTT.Util;
local LTT = Util.LibTalentTree;

--- @class TTT_TooltipIds: NumyConfig_Module
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

--- @param configBuilder NumyConfigBuilder
--- @param db TTT_TooltipIdsDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class TTT_TooltipIdsDB
    local defaults = {
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
    };
    configBuilder:SetDefaults(defaults);
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        elseif type(v) == 'table' then
            for kk, vv in pairs(v) do
                if db[k][kk] == nil then
                    db[k][kk] = vv;
                end
            end
        end
    end

    local function makeSubCheckbox(subHeader, label, key, tableKey, tooltip)
        configBuilder:MakeCheckbox(label, key, tooltip, nil, defaults[tableKey][key], db[tableKey]):SetParentInitializer(subHeader);
    end
    do
        local subHeader = configBuilder:MakeText(L['Talent Tooltip'], 2);
        makeSubCheckbox(subHeader, ENABLE, 'enabled', 'talentTooltip', L['Toggles for the Talent Tooltips.']);
        makeSubCheckbox(subHeader, 'Node ID', 'nodeId', 'talentTooltip'); -- don't translate
        makeSubCheckbox(subHeader, 'Entry ID', 'entryId', 'talentTooltip'); -- don't translate
        makeSubCheckbox(subHeader, 'Definition ID', 'definitionId', 'talentTooltip'); -- don't translate
        makeSubCheckbox(subHeader, L['Spell ID'], 'spellId', 'talentTooltip');
        makeSubCheckbox(subHeader, L['Row/Col Info'], 'rowColInfo', 'talentTooltip');
    end
    do
        local subHeader = configBuilder:MakeText(L['Professions Tooltip'], 2);
        makeSubCheckbox(subHeader, ENABLE, 'enabled', 'professionTooltip', L['Toggles for the Professions Tooltips.']);
        makeSubCheckbox(subHeader, 'Node ID', 'nodeId', 'professionTooltip'); -- don't translate
        makeSubCheckbox(subHeader, 'Entry ID', 'entryId', 'professionTooltip'); -- don't translate
        makeSubCheckbox(subHeader, 'Definition ID', 'definitionId', 'professionTooltip'); -- don't translate
        makeSubCheckbox(subHeader, L['Spell ID'], 'spellId', 'professionTooltip');
    end
end

--- @param tooltip GameTooltip
function Module:AlreadyAdded(textLine, tooltip)
    if textLine == nil then
        return false
    end

    for i = 1, tooltip:NumLines() do
        local leftLine = tooltip:GetLeftLine(i)
        if leftLine then
            local left = leftLine:GetText()
            if left and not issecretvalue(left) and string.find(left, textLine, 1, true) then return true end
        end

        local rightLine = tooltip:GetRightLine(i)
        if rightLine then
            local right = rightLine:GetText()
            if right and not issecretvalue(right) and string.find(right, textLine, 1, true) then return true end
        end
    end
end

function Module:AddItemToTooltip(idName, value, tooltip)
    if value == nil then
        return
    end
    local text = "|cFFEE6161" .. idName .. "|r " .. value
    if (not self:AlreadyAdded(text, tooltip)) then
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

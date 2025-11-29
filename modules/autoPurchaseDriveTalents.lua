--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

local TRAIT_SYSTEM_ID = 19;
local TREE_ID = 1056;
local DO_NOTHING = -1;

--- @class TTT_DriveModule: NumyConfig_Module, AceEvent-3.0
local Module = Main:NewModule('Drive Auto Purchaser', 'AceEvent-3.0');

function Module:OnInitialize()
    self:RegisterEvent('TRAIT_CONFIG_LIST_UPDATED', 'CheckConfig');
    self:RegisterEvent('TRAIT_CONFIG_CREATED', 'CheckConfig');
    self:RegisterEvent('PLAYER_ENTERING_WORLD', 'CheckConfig');
end

function Module:OnEnable()
    self.enabled = true;
    if self.configID then
        self:SelectTalents();
    end
end

function Module:OnDisable()
    self.enabled = false;
end

function Module:GetName()
    return L['DRIVE Auto Upgrades'];
end

function Module:GetDescription()
    return L['Automatically selects the DRIVE upgrades you want for all of your alts.'];
end

--- @param configBuilder NumyConfigBuilder
--- @param db TTT_DriveModuleDB
function Module:BuildConfig(configBuilder, db)
    self.configBuilder = configBuilder;
    self.db = db;
    --- @class TTT_DriveModuleDB
    local defaults = {
        reportPurchases = true,
    };
    configBuilder:SetDefaults(defaults, true);

    local initializer = configBuilder:MakeText(L['Loading...'] .. '\n' .. L['This module is only available for characters that have unlocked to the DRIVE system.']);
    initializer:AddShownPredicate(function() return not self.configID; end);
end

function Module:RebuildConfig()
    local configBuilder = self.configBuilder;
    if self.initializers then configBuilder:RemoveInitializers(self.initializers); end
    self.initializers = {};

    for index, nodeInfo in self:IterateNodes() do
        local options = { { value = DO_NOTHING, text = L['Do Nothing'], }, };
        for _, entryID in ipairs(nodeInfo.entryIDs) do
            local spellLink = self:GetSpellLinkFromEntryID(entryID);
            if spellLink then
                table.insert(options, { value = entryID, text = spellLink, });
            end
        end
        local dbKey = 'node-' .. nodeInfo.ID;
        if nil == self.db[dbKey] then
            self.db[dbKey] = (nodeInfo.activeEntry and nodeInfo.activeEntry.entryID) or (nodeInfo.entryIDs and nodeInfo.entryIDs[1]) or DO_NOTHING;
        end
        table.insert(self.initializers, (configBuilder:MakeDropdown(
            L['Row %d']:format(index),
            dbKey,
            L['Specify the upgrade you want to select on login.'],
            options,
            nil,
            DO_NOTHING
        )));
    end
    table.insert(self.initializers, configBuilder:MakeButton(
        L['Refresh Upgrades List'],
        function() self:RebuildConfig(); end,
        L['Refresh the list of upgrades. May be useful if you have recently unlocked new upgrades.']
    ));
    table.insert(self.initializers, configBuilder:MakeButton(
        L['Apply DRIVE Upgrades'],
        function() self:SelectTalents(); end,
        L['Force apply the selected DRIVE upgrades. This automatically happens on login as well.']
    ));
    table.insert(self.initializers, configBuilder:MakeButton(
        L['Toggle D.R.I.V.E. UI'],
        function()
            GenericTraitUI_LoadUI();
            if GenericTraitFrame.SetConfigIDBySystemID then
                GenericTraitFrame:SetConfigIDBySystemID(TRAIT_SYSTEM_ID);
            else
                GenericTraitFrame:SetSystemID(TRAIT_SYSTEM_ID);
            end
            GenericTraitFrame:SetTreeID(TREE_ID);
            GenericTraitFrame:SetShown(not GenericTraitFrame:IsShown());
            if GenericTraitFrame:GetNumPoints() == 0 then
                GenericTraitFrame:SetPoint('TOPLEFT', 16, -116); -- roughly where it would normally open
            end
            if not tIndexOf(UISpecialFrames, 'GenericTraitFrame') then
                table.insert(UISpecialFrames, 'GenericTraitFrame');
            end
        end,
        L['Toggle the DRIVE UI to view and adjust upgrades.']
    ));
    table.insert(self.initializers, (configBuilder:MakeCheckbox(
        L['Report On Selections'],
        'reportPurchases',
        L['Print in chat whenever a different upgrade is selected.']
    )));

    configBuilder:MoveInitializersAfter(self.initializers);
end

function Module:IterateNodes()
    local nodeInfos = {};
    for _, nodeID in pairs(C_Traits.GetTreeNodes(TREE_ID)) do
        local nodeInfo = C_Traits.GetNodeInfo(self.configID, nodeID);
        if nodeInfo then
            table.insert(nodeInfos, nodeInfo);
        end
    end
    table.sort(nodeInfos, function(a, b)
        return a.posY < b.posY;
    end);

    return ipairs(nodeInfos);
end

function Module:Print(...)
    print('|cff33ff99TTT-' .. L['DRIVE Auto Selector:'] .. '|r', ...);
end

function Module:CheckConfig()
    self.configID = C_Traits.GetConfigIDBySystemID(TRAIT_SYSTEM_ID);
    if not self.configID then return end

    self:RebuildConfig();

    if self.enabled then
        self:SelectTalents();
    end
    self:UnregisterAllEvents();
end

function Module:SelectTalents()
    if not self.configID then return; end

    for _, nodeInfo in self:IterateNodes() do
        local settingName = 'node-'..nodeInfo.ID;
        local targetEntryID = self.db[settingName];
        local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID;
        if
            (targetEntryID ~= DO_NOTHING and targetEntryID ~= activeEntryID)
            and C_Traits.SetSelection(self.configID, nodeInfo.ID, targetEntryID)
            and self.db.reportPurchases
        then
            self:Print(L['Automatically set'], self:GetSpellLinkFromEntryID(targetEntryID));
        end
    end

    C_Traits.CommitConfig(self.configID)
end

function Module:GetSpellLinkFromEntryID(entryID)
    if not self.configID then return; end

    local entryInfo = C_Traits.GetEntryInfo(self.configID, entryID);
    if entryInfo and entryInfo.definitionID then
        local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID);
        if definitionInfo and (definitionInfo.spellID or definitionInfo.overriddenSpellID) then
            local spellID = definitionInfo.spellID or definitionInfo.overriddenSpellID;
            local spellLink = spellID and C_Spell.GetSpellLink(spellID);

            local texture = spellID and C_Spell.GetSpellTexture(spellID);

            return spellLink and ('|T'..texture..':0|t ' .. spellLink) or spellLink;
        end
    end
end

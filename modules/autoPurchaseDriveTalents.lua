local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local TRAIT_SYSTEM_ID = 19;
local TREE_ID = 1056;
local DO_NOTHING = -1;

--- @class TalentTreeTweaks_DriveModule: AceModule, AceEvent-3.0
local Module = Main:NewModule('Drive Auto Purchaser', 'AceEvent-3.0');

function Module:OnInitialize()
    self:RegisterEvent('TRAIT_CONFIG_LIST_UPDATED');
end

function Module:OnEnable()
    self.enabled = true;
    if self.configID then
        self:PurchaseTalents();
    end
end

function Module:OnDisable()
    self.enabled = false;
end

function Module:GetName()
    return L['DRIVE Auto Purchaser'];
end

function Module:GetDescription()
    local text = L['Automatically purchases the DRIVE talents you want for all of your alts.'];

    return text;
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        reportPurchases = true,
    };
    for k, v in pairs(defaults) do
        if self.db[k] == nil then
            self.db[k] = v;
        end
    end

    local increment = CreateCounter(5);

    self.optionsTable = defaultOptionsTable;

    defaultOptionsTable.args.enable.width = 'full';

    defaultOptionsTable.args.loading = {
        type = 'description',
        name = L['Loading...'] .. '\n' .. L['This module is only available for characters that have unlocked to the DRIVE system.'],
        order = increment(),
        hidden = function() return self.configID; end,
    };

    return defaultOptionsTable;
end

function Module:BuildOptionsTable()
    local defaultOptionsTable = self.optionsTable;

    local function get(info)
        return self.db[info[#info]];
    end
    local function set(info, value)
        self.db[info[#info]] = value;
    end
    local increment = CreateCounter(10);

    for index, nodeInfo in self:IterateNodes() do
        local values = { [DO_NOTHING] = L['Do Nothing'] };
        local order = { DO_NOTHING };
        for _, entryID in ipairs(nodeInfo.entryIDs) do
            local spellLink = self:GetSpellLinkFromEntryID(entryID);
            if spellLink then
                values[entryID] = spellLink;
                table.insert(order, entryID);
            end
        end
        local dbKey = 'node-'..nodeInfo.ID;
        if nil == self.db[dbKey] then
            self.db[dbKey] = (nodeInfo.activeEntry and nodeInfo.activeEntry.entryID) or (nodeInfo.entryIDs and nodeInfo.entryIDs[1]) or DO_NOTHING;
        end
        defaultOptionsTable.args['node-'..nodeInfo.ID] = {
            type = 'select',
            name = L['Row %d']:format(index),
            desc = L['Specify the talent you want to select on login.'],
            values = values,
            sorting = order,
            order = increment(),
            get = get,
            set = set,
            width = 1.2,
        };
    end
    defaultOptionsTable.args.setTalents = {
        type = 'execute',
        name = L['Apply DRIVE Talents'],
        desc = L['Force apply the selected DRIVE talents. This automatically happens on login as well.'],
        order = increment(),
        func = function()
            self:PurchaseTalents();
        end,
        width = 'full',
    };
    defaultOptionsTable.args.openUI = {
        type = 'execute',
        name = L['Toggle D.R.I.V.E. UI'],
        desc = L['Toggle the DRIVE UI to view and adjust talents.'],
        order = increment(),
        func = function()
            GenericTraitUI_LoadUI();
            GenericTraitFrame:SetSystemID(TRAIT_SYSTEM_ID);
            GenericTraitFrame:SetTreeID(TREE_ID);
            GenericTraitFrame:SetShown(not GenericTraitFrame:IsShown());
            if GenericTraitFrame:GetNumPoints() == 0 then
                GenericTraitFrame:SetPoint('TOPLEFT', 16, -116); -- roughly where it would normally open
            end
            if not tIndexOf(UISpecialFrames, 'GenericTraitFrame') then
                table.insert(UISpecialFrames, 'GenericTraitFrame');
            end
        end,
    };
    defaultOptionsTable.args.reportPurchases = {
        type = 'toggle',
        name = L['Report Purchases'],
        desc = L['Print in chat whenever a new talent is purchased.'],
        order = increment(),
        get = get,
        set = set,
    };
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
    print('|cff33ff99TTT-' .. L['DRIVE Auto Purchaser:'] .. '|r', ...);
end

function Module:TRAIT_CONFIG_LIST_UPDATED()
    self.configID = C_Traits.GetConfigIDBySystemID(TRAIT_SYSTEM_ID);
    if not self.configID then return end

    self:BuildOptionsTable();
    Main:NotifyConfigChange();

    if self.enabled then
        self:PurchaseTalents();
    end
    self:UnregisterEvent('TRAIT_CONFIG_LIST_UPDATED');
end

function Module:PurchaseTalents()
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

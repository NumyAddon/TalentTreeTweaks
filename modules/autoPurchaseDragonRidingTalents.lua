local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local TRAIT_SYSTEM_ID = Constants.MountDynamicFlightConsts and Constants.MountDynamicFlightConsts.TRAIT_SYSTEM_ID or 1;
local TREE_ID = Constants.MountDynamicFlightConsts and Constants.MountDynamicFlightConsts.TREE_ID or 672;

local CHOICE_NODE_OPTION_1 = 1;
local CHOICE_NODE_OPTION_2 = 2;
local CHOICE_NODE_NOT_SET = 3;

local RIDE_ALONG_NODE_ID = 100167;
local RIDE_ALONG_ENTRY_IDS = {
    [CHOICE_NODE_OPTION_1] = 123785,
    [CHOICE_NODE_OPTION_2] = 123784,
};

local SURGE_NODE_ID = 100168;
local SURGE_ENTRY_IDS = {
    [CHOICE_NODE_OPTION_1] = 123787,
    [CHOICE_NODE_OPTION_2] = 123786,
};

local GetSpellLink = C_Spell.GetSpellLink;

--- @class TalentTreeTweaks_SkyridingModule: AceModule, AceEvent-3.0
local Module = Main:NewModule('Skyriding Auto Purchaser', 'AceEvent-3.0');

function Module:OnInitialize()
    self:RegisterEvent('SPELLS_CHANGED');
    self.disabledByRefund = false;
    hooksecurefunc(C_Traits, 'RefundRank', function(configID)
        if configID == self.configID then
            self.disabledByRefund = true;
        end
    end);
    hooksecurefunc(C_Traits, 'SetSelection', function(configID, nodeID, entryID)
        if configID == self.configID and entryID == nil then
            self.disabledByRefund = true;
        end
    end);
end

function Module:OnEnable()
    self.enabled = true;
    if self.talentsLoaded then
        self:PurchaseTalents();
    end
    self:RegisterEvent('TRAIT_TREE_CURRENCY_INFO_UPDATED');
end

function Module:OnDisable()
    self.enabled = false;
    self:UnregisterEvent('TRAIT_TREE_CURRENCY_INFO_UPDATED');
end

function Module:GetName()
    return L['Skyriding Auto Purchaser'];
end

function Module:GetDescription()
    local text = L['Automatically purchases the Skyriding talent when you have enough currency.'];
    if self.disabledByRefund then
        text = text .. ' ' .. L['Temporarily |cffff0000disabled|r until next reload, because you refunded a talent.'];
    end

    return text;
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        reportPurchases = true,
        rideAlong = CHOICE_NODE_OPTION_1,
        rideAlongCache = {},
        surge = CHOICE_NODE_OPTION_1,
        surgeCache = {},
    };
    for k, v in pairs(defaults) do
        if self.db[k] == nil then
            self.db[k] = v;
        end
    end

    local function get(info)
        return self.db[info[#info]];
    end
    local function set(info, value)
        self.db[info[#info]] = value;
    end
    local increment = CreateCounter(5);

    local addedToSpecialFrames;
    defaultOptionsTable.args.openUI = {
        type = 'execute',
        name = L['Toggle Skyriding UI'],
        desc = L['Toggle the Skyriding UI to view and adjust talents.'],
        order = increment(),
        func = function()
            GenericTraitUI_LoadUI();
            --- @type Frame
            local GenericTraitFrame = GenericTraitFrame;
            GenericTraitFrame:SetSystemID(TRAIT_SYSTEM_ID);
            GenericTraitFrame:SetTreeID(TREE_ID);
            GenericTraitFrame:SetShown(not GenericTraitFrame:IsShown());
            if GenericTraitFrame:GetNumPoints() == 0 then
                GenericTraitFrame:SetPoint('TOPLEFT', 16, -116); -- roughly where it would normally open
            end
            if not addedToSpecialFrames then
                addedToSpecialFrames = true;
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
    defaultOptionsTable.args.rideAlong = {
        type = 'select',
        style = 'radio',
        name = L['Auto Ride Along'],
        desc = L['Automatically enable/disable Ride Along the first time you log in on a character.'],
        values = {
            [CHOICE_NODE_OPTION_1] = L['Enable Ride Along'],
            [CHOICE_NODE_OPTION_2] = L['Disable Ride Along'],
            [CHOICE_NODE_NOT_SET] = L['Do Nothing'],
        },
        order = increment(),
        get = get,
        set = set,
    };
    defaultOptionsTable.args.resetRideALongCache = {
        type = 'execute',
        name = L['Reset Ride Along Cache'],
        desc = L['Reset the Ride Along cache, so all characters will match the current setting on login.'],
        order = increment(),
        func = function()
            self.db.rideAlongCache = {};
            self:PurchaseTalents();
        end,
        width = 'double',
    };
    defaultOptionsTable.args.surge = {
        type = 'select',
        style = 'radio',
        name = L['Auto Surge Choice'],
        desc = L['Automatically pick Whirling Surge/Lightning Surge the first time you log in on a character.'],
        values = function()
            return {
                [CHOICE_NODE_OPTION_1] = StripHyperlinks(self:GetSpellLinkFromEntryID(SURGE_ENTRY_IDS[CHOICE_NODE_OPTION_1]) or 'Whirling Surge'),
                [CHOICE_NODE_OPTION_2] = StripHyperlinks(self:GetSpellLinkFromEntryID(SURGE_ENTRY_IDS[CHOICE_NODE_OPTION_2]) or 'Lightning Surge'),
                [CHOICE_NODE_NOT_SET] = L['Do Nothing'],
            };
        end,
        order = increment(),
        get = get,
        set = set,
    };
    defaultOptionsTable.args.resetSurgeCache = {
        type = 'execute',
        name = L['Reset Surge Cache'],
        desc = L['Reset the Surge cache, so all characters will match the current setting on login.'],
        order = increment(),
        func = function()
            self.db.surgeCache = {};
            self:PurchaseTalents();
        end,
        width = 'double',
    };

    return defaultOptionsTable;
end

function Module:Print(...)
    print('|cff33ff99TTT-Skyriding Auto Purchaser:|r', ...);
end

function Module:SPELLS_CHANGED()
    self.talentsLoaded = true;

    self.configID = C_Traits.GetConfigIDBySystemID(TRAIT_SYSTEM_ID);
    if not self.configID then return end

    if self.enabled then
        self:PurchaseTalents();
    end
    self:UnregisterEvent('SPELLS_CHANGED');
end

function Module:TRAIT_TREE_CURRENCY_INFO_UPDATED(_, treeID)
    if not self.purchasing and treeID == TREE_ID then
        RunNextFrame(function() self:PurchaseTalents(); end);
    end
end

function Module:GetCurrencyInfo()
    local excludeStagedChanges = true;
    local currencyInfo = C_Traits.GetTreeCurrencyInfo(self.configID, TREE_ID, excludeStagedChanges);
    return currencyInfo;
end

function Module:SetSpecialChoiceNode(settingName, cacheName, nodeID, choiceEntryList)
    if self.purchasing or self.db[settingName] == CHOICE_NODE_NOT_SET or self.db[cacheName][Util.PlayerKey] then
        return;
    end
    self.purchasing = true;
    local nodeInfo = C_Traits.GetNodeInfo(self.configID, nodeID);
    if not nodeInfo then
        self.purchasing = false;
        return;
    end
    local targetEntryID = choiceEntryList[self.db[settingName]];
    if nodeInfo.activeEntry and nodeInfo.activeEntry.entryID == targetEntryID then
        self.purchasing = false;
        return;
    end
    if C_Traits.SetSelection(self.configID, nodeID, targetEntryID) and C_Traits.CommitConfig(self.configID) then
        self.db[cacheName][Util.PlayerKey] = self.db[settingName];
        if self.db.reportPurchases then
            self:Print(L['Automatically set'], self:GetSpellLinkFromEntryID(targetEntryID));
        end
    end

    self.purchasing = false;
end

function Module:PurchaseTalents()
    if not self.configID then return; end
    self:SetSpecialChoiceNode('rideAlong', 'rideAlongCache', RIDE_ALONG_NODE_ID, RIDE_ALONG_ENTRY_IDS);
    self:SetSpecialChoiceNode('surge', 'surgeCache', SURGE_NODE_ID, SURGE_ENTRY_IDS);

    if self.purchasing or self.disabledByRefund then
        -- Already purchasing or disabled by refund
        return;
    end

    local currencyInfo = self:GetCurrencyInfo();
    if
        not currencyInfo or
        not currencyInfo[1] or
        not currencyInfo[1].quantity
    then
        -- No currency found
        return;
    end
    local availableCurrency = currencyInfo[1].quantity;

    self.purchasing = true;
    local nodes = C_Traits.GetTreeNodes(TREE_ID);
    local purchasedEntries = {};
    repeat
        local purchasedSomething = false;
        for _, nodeID in ipairs(nodes) do
            local nodeInfo = C_Traits.GetNodeInfo(self.configID, nodeID);
            local nodeCost = self:GetOrCacheNodeCost(nodeID);
            if
                nodeInfo
                and nodeInfo.ID == nodeID
                and nodeID ~= RIDE_ALONG_NODE_ID
                and nodeID ~= SURGE_NODE_ID
                and nodeInfo.canPurchaseRank
                and (nodeCost == 0 or nodeCost <= availableCurrency)
            then
                if #nodeInfo.entryIDs == 1 then
                    -- Single entry, just purchase it
                    if C_Traits.PurchaseRank(self.configID, nodeID) then
                        availableCurrency = availableCurrency - nodeCost;
                        purchasedSomething = true;
                        table.insert(purchasedEntries, nodeInfo.entryIDs[1]);
                    end
                else
                    -- Multiple entries, purchase the first one
                    local entryID = nodeInfo.entryIDs[1];
                    if C_Traits.SetSelection(self.configID, nodeID, entryID) then
                        availableCurrency = availableCurrency - nodeCost;
                        purchasedSomething = true;
                        table.insert(purchasedEntries, entryID);
                    end
                end
            end
        end
    until (availableCurrency <= 0 or not purchasedSomething)
    if #purchasedEntries > 0 and C_Traits.CommitConfig(self.configID) then
        self:ReportPurchases(purchasedEntries);
    end

    self.purchasing = false;
end

function Module:GetOrCacheNodeCost(nodeID)
    if not self.nodeCostCache then
        self.nodeCostCache = {};
    end
    if not self.nodeCostCache[nodeID] then
        local nodeCost = C_Traits.GetNodeCost(self.configID, nodeID);
        self.nodeCostCache[nodeID] = nodeCost and nodeCost[1] and nodeCost[1].amount or 0;
    end
    return self.nodeCostCache[nodeID];
end

function Module:GetSpellLinkFromEntryID(entryID)
    if not self.configID then return; end

    local entryInfo = C_Traits.GetEntryInfo(self.configID, entryID);
    if entryInfo and entryInfo.definitionID then
        local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID);
        if definitionInfo and (definitionInfo.spellID or definitionInfo.overriddenSpellID) then
            local spellID = definitionInfo.spellID or definitionInfo.overriddenSpellID;
            local spellLink = spellID and GetSpellLink(spellID);

            return spellLink;
        end
    end
end

function Module:ReportPurchases(entryIDs)
    if not self.db.reportPurchases then
        return;
    end
    local spellLinks = {};
    for _, entryID in ipairs(entryIDs) do
        local spellLink = self:GetSpellLinkFromEntryID(entryID);
        if spellLink then
            table.insert(spellLinks, spellLink);
        end
    end
    self:Print(
        string.format(
            L['Purchased %d new talents.'] .. '%s',
            #entryIDs,
            table.concat(spellLinks, ', ')
        )
    );
end

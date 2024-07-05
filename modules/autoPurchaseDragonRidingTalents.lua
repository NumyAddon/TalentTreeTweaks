local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local TRAIT_SYSTEM_ID = Constants.MountDynamicFlightConsts and Constants.MountDynamicFlightConsts.TRAIT_SYSTEM_ID
    or DRAGONRIDING_TRAIT_SYSTEM_ID or 1;
local TREE_ID = Constants.MountDynamicFlightConsts and Constants.MountDynamicFlightConsts.TREE_ID
    or DRAGONRIDING_TREE_ID or 672;

local RIDE_ALONG_ENABLED = 1;
local RIDE_ALONG_DISABLED = 2;
local RIDE_ALONG_NOT_SET = 3;

local RIDE_ALONG_NODE_ID = 100167;
local RIDE_ALONG_ENABLED_ENTRY_ID = 123785;
local RIDE_ALONG_DISABLED_ENTRY_ID = 123784;

local GetSpellLink = GetSpellLink or C_Spell.GetSpellLink;

--- @class TalentTreeTweaks_DragonRidingModule: AceModule, AceEvent-3.0
local Module = Main:NewModule('DragonRiding Auto Purchaser', 'AceEvent-3.0');

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
    return L['DragonRiding Auto Purchaser'];
end

function Module:GetDescription()
    local text = L['Automatically purchases the DragonRiding talent when you have enough currency.'];
    if self.disabledByRefund then
        text = text .. ' ' .. L['Temporarily |cffff0000disabled|r until next reload, because you refunded a talent.'];
    end

    return text;
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        reportPurchases = true,
        rideAlong = RIDE_ALONG_ENABLED,
        rideAlongCache = {},
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

    defaultOptionsTable.args.openUI = {
        type = 'execute',
        name = L['Toggle Skyriding UI'],
        desc = L['Toggle the Skyriding UI to view and adjust talents.'],
        order = increment(),
        func = function()
            GenericTraitUI_LoadUI();
            GenericTraitFrame:SetSystemID(TRAIT_SYSTEM_ID);
            GenericTraitFrame:SetTreeID(TREE_ID);
            ToggleFrame(GenericTraitFrame);
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
    if not Util.isDF then
        defaultOptionsTable.args.rideAlong = {
            type = 'select',
            style = 'radio',
            name = L['Auto Ride Along'],
            desc = L['Automatically enable/disable Ride Along the first time you log in on a character.'],
            values = {
                [RIDE_ALONG_ENABLED] = L['Enable Ride Along'],
                [RIDE_ALONG_DISABLED] = L['Disable Ride Along'],
                [RIDE_ALONG_NOT_SET] = L['Do Nothing'],
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
    end

    return defaultOptionsTable;
end

function Module:Print(...)
    print('|cff33ff99TTT-DragonRiding Auto Purchaser:|r', ...);
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

function Module:SetRideAlong()
    if Util.isDF or self.purchasing or self.db.rideAlong == RIDE_ALONG_NOT_SET or self.db.rideAlongCache[Util.PlayerKey] then
        return;
    end
    self.purchasing = true;
    local nodeID = RIDE_ALONG_NODE_ID;
    local nodeInfo = C_Traits.GetNodeInfo(self.configID, nodeID);
    if not nodeInfo then
        self.purchasing = false;
        return;
    end
    local targetEntryID = self.db.rideAlong == RIDE_ALONG_ENABLED and RIDE_ALONG_ENABLED_ENTRY_ID or RIDE_ALONG_DISABLED_ENTRY_ID;
    if nodeInfo.activeEntry and nodeInfo.activeEntry.entryID == targetEntryID then
        self.purchasing = false;
        return;
    end
    if C_Traits.SetSelection(self.configID, nodeID, targetEntryID) then
        C_Traits.CommitConfig(self.configID);
        self.db.rideAlongCache[Util.PlayerKey] = self.db.rideAlong;
        if self.db.reportPurchases then
            self:Print(L['Automatically set'], self:GetSpellIDFromEntryID(targetEntryID));
        end
    end

    self.purchasing = false;
end

function Module:PurchaseTalents()
    if not self.configID then return; end
    self:SetRideAlong();

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
                    -- Multiple entries, purchase the second one
                    local entryID = nodeInfo.entryIDs[2];
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

function Module:GetSpellIDFromEntryID(entryID)
    local entryInfo = C_Traits.GetEntryInfo(self.configID, entryID);
    if entryInfo and entryInfo.definitionID then
        local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID);
        if definitionInfo and (definitionInfo.spellID or definitionInfo.overriddenSpellID) then
            local spellID = definitionInfo.spellID or definitionInfo.overriddenSpellID;
            local spellLink = GetSpellLink(spellID);
            if spellLink then
                return spellLink
            end
        end
    end
end

function Module:ReportPurchases(entryIDs)
    if not self.db.reportPurchases then
        return;
    end
    local spellLinks = {};
    for _, entryID in ipairs(entryIDs) do
        local spellLink = self:GetSpellIDFromEntryID(entryID);
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

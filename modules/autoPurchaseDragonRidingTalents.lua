local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local DRAGONRIDING_TRAIT_SYSTEM_ID = 1;

local Module = Main:NewModule('DragonRiding Auto Purchaser', 'AceEvent-3.0');

function Module:OnInitialize()
    self:RegisterEvent('SPELLS_CHANGED');
    self.disabledByRefund = false;
    hooksecurefunc(C_Traits, 'RefundRank', function(configID)
        if configID == self.configID then
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
    };
    for k, v in pairs(defaults) do
        if self.db[k] == nil then
            self.db[k] = v;
        end
    end

    defaultOptionsTable.args.reportPurchases = {
        type = 'toggle',
        name = L['Report Purchases'],
        desc = L['Print in chat whenever a new talent is purchased.'],
        order = 5,
        get = function()
            return self.db.reportPurchases;
        end,
        set = function(_, value)
            self.db.reportPurchases = value;
        end,
    };

    return defaultOptionsTable;
end

function Module:SPELLS_CHANGED()
    self.talentsLoaded = true;

    self.configID = C_Traits.GetConfigIDBySystemID(DRAGONRIDING_TRAIT_SYSTEM_ID);
    if not self.configID then return end
    local configInfo = C_Traits.GetConfigInfo(self.configID);
    self.treeID = configInfo and configInfo.treeIDs and configInfo.treeIDs[1];

    if self.enabled then
        self:PurchaseTalents();
    end
    self:UnregisterEvent('SPELLS_CHANGED');
end

function Module:TRAIT_TREE_CURRENCY_INFO_UPDATED(_, treeID)
    if not self.purchasing and treeID == self.treeID then
        RunNextFrame(function() self:PurchaseTalents(); end);
    end
end

function Module:GetCurrencyInfo()
    local excludeStagedChanges = true;
    local currencyInfo = C_Traits.GetTreeCurrencyInfo(self.configID, self.treeID, excludeStagedChanges);
    return currencyInfo;
end

function Module:PurchaseTalents()
    if not self.configID then return; end
    if self.purchasing or self.disabledByRefund then
        -- Already purchasing or disabled by refund
        return;
    end

    local currencyInfo = self:GetCurrencyInfo();
    if
        not currencyInfo or
        not currencyInfo[1] or
        not currencyInfo[1].quantity or
        currencyInfo[1].quantity < 1
    then
        -- Not enough currency
        return;
    end
    local availableCurrency = currencyInfo[1].quantity;

    self.purchasing = true;
    local nodes = C_Traits.GetTreeNodes(self.treeID);
    local purchasedEntries = {};
    while availableCurrency > 0 do
        local purchasedSomething = false;
        for _, nodeID in ipairs(nodes) do
            local nodeInfo = C_Traits.GetNodeInfo(self.configID, nodeID);
            local nodeCost = self:GetOrCacheNodeCost(nodeID);
            if
                nodeInfo
                and nodeInfo.ID == nodeID
                and nodeInfo.canPurchaseRank
                and nodeCost ~= 0
                and nodeCost <= availableCurrency
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
        if not purchasedSomething then
            -- Nothing left to purchase
            break;
        end
    end
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

function Module:ReportPurchases(entryIDs)
    if not self.db.reportPurchases then
        return;
    end
    local spellLinks = {};
    for _, entryID in ipairs(entryIDs) do
        local entryInfo = C_Traits.GetEntryInfo(self.configID, entryID);
        if entryInfo and entryInfo.definitionID then
            local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID);
            if definitionInfo and (definitionInfo.spellID or definitionInfo.overriddenSpellID) then
                local spellID = definitionInfo.spellID or definitionInfo.overriddenSpellID;
                local spellLink = GetSpellLink(spellID);
                if spellLink then
                    table.insert(spellLinks, spellLink);
                end
            end
        end
    end
    print(
        string.format(
            L['|cff33ff99TTT-DragonRiding Auto Purchaser:|r Purchased %d new talents.\n%s'],
            #entryIDs,
            table.concat(spellLinks, ', ')
        )
    );
end

--- @class TTT_NS
local TTT = select(2, ...);

local StripHyperlinks = C_StringUtil.StripHyperlinks;

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

local TOOLTIP_LINK_NAME = 'TalentTreeTweaks_TraitTooltip';
local OPEN_UI_LINK_NAME = 'TalentTreeTweaks_OpenGenericTraits';

local SKYRIDING_TREE_ID = Constants.MountDynamicFlightConsts and Constants.MountDynamicFlightConsts.TREE_ID or 672;
local HORRIFIC_VISIONS_TREE_ID = 1057;
local OVERCHARGED_TITAN_CONSOLE_TREE_ID = 1061;
local RESHII_WRAPS_TREE_ID = 1115;
local OMNIUM_FOLIO_TREE_ID = 1186;

local RESHII_QUEST_ID = 89561;
local OMNIUM_FOLIO_QUEST_ID = 96410;

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
local WHIRLING_SURGE_SPELL_ID = 447981;
local LIGHTNING_SURGE_SPELL_ID = 447982;

local GetSpellLink = C_Spell.GetSpellLink;

--- @class TTT_GenericTalentModule: NumyConfig_Module, NumyAceEvent-3.0
local Module = Main:NewModule('Skyriding Auto Purchaser', 'NumyAceEvent-3.0');
-- don't rename the module, the settings etc are stored there

Module.trees = {
    [SKYRIDING_TREE_ID] = { settingKey = 'skyridingEnabled', displayName = GENERIC_TRAIT_FRAME_DRAGONRIDING_TITLE },
    [HORRIFIC_VISIONS_TREE_ID] = { settingKey = 'horrificVisionsEnabled', displayName = SPLASH_BATTLEFORAZEROTH_8_3_0_FEATURE1_TITLE or L['Horrific Visions'] },
    [OVERCHARGED_TITAN_CONSOLE_TREE_ID] = { settingKey = 'overchargedTitanConsoleEnabled', displayName = GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE },
    [RESHII_WRAPS_TREE_ID] = { settingKey = 'reshiiWrapsEnabled', displayName = GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE },
    [OMNIUM_FOLIO_TREE_ID] = { settingKey = 'omniumFolioEnabled', displayName = RUNES_OF_POWER },
};
function Module:OnInitialize()
    --- @type table<number, number> # [treeID] = configID
    self.configIDsByTree = {};
    --- @type table<number, number> # [configID] = treeID
    self.treeByConfigID = {};

    --- @type table<number, boolean> # [configID] = true if currently purchasing
    self.purchasing = {};
    RunNextFrame(function()
        self.checkConfigEvents = {
            'TRAIT_CONFIG_LIST_UPDATED',
            'TRAIT_CONFIG_CREATED',
            'PLAYER_ENTERING_WORLD',
        };
        for _, event in pairs(self.checkConfigEvents) do
            self:RegisterEvent(event, 'CheckConfig');
        end
        self:CheckConfig();
    end);
    self.disabledByRefund = false;
    hooksecurefunc(C_Traits, 'RefundRank', function(configID)
        if self.treeByConfigID[configID] then
            self.disabledByRefund = true;
        end
    end);
    hooksecurefunc(C_Traits, 'SetSelection', function(configID, nodeID, entryID)
        if self.treeByConfigID[configID] and entryID == nil then
            self.disabledByRefund = true;
        end
    end);

    self.deferredPurchaseFrame = CreateFrame('Frame');
    self.deferredPurchaseFrame:Hide();
    self.deferredPurchaseFrame:SetScript('OnUpdate', function()
        self.deferredPurchaseFrame:Hide();
        self:PurchaseTalents();
    end);

    EventRegistry:RegisterCallback('SetItemRef', function(_, link, text)
        local linkType, addonName, linkData = strsplit(':', link)
        if linkType ~= 'addon' then return; end
        if addonName == TOOLTIP_LINK_NAME then
            local definitionInfo = C_Traits.GetDefinitionInfo(tonumber(linkData));
            if not definitionInfo or not definitionInfo.overrideDescription then
                return;
            end

            ItemRefTooltip:SetOwner(UIParent, 'ANCHOR_CURSOR');
            ItemRefTooltip:AddLine('placeholder');
            ItemRefTooltip:Show();
            ItemRefTooltip:SetOwner(UIParent, 'ANCHOR_PRESERVE');
            ItemRefTooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode('Talent Tree Tweaks ') .. text);
            ItemRefTooltip:AddLine(definitionInfo.overrideDescription, nil, nil, nil, true);
            ItemRefTooltip:Show();
        elseif addonName == OPEN_UI_LINK_NAME then
            local treeID = tonumber(linkData);
            self:ToggleTreeUI(treeID);
        end
    end);
end

function Module:OnEnable()
    self.enabled = true;
    if self.talentsLoaded then
        self:DeferPurchase();
    end
    self:RegisterEvent('TRAIT_TREE_CURRENCY_INFO_UPDATED');
end

function Module:OnDisable()
    self.enabled = false;
    self:UnregisterEvent('TRAIT_TREE_CURRENCY_INFO_UPDATED');
end

function Module:GetName()
    return L['Auto Talent Purchaser'];
end

function Module:GetDescription()
    local text = L['Automatically purchases Skyriding and other generic talents when you have enough currency.'];
    if self.disabledByRefund then
        text = text .. '\n' .. L['Temporarily |cffff0000disabled|r until next reload, because you refunded a talent.'];
    end

    return text;
end

--- @param configBuilder NumyConfigBuilder
--- @param db TTT_GenericTalentModuleDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class TTT_GenericTalentModuleDB
    local defaults = {
        reportPurchases = true,
        rideAlong = CHOICE_NODE_OPTION_1,
        rideAlongCache = {},
        surge = CHOICE_NODE_OPTION_1,
        surgeCache = {},
    };
    for _, info in pairs(self.trees) do
        defaults[info.settingKey] = true;
    end
    configBuilder:SetDefaults(defaults, true);

    local function setEnabledTreeIDs()
        self.enabledTreeIDs = {};
        for treeID, info in pairs(self.trees) do
            self.enabledTreeIDs[treeID] = self.db[info.settingKey] or nil;
        end
    end
    setEnabledTreeIDs();

    configBuilder:MakeCheckbox(
        L['Report Purchases'],
        'reportPurchases',
        L['Print in chat whenever a new talent is purchased.']
    );

    --- @param treeID number
    --- @return SettingsListElementInitializer
    local function makeConfig(treeID)
        local settingKey = self.trees[treeID].settingKey;
        local title = self.trees[treeID].displayName;

        local function isLoaded() return not not self.configIDsByTree[treeID]; end;
        local function isNotLoaded() return not isLoaded(); end;
        local header = configBuilder:MakeHeader(title, nil, 2);
        local loading = configBuilder:MakeText(L['Loading...'] .. '\n' .. L['You have not unlocked the %s system on this character yet.']:format(title), 2);
        loading:AddShownPredicate(isNotLoaded);
        configBuilder:MakeCheckbox(
            ENABLE,
            settingKey,
            L['Automatically purchase %s talents when you have enough currency.']:format(title)
        ):SetParentInitializer(header);
        configBuilder:MakeButton(
            L['Toggle UI'],
            function() self:ToggleTreeUI(treeID); end,
            L['Toggle the %s UI to view and adjust talents.']:format(title)
        ):SetParentInitializer(header, isLoaded);

        return header;
    end

    local skyridingHeader = makeConfig(SKYRIDING_TREE_ID);
    do
        configBuilder:MakeDropdown(
            L['Auto Ride Along'],
            'rideAlong',
            L['Automatically enable/disable Ride Along the first time you log in on a character.'],
            {
                { value = CHOICE_NODE_OPTION_1, text = L['Enable Ride Along'] },
                { value = CHOICE_NODE_OPTION_2, text = L['Disable Ride Along'] },
                { value = CHOICE_NODE_NOT_SET, text = L['Do Nothing'] },
            },
            setEnabledTreeIDs
        ):SetParentInitializer(skyridingHeader);
        configBuilder:MakeButton(
            L['Reset Ride Along Cache'],
            function()
                self.db.rideAlongCache = {};
                self:DeferPurchase();
            end,
            L['Reset the Ride Along cache, so all characters will match the current setting on login.']
        ):SetParentInitializer(skyridingHeader);
        configBuilder:MakeDropdown(
            L['Auto Surge Choice'],
            'surge',
            L['Automatically pick Whirling Surge/Lightning Surge the first time you log in on a character.'],
            {
                { value = CHOICE_NODE_OPTION_1, text = StripHyperlinks(C_Spell.GetSpellLink(WHIRLING_SURGE_SPELL_ID)) or 'Whirling Surge' },
                { value = CHOICE_NODE_OPTION_2, text = StripHyperlinks(C_Spell.GetSpellLink(LIGHTNING_SURGE_SPELL_ID)) or 'Lightning Surge' },
                { value = CHOICE_NODE_NOT_SET, text = L['Do Nothing'] },
            },
            setEnabledTreeIDs
        ):SetParentInitializer(skyridingHeader);
        configBuilder:MakeButton(
            L['Reset Surge Cache'],
            function()
                self.db.surgeCache = {};
                self:DeferPurchase();
            end,
            L['Reset the Surge cache, so all characters will match the current setting on login.']
        ):SetParentInitializer(skyridingHeader);
    end
    makeConfig(OMNIUM_FOLIO_TREE_ID);
    makeConfig(RESHII_WRAPS_TREE_ID);
    makeConfig(HORRIFIC_VISIONS_TREE_ID);
    makeConfig(OVERCHARGED_TITAN_CONSOLE_TREE_ID);
end

function Module:Print(...)
    print('|cff33ff99Talent Tree Tweaks-' .. L['Auto Talent Purchaser:'] .. '|r', ...);
end

function Module:TraitTreeExists(treeID)
    return not not C_Traits.GetConfigIDByTreeID(treeID)
end

function Module:ToggleTreeUI(treeID)
    if not self:TraitTreeExists(treeID) then
        return false;
    end
    GenericTraitUI_LoadUI();
    local systemID = C_Traits.GetSystemIDByTreeID(treeID);
    if GenericTraitFrame.SetConfigIDBySystemID then
        GenericTraitFrame:SetConfigIDBySystemID(systemID);
    else
        GenericTraitFrame:SetSystemID(systemID);
    end
    GenericTraitFrame:SetTreeID(treeID);
    GenericTraitFrame:SetShown(not GenericTraitFrame:IsShown());
    if GenericTraitFrame:GetNumPoints() == 0 then
        GenericTraitFrame:SetPoint('TOPLEFT', 16, -116); -- roughly where it would normally open
    end
    if not tIndexOf(UISpecialFrames, 'GenericTraitFrame') then
        table.insert(UISpecialFrames, 'GenericTraitFrame');
    end
end

function Module:CheckConfig()
    for treeID in pairs(self.trees) do
        local configID = C_Traits.GetConfigIDByTreeID(treeID);
        self.configIDsByTree[treeID] = configID;
        if configID then
            self.treeByConfigID[configID] = treeID;
        end
    end
    if not next(self.configIDsByTree) then
        return;
    end

    self.talentsLoaded = true;
    if self.enabled then
        self:DeferPurchase();
    end
    if table.count(self.configIDsByTree) == table.count(self.trees) then
        for _, event in pairs(self.checkConfigEvents) do
            self:UnregisterEvent(event);
        end
    end
end

function Module:TRAIT_TREE_CURRENCY_INFO_UPDATED(_, treeID)
    local configID = C_Traits.GetConfigIDByTreeID(treeID);
    if not self.purchasing[configID] and self.enabledTreeIDs[treeID] then
        RunNextFrame(function() self:DeferPurchase(); end);
    end
end

function Module:GetCurrencyInfo(treeID, configID)
    local excludeStagedChanges = true;
    local currencyInfo = C_Traits.GetTreeCurrencyInfo(configID, treeID, excludeStagedChanges);

    return currencyInfo;
end

function Module:SetSpecialChoiceNode(configID, settingName, cacheName, nodeID, choiceEntryList)
    if self.purchasing[configID] or self.db[settingName] == CHOICE_NODE_NOT_SET or self.db[cacheName][Util.PlayerKey] then
        return;
    end
    self.purchasing[configID] = true;
    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID);
    if not nodeInfo then
        self.purchasing[configID] = false;
        return;
    end
    local targetEntryID = choiceEntryList[self.db[settingName]];
    if nodeInfo.activeEntry and nodeInfo.activeEntry.entryID == targetEntryID then
        self.purchasing[configID] = false;
        return;
    end
    if C_Traits.SetSelection(configID, nodeID, targetEntryID) and C_Traits.CommitConfig(configID) then
        self.db[cacheName][Util.PlayerKey] = self.db[settingName];
        if self.db.reportPurchases then
            self:Print(L['Automatically set'], self:GetSpellLinkFromEntryID(configID, targetEntryID));
        end
    end

    self.purchasing[configID] = false;
end

function Module:DeferPurchase()
    self.deferredPurchaseFrame:Show();
end

function Module:PurchaseTalents()
    if self.disabledByRefund then return; end

    local purchaseConditions = {
        [RESHII_WRAPS_TREE_ID] = function()
            -- must wait until the quest is complete, or you will not be able to progress the questline
            return C_QuestLog.IsQuestFlaggedCompleted(RESHII_QUEST_ID);
        end,
        [OMNIUM_FOLIO_TREE_ID] = function()
            -- let's wait until the first quest is complete, just in case blizzard dun fucked up again
            return C_QuestLog.IsQuestFlaggedCompletedOnAccount(OMNIUM_FOLIO_QUEST_ID);
        end,
    }
    local ignoredNodeIDs = {
        [SKYRIDING_TREE_ID] = {
            [RIDE_ALONG_NODE_ID] = true,
            [SURGE_NODE_ID] = true,
        },
    };
    local specials = {
        [SKYRIDING_TREE_ID] = function(configID)
            self:SetSpecialChoiceNode(configID, 'rideAlong', 'rideAlongCache', RIDE_ALONG_NODE_ID, RIDE_ALONG_ENTRY_IDS);
            self:SetSpecialChoiceNode(configID, 'surge', 'surgeCache', SURGE_NODE_ID, SURGE_ENTRY_IDS);
        end,
    }
    local delayPurchases = {
        [RESHII_WRAPS_TREE_ID] = 1,
    }

    for treeID in pairs(self.enabledTreeIDs) do
        local configID = self.configIDsByTree[treeID];
        local condition = purchaseConditions[treeID];
        if configID and (not condition or condition()) then
            if specials[treeID] then
                specials[treeID](configID);
            end
            self:DoPurchase(configID, treeID, ignoredNodeIDs[treeID] or {}, delayPurchases[treeID]);
        end
    end
end

--- @param configID number
--- @param treeID number
--- @param ignoredNodeIDs table<number, boolean> # [nodeID] = true to ignore
--- @param delayPurchases nil|number # if set, there will be x seconds delay between each purchase
function Module:DoPurchase(configID, treeID, ignoredNodeIDs, delayPurchases)
    if self.purchasing[configID] or self.disabledByRefund then
        return;
    end

    if C_Traits.ConfigHasStagedChanges(configID) then return; end

    local currencyInfo = self:GetCurrencyInfo(treeID, configID);
    if
        not currencyInfo or
        not currencyInfo[1] or
        not currencyInfo[1].quantity
    then
        -- No currency found
        return;
    end
    local availableCurrency = currencyInfo[1].quantity;

    self.purchasing[configID] = true;
    local nodes = C_Traits.GetTreeNodes(treeID);
    local purchasedEntries = {};
    local purchasedChoiceNode = false;
    local purchasedCount = 0;
    local retriedCommit = false;
    local innerDoPurchase;
    innerDoPurchase = function()
        local purchasedSomething = false;
        for _, nodeID in ipairs(nodes) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID);
            local nodeCost = self:GetOrCacheNodeCost(configID, nodeID);
            if
                nodeInfo
                and nodeInfo.ID == nodeID
                and not ignoredNodeIDs[nodeID]
                and nodeInfo.canPurchaseRank
                and (nodeCost == 0 or nodeCost <= availableCurrency)
            then
                if #nodeInfo.entryIDs == 1 then
                    -- Single entry, just purchase it
                    if C_Traits.PurchaseRank(configID, nodeID) then
                        availableCurrency = availableCurrency - nodeCost;
                        purchasedSomething = true;
                        table.insert(purchasedEntries, nodeInfo.entryIDs[1]);
                    end
                else
                    -- Multiple entries, purchase the first one
                    local entryID = nodeInfo.entryIDs[1];
                    if C_Traits.SetSelection(configID, nodeID, entryID) then
                        availableCurrency = availableCurrency - nodeCost;
                        purchasedSomething = true;
                        purchasedChoiceNode = true;
                        table.insert(purchasedEntries, entryID);
                    end
                end
            end
            if purchasedSomething and delayPurchases then
                purchasedSomething = C_Traits.CommitConfig(configID)
                break; -- only one purchase at a time if delaying
            end
        end
        if purchasedSomething then
            purchasedCount = purchasedCount + 1;
        end
        if purchasedSomething and availableCurrency > 0 then
            if delayPurchases then
                C_Timer.After(delayPurchases, innerDoPurchase);
            else
                innerDoPurchase();
            end
        else
            if #purchasedEntries > 0 then
                if not delayPurchases and not C_Traits.CommitConfig(configID) then
                    if retriedCommit then
                        -- failed to commit, giving up :(
                        self.purchasing[configID] = false;
                        return;
                    end
                    retriedCommit = true;
                    C_Timer.After(0.5, innerDoPurchase);
                    return;
                else
                    self:ReportPurchases(configID, treeID, purchasedEntries, purchasedChoiceNode);
                end
            end

            self.purchasing[configID] = false;
        end
    end
    innerDoPurchase();
end

function Module:GetOrCacheNodeCost(configID, nodeID)
    if not self.nodeCostCache then
        self.nodeCostCache = {};
    end
    if not self.nodeCostCache[nodeID] then
        local nodeCost = C_Traits.GetNodeCost(configID, nodeID);
        self.nodeCostCache[nodeID] = nodeCost and nodeCost[1] and nodeCost[1].amount or 0;
    end
    return self.nodeCostCache[nodeID];
end

function Module:GetSpellLinkFromEntryID(configID, entryID)
    local entryInfo = C_Traits.GetEntryInfo(configID, entryID);
    if entryInfo and entryInfo.definitionID then
        local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID);
        if definitionInfo and (definitionInfo.spellID or definitionInfo.overriddenSpellID) then
            local spellID = definitionInfo.spellID or definitionInfo.overriddenSpellID;
            local spellLink = spellID and GetSpellLink(spellID);

            return spellLink;
        elseif definitionInfo and definitionInfo.overrideName then
            return string.format(
                '|cff71d5ff|Haddon:%s:%d|h[%s]|h|r',
                TOOLTIP_LINK_NAME,
                entryInfo.definitionID,
                definitionInfo.overrideName
            );
        end
    end

    return '[unknown talent]';
end

--- @param configID number
--- @param treeID number
--- @param entryIDs number[]
--- @param purchasedChoiceNode boolean
function Module:ReportPurchases(configID, treeID, entryIDs, purchasedChoiceNode)
    if not self.db.reportPurchases then
        return;
    end
    local spellLinks = {};
    local entryIDCount = {};
    for _, entryID in pairs(entryIDs) do
        entryIDCount[entryID] = (entryIDCount[entryID] or 0) + 1;
    end
    for _, entryID in ipairs(entryIDs) do
        local spellLink = self:GetSpellLinkFromEntryID(configID, entryID);
        if spellLink and entryIDCount[entryID] then
            if entryIDCount[entryID] > 1 then
                spellLink = spellLink .. ' x' .. entryIDCount[entryID];
            end
            table.insert(spellLinks, spellLink);
            entryIDCount[entryID] = nil; -- only add once
        end
    end
    self:Print(
        string.format(
            L['Purchased %d new talents.'] .. ' %s',
            #entryIDs,
            table.concat(spellLinks, ', ')
        )
    );
    if purchasedChoiceNode then
        self:Print(L['Auto selected a choice node.'], string.format(
            '|cff71d5ff|Haddon:%s:%d|h[%s%s]|h|r',
            OPEN_UI_LINK_NAME,
            treeID,
            CreateAtlasMarkup('NPE_LeftClick', 18, 18),
            L['Toggle UI']
        ));
    end
end

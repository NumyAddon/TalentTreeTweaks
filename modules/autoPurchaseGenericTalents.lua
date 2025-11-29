--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

local LINK_NAME = 'TalentTreeTweaks_TraitTooltip';

local SKYRIDING_TREE_ID = Constants.MountDynamicFlightConsts and Constants.MountDynamicFlightConsts.TREE_ID or 672;
local HORRIFIC_VISIONS_TREE_ID = 1057;
local OVERCHARGED_TITAN_CONSOLE_TREE_ID = 1061;
local RESHII_WRAPS_TREE_ID = 1115;
local LEMIX_TREE_ID = 1161;

local RESHII_QUEST_ID = 89561;

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
local LIMITS_UNBOUND_NODE_ID = 108700;

local LEMIX_SEASON_ID = 2;
local IS_LEMIX;

local GetSpellLink = C_Spell.GetSpellLink;

--- @class TTT_GenericTalentModule: NumyConfig_Module, AceEvent-3.0
local Module = Main:NewModule('Skyriding Auto Purchaser', 'AceEvent-3.0');
-- don't rename the module, the settings etc are stored there

function Module:OnInitialize()
    IS_LEMIX = PlayerGetTimerunningSeasonID() == LEMIX_SEASON_ID;
    RunNextFrame(function() IS_LEMIX = PlayerGetTimerunningSeasonID() == LEMIX_SEASON_ID; end);

    --- @type table<number, number> # [specID] = lemixConfigID
    self.lemixConfigIDBySpecID = {};
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
        if
            configID == self.skyridingConfigID
            or configID == self.horrificVisionsConfigID
            or configID == self.overchargedTitanConsoleConfigID
            or configID == self.reshiiWrapsConfigID
        then
            self.disabledByRefund = true;
        end
    end);
    hooksecurefunc(C_Traits, 'SetSelection', function(configID, nodeID, entryID)
        if
            (
                configID == self.skyridingConfigID
                or configID == self.horrificVisionsConfigID
                or configID == self.overchargedTitanConsoleConfigID
                or configID == self.reshiiWrapsConfigID
            )
            and entryID == nil
        then
            self.disabledByRefund = true;
        end
    end);

    self.defferedPurchaseFrame = CreateFrame('Frame');
    self.defferedPurchaseFrame:Hide();
    self.defferedPurchaseFrame:SetScript('OnUpdate', function()
        self.defferedPurchaseFrame:Hide();
        self:PurchaseTalents();
    end);

    EventRegistry:RegisterCallback('SetItemRef', function(_, link, text)
        local linkType, addonName, linkData = strsplit(':', link)
        if linkType == 'addon' and addonName == LINK_NAME then
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
        end
    end);
end

function Module:OnEnable()
    self.enabled = true;
    if self.talentsLoaded then
        self:DefferPurchase();
    end
    self:RegisterEvent('TRAIT_TREE_CURRENCY_INFO_UPDATED');
    self:RegisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED');
end

function Module:OnDisable()
    self.enabled = false;
    self:UnregisterEvent('TRAIT_TREE_CURRENCY_INFO_UPDATED');
    self:UnregisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED');
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
        skyridingEnabled = true,
        rideAlong = CHOICE_NODE_OPTION_1,
        rideAlongCache = {},
        surge = CHOICE_NODE_OPTION_1,
        surgeCache = {},
        horrificVisionsEnabled = true,
        overchargedTitanConsoleEnabled = true,
        reshiiWrapsEnabled = true,
        lemixLimitsUnboundEnabled = true,
    };
    configBuilder:SetDefaults(defaults, true);

    local function setEnabledTreeIDs()
        self.enabledTreeIDs = {
            [SKYRIDING_TREE_ID] = self.db.skyridingEnabled or nil,
            [HORRIFIC_VISIONS_TREE_ID] = self.db.horrificVisionsEnabled or nil,
            [OVERCHARGED_TITAN_CONSOLE_TREE_ID] = self.db.overchargedTitanConsoleEnabled or nil,
            [RESHII_WRAPS_TREE_ID] = self.db.reshiiWrapsEnabled or nil,
            [LEMIX_TREE_ID] = IS_LEMIX and self.db.lemixLimitsUnboundEnabled or nil,
        };
    end
    setEnabledTreeIDs();

    configBuilder:MakeCheckbox(
        L['Report Purchases'],
        'reportPurchases',
        L['Print in chat whenever a new talent is purchased.']
    );

    do
        local function isLoaded() return not not self.skyridingConfigID; end;
        local function isNotLoaded() return not isLoaded; end;
        local header = configBuilder:MakeHeader(GENERIC_TRAIT_FRAME_DRAGONRIDING_TITLE, nil, 2);
        local loading = configBuilder:MakeText(L['Loading...'] .. '\n' .. L['You have not unlocked the Skyriding system on this character yet.'], 2);
        loading:AddShownPredicate(isNotLoaded);
        configBuilder:MakeCheckbox(
            ENABLE,
            'skyridingEnabled',
            L['Automatically purchase %s talents when you have enough currency.']:format(GENERIC_TRAIT_FRAME_DRAGONRIDING_TITLE)
        ):SetParentInitializer(header);
        configBuilder:MakeButton(
            L['Toggle UI'],
            function() self:ToggleTreeUI(SKYRIDING_TREE_ID); end,
            L['Toggle the %s UI to view and adjust talents.']:format(GENERIC_TRAIT_FRAME_DRAGONRIDING_TITLE)
        ):SetParentInitializer(header, isLoaded);
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
        ):SetParentInitializer(header);
        configBuilder:MakeButton(
            L['Reset Ride Along Cache'],
            function()
                self.db.rideAlongCache = {};
                self:DefferPurchase();
            end,
            L['Reset the Ride Along cache, so all characters will match the current setting on login.']
        ):SetParentInitializer(header);
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
        ):SetParentInitializer(header);
        configBuilder:MakeButton(
            L['Reset Surge Cache'],
            function()
                self.db.surgeCache = {};
                self:DefferPurchase();
            end,
            L['Reset the Surge cache, so all characters will match the current setting on login.']
        ):SetParentInitializer(header);
    end
    do
        local function isLoaded() return not not self:GetLemixConfigID(); end;
        local function isNotLoaded() return not isLoaded(); end;
        local function isLemix() return IS_LEMIX; end;
        local header = configBuilder:MakeHeader(L['Legion Remix: Limits Unbound'], nil, 2)
        header:AddShownPredicate(isLemix);

        local loading = configBuilder:MakeText(L['Loading...'] .. '\n' .. L['You have not unlocked Legion Remix artifact traits yet.'], 2);
        loading:AddShownPredicate(isNotLoaded);
        loading:AddShownPredicate(isLemix);

        local enabled = configBuilder:MakeCheckbox(
            ENABLE,
            'lemixLimitsUnboundEnabled',
            L['Automatically upgrade the final Limits Unbound talent when you have enough currency.']
        );
        enabled:AddShownPredicate(isLemix);
        enabled:SetParentInitializer(header);

        local openUI = configBuilder:MakeButton(
            L['Open Artifact Traits UI'],
            function() SocketInventoryItem(16); end,
            L['Open the Legion Remix Artifact traits UI to view and adjust talents.']
        );
        openUI:SetParentInitializer(header, isLoaded)
        openUI:AddShownPredicate(isLemix);
    end
    do
        local function isLoaded() return not not self.reshiiWrapsConfigID; end;
        local function isNotLoaded() return not isLoaded(); end;
        local header = configBuilder:MakeHeader(GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE, nil, 2);
        local loading = configBuilder:MakeText(L['Loading...'] .. '\n' .. L['You have not unlocked the %s system on this character yet.']:format(GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE), 2);
        loading:AddShownPredicate(isNotLoaded);
        configBuilder:MakeCheckbox(
            ENABLE,
            'reshiiWrapsEnabled',
            L['Automatically purchase %s talents when you have enough currency.']:format(GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE)
        ):SetParentInitializer(header);
        configBuilder:MakeButton(
            L['Toggle UI'],
            function() self:ToggleTreeUI(RESHII_WRAPS_TREE_ID); end,
            L['Toggle the %s UI to view and adjust talents.']:format(GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE)
        ):SetParentInitializer(header, isLoaded);
    end
    do
        local HORRIFIC_VISIONS_TITLE = SPLASH_BATTLEFORAZEROTH_8_3_0_FEATURE1_TITLE or L['Horrific Visions'];
        local function isLoaded() return not not self.horrificVisionsConfigID; end;
        local function isNotLoaded() return not isLoaded(); end;
        local header = configBuilder:MakeHeader(HORRIFIC_VISIONS_TITLE, nil, 2);
        local loading = configBuilder:MakeText(L['Loading...'] .. '\n' .. L['You have not unlocked the Horrific Visions system on this character yet.'], 2);
        loading:AddShownPredicate(isNotLoaded);
        configBuilder:MakeCheckbox(
            ENABLE,
            'horrificVisionsEnabled',
            L['Automatically purchase Horrific Visions talents when you have enough currency.']
        ):SetParentInitializer(header);
        configBuilder:MakeButton(
            L['Toggle UI'],
            function() self:ToggleTreeUI(HORRIFIC_VISIONS_TREE_ID); end,
            L['Toggle the %s UI to view and adjust talents.']:format(HORRIFIC_VISIONS_TITLE)
        ):SetParentInitializer(header, isLoaded);
    end
    do
        local function isLoaded() return not not self.overchargedTitanConsoleConfigID; end;
        local function isNotLoaded() return not isLoaded(); end;
        local header = configBuilder:MakeHeader(GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE, nil, 2);
        local loading = configBuilder:MakeText(L['Loading...'] .. '\n' .. L['You have not unlocked the %s system on this character yet.']:format(GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE), 2);
        loading:AddShownPredicate(isNotLoaded);
        configBuilder:MakeCheckbox(
            ENABLE,
            'overchargedTitanConsoleEnabled',
            L['Automatically purchase %s talents when you have enough currency.']:format(GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE)
        ):SetParentInitializer(header);
        configBuilder:MakeButton(
            L['Toggle UI'],
            function() self:ToggleTreeUI(OVERCHARGED_TITAN_CONSOLE_TREE_ID); end,
            L['Toggle the %s UI to view and adjust talents.']:format(GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE)
        ):SetParentInitializer(header, isLoaded);
    end
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

function Module:GetLemixConfigID()
    if not IS_LEMIX then return nil; end
    local specID = PlayerUtil.GetCurrentSpecID() or 0;
    if not self.lemixConfigIDBySpecID[specID] then
        local shown = RemixArtifactFrame and RemixArtifactFrame:IsShown();
        SocketInventoryItem(16);
        if not RemixArtifactFrame then return; end -- happens when you don't have the artifact weapon yet

        self.lemixConfigIDBySpecID[specID] = RemixArtifactFrame:GetConfigID();
        if not shown then
            HideUIPanel(RemixArtifactFrame);
        end
    end

    return self.lemixConfigIDBySpecID[specID];
end

function Module:CheckConfig()
    self.skyridingConfigID = C_Traits.GetConfigIDByTreeID(SKYRIDING_TREE_ID);
    self.horrificVisionsConfigID = C_Traits.GetConfigIDByTreeID(HORRIFIC_VISIONS_TREE_ID);
    self.overchargedTitanConsoleConfigID = C_Traits.GetConfigIDByTreeID(OVERCHARGED_TITAN_CONSOLE_TREE_ID);
    self.reshiiWrapsConfigID = C_Traits.GetConfigIDByTreeID(RESHII_WRAPS_TREE_ID);
    if
        not self.skyridingConfigID
        and not self.horrificVisionsConfigID
        and not self.overchargedTitanConsoleConfigID
        and not self.reshiiWrapsConfigID
        and not self:GetLemixConfigID()
    then
        return;
    end

    self.talentsLoaded = true;
    if self.enabled then
        self:DefferPurchase();
    end
    if
        self.skyridingConfigID
        and self.horrificVisionsConfigID
        and self.overchargedTitanConsoleConfigID
        and self.reshiiWrapsConfigID
        and self:GetLemixConfigID()
    then
        for _, event in pairs(self.checkConfigEvents) do
            self:UnregisterEvent(event);
        end
    end
end

function Module:ACTIVE_PLAYER_SPECIALIZATION_CHANGED()
    if IS_LEMIX then
        RunNextFrame(function() self:DefferPurchase(); end);
    end
end

function Module:TRAIT_TREE_CURRENCY_INFO_UPDATED(_, treeID)
    local configID = C_Traits.GetConfigIDByTreeID(treeID);
    if not self.purchasing[configID] and self.enabledTreeIDs[treeID] then
        RunNextFrame(function() self:DefferPurchase(); end);
    end
end

function Module:GetCurrencyInfo(treeID)
    local configID = C_Traits.GetConfigIDByTreeID(treeID);
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

function Module:DefferPurchase()
    self.defferedPurchaseFrame:Show();
end

function Module:PurchaseTalents()
    if self.db.skyridingEnabled then
        self:PurchaseSkyridingTalents();
    end
    if self.db.horrificVisionsEnabled then
        self:PurchaseHorrificVisionsTalents();
    end
    if self.db.overchargedTitanConsoleEnabled then
        self:PurchaseOverchargedTitanConsoleTalents();
    end
    if self.db.reshiiWrapsEnabled then
        self:PurchaseRishiiWrapsTalents();
    end
    if self.db.lemixLimitsUnboundEnabled then
        self:PurchaseLemixLimitsUnboundTalent();
    end
end

function Module:PurchaseSkyridingTalents()
    if not self.skyridingConfigID then return; end

    local configID = self.skyridingConfigID;
    self:SetSpecialChoiceNode(configID, 'rideAlong', 'rideAlongCache', RIDE_ALONG_NODE_ID, RIDE_ALONG_ENTRY_IDS);
    self:SetSpecialChoiceNode(configID, 'surge', 'surgeCache', SURGE_NODE_ID, SURGE_ENTRY_IDS);

    local ignoredNodeIDs = {
        [RIDE_ALONG_NODE_ID] = true,
        [SURGE_NODE_ID] = true,
    };
    local treeID = SKYRIDING_TREE_ID;
    self:DoPurchase(configID, treeID, ignoredNodeIDs);
end

function Module:PurchaseHorrificVisionsTalents()
    if not self.horrificVisionsConfigID then return; end

    local ignoredNodeIDs = {};
    local configID = self.horrificVisionsConfigID;
    local treeID = HORRIFIC_VISIONS_TREE_ID;
    self:DoPurchase(configID, treeID, ignoredNodeIDs);
end

function Module:PurchaseOverchargedTitanConsoleTalents()
    if not self.overchargedTitanConsoleConfigID then return; end

    local ignoredNodeIDs = {};
    local configID = self.overchargedTitanConsoleConfigID;
    local treeID = OVERCHARGED_TITAN_CONSOLE_TREE_ID;
    self:DoPurchase(configID, treeID, ignoredNodeIDs);
end

function Module:PurchaseRishiiWrapsTalents()
    if not self.reshiiWrapsConfigID then return; end
    if not C_QuestLog.IsQuestFlaggedCompleted(RESHII_QUEST_ID) then
        -- must wait until the quest is complete, or you will not be able to progress the questline
        return;
    end

    local ignoredNodeIDs = {};
    local configID = self.reshiiWrapsConfigID;
    local treeID = RESHII_WRAPS_TREE_ID;
    self:DoPurchase(configID, treeID, ignoredNodeIDs, 1);
end

function Module:PurchaseLemixLimitsUnboundTalent()
    if not IS_LEMIX or not self:GetLemixConfigID() then return; end

    local ignoredNodeIDs = { [LIMITS_UNBOUND_NODE_ID] = false };
    setmetatable(ignoredNodeIDs, { __index = function() return true; end }); -- ignore all other nodes
    local configID = self:GetLemixConfigID();
    local treeID = LEMIX_TREE_ID;
    self:DoPurchase(configID, treeID, ignoredNodeIDs, nil);
end

--- @param configID number
--- @param treeID number
--- @param ignoredNodeIDs table<number, boolean> # [nodeID] = true to ignore
--- @param delayPurchases nil|number # if set, there will be x seconds delay between each purchase
--- @param onSuccessCallback nil|fun() # if set, will be called after all purchases and commits are done
function Module:DoPurchase(configID, treeID, ignoredNodeIDs, delayPurchases, onSuccessCallback)
    if self.purchasing[configID] or self.disabledByRefund then
        -- Already purchasing or disabled by refund
        return;
    end

    if C_Traits.ConfigHasStagedChanges(configID) then return; end

    local currencyInfo = self:GetCurrencyInfo(treeID);
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
    local purchasedCount = 0;
    local retriedCommit = false;
    local innerDoPurchase;
    innerDoPurchase = function()
        local purchasedSomething = false;
        for _, nodeID in ipairs(nodes) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID);
            local nodeCost = self:GetOrCacheNodeCost(nodeID);
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
                    self:ReportPurchases(configID, purchasedEntries);
                end
            end

            self.purchasing[configID] = false;
        end
    end
    innerDoPurchase();
end

function Module:GetOrCacheNodeCost(nodeID)
    if not self.nodeCostCache then
        self.nodeCostCache = {};
    end
    if not self.nodeCostCache[nodeID] then
        local nodeCost = C_Traits.GetNodeCost(self.skyridingConfigID, nodeID);
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
                LINK_NAME,
                entryInfo.definitionID,
                definitionInfo.overrideName
            );
        end
    end

    return '[unknown talent]';
end

function Module:ReportPurchases(configID, entryIDs)
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
end

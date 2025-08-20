local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local LINK_NAME = 'TTT_TraitTooltip';

local SKYRIDING_TREE_ID = Constants.MountDynamicFlightConsts and Constants.MountDynamicFlightConsts.TREE_ID or 672;
local HORRIFIC_VISIONS_TREE_ID = 1057;
local OVERCHARGED_TITAN_CONSOLE_TREE_ID = 1061;
local RESHII_WRAPS_TREE_ID = 1115;

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

local GetSpellLink = C_Spell.GetSpellLink;

--- @class TalentTreeTweaks_GenericTalentModule: AceModule, AceEvent-3.0
local Module = Main:NewModule('Skyriding Auto Purchaser', 'AceEvent-3.0');
-- don't rename the module, the settings etc are stored there

function Module:OnInitialize()
    self.checkConfigEvents = {
        'TRAIT_CONFIG_LIST_UPDATED',
        'TRAIT_CONFIG_CREATED',
        'PLAYER_ENTERING_WORLD',
    };
    for _, event in pairs(self.checkConfigEvents) do
        self:RegisterEvent(event, 'CheckConfig');
    end
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
        self:PurchaseTalents();
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

function Module:GetOptions(defaultOptionsTable, db)
    --- @type TalentTreeTweaks_GenericTalentModuleDB
    self.db = db;
    --- @class TalentTreeTweaks_GenericTalentModuleDB
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
    };
    for k, v in pairs(defaults) do
        if self.db[k] == nil then
            self.db[k] = v;
        end
    end
    local function setEnabledTreeIDs()
        self.enabledTreeIDs = {
            [SKYRIDING_TREE_ID] = self.db.skyridingEnabled or nil,
            [HORRIFIC_VISIONS_TREE_ID] = self.db.horrificVisionsEnabled or nil,
            [OVERCHARGED_TITAN_CONSOLE_TREE_ID] = self.db.overchargedTitanConsoleEnabled or nil,
            [RESHII_WRAPS_TREE_ID] = self.db.reshiiWrapsEnabled or nil,
        };
    end
    setEnabledTreeIDs();

    local function get(info)
        return self.db[info[#info]];
    end
    local function set(info, value)
        self.db[info[#info]] = value;
        setEnabledTreeIDs();
    end
    local increment = CreateCounter(5);

    defaultOptionsTable.args.reportPurchases = {
        type = 'toggle',
        name = L['Report Purchases'],
        desc = L['Print in chat whenever a new talent is purchased.'],
        order = increment(),
        get = get,
        set = set,
    };
    local GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE = GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE or "Reshii Wraps (added in 11.2.0)"

    function Module:BuildOptionsTable()
        local isSkyridingLoaded = not not self.skyridingConfigID;
        local isHorrificVisionsLoaded = not not self.horrificVisionsConfigID;
        local isOverchargedTitanConsoleLoaded = not not self.overchargedTitanConsoleConfigID;
        local isRishiiWrapsLoaded = not not self.reshiiWrapsConfigID;

        defaultOptionsTable.args.skyRiding = {
            type = 'group',
            inline = true,
            name = L['Skyriding'],
            order = increment(),
            args = {
                loading = {
                    type = 'description',
                    name = L['Loading...'] .. '\n' .. L['You have not unlocked the Skyriding system on this character yet.'],
                    order = increment(),
                    hidden = isSkyridingLoaded,
                },
                skyridingEnabled = {
                    type = 'toggle',
                    name = L['Enable'],
                    desc = L['Automatically purchase Skyriding talents when you have enough currency.'],
                    order = increment(),
                    get = get,
                    set = set,
                },
                openUI = {
                    type = 'execute',
                    name = L['Toggle Skyriding UI'],
                    desc = L['Toggle the Skyriding UI to view and adjust talents.'],
                    order = increment(),
                    func = function() self:ToggleTreeUI(SKYRIDING_TREE_ID); end,
                    disabled = not isSkyridingLoaded,
                },
                rideAlong = {
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
                },
                resetRideALongCache = {
                    type = 'execute',
                    name = L['Reset Ride Along Cache'],
                    desc = L['Reset the Ride Along cache, so all characters will match the current setting on login.'],
                    order = increment(),
                    func = function()
                        self.db.rideAlongCache = {};
                        self:PurchaseTalents();
                    end,
                    width = 'double',
                },
                surge = {
                    type = 'select',
                    style = 'radio',
                    name = L['Auto Surge Choice'],
                    desc = L['Automatically pick Whirling Surge/Lightning Surge the first time you log in on a character.'],
                    values = function()
                        return {
                            [CHOICE_NODE_OPTION_1] = StripHyperlinks(self:GetSpellLinkFromEntryID(self.skyridingConfigID, SURGE_ENTRY_IDS[CHOICE_NODE_OPTION_1]) or 'Whirling Surge'),
                            [CHOICE_NODE_OPTION_2] = StripHyperlinks(self:GetSpellLinkFromEntryID(self.skyridingConfigID, SURGE_ENTRY_IDS[CHOICE_NODE_OPTION_2]) or 'Lightning Surge'),
                            [CHOICE_NODE_NOT_SET] = L['Do Nothing'],
                        };
                    end,
                    order = increment(),
                    get = get,
                    set = set,
                },
                resetSurgeCache = {
                    type = 'execute',
                    name = L['Reset Surge Cache'],
                    desc = L['Reset the Surge cache, so all characters will match the current setting on login.'],
                    order = increment(),
                    func = function()
                        self.db.surgeCache = {};
                        self:PurchaseTalents();
                    end,
                    width = 'double',
                },
            },
        };
        defaultOptionsTable.args.reshiiWraps = {
            type = 'group',
            inline = true,
            name = GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE,
            order = increment(),
            args = {
                loading = {
                    type = 'description',
                    name = L['Loading...'] .. '\n' .. L['You have not unlocked the %s system on this character yet.']:format(GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE),
                    order = increment(),
                    hidden = isRishiiWrapsLoaded,
                },
                reshiiWrapsEnabled = {
                    type = 'toggle',
                    name = L['Enable'],
                    desc = L['Automatically purchase %s talents when you have enough currency.']:format(GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE),
                    order = increment(),
                    get = get,
                    set = set,
                },
                openUI = {
                    type = 'execute',
                    name = L['Toggle %s UI']:format(GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE),
                    desc = L['Toggle the %s UI to view and adjust talents.']:format(GENERIC_TRAIT_FRAME_RESHII_WRAPS_TITLE),
                    order = increment(),
                    func = function() self:ToggleTreeUI(RESHII_WRAPS_TREE_ID); end,
                    disabled = not isRishiiWrapsLoaded,
                },
            },
        };
        defaultOptionsTable.args.horrificVisions = {
            type = 'group',
            inline = true,
            name = L['Horrific Visions'],
            order = increment(),
            args = {
                loading = {
                    type = 'description',
                    name = L['Loading...'] .. '\n' .. L['You have not unlocked the Horrific Visions system on this character yet.'],
                    order = increment(),
                    hidden = isHorrificVisionsLoaded,
                },
                horrificVisionsEnabled = {
                    type = 'toggle',
                    name = L['Enable'],
                    desc = L['Automatically purchase Horrific Visions talents when you have enough currency.'],
                    order = increment(),
                    get = get,
                    set = set,
                },
                openUI = {
                    type = 'execute',
                    name = L['Toggle Horrific Visions UI'],
                    desc = L['Toggle the Horrific Visions UI to view and adjust talents.'],
                    order = increment(),
                    func = function() self:ToggleTreeUI(HORRIFIC_VISIONS_TREE_ID); end,
                    disabled = not isHorrificVisionsLoaded,
                },
            },
        };
        defaultOptionsTable.args.overchargedTitanConsole = {
            type = 'group',
            inline = true,
            name = GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE,
            order = increment(),
            args = {
                loading = {
                    type = 'description',
                    name = L['Loading...'] .. '\n' .. L['You have not unlocked the %s system on this character yet.']:format(GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE),
                    order = increment(),
                    hidden = isOverchargedTitanConsoleLoaded,
                },
                overchargedTitanConsoleEnabled = {
                    type = 'toggle',
                    name = L['Enable'],
                    desc = L['Automatically purchase %s talents when you have enough currency.']:format(GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE),
                    order = increment(),
                    get = get,
                    set = set,
                },
                openUI = {
                    type = 'execute',
                    name = L['Toggle %s UI']:format(GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE),
                    desc = L['Toggle the %s UI to view and adjust talents.']:format(GENERIC_TRAIT_FRAME_TITAN_CONSOLE_TITLE),
                    order = increment(),
                    func = function() self:ToggleTreeUI(OVERCHARGED_TITAN_CONSOLE_TREE_ID); end,
                    disabled = not isOverchargedTitanConsoleLoaded,
                },
            },
        };
    end
    self:BuildOptionsTable();

    return defaultOptionsTable;
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
    GenericTraitFrame:SetSystemID(systemID);
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
    self.skyridingConfigID = C_Traits.GetConfigIDByTreeID(SKYRIDING_TREE_ID);
    self.horrificVisionsConfigID = C_Traits.GetConfigIDByTreeID(HORRIFIC_VISIONS_TREE_ID);
    self.overchargedTitanConsoleConfigID = C_Traits.GetConfigIDByTreeID(OVERCHARGED_TITAN_CONSOLE_TREE_ID);
    self.reshiiWrapsConfigID = C_Traits.GetConfigIDByTreeID(RESHII_WRAPS_TREE_ID);
    if
        not self.skyridingConfigID
        and not self.horrificVisionsConfigID
        and not self.overchargedTitanConsoleConfigID
        and not self.reshiiWrapsConfigID
    then return; end

    self:BuildOptionsTable();
    Main:NotifyConfigChange();
    self.talentsLoaded = true;
    if self.enabled then
        self:PurchaseTalents();
    end
    if
        self.skyridingConfigID
        and self.horrificVisionsConfigID
        and self.overchargedTitanConsoleConfigID
        and self.reshiiWrapsConfigID
    then
        for _, event in pairs(self.checkConfigEvents) do
            self:UnregisterEvent(event);
        end
    end
end

function Module:TRAIT_TREE_CURRENCY_INFO_UPDATED(_, treeID)
    if not self.purchasing and self.enabledTreeIDs[treeID] then
        RunNextFrame(function() self:PurchaseTalents(); end);
    end
end

function Module:GetCurrencyInfo(treeID)
    local configID = C_Traits.GetConfigIDByTreeID(treeID);
    local excludeStagedChanges = true;
    local currencyInfo = C_Traits.GetTreeCurrencyInfo(configID, treeID, excludeStagedChanges);

    return currencyInfo;
end

function Module:SetSpecialChoiceNode(configID, settingName, cacheName, nodeID, choiceEntryList)
    if self.purchasing or self.db[settingName] == CHOICE_NODE_NOT_SET or self.db[cacheName][Util.PlayerKey] then
        return;
    end
    self.purchasing = true;
    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID);
    if not nodeInfo then
        self.purchasing = false;
        return;
    end
    local targetEntryID = choiceEntryList[self.db[settingName]];
    if nodeInfo.activeEntry and nodeInfo.activeEntry.entryID == targetEntryID then
        self.purchasing = false;
        return;
    end
    if C_Traits.SetSelection(configID, nodeID, targetEntryID) and C_Traits.CommitConfig(configID) then
        self.db[cacheName][Util.PlayerKey] = self.db[settingName];
        if self.db.reportPurchases then
            self:Print(L['Automatically set'], self:GetSpellLinkFromEntryID(configID, targetEntryID));
        end
    end

    self.purchasing = false;
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
    self:DoPurchase(configID, treeID, ignoredNodeIDs);
end

function Module:DoPurchase(configID, treeID, ignoredNodeIDs)
    if self.purchasing or self.disabledByRefund then
        -- Already purchasing or disabled by refund
        return;
    end

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

    self.purchasing = true;
    local nodes = C_Traits.GetTreeNodes(treeID);
    local purchasedEntries = {};
    repeat
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
        end
    until (availableCurrency <= 0 or not purchasedSomething)
    if #purchasedEntries > 0 and C_Traits.CommitConfig(configID) then
        self:ReportPurchases(configID, purchasedEntries);
    end

    self.purchasing = false;
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
    for _, entryID in ipairs(entryIDs) do
        local spellLink = self:GetSpellLinkFromEntryID(configID, entryID);
        if spellLink then
            table.insert(spellLinks, spellLink);
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

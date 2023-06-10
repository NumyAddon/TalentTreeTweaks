local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local Module = Main:NewModule('AlwaysShowGates', 'AceHook-3.0');
--- @type LibTalentTree
local LTT = Util.LibTalentTree;
local GATE_TEXT_FORMAT = '%d (+%d)';
local TOOLTIP_FORMAT = L['%d points spent past the gate.\n%d extra points above the gate are free to be moved away.'];

function Module:OnInitialize()
    self.gateInfo = {};
end

function Module:OnEnable()
    Util:OnClassTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if ClassTalentFrame and ClassTalentFrame.TalentsTab then
        ClassTalentFrame.TalentsTab:RefreshGates();
    end
end

function Module:GetDescription()
    return L['Always show the "x more points required" gates. Gates that are passed will be semi-transparent.'];
end

function Module:GetName()
    return L['Always Show Gates'];
end

function Module:SetupHook()
    local talentFrame = ClassTalentFrame.TalentsTab;
    -- We have to create our own gatePool, because otherwise we will cause massive taint issues
    -- when acquiring a gate from the pool. Using our own pool causes no such issues
    self.gatePool = self.gatePool or CreateFramePool("FRAME", talentFrame.ButtonsParent, "TalentFrameGateTemplate");
    self:SecureHook(talentFrame, 'RefreshGates', function() RunNextFrame(function() self:RefreshGates() end) end);
    self:RefreshGates();
end

local function GateOnEnter(gate)
    if not gate or not gate.tooltip then return; end
    local tooltip = GameTooltip;
    tooltip:SetOwner(gate, "ANCHOR_LEFT", 4, -4);
    tooltip:AddLine(gate.tooltip);
    tooltip:Show();
end

function Module:RefreshGates()
    local talentFrame = ClassTalentFrame.TalentsTab;
    self.gatePool:ReleaseAll();

    if not talentFrame.talentTreeInfo or not talentFrame.talentTreeInfo.gates then
        return;
    end

    for i, gateInfo in ipairs(talentFrame.talentTreeInfo.gates) do
        local firstButton = talentFrame:GetTalentButtonByNodeID(gateInfo.topLeftNodeID);
        local condInfo = talentFrame:GetAndCacheCondInfo(gateInfo.conditionID);
        if firstButton and firstButton:IsVisible() and condInfo.isMet then
            local gate = self.gatePool:Acquire();
            gate:SetScript('OnEnter', GateOnEnter);
            condInfo = self:EnrichConditionInfo(condInfo);
            gate:Init(talentFrame, firstButton, condInfo);
            talentFrame:AnchorGate(gate, firstButton);
            gate:Show();
            gate:SetAlpha(0.4);
            gate.tooltip = condInfo.tooltip;

            talentFrame:OnGateDisplayed(gate, firstButton, condInfo);
        end
    end
end

function Module:EnrichConditionInfo(condInfo)
    if not LTT then return condInfo; end
    local talentFrame = ClassTalentFrame.TalentsTab;
    local specID = talentFrame:GetSpecID();
    self.gateInfo[specID] = self.gateInfo[specID] or LTT:GetGates(specID);

    for _, gateInfo in ipairs(self.gateInfo[specID]) do
        if gateInfo.conditionID == condInfo.condID then
            local spentAmountRequired = gateInfo.spentAmountRequired;
            local currencyID = gateInfo.traitCurrencyID;
            local spent = talentFrame.treeCurrencyInfoMap[currencyID].spent;
            local extraSpentAboveGate = (0 - spentAmountRequired) + self:GetCurrencySpentAboveGate(condInfo.condID, currencyID);
            local extraSpent = spentAmountRequired - spent;
            condInfo = Mixin({}, condInfo);
            condInfo.spentAmountRequired = GATE_TEXT_FORMAT:format(extraSpent, extraSpentAboveGate);
            condInfo.tooltip = TOOLTIP_FORMAT:format(0 - extraSpent, extraSpentAboveGate);

            return condInfo;
        end
    end

    return condInfo;
end

function Module:GetCurrencySpentAboveGate(condID, currencyID)
    local talentFrame = ClassTalentFrame.TalentsTab;
    local nodesAboveGate = self:GetNodesAboveGate(condID, currencyID);
    local spent = 0;
    for _, nodeID in ipairs(nodesAboveGate) do
        local nodeInfo = talentFrame:GetAndCacheNodeInfo(nodeID);
        if nodeInfo and nodeInfo.ranksPurchased then
            spent = spent + nodeInfo.ranksPurchased;
        end
    end

    return spent;
end

local nodesCache = {};
function Module:GetNodes()
    local talentFrame = ClassTalentFrame.TalentsTab;
    local treeID = talentFrame:GetTalentTreeID();
    if not nodesCache[treeID] then
        nodesCache[treeID] = C_Traits.GetTreeNodes(treeID);
    end

    return nodesCache[treeID];
end

local nodesAboveGateCache = {};
function Module:GetNodesAboveGate(condID, currencyID)
    if not nodesAboveGateCache[condID] then
        local talentFrame = ClassTalentFrame.TalentsTab;
        local treeID = talentFrame:GetTalentTreeID();
        local nodes = self:GetNodes();
        local nodesAboveGate = {};
        local currencyIsClassCurrency = self:IsCurrencyClassCurrency(currencyID);
        for _, nodeID in ipairs(nodes) do
            local nodeInfo = talentFrame:GetAndCacheNodeInfo(nodeID);
            if nodeInfo and (LTT:IsClassNode(treeID, nodeID) == currencyIsClassCurrency) then
                local conditionFound = false;
                for _, conditionID in ipairs(nodeInfo.conditionIDs) do
                    if conditionID == condID then
                        conditionFound = true;
                        break;
                    end
                end
                if not conditionFound then
                    table.insert(nodesAboveGate, nodeID);
                end
            end
        end

        nodesAboveGateCache[condID] = nodesAboveGate;
    end

    return nodesAboveGateCache[condID];
end

local currencyCache = {};
function Module:IsCurrencyClassCurrency(currencyID)
    if currencyCache[currencyID] == nil then
        local talentFrame = ClassTalentFrame.TalentsTab;
        local configID = talentFrame:GetConfigID();
        local treeID = talentFrame:GetTalentTreeID();
        for i, currencyInfo in ipairs(C_Traits.GetTreeCurrencyInfo(configID, treeID, true)) do
            currencyCache[currencyInfo.traitCurrencyID] = i == 1;
        end
    end

    return currencyCache[currencyID];
end

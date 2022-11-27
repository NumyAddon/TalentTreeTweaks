local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;

local Module = Main:NewModule('AlwaysShowGates', 'AceHook-3.0');
--- @type LibTalentTree
local LTT = LibStub('LibTalentTree-1.0');

function Module:OnInitialize()
    self.gateInfo = {};
end

function Module:OnEnable()
    EventUtil.ContinueOnAddOnLoaded('Blizzard_ClassTalentUI', function()
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
    return 'Always show the "x more points required" gates. Gates that are passed will be semi-transparent.';
end

function Module:GetName()
    return 'Always Show Gates';
end

function Module:SetupHook()
    local talentFrame = ClassTalentFrame.TalentsTab;
    -- We have to create our own gatePool, because otherwise we will cause massive taint issues
    -- when acquiring a gate from the pool. Using our own pool causes no such issues
    self.gatePool = self.gatePool or CreateFramePool("FRAME", talentFrame.ButtonsParent, "TalentFrameGateTemplate");
    self:SecureHook(talentFrame, 'RefreshGates');
    self:RefreshGates();
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
            condInfo = self:EnrichConditionInfo(condInfo);
            gate:Init(talentFrame, firstButton, condInfo);
            talentFrame:AnchorGate(gate, firstButton);
            gate:Show();
            gate:SetAlpha(0.4);

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
            condInfo = Mixin({}, condInfo);
            condInfo.spentAmountRequired = spentAmountRequired - spent;

            return condInfo;
        end
    end

    return condInfo;
end

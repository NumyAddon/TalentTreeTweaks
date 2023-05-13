local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local Module = Main:NewModule('UnlockRestrictions', 'AceHook-3.0');
Module.ignoredErrors = {
    [ERR_TALENT_FAILED_IN_COMBAT] = true,
};
Module.textsToUnlock = {};

function Module:OnInitialize()
    local texts = {
        TALENT_FRAME_DROP_DOWN_EXPORT,
        TALENT_FRAME_DROP_DOWN_EXPORT_CLIPBOARD,
        TALENT_FRAME_DROP_DOWN_EXPORT_CHAT_LINK,
    };
    for _, text in pairs(texts) do
        self.textsToUnlock[text] = true;
    end
end

function Module:OnEnable()
    self.enabled = true;
    Util:OnClassTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self.enabled = false;
    self:UnhookAll();
end

function Module:GetDescription()
    return L['Unlocks several restrictions on the talent tree UI, such as being able to spend points while in combat, and being able to share your build without spending all points.'];
end

function Module:GetName()
    return L['Unlock Restrictions'];
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db
    local defaults = {
        unlockShareButton = true,
        unlockInCombatSpending = true,
    };
    for key, value in pairs(defaults) do
        if db[key] == nil then
            db[key] = value;
        end
    end

    local get = function(info) return self.db[info[#info]] end
    local set = function(info, value) self.db[info[#info]] = value end

    defaultOptionsTable.args.unlockShareButton = {
        type = 'toggle',
        name = L['Unlock Share Button'],
        desc = L['Unlocks the share button, so you can share your build without spending all points.'],
        order = 5,
        width = 'double',
        get = get,
        set = set,
    };
    defaultOptionsTable.args.unlockInCombatSpending = {
        type = 'toggle',
        name = L['Unlock In Combat Spending'],
        desc = L['Unlocks the talent buttons, so you can reallocate points while in combat.'],
        order = 6,
        width = 'double',
        get = get,
        set = set,
    };

    return defaultOptionsTable;
end

function Module:SetupHook()
    self:UpdateShareButton();
    -- todo: hook SetVisualState and ignore the in-combat locked state
    EventRegistry:RegisterCallback('TalentButton.OnClick', self.OnButtonClick, self);
end

function Module:UpdateShareButton()
    local dropdown = ClassTalentFrame.TalentsTab.LoadoutDropDown;
    for _, sentinelInfo in pairs(dropdown.sentinelKeyToInfo) do
        if self.textsToUnlock[sentinelInfo.text] then
            self.textsToUnlock[sentinelInfo.text] = nil;
            local oldDisabledCallback = sentinelInfo.disabledCallback;
            sentinelInfo.disabledCallback = function(...)
                return not ((self.enabled and self.db.unlockShareButton) or not oldDisabledCallback(...));
            end;
        end
    end
end

Module.ButtonTypes = {
    SpendButton = 1, -- regular buttons
    SelectButton = 2, -- choice talent base button
    SelectionChoiceButton = 3, -- choice talent, choice specific button
};
function Module:DetermineButtonType(talentButton)
    if talentButton.talentSelections then
        return self.ButtonTypes.SelectButton;
    end
    if talentButton.selectionIndex then
        return self.ButtonTypes.SelectionChoiceButton;
    end
    return self.ButtonTypes.SpendButton;
end

function Module:OnButtonClick(talentButton, mouseButton)
    if
        not self.db.unlockInCombatSpending
        or talentButton.talentFrame ~= ClassTalentFrame.TalentsTab
        or talentButton:IsInspecting()
    then
        return
    end

    local canEditTalents, errorMessage = C_ClassTalents.CanEditTalents();
    if not canEditTalents and self.ignoredErrors[errorMessage] then
        local buttonType = self:DetermineButtonType(talentButton);
        local configID = talentButton:GetTalentFrame():GetConfigID();
        local baseButton = talentButton.GetBaseButton and talentButton:GetBaseButton() or talentButton;

        if mouseButton == "LeftButton" then
            if IsShiftKeyDown() and self:CanCascadeRepurchaseRanks(talentButton) then
                baseButton:PlaySelectSound();
                C_Traits.CascadeRepurchaseRanks(configID, baseButton:GetNodeID());
            elseif IsModifiedClick("CHATLINK") then
                -- handled in original OnClick
            elseif buttonType == self.ButtonTypes.SpendButton and self:CanPurchaseRank(talentButton) then
                baseButton:PlaySelectSound();
                C_Traits.PurchaseRank(configID, baseButton:GetNodeID());
            elseif buttonType == self.ButtonTypes.SelectButton then
                -- clicking the base button of a choice talent should do nothing
            elseif buttonType == self.ButtonTypes.SelectionChoiceButton and self:CanSelectChoice(talentButton) then
                local selectionChoiceFrame = talentButton:GetParent();
                selectionChoiceFrame:SetSelectedEntryID(talentButton:GetEntryID(), talentButton:GetDefinitionInfo());
            end
        elseif mouseButton == "RightButton" then
            if buttonType == self.ButtonTypes.SpendButton and self:CanRefundRank(talentButton) then
                baseButton:PlayDeselectSound();
                C_Traits.RefundRank(configID, baseButton:GetNodeID());
            elseif buttonType == self.ButtonTypes.SelectButton then
                -- for some reason, this isn't blocked in base UI
            elseif buttonType == self.ButtonTypes.SelectionChoiceButton then
                -- for some reason, this isn't blocked in base UI
            elseif talentButton:IsGhosted() then
                talentButton:ClearCascadeRepurchaseHistory();
            end
        end
    end
end

function Module:IsTalentButtonLocked(baseButton)
    return not baseButton or not baseButton.nodeInfo or not baseButton.nodeInfo.meetsEdgeRequirements;
end

function Module:CanCascadeRepurchaseRanks(talentButton)
    local baseButton = talentButton.GetBaseButton and talentButton:GetBaseButton() or talentButton;

    local isLocked = self:IsTalentButtonLocked(baseButton);
    local isGated = not baseButton or baseButton:IsGated();

    return not isLocked and not isGated and talentButton:IsCascadeRepurchasable();
end

function Module:CanPurchaseRank(talentButton)
    local baseButton = talentButton.GetBaseButton and talentButton:GetBaseButton() or talentButton;

    return baseButton.nodeInfo and not self:IsTalentButtonLocked(baseButton) and baseButton.nodeInfo.canPurchaseRank and baseButton:CanAfford();
end

function Module:CanRefundRank(talentButton)
    local baseButton = talentButton.GetBaseButton and talentButton:GetBaseButton() or talentButton;
    local nodeInfo = baseButton.nodeInfo;

    return nodeInfo and not self:IsTalentButtonLocked(baseButton) and nodeInfo.canRefundRank and nodeInfo.ranksPurchased and (nodeInfo.ranksPurchased > 0);
end

function Module:CanSelectChoice(talentButton)
    local baseButton = talentButton.GetBaseButton and talentButton:GetBaseButton() or talentButton;

    return talentButton.CanSelectChoice and talentButton.entryInfo.isAvailable and not talentButton.isCurrentSelection and not self:IsTalentButtonLocked(baseButton);
end

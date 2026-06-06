--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

--- @class TTT_BulkProfessionUpgrade: NumyConfig_Module, AceHook-3.0
local Module = Main:NewModule('BulkProfessionUpgrade', 'AceHook-3.0');

function Module:OnEnable()
    Util:ContinueOnAddonLoaded('Blizzard_Professions', function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if ProfessionsFrame and ProfessionsFrame.SpecPage then
        self:RestoreSpendPointsButton(ProfessionsFrame.SpecPage);
    end
end

function Module:GetDescription()
    return L['Adds bulk spending to the profession specialization Spend Points button.'];
end

function Module:GetName()
    return L['Bulk Profession Upgrade'];
end

function Module:SetupHook()
    if ProfessionsFrame and ProfessionsFrame.SpecPage then
        self:SecureHook(ProfessionsFrame.SpecPage, 'ConfigureButtons', function(specPage)
            self:OverrideSpendPointsButton(specPage);
        end);

        self:OverrideSpendPointsButton(ProfessionsFrame.SpecPage);
    end
end

--- @param specPage ProfessionsFrame_SpecPage
function Module:OnSpendPointsClick(specPage)
    local currRank, maxRank = specPage:GetDetailedPanelPath():GetRanks();
    local targetRank = currRank + 1;
    if IsShiftKeyDown() then
        targetRank = maxRank;
    elseif IsControlKeyDown() then
        targetRank = currRank + (5 - (currRank % 5))
    end
    for i = currRank, targetRank - 1 do
        specPage:PurchaseRank(specPage:GetDetailedPanelNodeID());
    end
    PlaySound(SOUNDKIT.UI_PROFESSION_SPEC_PATH_SPEND);
end

--- @param specPage ProfessionsFrame_SpecPage
function Module:OverrideSpendPointsButton(specPage)
    if not specPage or not specPage.DetailedView then
        return;
    end

    local button = specPage.DetailedView.SpendPointsButton;
    if not button then
        return;
    end

    button:SetScript('OnClick', function()
        Module:OnSpendPointsClick(specPage);
    end);

    button:SetScript('OnEnter', function()
        GameTooltip:SetOwner(button, 'ANCHOR_RIGHT');
        GameTooltip:SetText(L['Bulk Apply Knowledge']);
        GameTooltip:AddLine(L['|cffeda55fClick|r to spend a point on this path.'], 1, 1, 1, true);
        GameTooltip:AddLine(L['|cffeda55fCTRL-Click|r to spend up to the next 5 point breakpoint.'], 1, 1, 1, true);
        GameTooltip:AddLine(L['|cffeda55fShift-Click|r to spend all points on this path.'], 1, 1, 1, true);
        GameTooltip:Show();
    end);
end

--- @param specPage ProfessionsFrame_SpecPage
function Module:RestoreSpendPointsButton(specPage)
    if not specPage.DetailedView then
        return;
    end

    local button = specPage.DetailedView.SpendPointsButton;
    if not button then
        return;
    end

    button:SetScript('OnClick', function()
        specPage:PurchaseRank(specPage:GetDetailedPanelNodeID());
        PlaySound(SOUNDKIT.UI_PROFESSION_SPEC_PATH_SPEND);
    end);
    button:SetScript('OnEnter', nil);
end

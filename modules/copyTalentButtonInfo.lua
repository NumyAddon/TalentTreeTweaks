local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @class TalentTreeTweaks_CopyTalentButtonInfo: AceModule, AceHook-3.0, AceEvent-3.0
local Module = Main:NewModule('CopyTalentButtonInfo', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnInitialize()
    self.bindingButton = CreateFrame('Button', 'TalentTreeTweaks_CopyTalentButtonInfoButton');
    self.bindingButton:SetScript('OnClick', function()
        if self.textToCopy then
            Util:CopyText(self.textToCopy, L['SpellID']);
        end
    end);
end

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupHook(Util:GetTalentFrame());
    end);
    EventUtil.ContinueOnAddOnLoaded('Blizzard_GenericTraitUI', function()
        self:SetupHook(GenericTraitFrame);
    end);
    EventUtil.ContinueOnAddOnLoaded(TalentViewerLoader and TalentViewerLoader:GetLodAddonName() or 'TalentTreeViewer', function()
        local talentsTab = TalentViewer and TalentViewer.GetTalentFrame and TalentViewer:GetTalentFrame();
        if not talentsTab then return; end
        self:SetupHook(talentsTab);
    end)
    self:RegisterEvent('PLAYER_REGEN_DISABLED');
    self:RegisterEvent('PLAYER_REGEN_ENABLED');
    EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", self.OnTalentTooltipCreated, self)
end

function Module:OnDisable()
    self.textToCopy = nil;
    self:DisableBinding();
    self:UnhookAll();

    local talentFrame = Util:GetTalentFrame(true);
    if talentFrame then
        talentFrame:UnregisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self);
        Util:GetTalentContainerFrame().SpellBookFrame.PagedSpellsFrame:UnregisterCallback('OnUpdate', self);
    end
    if GenericTraitFrame then
        GenericTraitFrame:UnregisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self);
    end
    EventRegistry:UnregisterCallback("TalentDisplay.TooltipCreated", self)
end

function Module:GetDescription()
    return L['Allows you to press CTRL-C to copy the spellID of a talent, while hovering over it.'];
end

function Module:GetName()
    return L['Copy SpellID on hover'];
end

function Module:SetupHook(talentsTab)
    talentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    for talentButton in talentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton);
    end
    self:SecureHook(talentsTab, 'ShowSelections', 'OnShowSelections');
    EventRegistry:RegisterCallback("PlayerSpellsFrame.SpellBookFrame.DisplayedSpellsChanged", self.OnSpellbookUpdate, self);
    self:OnSpellbookUpdate();
end

function Module:EnableBinding()
    if not InCombatLockdown() then
        SetOverrideBinding(
            self.bindingButton,
            true,
            'CTRL-C',
            string.format('CLICK %s:LeftButton', self.bindingButton:GetName())
        );
    end
end

function Module:DisableBinding()
    if not InCombatLockdown() then
        ClearOverrideBindings(self.bindingButton);
    end
end

function Module:PLAYER_REGEN_DISABLED()
    if self.textToCopy then
        self:DisableBinding();
    end
end

function Module:PLAYER_REGEN_ENABLED()
    if self.textToCopy then
        self:EnableBinding();
    end
end

function Module:OnTalentButtonEnter(talentButton)
    self.textToCopy = talentButton:GetSpellID();
    self:EnableBinding();
end

function Module:OnTalentButtonLeave()
    self.textToCopy = nil;
    self:DisableBinding();
end

function Module:OnTalentButtonAcquired(talentButton)
    if self:IsHooked(talentButton, 'OnEnter') then
        return;
    end
    self:SecureHookScript(talentButton, 'OnEnter', 'OnTalentButtonEnter');
    self:SecureHookScript(talentButton, 'OnLeave', 'OnTalentButtonLeave');
end

function Module:OnShowSelections(talentsTab)
    for _, button in pairs(talentsTab.SelectionChoiceFrame.selectionFrameArray) do
        self:OnTalentButtonAcquired(button);
    end
end

function Module:OnSpellbookButtonEnter(button)
    local spellFrame = button:GetParent();
    local spellID = spellFrame.spellBookItemInfo and spellFrame.spellBookItemInfo.spellID;
    if not spellID then return; end
    self.textToCopy = spellID;
    self:EnableBinding();
    self:OnTalentTooltipCreated(nil, GameTooltip);
end

function Module:OnSpellbookButtonLeave()
    self.textToCopy = nil;
    self:DisableBinding();
end

Module.hookedTooltipFrames = {};
function Module:OnSpellbookUpdate()
    local spellBookFrame = Util:GetTalentContainerFrame().SpellBookFrame;

	for _, frame in pairs(spellBookFrame.PagedSpellsFrame.frames) do
		if frame.elementData and frame.spellBookItemInfo then -- Avoid header or spacer frames
            local button = frame.Button;
            if self:IsHooked(button, 'OnEnter') then
                return;
            end
            self.hookedTooltipFrames[button] = true;
            self:SecureHookScript(button, 'OnEnter', 'OnSpellbookButtonEnter');
            self:SecureHookScript(button, 'OnLeave', 'OnSpellbookButtonLeave');
		end
	end
end

function Module:OnTalentTooltipCreated(_, tooltip)
    local text = GREEN_FONT_COLOR:WrapTextInColorCode(L['CTRL-C to copy spellID']);
    if InCombatLockdown() then
        text = string.format('%s|cFFFF0000 %s|r', text, L['blocked in combat']);
    end
    tooltip:AddLine(text);
    tooltip:Show();
end

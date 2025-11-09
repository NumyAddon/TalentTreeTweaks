--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

--- @class TTT_DebugNodeInfo: TTT_Module, AceHook-3.0, AceEvent-3.0
local Module = Main:NewModule('DebugNodeInfo', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnInitialize()
    self.bindingButton = CreateFrame('Button', 'TalentTreeTweaks_DebugNodeInfoButton');
    self.bindingButton:SetScript('OnClick', function()
        if self.targetButton then
            self:ShowDebugInfo(self.targetButton);
        end
    end);
end

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupHook(Util:GetTalentFrame());
    end);
    Util:ContinueOnAddonLoaded('Blizzard_GenericTraitUI', function()
        self:SetupHook(GenericTraitFrame);
    end);
    Util:ContinueOnAddonLoaded('Blizzard_RemixArtifactUI', function()
        self:SetupHook(RemixArtifactFrame);
    end);
    Util:ContinueOnAddonLoaded(TalentViewerLoader and TalentViewerLoader:GetLodAddonName() or 'TalentTreeViewer', function()
        local talentsTab = TalentViewer and TalentViewer.GetTalentFrame and TalentViewer:GetTalentFrame();
        if not talentsTab then return; end
        self:SetupHook(talentsTab);
    end);
    self:RegisterEvent('PLAYER_REGEN_DISABLED');
    self:RegisterEvent('PLAYER_REGEN_ENABLED');
    EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", self.OnTalentTooltipCreated, self)
end

function Module:OnDisable()
    self.targetButton = nil;
    self:DisableBinding();
    self:UnhookAll();

    local talentFrame = Util:GetTalentFrameIfLoaded();
    if talentFrame then
        talentFrame:UnregisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self);
    end
    if TalentViewer then
        TalentViewer:GetTalentFrame():UnregisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self);
    end
    if GenericTraitFrame then
        GenericTraitFrame:UnregisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self);
    end
    if RemixArtifactFrame then
        RemixArtifactFrame:UnregisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self);
    end
    EventRegistry:UnregisterCallback("TalentDisplay.TooltipCreated", self)
end

function Module:GetDescription()
    return L['Allows you to press CTRL-D to open a table inspector of your choice, with the nodeInfo associated with the node.'];
end

function Module:GetName()
    return L['Debug Talent.nodeInfo'];
end

--- @param configBuilder TTT_ConfigBuilder
--- @param db TTT_DebugNodeInfoDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class TTT_DebugNodeInfoDB
    local defaults = {
        tinspect = true,
        viragDevTool = true,
        luaBrowser = true,
        slashDump = false,
    };
    configBuilder:SetDefaults(defaults, true);

    configBuilder:MakeText(L['You can toggle any of the following on/off to enable/disable the integration with that debug tool.']);

    configBuilder:MakeCheckbox(
        '/tinspect',
        'tinspect',
        L['Opens Blizzard\'s table inspect window.']
    );
    configBuilder:MakeCheckbox(
        '(Virag-)DevTool',
        'viragDevTool',
        L['Use (Virag-)DevTool to inspect the nodeInfo table.']
    ):AddModifyPredicate(function()
        return select(4, C_AddOns.GetAddOnInfo('ViragDevTool')) or select(4, C_AddOns.GetAddOnInfo('DevTool')); -- 4-> loadable
    end);
    configBuilder:MakeCheckbox(
        'LuaBrowser',
        'luaBrowser',
        L['Use LuaBrowser to inspect the nodeInfo table.']
    ):AddModifyPredicate(function()
        return select(4, C_AddOns.GetAddOnInfo('LuaBrowser')); -- 4-> loadable
    end);
    configBuilder:MakeCheckbox(
        '/dump',
        'slashDump',
        L['Dump the nodeInfo table to chat.']
    );
end

function Module:SetupHook(talentsTab)
    talentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    for talentButton in talentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton);
    end
    self:SecureHook(talentsTab, 'ShowSelections', 'OnShowSelections');
end

function Module:EnableBinding()
    if not InCombatLockdown() then
        SetOverrideBinding(
            self.bindingButton,
            true,
            'CTRL-D',
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
    if self.targetButton then
        self:DisableBinding();
    end
end

function Module:PLAYER_REGEN_ENABLED()
    if self.targetButton then
        self:EnableBinding();
    end
end

function Module:OnTalentButtonEnter(talentButton)
    self.targetButton = talentButton;
    self:EnableBinding();
end

function Module:OnTalentButtonLeave()
    self.targetButton = nil;
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

function Module:OnTalentTooltipCreated(_, tooltip)
    local text = GREEN_FONT_COLOR:WrapTextInColorCode(L['CTRL-D to debug nodeInfo']);
    if InCombatLockdown() then
        text = string.format('%s|cFFFF0000 %s|r', text, L['blocked in combat']);
    end
    tooltip:AddLine(text);
    tooltip:Show();
end

function Module:ShowDebugInfo(buttonFrame)
    local nodeInfo = buttonFrame.nodeInfo or buttonFrame.GetNodeInfo and buttonFrame:GetNodeInfo() or {};
    nodeInfo = Mixin({}, nodeInfo);
    nodeInfo._entryInfo = buttonFrame.entryInfo or buttonFrame.GetEntryInfo and buttonFrame:GetEntryInfo() or nil;

    if self.db.slashDump then
        DevTools_Dump(nodeInfo, 'value');
    end

    nodeInfo._button = buttonFrame;

    if self.db.tinspect then
        UIParentLoadAddOn("Blizzard_DebugTools");
        DisplayTableInspectorWindow(nodeInfo);
    end

    if self.db.viragDevTool and ViragDevTool_AddData then
        ViragDevTool_AddData(nodeInfo, 'NodeInfo ID ' .. (nodeInfo.ID or 'nil'));
    end
    if self.db.viragDevTool and DevTool and DevTool.AddData then
        DevTool:AddData(nodeInfo, 'NodeInfo ID ' .. (nodeInfo.ID or 'nil'));
    end

    if self.db.luaBrowser and SlashCmdList.LuaBrowser then
        _G['TalentTreeTweaksDebugNodeInfo'] = nodeInfo;
        SlashCmdList.LuaBrowser('code TalentTreeTweaksDebugNodeInfo');
    end
end

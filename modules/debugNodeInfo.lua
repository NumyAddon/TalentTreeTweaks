local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @class TalentTreeTweaks_DebugNodeInfo: AceModule, AceHook-3.0, AceEvent-3.0
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

function Module:GetOptions(defaultOptionsTable, db)
    local defaultDb = {
        tinspect = true,
        viragDevTool = true,
        luaBrowser = true,
        slashDump = false,
    }
    self.db = db;
    for k, v in pairs(defaultDb) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    local set = function(info, value)
        self.db[info[#info]] = value;
    end;
    local get = function(info)
        return self.db[info[#info]];
    end;
    local order = 5;
    local function increment()
        order = order + 1; return order;
    end;

    defaultOptionsTable.args.extraDescription = {
        type = 'description',
        name = L['You can toggle any of the following on/off to enable/disable the integration with that debug tool.'],
        order = increment(),
    };
    defaultOptionsTable.args.tinspect = {
        type = 'toggle',
        name = '/tinspect',
        desc = L['Opens Blizzard\'s table inspect window.'],
        get = get,
        set = set,
        order = increment(),
    };
    defaultOptionsTable.args.viragDevTool = {
        type = 'toggle',
        name = '(Virag-)DevTool',
        desc = L['Use (Virag-)DevTool to inspect the nodeInfo table.'],
        get = get,
        set = set,
        disabled = not select(4, C_AddOns.GetAddOnInfo('ViragDevTool')) and not select(4, C_AddOns.GetAddOnInfo('DevTool')), -- 4-> loadable
        order = increment(),
    };
    defaultOptionsTable.args.luaBrowser = {
        type = 'toggle',
        name = 'LuaBrowser',
        desc = L['Use LuaBrowser to inspect the nodeInfo table.'],
        get = get,
        set = set,
        disabled = not select(4, C_AddOns.GetAddOnInfo('LuaBrowser')), -- 4-> loadable
        order = increment(),
    };
    defaultOptionsTable.args.slashDump = {
        type = 'toggle',
        name = '/dump',
        desc = L['Dump the nodeInfo table to chat.'],
        get = get,
        set = set,
        order = increment(),
    };

    return defaultOptionsTable;
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
    nodeInfo._button = buttonFrame;
    nodeInfo._entryInfo = buttonFrame.entryInfo or buttonFrame.GetEntryInfo and buttonFrame:GetEntryInfo() or nil;

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

    if self.db.slashDump then
        DevTools_Dump(nodeInfo, 'value');
    end
end

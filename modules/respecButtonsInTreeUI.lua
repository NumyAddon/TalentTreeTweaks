local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @class TTT_RespecButtons: AceModule, AceHook-3.0, AceEvent-3.0
local Module = Main:NewModule('RespecButtons', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if(self.respecButtonContainer) then
        self.respecButtonContainer:Hide();
    end
end

function Module:GetDescription()
    return L['Adds respec buttons to the talent tree UI.'];
end

function Module:GetName()
    return L['Respec Buttons'];
end

function Module:GetOptions(defaultOptionsTable, db)
    Util:PrepareModuleDb(self, db, {
        inverseHighlight = false,
    });
    local getter, setter, increment = Util:GetterSetterIncrementFactory(db, function() self:UpdateRespecButtonContainer(); end);

    defaultOptionsTable.args.inverseHighlight = {
        order = increment(),
        type = "toggle",
        name = L["Invert highlight"],
        desc = L["Grey out inactive spec buttons, rather than the active spec button."],
        get = getter,
        set = setter,
    }

    return defaultOptionsTable;
end

function Module:SetupHook()
    local talentFrame = Util:GetTalentFrame();
    self:SecureHook(talentFrame, 'UpdateInspecting', function() self:UpdateRespecButtonContainer(); end);

    if self.respecButtonContainer then self:UpdateRespecButtonContainer(); return; end
    local container = CreateFrame('Frame', nil, talentFrame);
    talentFrame.TalentTreeTweaks_RespecButtonContainer = container;
    self.respecButtonContainer = container;

    -- create a respec button per spec, with icon and tooltip
    container.buttons = {};
    for i = 1, GetNumSpecializations() do
        self:MakeRespecButton(container, i);
    end

    container:SetSize(41 * GetNumSpecializations(), 40);

    container:ClearAllPoints();
    container:SetPoint('RIGHT', talentFrame.PvPTalentSlotTray.Label, 'LEFT', -20, 0);
    container:Show();
end

function Module:UpdateRespecButtonContainer()
    for _, button in pairs(self.respecButtonContainer.buttons) do
        button:OnEvent();
    end

    local talentsTab = Util:GetTalentFrame();
    if not talentsTab:IsInspecting() then
        self.respecButtonContainer:Show();
        return;
    end

    self.respecButtonContainer:Hide();
end

local respecButtonMixin = {};
do
    function respecButtonMixin:OnEnter()
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT');
        GameTooltip:SetText(self.name);
        GameTooltip:AddLine(L['Click to respec to this specialization.']);
        GameTooltip:Show();
    end
    function respecButtonMixin:OnLeave() GameTooltip:Hide() end
    function respecButtonMixin:OnClick()
        local specIndex = self:GetID();
        if GetSpecialization() == specIndex then return end
        if ClassTalentHelper and ClassTalentHelper.SwitchToSpecializationByIndex then
            ClassTalentHelper.SwitchToSpecializationByIndex(specIndex)
            return
        end
        SetSpecialization(specIndex)
        Util:GetTalentFrame():SetCommitStarted(0)
        Module:RegisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED')
        Module:RegisterEvent('SPECIALIZATION_CHANGE_CAST_FAILED')
    end
    function respecButtonMixin:OnEvent()
        local specIndex = self:GetID();
        if GetSpecialization() == specIndex then
            self:Disable();
            self:DesaturateHierarchy(Module.db.inverseHighlight and 0 or 1);
        else
            self:Enable();
            self:DesaturateHierarchy(Module.db.inverseHighlight and 1 or 0);
        end
    end
end

function Module:MakeRespecButton(parent, specIndex)
    local _, name, _, icon, _ = GetSpecializationInfo(specIndex);
    local button = CreateFrame('Button', nil, parent, 'UIPanelButtonNoTooltipTemplate, UIButtonTemplate');
    Mixin(button, respecButtonMixin);
    button:SetSize(40, 40);
    button.name = name;
    button:SetID(specIndex);
    button:SetNormalTexture(icon);
    button:SetScript('OnEnter', respecButtonMixin.OnEnter);
    button:SetScript('OnLeave', respecButtonMixin.OnLeave);
    button:SetScript('OnClick', respecButtonMixin.OnClick);
    button:SetScript('OnEvent', respecButtonMixin.OnEvent);
    button:RegisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED');
    parent['RespecButton' .. specIndex] = button;
    parent.buttons[specIndex] = button;
    button:OnEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED');

    button:ClearAllPoints();
    if specIndex == 1 then
        button:SetPoint('LEFT', parent, 'LEFT', 0, 0);
    else
        button:SetPoint('LEFT', parent.buttons[specIndex - 1], 'RIGHT', 1, 0);
    end
    button:Show()
end

function Module:ACTIVE_PLAYER_SPECIALIZATION_CHANGED()
    self:UnregisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED')
    self:UnregisterEvent('SPECIALIZATION_CHANGE_CAST_FAILED')
    Util:GetTalentFrame():SetCommitStarted(nil)
end

function Module:SPECIALIZATION_CHANGE_CAST_FAILED()
    self:UnregisterEvent('ACTIVE_PLAYER_SPECIALIZATION_CHANGED')
    self:UnregisterEvent('SPECIALIZATION_CHANGE_CAST_FAILED')
    Util:GetTalentFrame():SetCommitStarted(nil)
end

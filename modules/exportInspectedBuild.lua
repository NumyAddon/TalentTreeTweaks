local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;

local Module = Main:NewModule('ExportInspectedBuild', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnEnable()
    if IsAddOnLoaded('Blizzard_ClassTalentUI') then
        self:SetupHook();
    else
        self:RegisterEvent('ADDON_LOADED');
    end
end

function Module:OnDisable()
    self:UnhookAll();
    if(self.exportButton) then
        self.exportButton:Hide();
    end
end

function Module:GetDescription()
    return 'Adds an export button when inspecting another player.'
end

function Module:GetName()
    return 'Export When Inspecting'
end

function Module:ADDON_LOADED(_, addon)
    if addon == 'Blizzard_ClassTalentUI' then
        self:SetupHook();
        self:UnregisterEvent('ADDON_LOADED');
    end
end

function Module:SetupHook()
    self:SecureHook(ClassTalentFrame.TalentsTab, 'UpdateInspecting', function() Module:UpdateExportButton(); end);

    if self.exportButton then
        Module:UpdateExportButton();
        return;
    end
    self.exportButton = CreateFrame('Button', nil, ClassTalentFrame.TalentsTab, 'UIPanelButtonNoTooltipTemplate, UIButtonTemplate');
    local button = self.exportButton;
    button:SetSize(100, 40);
    button:SetText('Export');
    button:ClearAllPoints();
    button:SetPoint('CENTER', ClassTalentFrame.TalentsTab.BottomBar, 'CENTER', 0, 0);
    button:Show();
    button:SetScript('OnClick', function()
        local exportString = Util:GetLoadoutExportString(ClassTalentFrame.TalentsTab);
        Util:CopyText(exportString);
    end);
    Module:UpdateExportButton();
end

function Module:UpdateExportButton()
    local talentsTab = ClassTalentFrame.TalentsTab;
    if not talentsTab:IsInspecting() then
        self.exportButton:Hide();
        return;
    end

    self.exportButton:Show();
end

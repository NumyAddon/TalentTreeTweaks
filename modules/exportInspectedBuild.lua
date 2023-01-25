local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;

local Module = Main:NewModule('ExportInspectedBuild', 'AceHook-3.0');

Module.shouldShowExportButton = select(4, GetBuildInfo()) < 100005 -- blizzard added their own version of this in 10.0.5

function Module:OnEnable()
    EventUtil.ContinueOnAddOnLoaded('Blizzard_ClassTalentUI', function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if(self.exportButton) then
        self.exportButton:Hide();
    end
    if ClassTalentFrame and ClassTalentFrame.TalentsTab then
        ClassTalentFrame.TalentsTab.LoadoutDropDown:SetRightClickCallback(nil);
    end
end

function Module:GetDescription()
    local description = self.shouldShowExportButton and 'Adds an export button when inspecting another player.\n' or '';
    description = description .. 'Adds a right-click option to the loadout dropdown to export your build.';

    return description;
end

function Module:GetName()
    return 'Export Loadouts';
end

function Module:SetupHook()
    local talentsTab = ClassTalentFrame.TalentsTab;
    self:SecureHook(talentsTab, 'UpdateInspecting', function() Module:UpdateExportButton(); end);

    local dropdown = talentsTab.LoadoutDropDown
    dropdown:SetRightClickCallback(function(configID)
        local exportString = Util:GetLoadoutExportString(talentsTab, configID);
        Util:CopyText(exportString);
    end);
    self:SecureHook(dropdown, 'SetSelectionOptions', 'OnSetSelectionOptions');
    Module:OnSetSelectionOptions(dropdown)

    if not self.shouldShowExportButton then return; end
    if self.exportButton then
        Module:UpdateExportButton();
        return;
    end
    self.exportButton = CreateFrame('Button', nil, talentsTab, 'UIPanelButtonNoTooltipTemplate, UIButtonTemplate');
    local button = self.exportButton;
    button:SetSize(100, 40);
    button:SetText('Export');
    button:ClearAllPoints();
    button:SetPoint('CENTER', talentsTab.BottomBar, 'CENTER', 0, 0);
    button:Show();
    button:SetScript('OnClick', function()
        local exportString = Util:GetLoadoutExportString(talentsTab);
        Util:CopyText(exportString);
    end);
    Module:UpdateExportButton();
end

function Module:OnSetSelectionOptions(dropdown)
    if self:IsHooked(dropdown, 'tooltipTranslation') then
        self:Unhook(dropdown, 'tooltipTranslation');
    end
    self:RawHook(dropdown, 'tooltipTranslation', function(configID)
        return
            self.hooks[dropdown].tooltipTranslation(configID)
            or 'Right-click to share';
    end, true);
    dropdown:UpdateSelectionOptions();
end

function Module:UpdateExportButton()
    if not self.exportButton then
        return;
    end
    local talentsTab = ClassTalentFrame.TalentsTab;
    if not talentsTab:IsInspecting() then
        self.exportButton:Hide();
        return;
    end

    self.exportButton:Show();
end

local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;

local Module = Main:NewModule('ExportInspectedBuild', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnInitialize()
    self.dialogName = 'TalentTreeTweaksExportInspectedBuildDialog';
    StaticPopupDialogs['TalentTreeTweaksExportInspectedBuildDialog'] = {
        text = 'CTRL-C to copy',
        button1 = CLOSE,
        OnShow = function(dialog, data)
            local function HidePopup()
                dialog:Hide();
            end
            dialog.editBox:SetScript('OnEscapePressed', HidePopup);
            dialog.editBox:SetScript('OnEnterPressed', HidePopup);
            dialog.editBox:SetScript('OnKeyUp', function(_, key)
                if IsControlKeyDown() and key == 'C' then
                    HidePopup();
                end
            end);
            dialog.editBox:SetMaxLetters(0);
            dialog.editBox:SetText(data);
            dialog.editBox:HighlightText();
        end,
        hasEditBox = true,
        editBoxWidth = 240,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    };
end

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

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;

    return defaultOptionsTable;
end

function Module:ADDON_LOADED(_, addon)
    if addon == 'Blizzard_ClassTalentUI' then
        self:SetupHook();
        self:UnregisterEvent('ADDON_LOADED');
    end
end

function Module:SetupHook()
    self:SecureHook(ClassTalentFrame.TalentsTab, 'UpdateInspecting', function() Module:UpdateExportButton(); end);

    if self.exportButton then return; end
    self.exportButton = CreateFrame('Button', nil, ClassTalentFrame.TalentsTab, 'UIPanelButtonNoTooltipTemplate, UIButtonTemplate');
    local button = self.exportButton;
    button:SetSize(100, 40);
    button:SetText('Export');
    button:ClearAllPoints();
    button:SetPoint('CENTER', ClassTalentFrame.TalentsTab.BottomBar, 'CENTER', 0, 0);
    button:Show();
    button:SetScript('OnClick', function()
        local exportString = self:GetLoadoutExportString(ClassTalentFrame.TalentsTab);
        StaticPopup_Show(self.dialogName, nil, nil, exportString);
    end);
end

local LOADOUT_SERIALIZATION_VERSION = 1;
function Module:GetLoadoutExportString(talentsTab)
    local exportStream = ExportUtil.MakeExportDataStream();
    local configID = talentsTab:GetConfigID();
    local currentSpecID = talentsTab:GetSpecID();
    local treeInfo = talentsTab:GetTreeInfo();

    -- write header
    exportStream:AddValue(talentsTab.bitWidthHeaderVersion, LOADOUT_SERIALIZATION_VERSION);
    exportStream:AddValue(talentsTab.bitWidthSpecID, currentSpecID);
    -- treeHash is a 128bit hash, passed as an array of 16, 8-bit values
    -- empty tree hash will disable validation on import
    exportStream:AddValue(8 * 16, 0);

    talentsTab:WriteLoadoutContent(exportStream, configID, treeInfo.ID);

    return exportStream:GetExportString();
end

function Module:UpdateExportButton()
    local talentsTab = ClassTalentFrame.TalentsTab;
    if not talentsTab:IsInspecting() then
        self.exportButton:Hide();
        return;
    end

    self.exportButton:Show();
end

local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local Module = Main:NewModule('InspectDiff', 'AceHook-3.0');

function Module:OnEnable()
    self.blizzardButtonTextures = self.blizzardButtonTextures or {};
    Util:OnClassTalentUILoad(function()
        self:SetupBlizzardHook();
    end);

    self.viewerButtonTextures = self.viewerButtonTextures or {};
    EventUtil.ContinueOnAddOnLoaded('TalentTreeViewer', function()
        self:SetupViewerHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if(self.blizzardButtonTextures) then
        for _, texture in pairs(self.blizzardButtonTextures) do
            texture:Hide();
        end
    end
    if(self.viewerButtonTextures) then
        for _, texture in pairs(self.viewerButtonTextures) do
            texture:Hide();
        end
    end
end

function Module:GetDescription()
    return L['Shows the difference between your talent choices, and the inspected player\'s talent choices.'];
end

function Module:GetName()
    return L['Inspect Diff'];
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;

    local defaults = {
        colorGreen = {
            r = 0,
            g = 1,
            b = 0.3,
            a = 0.58,
        },
        colorRed = {
            r = 1,
            g = 0,
            b = 0,
            a = 0.5,
        },
        colorYellow = {
            r = 1,
            g = 0.67,
            b = 0,
            a = 0.75,
        },
        enableTalentTreeViewerDiff = true,
    }
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    local function GetColor(info)
        local color = self.db[info[#info]];
        return color.r, color.g, color.b, color.a;
    end
    local function SetColor(info, r, g, b, a)
        local color = self.db[info[#info]];
        color.r, color.g, color.b, color.a = r, g, b, a;
        self:UpdateBlizzardColors();
        self:UpdateViewerColors();
    end
    defaultOptionsTable.args.colorRed = {
        type = 'color',
        name = L['You have a talent they don\'t'],
        hasAlpha = true,
        get = GetColor,
        set = SetColor,
        order = 5,
    };
    defaultOptionsTable.args.colorGreen = {
        type = 'color',
        name = L['They have a talent you don\'t'],
        hasAlpha = true,
        get = GetColor,
        set = SetColor,
        order = 6,
    };
    defaultOptionsTable.args.colorYellow = {
        type = 'color',
        name = L['You have selected a different choice, or different number of points in a talent'],
        hasAlpha = true,
        get = GetColor,
        set = SetColor,
        order = 7,
    };
    defaultOptionsTable.args.reset = {
        type = 'execute',
        name = RESET,
        desc = L['Reset the colors to default'],
        func = function()
            self.db.colorRed = defaults.colorRed;
            self.db.colorGreen = defaults.colorGreen;
            self.db.colorYellow = defaults.colorYellow;
            self:UpdateBlizzardColors();
            self:UpdateViewerColors();
        end,
        order = 10,
    };
    defaultOptionsTable.args.enableTalentTreeViewerDiff = {
        type = 'toggle',
        name = L['Enable Talent Tree Viewer Diff'],
        desc = L['Show the difference between your talent choices, and the talent build in Talent Tree Viewer.'],
        get = function() return self.db.enableTalentTreeViewerDiff end,
        set = function(_, value)
            self.db.enableTalentTreeViewerDiff = value
            if self.viewerButtonTextures then
                if not value then
                    for _, texture in pairs(self.viewerButtonTextures) do
                        texture:Hide();
                    end
                else
                    self:UpdateViewerColors();
                end
            end
        end,
        disabled = function() return not Main:IsTalentTreeViewerEnabled() end,
        width = 'full',
        order = 15,
    };

    return defaultOptionsTable;
end

function Module:SetupBlizzardHook()
    local talentFrame = ClassTalentFrame.TalentsTab;
    self:SecureHook(talentFrame, 'UpdateInspecting');
    self:UpdateInspecting(talentFrame);

    self:SecureHook(talentFrame, 'ShowSelections', 'OnBlizzardShowSelections');

    talentFrame:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnBlizzardTalentButtonAcquired, self);
    for talentButton in talentFrame:EnumerateAllTalentButtons() do
        self:OnBlizzardTalentButtonAcquired(talentButton);
    end
end

function Module:SetupViewerHook()
    local talentViewerFrame = TalentViewer:GetTalentFrame();
    self:InitCheckbox(talentViewerFrame);
    self:SecureHook(TalentViewer, 'SelectSpec', 'UpdateViewerSpec');
    self:UpdateViewerSpec(TalentViewer, talentViewerFrame:GetClassID(), talentViewerFrame:GetSpecID());

    self:SecureHook(talentViewerFrame, 'ShowSelections', 'OnViewerShowSelections');

    talentViewerFrame:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnViewerTalentButtonAcquired, self);
    for talentButton in talentViewerFrame:EnumerateAllTalentButtons() do
        self:OnViewerTalentButtonAcquired(talentButton);
    end
    self:SecureHook(TalentViewer, 'ReduceCurrency', 'ViewerNodeChanged');
    self:SecureHook(TalentViewer, 'RestoreCurrency', 'ViewerNodeChanged');

    self.viewerCheckbox:Show();
    self.viewerCheckbox:SetChecked(self.db.enableTalentTreeViewerDiff);
end

function Module:InitCheckbox(talentViewerFrame)
    if self.viewerCheckbox then
        return;
    end

    local checkbox = CreateFrame('CheckButton', nil, talentViewerFrame, 'UICheckButtonTemplate');
    checkbox:SetPoint('TOPLEFT', talentViewerFrame.IgnoreRestrictions, 'BOTTOMLEFT');
    checkbox:SetSize(25, 25);
    checkbox:SetScript('OnClick', function()
        self.db.enableTalentTreeViewerDiff = checkbox:GetChecked();
        if self.db.enableTalentTreeViewerDiff then
            self:UpdateViewerColors();
        else
            for _, texture in pairs(self.viewerButtonTextures) do
                texture:Hide();
            end
        end
    end);
    checkbox:SetScript('OnEnter', function()
        GameTooltip:SetOwner(checkbox, 'ANCHOR_RIGHT');
        GameTooltip:AddLine(L['TalentTreeTweaks Diff Viewer']);
        GameTooltip:AddLine(L['Show the difference between your talent choices, and the talent build in Talent Tree Viewer.'], 1, 1, 1, true);
        GameTooltip:Show();
    end);
    checkbox:SetScript('OnLeave', function() GameTooltip:Hide(); end);
    checkbox.Text:SetText(L['Show Diff']);
    checkbox:SetHitRectInsets(0, -checkbox.Text:GetWidth(), 0, 0);

    self.viewerCheckbox = checkbox;
end

function Module:ViewerNodeChanged(TalentViewer, nodeID)
    local talentFrame = TalentViewer:GetTalentFrame();
    local button = talentFrame:GetTalentButtonByNodeID(nodeID);
    if button and self.viewerButtonTextures[button] then
        C_Timer.After(0, function()
            self:SetViewerButtonState(button, self.viewerButtonTextures[button]);
        end)
    end
end

function Module:UpdateInspecting(talentsTab)
    self.isInspectingSameSpec = talentsTab:IsInspecting() and talentsTab:GetSpecID() == PlayerUtil.GetCurrentSpecID();

    self:UpdateBlizzardColors();
end

function Module:UpdateViewerSpec(TalentViewer, classID, specID)
    self.isViewerSameSpec = specID == PlayerUtil.GetCurrentSpecID();
    self.viewerCheckbox:SetEnabled(self.isViewerSameSpec);

    self:UpdateViewerColors();
end

function Module:OnBlizzardShowSelections(talentsTab)
    for _, button in pairs(talentsTab.SelectionChoiceFrame.selectionFrameArray) do
        self:OnBlizzardTalentButtonAcquired(button);
    end
end

function Module:OnViewerShowSelections(talentFrame)
    for _, button in pairs(talentFrame.SelectionChoiceFrame.selectionFrameArray) do
        self:OnViewerTalentButtonAcquired(button);
    end
end

function Module:CreateTexture(button)
    local texture = button:CreateTexture(nil, 'OVERLAY');
    texture:SetAllPoints(button);
    texture:SetTexture('Interface/Tooltips/UI-Tooltip-Background');
    texture:SetVertexColor(self.db.colorRed.r, self.db.colorRed.g, self.db.colorRed.b, self.db.colorRed.a);
    texture:AddMaskTexture(button.IconMask);
    texture:Hide();
    return texture;
end

function Module:OnBlizzardTalentButtonAcquired(button)
    if not self.blizzardButtonTextures[button] then
        self.blizzardButtonTextures[button] = self:CreateTexture(button);
    end

    self:SetBlizzardButtonState(button, self.blizzardButtonTextures[button]);
end

function Module:OnViewerTalentButtonAcquired(button)
    if not self.viewerButtonTextures[button] then
        self.viewerButtonTextures[button] = self:CreateTexture(button);
    end

    self:SetViewerButtonState(button, self.viewerButtonTextures[button]);
end

function Module:UpdateBlizzardColors()
    for button, texture in pairs(self.blizzardButtonTextures) do
        self:SetBlizzardButtonState(button, texture);
    end
end

function Module:UpdateViewerColors()
    if not self.db.enableTalentTreeViewerDiff then
        return;
    end

    for button, texture in pairs(self.viewerButtonTextures) do
        self:SetViewerButtonState(button, texture);
    end
end

function Module:SetBlizzardButtonState(button, texture)
    if not self.isInspectingSameSpec then
        texture:Hide();
        return;
    end

    self:SetButtonState(button, texture);
end

function Module:SetViewerButtonState(button, texture)
    if not self.isViewerSameSpec then
        texture:Hide();
        return;
    end

    self:SetButtonState(button, texture);
end

function Module:SetButtonState(button, texture)
    local isChoiceButton = not not button.selectionIndex

    local colorToUse
    local inspectNodeInfo = button.nodeInfo or button.GetNodeInfo and button:GetNodeInfo() or {};
    local inspectEntry = inspectNodeInfo and inspectNodeInfo.activeEntry and inspectNodeInfo.activeEntry.entryID;
    local inspectRank = inspectNodeInfo and inspectNodeInfo.activeEntry and inspectNodeInfo.activeEntry.rank or 0;

    local selfNodeInfo = C_Traits.GetNodeInfo(C_ClassTalents.GetActiveConfigID(), inspectNodeInfo.ID);
    local selfEntry = selfNodeInfo and selfNodeInfo.activeEntry and selfNodeInfo.activeEntry.entryID;
    local selfRank = selfNodeInfo and selfNodeInfo.activeEntry and selfNodeInfo.activeEntry.rank or 0;

    if inspectEntry and selfEntry and inspectEntry == selfEntry then
        if inspectRank == selfRank then
            colorToUse = nil;
        elseif inspectRank ~= 0 and selfRank ~= 0 then
            colorToUse = self.db.colorYellow; -- same entry, different rank
        elseif inspectRank == 0 then
            colorToUse = self.db.colorRed; -- inspect has entry, self doesn't
        elseif selfRank == 0 then
            colorToUse = self.db.colorGreen; -- self has entry, inspect doesn't
        end
    else
        local buttonEntryID = button.entryID;
        if inspectRank ~= 0 and selfRank ~= 0 then -- both have entries, but different
            if not isChoiceButton then
                colorToUse = self.db.colorYellow; -- different entry, base button
            else
                if buttonEntryID == inspectEntry then
                    colorToUse = self.db.colorGreen; -- specific button, inspect has entry, self doesn't
                else
                    colorToUse = self.db.colorRed; -- specific button, inspect doesn't have entry, self does
                end
            end
        else -- one or both don't have entries
            if ((inspectRank == 0 and selfRank == 0) or (buttonEntryID ~= inspectEntry and buttonEntryID ~= selfEntry)) then
                colorToUse = nil; -- neither has entry
            elseif inspectRank == 0 then
                colorToUse = self.db.colorRed; -- inspect doesn't have entry, self does
            elseif selfRank == 0 then
                colorToUse = self.db.colorGreen; -- self has entry, inspect doesn't
            end
        end
    end
    if not colorToUse then
        texture:Hide();
    else
        texture:SetVertexColor(colorToUse.r, colorToUse.g, colorToUse.b, colorToUse.a);
        texture:Show();
    end
end

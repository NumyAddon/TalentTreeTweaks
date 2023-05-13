local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local Module = Main:NewModule('ChangeBackground', 'AceHook-3.0', 'AceEvent-3.0');
Module.originalAlpha = {}

function Module:OnEnable()
    Util:OnClassTalentUILoad(function()
        self:SetupDefaultUI();
    end);
    EventUtil.ContinueOnAddOnLoaded('TalentTreeViewer', function()
        self:SetupTTVUI();
    end);
end

function Module:OnDisable()
    self:UpdateBackground(true);
    if self.alphaSlider then
        self.alphaSlider:Hide();
    end
    if self.viewerAlphaSlider then
        self.viewerAlphaSlider:Hide();
    end
end

function Module:GetDescription()
    return L['Adds options to adjust the background of the talent tree UI.'];
end

function Module:GetName()
    return L['Change Background'];
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        alpha = 1,
        showAlphaInUI = true,
        showAlphaInViewerUI = true,
    }
    for key, value in pairs(defaults) do
        if self.db[key] == nil then
            self.db[key] = value;
        end
    end

    local get = function(info)
        return self.db[info[#info]];
    end
    local set = function(info, value)
        local setting = info[#info];
        self.db[setting] = value;

        if setting == 'alpha' then
            self:UpdateBackground();
        elseif setting == 'showAlphaInUI' and self.alphaSlider then
            self.alphaSlider:SetShown(value);
        elseif setting == 'showAlphaInViewerUI' and self.viewerAlphaSlider then
            self.viewerAlphaSlider:SetShown(value);
        end
    end
    local counter = CreateCounter(5);

    defaultOptionsTable.args.spacer1 = {
        order = counter(),
        type = 'description',
        name = '',
        width = 'full',
    }
    defaultOptionsTable.args.alpha = {
        type = 'range',
        name = L['Background Transparency'],
        order = counter(),
        get = get,
        set = set,
        min = 0,
        max = 1,
        step = 0.01,
        width = 'full',
    };
    defaultOptionsTable.args.showAlphaInUI = {
        type = 'toggle',
        name = L['Show a slider in the talent UI'],
        order = counter(),
        get = get,
        set = set,
    };
    defaultOptionsTable.args.showAlphaInViewerUI = {
        type = 'toggle',
        name = L['Show a slider in Talent Tree Viewer UI'],
        order = counter(),
        get = get,
        set = set,
        disabled = function() return not Main:IsTalentTreeViewerEnabled() end,
    };

    return defaultOptionsTable;
end

function Module:TrySetAlpha(frame, alpha)
    if frame and frame.SetAlpha and frame.GetAlpha then
        if not self.originalAlpha[frame] then
            self.originalAlpha[frame] = frame:GetAlpha();
        end
        frame:SetAlpha(self.originalAlpha[frame] * alpha);
    end
end

function Module:UpdateBackground(resetAlpha)
    local alpha = resetAlpha and 1 or self.db.alpha;
    if ClassTalentFrame then
        self:TrySetAlpha(ClassTalentFrame.TalentsTab.Background, alpha);
        self:TrySetAlpha(ClassTalentFrame.TalentsTab.BlackBG, alpha);
        self:TrySetAlpha(ClassTalentFrame.Center, alpha); -- ElvUI background
        self:TrySetAlpha(ClassTalentFrameBg, alpha);
    end

    if TalentViewer and TalentViewer.GetTalentFrame and TalentViewer:GetTalentFrame() then
        local talentViewerFrame = TalentViewer:GetTalentFrame();
        self:TrySetAlpha(talentViewerFrame.Background, alpha);
        self:TrySetAlpha(talentViewerFrame.BlackBG, alpha);
        self:TrySetAlpha(TalentViewer_DFBg, alpha);
    end
    if TalentLoadoutManager then
        if TalentLoadoutManager.SideBarModule and TalentLoadoutManager.SideBarModule.SideBar then
            local sideBar = TalentLoadoutManager.SideBarModule.SideBar;
            self:TrySetAlpha(sideBar.Background, alpha);
        end
        if TalentLoadoutManager.TTVSideBarModule and TalentLoadoutManager.TTVSideBarModule.SideBar then
            local sideBar = TalentLoadoutManager.TTVSideBarModule.SideBar;
            self:TrySetAlpha(sideBar.Background, alpha);
        end
    end

    if self.alphaSlider then
        self.alphaSlider:SetValue(alpha);
    end
    if self.viewerAlphaSlider then
        self.viewerAlphaSlider:SetValue(alpha);
    end
end

function Module:SetupDefaultUI()
    self:UpdateBackground();
    self.alphaSlider = self.alphaSlider or self:CreateSlider(ClassTalentFrame.TalentsTab);
    self.alphaSlider:SetShown(self.db.showAlphaInUI);

    RunNextFrame(function()
        -- give time for other addons that hook into Default UI to load up
        self:UpdateBackground();
    end);
end

function Module:SetupTTVUI()
    self:UpdateBackground();
    local xOffset = 25;
    self.viewerAlphaSlider = self.viewerAlphaSlider or self:CreateSlider(TalentViewer:GetTalentFrame(), xOffset);
    self.viewerAlphaSlider:SetShown(self.db.showAlphaInViewerUI);

    RunNextFrame(function()
        -- give time for other addons that hook into TTV UI to load up
        self:UpdateBackground();
    end);
end

function Module:CreateSlider(talentFrame, xOffset)
    local slider = CreateFrame('Slider', nil, talentFrame, 'MinimalSliderWithSteppersTemplate');
    slider:OnLoad();
    slider:SetPoint('BOTTOM', talentFrame.BottomBar, 'BOTTOM', xOffset or 0, 10);
    local minValue = 0;
    local maxValue = 1;
    local steps = 40;
    local formatters = {
        [MinimalSliderWithSteppersMixin.Label.Left] = function() return L['Transparency'] end,
        [MinimalSliderWithSteppersMixin.Label.Right] = function(value) return string.format('%.2f%%', value) end,
    }
    slider:Init(self.db.alpha, minValue, maxValue, steps, formatters);
    slider:SetWidth(200);
    slider:SetHeight(16);
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        self.db.alpha = value;
        self:UpdateBackground();
    end);

    return slider;
end

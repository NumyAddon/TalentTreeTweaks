local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @class TTT_ChangeBackground: AceModule, AceHook-3.0, AceEvent-3.0
local Module = Main:NewModule('ChangeBackground', 'AceHook-3.0', 'AceEvent-3.0');
Module.originalAlpha = {}

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupDefaultUI();
    end);
    EventUtil.ContinueOnAddOnLoaded(TalentViewerLoader and TalentViewerLoader:GetLodAddonName() or 'TalentTreeViewer', function()
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
    --- @type TTT_ChangeBackgroundDB
    self.db = db;
    --- @class TTT_ChangeBackgroundDB
    local defaults = {
        alpha = 1,
        spellbookAlpha = 1,
        showAlphaInUI = true,
        showAlphaInSpellbookUI = true,
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

        if setting == 'alpha' or setting == 'spellbookAlpha' then
            self:UpdateBackground();
        elseif setting == 'showAlphaInUI' and self.alphaSlider then
            self.alphaSlider:SetShown(value);
        elseif setting == 'showAlphaInSpellbookUI' and self.spellbookAlphaSlider then
            self.spellbookAlphaSlider:SetShown(value);
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
    defaultOptionsTable.args.spellbookAlpha = {
        type = 'range',
        name = L['Spellbook Background Transparency'],
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
        width = 'double',
    };
    defaultOptionsTable.args.showAlphaInSpellbookUI = {
        type = 'toggle',
        name = L['Show a slider in the spellbook UI'],
        order = counter(),
        get = get,
        set = set,
        width = 'double',
    };
    defaultOptionsTable.args.showAlphaInViewerUI = {
        type = 'toggle',
        name = L['Show a slider in Talent Tree Viewer UI'],
        order = counter(),
        get = get,
        set = set,
        disabled = function() return not Main:IsTalentTreeViewerEnabled() end,
        width = 'double',
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
    local spellbookAlpha = resetAlpha and 1 or self.db.spellbookAlpha;
    local talentContainerFrame = Util:GetTalentContainerFrame();
    if talentContainerFrame then
        local talentFrame = Util:GetTalentFrame();
        self:TrySetAlpha(talentFrame.Background, alpha);
        self:TrySetAlpha(talentFrame.BlackBG, alpha);
        self:TrySetAlpha(talentContainerFrame.Center, alpha); -- ElvUI background
        self:TrySetAlpha(_G[talentContainerFrame:GetName() .. 'Bg'], alpha);

        local spellbookFrame = talentContainerFrame.SpellBookFrame;
        if spellbookFrame then
            self:TrySetAlpha(spellbookFrame.BookBGHalved, spellbookAlpha);
            self:TrySetAlpha(spellbookFrame.BookBGLeft, spellbookAlpha);
            self:TrySetAlpha(spellbookFrame.BookBGRight, spellbookAlpha);
            self:TrySetAlpha(spellbookFrame.BookCornerFlipbook, spellbookAlpha * spellbookAlpha);
        end
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
    if self.spellbookAlphaSlider then
        self.spellbookAlphaSlider:SetValue(spellbookAlpha);
    end
    if self.viewerAlphaSlider then
        self.viewerAlphaSlider:SetValue(alpha);
    end
end

function Module:SetupDefaultUI()
    self:UpdateBackground();
    self.alphaSlider = self.alphaSlider or self:CreateSlider(Util:GetTalentFrame());
    self.alphaSlider:SetShown(self.db.showAlphaInUI);

    self.spellbookAlphaSlider = self.spellbookAlphaSlider or self:CreateSlider(Util:GetTalentContainerFrame().SpellBookFrame, 'spellbookAlpha');
    self.spellbookAlphaSlider:SetShown(self.db.showAlphaInSpellbookUI);

    RunNextFrame(function()
        -- give time for other addons that hook into Default UI to load up
        self:UpdateBackground();
    end);
end

function Module:SetupTTVUI()
    self:UpdateBackground();
    local xOffset = 25;
    self.viewerAlphaSlider = self.viewerAlphaSlider or self:CreateSlider(TalentViewer:GetTalentFrame(), nil, xOffset);
    self.viewerAlphaSlider:SetShown(self.db.showAlphaInViewerUI);

    RunNextFrame(function()
        -- give time for other addons that hook into TTV UI to load up
        self:UpdateBackground();
    end);
end

--- @return Slider
function Module:CreateSlider(parentFrame, alphaSetting, xOffset)
    alphaSetting = alphaSetting or 'alpha';
    local slider = CreateFrame('Slider', nil, parentFrame, 'MinimalSliderWithSteppersTemplate');
    parentFrame.TalentTreeTweaks_TransparencySlider = slider;
    slider:OnLoad();
    slider:SetPoint('BOTTOM', parentFrame.BottomBar or parentFrame, 'BOTTOM', xOffset or 0, 10);
    local minValue = 0;
    local maxValue = 1;
    local steps = 40;
    local formatters = {
        [MinimalSliderWithSteppersMixin.Label.Left] = function() return L['Transparency'] end,
        [MinimalSliderWithSteppersMixin.Label.Right] = function(value) return string.format('%.2f%%', value) end,
    }
    slider:Init(self.db[alphaSetting], minValue, maxValue, steps, formatters);
    slider:SetWidth(200);
    slider:SetHeight(16);
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        self.db[alphaSetting] = value;
        self:UpdateBackground();
    end);

    return slider;
end

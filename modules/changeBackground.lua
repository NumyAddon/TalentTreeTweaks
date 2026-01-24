--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

--- @class TTT_ChangeBackground: NumyConfig_Module, AceHook-3.0, AceEvent-3.0
local Module = Main:NewModule('ChangeBackground', 'AceHook-3.0', 'AceEvent-3.0');
Module.originalAlpha = {}

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupDefaultUI();
    end);
    Util:ContinueOnAddonLoaded(TalentViewerLoader and TalentViewerLoader:GetLodAddonName() or 'TalentTreeViewer', function()
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

--- @param configBuilder NumyConfigBuilder
--- @param db TTT_ChangeBackgroundDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class TTT_ChangeBackgroundDB
    local defaults = {
        alpha = 1,
        spellbookAlpha = 1,
        showAlphaInUI = true,
        showAlphaInSpellbookUI = true,
        showAlphaInViewerUI = true,
    };
    configBuilder:SetDefaults(defaults, true);

    configBuilder:MakeSlider(
        L['Background Transparency'],
        'alpha',
        nil,
        configBuilder.sliderOptions.percent,
        function() self:UpdateBackground(); end
    );
    configBuilder:MakeSlider(
        L['Spellbook Background Transparency'],
        'spellbookAlpha',
        nil,
        configBuilder.sliderOptions.percent,
        function() self:UpdateBackground(); end
    );
    configBuilder:MakeCheckbox(
        L['Show a slider in the talent UI'],
        'showAlphaInUI',
        nil,
        function(_, value)
            if self.alphaSlider then
                self.alphaSlider:SetShown(value);
            end
        end
    );
    configBuilder:MakeCheckbox(
        L['Show a slider in the spellbook UI'],
        'showAlphaInSpellbookUI',
        nil,
        function(_, value)
            if self.spellbookAlphaSlider then
                self.spellbookAlphaSlider:SetShown(value);
            end
        end
    );
    configBuilder:MakeCheckbox(
        L['Show a slider in Talent Tree Viewer UI'],
        'showAlphaInViewerUI',
        L['Requires the Talent Tree Viewer addon to be installed and enabled.'],
        function(_, value)
            if self.viewerAlphaSlider then
                self.viewerAlphaSlider:SetShown(value);
            end
        end
    ):AddModifyPredicate(function() return Main:IsTalentTreeViewerEnabled(); end);
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
        [MinimalSliderWithSteppersMixin.Label.Right] = function(value) return string.format('%.1f%%', 100 * value) end,
    }
    slider:Init(self.db[alphaSetting], minValue, maxValue, steps, formatters);
    slider:SetWidth(200);
    slider:SetHeight(16);
    slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
        self.db[alphaSetting] = value;
        self:UpdateBackground();
        TTT.Config:NotifyChange(true);
    end);

    return slider;
end

--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

--- @class TTT_ScaleTalentFrame: NumyConfig_Module, AceHook-3.0
local Module = Main:NewModule('ScaleTalentFrame', 'AceHook-3.0');

local SetScale = GetFrameMetatable().__index.SetScale
local TALENT_TREE_VIEWER = TalentViewerLoader and TalentViewerLoader:GetLodAddonName() or 'TalentTreeViewer';
local BLIZZARD_TALENT_UI = 2;

function Module:OnEnable()
    if self.blizzMoveEnabled then return end
    Util:OnTalentUILoad(function() self:SetupHook(BLIZZARD_TALENT_UI); end);
    Util:ContinueOnAddonLoaded(TALENT_TREE_VIEWER, function() self:SetupHook(TALENT_TREE_VIEWER); end);
end

function Module:OnDisable()
    if self.blizzMoveEnabled then return end

    if Util:GetTalentContainerFrameIfLoaded() and not InCombatLockdown() then Util:GetTalentContainerFrame():SetScale(1); end
    if TalentViewer_DF then TalentViewer_DF:SetScale(1); end
    self:UnhookAll();
end

function Module:GetDescription()
    return L['Allows you to scale the talent tree with CTRL+Scrolling with the mousewheel.'];
end

function Module:GetName()
    return L['Scale Talent Frame'];
end

--- @param configBuilder NumyConfigBuilder
--- @param db TTT_ScaleTalentFrameDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class TTT_ScaleTalentFrameDB
    local defaults = {
        scale = 1,
    };
    configBuilder:SetDefaults(defaults, true);
    self.blizzMoveEnabled = not not (_G.BlizzMoveAPI or C_AddOns.GetAddOnEnableState('BlizzMove', UnitName('player')) == 2);
    local function blizzMoveEnabledPredicate() return self.blizzMoveEnabled; end
    local function blizzMoveMissingPredicate() return not self.blizzMoveEnabled; end

    configBuilder.enableInitializer:AddModifyPredicate(blizzMoveMissingPredicate);
    local warning = configBuilder:MakeText(WHITE_FONT_COLOR:WrapTextInColorCode(L['This module is incompatible with BlizzMove, and has been disabled.']), 2);
    warning:AddShownPredicate(blizzMoveEnabledPredicate);
    configBuilder:MakeSlider(
        L['Change Scale'],
        'scale',
        nil,
        configBuilder:MakeSliderOptions(0.5, 2, 0.05, function(value) return ('%.1fx'):format(value); end),
        function(_, value)
            local containerFrame = Util:GetTalentContainerFrameIfLoaded();
            if containerFrame and containerFrame.SetScale and not InCombatLockdown() then SetScale(containerFrame, value); end
        end
    ):AddModifyPredicate(blizzMoveMissingPredicate);
end

function Module:SetupHook(addon)
    local settingKey, frame, buttonsParent
    if addon == BLIZZARD_TALENT_UI then
        settingKey = 'scale';
        frame = Util:GetTalentContainerFrame();
        buttonsParent = Util:GetTalentFrame().ButtonsParent;
    elseif addon == TALENT_TREE_VIEWER then
        settingKey = 'viewerScale';
        frame = TalentViewer:GetTalentFrame():GetParent();
        buttonsParent = TalentViewer:GetTalentFrame().ButtonsParent;
    end
    if not frame then return; end
    if self.db[settingKey] == nil then
        self.db[settingKey] = frame:GetScale();
    end

    self:SecureHook(frame, 'SetScale', function()
        self:OnShow(frame, settingKey);  -- Reset the scale if someone else tries to set it.
    end);
    self:SecureHookScript(frame, 'OnMouseWheel', function(_, delta) self:OnMouseWheel(frame, delta, settingKey); end);
    self:SecureHookScript(buttonsParent, 'OnMouseWheel', function(_, delta) self:OnMouseWheel(frame, delta, settingKey); end);
    self:SecureHookScript(frame, 'OnShow', function() self:OnShow(frame, settingKey); end);

    if frame:IsProtected() then
        Util:AddToCombatLockdownQueue(function()
            SetScale(frame, self.db[settingKey]);
            local helper = CreateFrame('Frame', nil, frame, 'SecureHandlerShowHideTemplate');
            frame.TTT_ScaleHelper = helper;
            helper:SetFrameRef('frame', frame);
            helper:SetAttribute('scale', self.db[settingKey]);
            helper:SetAttribute('_onshow', [[
                if not PlayerInCombat() then return; end

                local frame = self:GetFrameRef('frame');
                local scale = self:GetAttribute('scale');
                frame:SetScale(scale);
            ]]);
        end);
    else
        SetScale(frame, self.db[settingKey]);
    end
end

---@param frame Frame
---@param settingKey string
function Module:OnShow(frame, settingKey)
    if frame:IsProtected() and InCombatLockdown() then return; end

    SetScale(frame, self.db[settingKey]);
end

---@param frame Frame
---@param delta number
---@param settingKey string
function Module:OnMouseWheel(frame, delta, settingKey)
    if not IsControlKeyDown() then return; end

    local scale = self.db[settingKey] or 1;
    scale = scale + delta * 0.05;
    scale = math.max(0.5, math.min(2, scale));
    self.db[settingKey] = scale;
    if frame:IsProtected() and InCombatLockdown() then return; end
    if frame.TTT_ScaleHelper then
        frame.TTT_ScaleHelper:SetAttribute('scale', scale);
    end
    SetScale(frame, scale);
end

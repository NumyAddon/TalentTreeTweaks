local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @class TalentTreeTweaks_ScaleTalentFrame: AceModule, AceHook-3.0
local Module = Main:NewModule('ScaleTalentFrame', 'AceHook-3.0');

local TALENT_TREE_VIEWER = TalentViewerLoader and TalentViewerLoader:GetLodAddonName() or 'TalentTreeViewer';
local BLIZZARD_TALENT_UI = 2;

function Module:OnEnable()
    if self.blizzMoveEnabled then return end
    Util:OnTalentUILoad(function()
        self:SetupHook(BLIZZARD_TALENT_UI);
    end);
    EventUtil.ContinueOnAddOnLoaded(TALENT_TREE_VIEWER, function()
        self:SetupHook(TALENT_TREE_VIEWER);
    end)
end

function Module:OnDisable()
    if self.blizzMoveEnabled then return end

    if Util:GetTalentContainerFrame(true) then Util:GetTalentContainerFrame(true):SetScale(1); end
    if TalentViewer_DF then TalentViewer_DF:SetScale(1); end
    self:UnhookAll();
end

function Module:GetDescription()
    return L['Allows you to scale the talent tree with CTRL+Scrolling with the mousewheel.'];
end

function Module:GetName()
    return L['Scale Talent Frame'];
end

function Module:GetOptions(defaultOptionsTable, db)
    self.blizzMoveEnabled = C_AddOns.GetAddOnEnableState('BlizzMove', UnitName('player')) == 2;
    self.db = db;

    if self.blizzMoveEnabled then
        defaultOptionsTable.args.enable.disabled = true
        defaultOptionsTable.args.blizzMove = {
            type = 'description',
            name = L['This module is incompatible with BlizzMove, and has been disabled.'],
            order = 5,
        };
    end

    defaultOptionsTable.args.scale = {
        type = 'range',
        name = L['Change Scale'],
        order = 6,
        disabled = self.blizzMoveEnabled,
        get = function(info)
            return self.db[info[#info]];
        end,
        set = function(info, value)
            value = math.max(0.5, math.min(2, value));
            self.db[info[#info]] = value;
            local containerFrame = Util:GetTalentContainerFrame(true);
            if containerFrame and containerFrame.SetScale then containerFrame:SetScale(value); end
        end,
        min = 0.5,
        max = 2,
        step = 0.05,
        width = 'full',
    };

    return defaultOptionsTable;
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
    if self.db[settingKey] == nil then
        self.db[settingKey] = frame:GetScale();
    end

    self:SecureHookScript(frame, 'OnMouseWheel', function(_, delta) self:OnMouseWheel(frame, delta, settingKey); end);
    self:SecureHookScript(buttonsParent, 'OnMouseWheel', function(_, delta) self:OnMouseWheel(frame, delta, settingKey); end);
    self:SecureHookScript(frame, 'OnShow', function() self:OnShow(frame, settingKey); end);

    frame:SetScale(self.db[settingKey]);
end

function Module:OnShow(frame, settingKey)
    frame:SetScale(self.db[settingKey]);
end

function Module:OnMouseWheel(frame, delta, settingKey)
    if not IsControlKeyDown() then return end

    local scale = self.db[settingKey] or 1;
    scale = scale + delta * 0.05;
    scale = math.max(0.5, math.min(2, scale));
    self.db[settingKey] = scale;
    frame:SetScale(scale);
end

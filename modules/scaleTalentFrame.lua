local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;

local Module = Main:NewModule('ScaleTalentFrame', 'AceHook-3.0', 'AceEvent-3.0');

local ADDON_NAME_TALENT_TREE_VIEWER = 'TalentTreeViewer';
local ADDON_NAME_BLIZZARD_CLASS_TALENT_UI = 'Blizzard_ClassTalentUI';

function Module:OnEnable()
    if self.blizzMoveEnabled then return end

    if IsAddOnLoaded(ADDON_NAME_BLIZZARD_CLASS_TALENT_UI) then
        self:SetupHook(ADDON_NAME_BLIZZARD_CLASS_TALENT_UI);
    end
    if IsAddOnLoaded(ADDON_NAME_TALENT_TREE_VIEWER) then
        self:SetupHook(ADDON_NAME_TALENT_TREE_VIEWER);
    end
    self:RegisterEvent('ADDON_LOADED');
end

function Module:OnDisable()
    if self.blizzMoveEnabled then return end

    if ClassTalentFrame then ClassTalentFrame:SetScale(1); end
    if TalentViewer_DF then TalentViewer_DF:SetScale(1); end
    self:UnhookAll();
end

function Module:GetDescription()
    return 'Allows you to scale the talent tree with CTRL+Scrolling with the mousewheel.'
end

function Module:GetName()
    return 'Scale Talent Frame'
end

function Module:GetOptions(defaultOptionsTable, db)
    self.blizzMoveEnabled = GetAddOnEnableState(UnitName('player'), 'BlizzMove') == 2;
    self.db = db;

    if self.blizzMoveEnabled then
        defaultOptionsTable.args.enable.disabled = true
        defaultOptionsTable.args.blizzMove = {
            type = 'description',
            name = 'This module is incompatible with BlizzMove, and has been disabled.',
            order = 5,
        };
    end

    return defaultOptionsTable;
end

function Module:ADDON_LOADED(_, addon)
    if addon == ADDON_NAME_BLIZZARD_CLASS_TALENT_UI or addon == ADDON_NAME_TALENT_TREE_VIEWER then
        self:SetupHook(addon);
    end
end

function Module:SetupHook(addon)
    local settingKey, frame, buttonsParent
    if addon == ADDON_NAME_BLIZZARD_CLASS_TALENT_UI then
        settingKey = 'scale'
        frame = ClassTalentFrame
        buttonsParent = frame.TalentsTab.ButtonsParent
    end
    if addon == ADDON_NAME_TALENT_TREE_VIEWER then
        settingKey = 'viewerScale'
        frame = TalentViewer_DF
        buttonsParent = frame.Talents.ButtonsParent
    end
    if self.db[settingKey] == nil then
        self.db[settingKey] = frame:GetScale();
    end

    self:HookScript(frame, 'OnMouseWheel', function(_, delta) self:OnMouseWheel(frame, delta, settingKey); end);
    self:HookScript(buttonsParent, 'OnMouseWheel', function(_, delta) self:OnMouseWheel(frame, delta, settingKey); end);
    self:HookScript(frame, 'OnShow', function() self:OnShow(frame, settingKey); end);

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

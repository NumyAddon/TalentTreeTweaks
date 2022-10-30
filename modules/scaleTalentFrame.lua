local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;

local Module = Main:NewModule('ScaleTalentFrame', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnEnable()
    if self.blizzMoveEnabled then return end

    if IsAddOnLoaded('Blizzard_ClassTalentUI') then
        self:SetupHook();
    else
        self:RegisterEvent('ADDON_LOADED');
    end
end

function Module:OnDisable()
    if self.blizzMoveEnabled then return end

    ClassTalentFrame:SetScale(1);
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
    if addon == 'Blizzard_ClassTalentUI' then
        self:SetupHook();
        self:UnregisterEvent('ADDON_LOADED');
    end
end

function Module:SetupHook()
    if self.db.scale == nil then
        self.db.scale = ClassTalentFrame:GetScale();
    end

    self:HookScript(ClassTalentFrame, 'OnMouseWheel', 'OnMouseWheel');
    self:HookScript(ClassTalentFrame.TalentsTab.ButtonsParent, 'OnMouseWheel', 'OnMouseWheel');

    ClassTalentFrame:SetScale(self.db.scale);
end

function Module:OnMouseWheel(_, delta)
    if not IsControlKeyDown() then return end

    local scale = self.db.scale or 1;
    scale = scale + delta * 0.05;
    scale = math.max(0.5, math.min(2, scale));
    self.db.scale = scale;
    ClassTalentFrame:SetScale(scale);
end

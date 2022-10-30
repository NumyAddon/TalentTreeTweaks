local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;

local Module = Main:NewModule('ScaleTalentFrame', 'AceHook-3.0', 'AceEvent-3.0');

function Module:OnEnable()
    if self.blizzMoveEnabled then return end

    local registerEvent = false
    if IsAddOnLoaded('Blizzard_ClassTalentUI') then
        self:SetupHook('Blizzard_ClassTalentUI');
    else
        registerEvent = true;
    end
    if GetAddOnEnableState(UnitName('player'), 'TalentTreeViewer') == 2 then
        if IsAddOnLoaded('TalentTreeViewer') then
            self:SetupHook('TalentTreeViewer');
        else
            registerEvent = true;
        end
    end
    if registerEvent then
        self:RegisterEvent('ADDON_LOADED');
    end
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
    if addon == 'Blizzard_ClassTalentUI' or addon == 'TalentTreeViewer' then
        self:SetupHook(addon);
    end
end

function Module:SetupHook(addon)
    if addon == 'Blizzard_ClassTalentUI' then
        if self.db.scale == nil then
            self.db.scale = ClassTalentFrame:GetScale();
        end

        self:HookScript(ClassTalentFrame, 'OnMouseWheel', 'OnMouseWheelBlizzard');
        self:HookScript(ClassTalentFrame.TalentsTab.ButtonsParent, 'OnMouseWheel', 'OnMouseWheelBlizzard');

        ClassTalentFrame:SetScale(self.db.scale);
    end
    if addon == 'TalentTreeViewer' then
        if self.db.viewerScale == nil then
            self.db.viewerScale = TalentViewer_DF:GetScale();
        end

        self:HookScript(TalentViewer_DF, 'OnMouseWheel', 'OnMouseWheelTalentTreeViewer');
        self:HookScript(TalentViewer_DF.Talents.ButtonsParent, 'OnMouseWheel', 'OnMouseWheelTalentTreeViewer');

        TalentViewer_DF:SetScale(self.db.viewerScale);
    end
end

function Module:OnMouseWheelBlizzard(_, delta)
    if not IsControlKeyDown() then return end

    local scale = self.db.scale or 1;
    scale = scale + delta * 0.05;
    scale = math.max(0.5, math.min(2, scale));
    self.db.scale = scale;
    ClassTalentFrame:SetScale(scale);
end

function Module:OnMouseWheelTalentTreeViewer(_, delta)
    if not IsControlKeyDown() then return end

    local scale = self.db.viewerScale or 1;
    scale = scale + delta * 0.05;
    scale = math.max(0.5, math.min(2, scale));
    self.db.viewerScale = scale;
    TalentViewer_DF:SetScale(scale);
end

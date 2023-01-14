local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;

local Module = Main:NewModule('MiscFixes', 'AceHook-3.0');

function Module:OnEnable()
    EventUtil.ContinueOnAddOnLoaded('Blizzard_ClassTalentUI', function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();

    if ClassTalentFrame and ClassTalentFrame.TalentsTab then
        ClassTalentFrame.TalentsTab:UnregisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquire, self);
    end
end

function Module:GetDescription()
    return 'Adds a few fixes for minor issues.';
end

function Module:GetName()
    return 'Misc Fixes';
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;

    local defaults = {
        fixButtonMouseOver = true,
    }
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    local get = function(info)
        return self.db[info[#info]];
    end
    local set = function(info, value)
        self.db[info[#info]] = value;
        self:UpdateButtonHooks();
    end

    defaultOptionsTable.args.fixButtonMouseOver = {
        type = 'toggle',
        name = 'Fix talent tooltips showing up incorrectly',
        desc = 'Prevents the tooltip from showing when the button is underneath another frame.',
        get = get,
        set = set,
        order = 10,
    };

    return defaultOptionsTable;
end

function Module:SetupHook()
    local talentsTab = ClassTalentFrame.TalentsTab;

    talentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    self:UpdateButtonHooks();
end

function Module:UpdateButtonHooks()
    if not ClassTalentFrame or not ClassTalentFrame.TalentsTab then return; end

    local talentsTab = ClassTalentFrame.TalentsTab;
    for talentButton in talentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton);
    end
end

function Module:OnButtonUpdateMouseOverInfo(talentButton)
    --- The original function checks if the mouse is over the button, but the more intuitive behavior is to check if
    --- the button is the mouse's focus. This is especially important when the button is underneath another frame.
    --- We also check if the current tooltip is owned by the button, just to update the tooltip if it's already showing.
    if GetMouseFocus() == talentButton or GameTooltip:GetOwner() == talentButton then
        talentButton:OnEnter();
    end
end

function Module:OnTalentButtonAcquired(talentButton)
    if self.db.fixButtonMouseOver then
        if not self:IsHooked(talentButton, 'UpdateMouseOverInfo') then
            self:RawHook(talentButton, 'UpdateMouseOverInfo', 'OnButtonUpdateMouseOverInfo', true);
        end
    else
        self:Unhook(talentButton, 'UpdateMouseOverInfo');
    end
end


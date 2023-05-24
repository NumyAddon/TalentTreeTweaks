local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local Module = Main:NewModule('HighlightCascadeRepurchable');
Module.enabled = false;

function Module:OnEnable()
    self.enabled = true;
    self.buttonTextures = self.buttonTextures or {};
    Util:OnClassTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self.enabled = false;
    if(self.buttonTextures) then
        for _, texture in pairs(self.buttonTextures) do
            texture:Hide();
        end
    end
    if ClassTalentFrame and ClassTalentFrame.TalentsTab then
        ClassTalentFrame.TalentsTab:UnregisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self);
    end
end

function Module:GetDescription()
    return L['Adds a more obvious highlight when you can relearn talents in bulk by shift-clicking them.'];
end

function Module:GetName()
    return L['Highlight Cascade Repurchable'];
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;

    local defaults = {
        color = {
            r = 0,
            g = 0,
            b = 1,
            a = 0.5,
        },
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
        self:UpdateColors();
    end
    defaultOptionsTable.args.color = {
        type = 'color',
        name = COLOR,
        desc = L['Color of the highlight'],
        hasAlpha = true,
        get = GetColor,
        set = SetColor,
        order = 5,
    };
    defaultOptionsTable.args.reset = {
        type = 'execute',
        name = RESET,
        desc = L['Reset the color to default'],
        func = function()
            self.db.color = defaults.color;
            self:UpdateColors();
        end,
        order = 6,
    };

    return defaultOptionsTable;
end

function Module:SetupHook()
    ClassTalentFrame.TalentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    for talentButton in ClassTalentFrame.TalentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton);
    end
end

function Module:UpdateColors()
    if(self.buttonTextures) then
        for _, texture in pairs(self.buttonTextures) do
            texture:SetVertexColor(self.db.color.r, self.db.color.g, self.db.color.b, self.db.color.a);
        end
    end
end

local function UpdateNonStateVisualsHook(button)
    if not Module.enabled then return; end
    Module.buttonTextures[button]:SetShown(button:IsCascadeRepurchasable());
end

function Module:OnTalentButtonAcquired(button)
    if not self.buttonTextures[button] then
        self.buttonTextures[button] = button:CreateTexture(nil, 'OVERLAY')
        local texture = self.buttonTextures[button];
        texture:SetAllPoints(button);
        texture:SetTexture('Interface/Tooltips/UI-Tooltip-Background');
        texture:SetVertexColor(self.db.color.r, self.db.color.g, self.db.color.b, self.db.color.a);
        texture:AddMaskTexture(button.IconMask);
        texture:Hide();
        hooksecurefunc(button, 'UpdateNonStateVisuals', UpdateNonStateVisualsHook);
    end
    UpdateNonStateVisualsHook(button);
end


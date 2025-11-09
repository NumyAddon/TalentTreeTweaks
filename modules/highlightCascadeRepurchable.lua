--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

--- @class TTT_HighlightCascadeRepurchable: TTT_Module
local Module = Main:NewModule('HighlightCascadeRepurchable');
Module.enabled = false;

function Module:OnEnable()
    self.enabled = true;
    self.buttonTextures = self.buttonTextures or {};
    Util:OnTalentUILoad(function() self:SetupHook(); end);
end

function Module:OnDisable()
    self.enabled = false;
    if self.buttonTextures then
        for _, texture in pairs(self.buttonTextures) do
            texture:Hide();
        end
    end
    if Util:GetTalentFrame() then
        Util:GetTalentFrame():UnregisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self);
    end
end

function Module:GetDescription()
    return L['Adds a more obvious highlight when you can relearn talents in bulk by shift-clicking them.'];
end

function Module:GetName()
    return L['Highlight Cascade Repurchable'];
end

--- @param configBuilder TTT_ConfigBuilder
--- @param db TTT_HighlightCascadeRepurchableDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class TTT_HighlightCascadeRepurchableDB
    local defaults = {
        color = {
            r = 0,
            g = 0,
            b = 1,
            a = 0.5,
        },
    };
    configBuilder:SetDefaults(defaults, true);
    configBuilder:MakeColorPicker(
        COLOR,
        'color',
        L['Color of the highlight'],
        function() self:UpdateColors(); end
    );
    configBuilder:MakeButton(
        RESET,
        function()
            self.db.color = defaults.color;
            self:UpdateColors();
        end,
        L['Reset the color to default']
    );
end

function Module:SetupHook()
    Util:GetTalentFrame():RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    for talentButton in Util:GetTalentFrame():EnumerateAllTalentButtons() do
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


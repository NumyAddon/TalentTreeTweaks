local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local Module = Main:NewModule("ReduceSpam", "AceHook-3.0");

function Module:OnEnable()
    Util:OnClassTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
end

function Module:GetDescription()
    return L["Mute chat spam while switching loadouts or specs."];
end

function Module:GetName()
    return L["Reduce spam"];
end

function Module:SetupHook()
    self:SetFilterEnabled(true);
end

function Module:SetFilterEnabled(enable)
    if enable then
        ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", self.FilterMessage);
    else
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", self.FilterMessage);
    end
end

local messagesToHide = {
    ERR_SPELL_UNLEARNED_S,
    ERR_LEARN_PASSIVE_S,
    ERR_LEARN_SPELL_S,
    ERR_LEARN_ABILITY_S,
};
Module.FilterMessage = function(_, _, message)
    for _, messageToHide in ipairs(messagesToHide) do
        if message:find("^" .. messageToHide:format(".*") .. "$") then return true; end
    end
end

local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local GetSpellLink = GetSpellLink or C_Spell.GetSpellLink;

--- @class TalentTreeTweaks_MiscFixes: AceModule, AceHook-3.0
local Module = Main:NewModule('MiscFixes', 'AceHook-3.0');

function Module:OnEnable()
    EventRegistry:RegisterCallback('TalentButton.OnClick', self.OnButtonClick, self);
    Util:OnTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    EventRegistry:UnregisterCallback('TalentButton.OnClick', self);
    self:UnhookAll();
end

function Module:GetDescription()
    return L['Adds a few fixes for minor issues.'];
end

function Module:GetName()
    return L['Misc Fixes'];
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;

    local defaults = {
        dropdownUpdateOnLoadConfigFix = true,
        linkChoiceNodeInChatFix = true,
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
        self:UpdateSetting(info[#info], value);
    end

    defaultOptionsTable.args.dropdownUpdateOnLoadConfigFix = {
        type = 'toggle',
        name = L['Fix issue with the loadout dropdown not updating'],
        desc = L['Macros and certain addons that change loadouts, cause the dropdown to not update properly in some situations. This fixes that.'],
        get = get,
        set = set,
        order = 10,
    };

    defaultOptionsTable.args.linkChoiceNodeInChatFix = {
        type = 'toggle',
        name = L['Fix issue that prevents linking choice talents in chat, when inspecting a build'],
        get = get,
        set = set,
        order = 15,
    }

    return defaultOptionsTable;
end

function Module:UpdateSetting(key, value)
    self.db[key] = value;
    if key == 'dropdownUpdateOnLoadConfigFix' then
        if value then
            self:SetupDropDownUpdateHook();
        else
            self:UnhookDropDownUpdateHook();
        end
    end
end

function Module:SetupHook()
    if self.db.dropdownUpdateOnLoadConfigFix then
        self:SetupDropDownUpdateHook();
    end
end

function Module:OnButtonClick(buttonFrame, mouseButton)
    if not self.db.linkChoiceNodeInChatFix then
        return;
    end

    -- The default UI has an early return if IsInspecting is true, which prevents linking to chat
    if
        mouseButton == 'LeftButton' and buttonFrame and buttonFrame.selectionIndex
        and buttonFrame.IsInspecting and buttonFrame:IsInspecting() and IsModifiedClick("CHATLINK")
    then
        local spellID = buttonFrame:GetSpellID();
        if spellID then
            local spellLink = GetSpellLink(spellID);
            ChatEdit_InsertLink(spellLink);
        end
    end
end

function Module:SetupDropDownUpdateHook()
    local talentsTab = Util:GetTalentFrame();
    local dropdown = talentsTab.LoadoutDropDown or talentsTab.LoadSystem;

    self:SecureHook(talentsTab, 'CheckUpdateLastSelectedConfigID', function(frame, configID)
        if
            frame:IsInspecting() or not configID or configID == C_ClassTalents.GetActiveConfigID()
        then
            return;
        end

        dropdown:SetSelectionID(configID);
    end)
end

function Module:UnhookDropDownUpdateHook()
    self:Unhook(Util:GetTalentFrame(), 'CheckUpdateLastSelectedConfigID');
end

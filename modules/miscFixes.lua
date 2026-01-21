--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

local ChatEdit_InsertLink = ChatFrameUtil and ChatFrameUtil.InsertLink or ChatEdit_InsertLink;
local GetSpellLink = C_Spell.GetSpellLink;

--- @class TTT_MiscFixes: NumyConfig_Module, AceHook-3.0
local Module = Main:NewModule('MiscFixes', 'AceHook-3.0');

function Module:OnEnable()
    EventRegistry:RegisterCallback('TalentButton.OnClick', self.OnButtonClick, self);
    Util:OnTalentUILoad(function() self:SetupHook(); end);
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

--- @param configBuilder NumyConfigBuilder
--- @param db TTT_MiscFixesDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class TTT_MiscFixesDB
    local defaults = {
        dropdownUpdateOnLoadConfigFix = true,
        dropdownFixOrder = true,
        linkChoiceNodeInChatFix = true,
    };
    configBuilder:SetDefaults(defaults, true);

    configBuilder:MakeCheckbox(
        L['Fix issue with the loadout dropdown not updating'],
        'dropdownUpdateOnLoadConfigFix',
        L['Macros and certain addons that change loadouts, cause the dropdown to not update properly in some situations. This fixes that.'],
        function(_, value)
            if value then self:SetupDropDownUpdateHook(); else self:UnhookDropDownUpdateHook(); end
        end
    );
    configBuilder:MakeCheckbox(
        L['Fix the loadout dropdown having a random order'],
        'dropdownFixOrder',
        L['Changes the loadout to be ordered based on when a loadout was created.'],
        function(_, value)
            if value then self:SetupDropdownOrderHook(); else self:UnhookDropdownOrderHook(); end
        end
    );
    configBuilder:MakeCheckbox(
        L['Fix issue that prevents linking choice talents in chat, when inspecting a build'],
        'linkChoiceNodeInChatFix'
    );
end

function Module:SetupHook()
    if self.db.dropdownUpdateOnLoadConfigFix then
        self:SetupDropDownUpdateHook();
    end
    if self.db.dropdownFixOrder then
        self:SetupDropdownOrderHook();
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

function Module:SetupDropdownOrderHook()
    local talentsTab = Util:GetTalentFrame()
    local dropdown = talentsTab.LoadSystem;
    local function sortSelections()
        --- @param a number
        --- @param b number
        table.sort(dropdown.possibleSelections, function(a, b)
            -- sort negative values at the bottom, positive values in ascending order
            if a < 0 and b < 0 then
                return false;
            elseif a < 0 then
                return false;
            elseif b < 0 then
                return true;
            else
                return a < b;
            end
        end);
    end
    self:SecureHook(dropdown, 'SetSelectionOptions', function()
        sortSelections();
    end);
    sortSelections();
end

function Module:UnhookDropdownOrderHook()
    self:Unhook(Util:GetTalentFrame().LoadSystem, 'SetSelectionOptions');
end

function Module:SetupDropDownUpdateHook()
    local talentsTab = Util:GetTalentFrame();
    local dropdown = talentsTab.LoadSystem;

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

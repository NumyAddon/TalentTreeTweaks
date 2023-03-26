local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;

local Module = Main:NewModule('ExportInspectedBuild', 'AceHook-3.0');

function Module:OnEnable()
    Util:OnClassTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if ClassTalentFrame and ClassTalentFrame.TalentsTab then
        ClassTalentFrame.TalentsTab.LoadoutDropDown:SetRightClickCallback(nil);
    end
end

function Module:GetDescription()
    return 'Adds a right-click option to the loadout dropdown to export your build.';
end

function Module:GetName()
    return 'Export Loadouts';
end

function Module:SetupHook()
    local talentsTab = ClassTalentFrame.TalentsTab;

    local dropdown = talentsTab.LoadoutDropDown;
    dropdown:SetRightClickCallback(function(configID)
        local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID);
        if not ok or not configInfo then return; end
        local exportString = Util:GetLoadoutExportString(talentsTab, configID);
        Util:CopyText(exportString, 'Talent Loadout String');
    end);
    self:SecureHook(dropdown.DropDownControl, 'SetCustomSetup', 'HookCustomSetupCallback');
    self:HookCustomSetupCallback(dropdown.DropDownControl);
end

function Module:HookCustomSetupCallback(dropdownControl)
    if not self:IsHooked(dropdownControl, 'customSetupCallback') then
        self:SecureHook(dropdownControl, 'customSetupCallback', function(info)
            local originalFuncOnEnter = info.funcOnEnter;
            local originalFuncOnLeave = info.funcOnLeave;
            info.funcOnEnter = function(dropdownButton, ...)
                self:LoadoutDropdownOnEnter(dropdownButton);
                if(originalFuncOnEnter) then originalFuncOnEnter(dropdownButton, ...); end
            end
            info.funcOnLeave = function(dropdownButton, ...)
                self:LoadoutDropdownOnLeave(dropdownButton);
                if(originalFuncOnLeave) then originalFuncOnLeave(dropdownButton, ...); end
            end
        end);
    end
end

function Module:LoadoutDropdownOnEnter(dropdownButton)
    local ok, configInfo = pcall(C_Traits.GetConfigInfo, dropdownButton.value);
    if not ok or not configInfo then return; end

    if dropdownButton ~= GameTooltip:GetOwner() or not GameTooltip:IsShown() then
        self.tooltipShown = true;
        GameTooltip:SetOwner(dropdownButton, "ANCHOR_RIGHT");
    end
    GameTooltip:AddLine("Right-click to share");
    GameTooltip:Show();
end

function Module:LoadoutDropdownOnLeave(dropdownButton)
    if self.tooltipShown then GameTooltip:Hide(); end
    self.tooltipShown = false
end

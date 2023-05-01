local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;

local LEVEL_CAP = 70;

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
    if self.linkButton then self.linkButton:Hide(); end
end

function Module:GetDescription()
    return [[
Adds a right-click option to the loadout dropdown to export your build.

Adds a button to link the currently shown build in chat.
]];
end

function Module:GetName()
    return 'Export Loadouts';
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        exportOnDropdownRightClick = true,
        showLinkInChatButton = true,
    };
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    local counter = CreateCounter(10);

    local get = function(info)
        return self.db[info[#info]];
    end
    local set = function(info, value)
        self.db[info[#info]] = value;
        self:OnDisable();
        self:OnEnable();
    end
    defaultOptionsTable.args.exportOnDropdownRightClick = {
        type = 'toggle',
        name = 'Export on Right-Click',
        desc = 'Adds a right-click option to the loadout dropdown to export your build.',
        order = counter(),
        get = get,
        set = set,
    };
    defaultOptionsTable.args.showLinkInChatButton = {
        type = 'toggle',
        name = 'Show '.. (TALENT_FRAME_DROP_DOWN_EXPORT_CHAT_LINK or 'Post in Chat') ..' Button',
        desc = 'Adds a button to link the currently shown build in chat.',
        order = counter(),
        get = get,
        set = set,
    }

    return defaultOptionsTable;
end


function Module:SetupHook()
    local talentsTab = ClassTalentFrame.TalentsTab;

    if self.db.exportOnDropdownRightClick then
        self:SetupDropdownHook(talentsTab);
    end

    if self.db.showLinkInChatButton then
        if not self.linkButton then
            self.linkButton = self:MakeLinkButton(talentsTab);
        end
        self.linkButton:Show();
    end
end

function Module:MakeLinkButton(talentsTab)
    local button = CreateFrame('Button', nil, talentsTab, 'UIPanelButtonNoTooltipTemplate, UIButtonTemplate');
    button:SetText(TALENT_FRAME_DROP_DOWN_EXPORT_CHAT_LINK or 'Post in Chat');
    button:SetSize(100, 22);
    button:SetPoint('BOTTOMLEFT', 47, 5);
    button:SetScript('OnClick', function()
        local exportString = Util:GetLoadoutExportString(talentsTab);

        if not TALENT_BUILD_CHAT_LINK_TEXT then
            if not ChatEdit_InsertLink(exportString) then
                ChatFrame_OpenChat(exportString);
            end
            return;
        end

        local specName = talentsTab:GetSpecName();
        local className = talentsTab:GetClassName();
        local specID = talentsTab:GetSpecID();
        local classColor = RAID_CLASS_COLORS[select(2, GetClassInfo(talentsTab:GetClassID()))];
        local level = LEVEL_CAP;

        local linkDisplayText = ("[%s]"):format(TALENT_BUILD_CHAT_LINK_TEXT:format(specName, className));
        local linkText = LinkUtil.FormatLink("talentbuild", linkDisplayText, specID, level, exportString);
        local chatLink = classColor:WrapTextInColorCode(linkText);
        if not ChatEdit_InsertLink(chatLink) then
            ChatFrame_OpenChat(chatLink);
        end
    end);

    return button;
end

function Module:SetupDropdownHook(talentsTab)
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

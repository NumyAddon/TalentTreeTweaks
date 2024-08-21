local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local LEVEL_CAP = 80;

--- @class TalentTreeTweaks_ExportInspectedBuild: AceModule, AceHook-3.0
local Module = Main:NewModule('ExportInspectedBuild', 'AceHook-3.0');

Module.overlayPool = {
    --- @type table<BUTTON, true>
    active = {},
    --- @type BUTTON[]
    inactive = {},
    --- @return BUTTON?
    Acquire = function(self)
        local btn = table.remove(self.inactive);
        if not btn then return; end
        self.active[btn] = true;
        return btn;
    end,
    --- @param btn BUTTON
    Release = function(self, btn)
        self.active[btn] = nil;
        table.insert(self.inactive, btn);
        btn:ClearAllPoints();
        btn:Hide();
    end,
};
for i = 1, 50 do
    local btn = CreateFrame('BUTTON');
    btn:RegisterForClicks('RightButtonDown');
    btn:RegisterForClicks('RightButtonUp');
    btn:SetPassThroughButtons('LeftButton');
    btn:SetPropagateMouseMotion(true);
    btn:Hide();
    Module.overlayPool.inactive[i] = btn;
end

function Module:OnInitialize()
    Menu.ModifyMenu('MENU_CLASS_TALENT_PROFILE', function(dropdown, rootDescription, contextData)
        if self:IsEnabled() and self.db.exportOnDropdownRightClick then
            self:OnLoadoutMenuOpen(dropdown, rootDescription);
        end
    end);
end

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if self.linkButton then self.linkButton:Hide(); end
end

function Module:GetDescription()
    return
        L['Adds a right-click option to the loadout dropdown to export your build.']
        .. '\n\n' ..
        L['Adds a button to link the currently shown build in chat.'];
end

function Module:GetName()
    return L['Export Loadouts'];
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
        name = L['Export on Right-Click'],
        desc = L['Adds a right-click option to the loadout dropdown to export your build.'],
        order = counter(),
        get = get,
        set = set,
    };
    defaultOptionsTable.args.showLinkInChatButton = {
        type = 'toggle',
        name = string.format(L['Show %s Button'], TALENT_FRAME_DROP_DOWN_EXPORT_CHAT_LINK or L['Post in Chat']),
        desc = L['Adds a button to link the currently shown build in chat.'],
        order = counter(),
        get = get,
        set = set,
    }

    return defaultOptionsTable;
end


function Module:SetupHook()
    local talentsTab = Util:GetTalentFrame();

    if self.db.showLinkInChatButton then
        self:SecureHook(talentsTab, 'UpdateInspecting', 'OnUpdateInspecting');
        if not self.linkButton then
            self.linkButton = self:MakeLinkButton(talentsTab);
        end
        self.linkButton:Show();
    end
end

function Module:OnUpdateInspecting(talentsTab)
    local isInspecting = talentsTab:IsInspecting();
    if not isInspecting then
        self.cachedInspectSpecID = nil;
        self.cachedInspectClassID = nil;
        self.cachedInspectUnitSex = nil;
        self.cachedInspectExportString = nil;

        return;
    end
    self.cachedInspectSpecID = talentsTab:GetSpecID();
    self.cachedInspectClassID = talentsTab:GetClassID();
    self.cachedInspectUnitSex = Util:GetTalentContainerFrame():GetUnitSex();
    self.cachedInspectExportString = talentsTab:GetInspectUnit() and C_Traits.GenerateInspectImportString(talentsTab:GetInspectUnit()) or talentsTab:GetInspectString();
end

function Module:MakeLinkButton(talentsTab)
    local button = CreateFrame('Button', nil, talentsTab, 'UIPanelButtonNoTooltipTemplate, UIButtonTemplate');
    talentsTab.TalentTreeTweaks_LinkToChatButton = button;
    button:SetText(TALENT_FRAME_DROP_DOWN_EXPORT_CHAT_LINK or L['Post in Chat']);
    button:SetSize(100, 22);
    button:SetPoint('BOTTOMLEFT', 47, 5);
    button:SetScript('OnClick', function()
        local specID = self.cachedInspectSpecID or talentsTab:GetSpecID();
        local classID = self.cachedInspectClassID or talentsTab:GetClassID();
	    local unitSex = self.cachedInspectUnitSex or Util:GetTalentContainerFrame():GetUnitSex();
        local exportString = self.cachedInspectExportString or Util:GetLoadoutExportString(talentsTab);

	    local specName = select(2, GetSpecializationInfoByID(specID, unitSex));
	    local classInfo = C_CreatureInfo.GetClassInfo(classID);
        local className = classInfo and classInfo.className;
        local classColor = RAID_CLASS_COLORS[classInfo and classInfo.classFile];
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

function Module:ApplyLoadoutMenuItemOverlay(attachment, configID)
    local btn = self.overlayPool:Acquire();
    if not btn then
        Util:DebugPrint('No buttons available in overlay pool');
        return;
    end
    btn:SetParent(attachment);
    btn:SetAllPoints();
    btn:Show();
    btn:SetScript('OnClick', function()
        local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID);
        if not ok or not configInfo then return; end
        local talentsTab = Util:GetTalentFrame();
        local exportString = Util:GetLoadoutExportString(talentsTab, configID);
        Util:CopyText(exportString, L['Talent Loadout String']);
    end);
    attachment:SetScript('OnHide', function() self.overlayPool:Release(btn) end);
end

function Module:OnLoadoutMenuOpen(dropdown, rootDescription)
    for _, elementDescription in rootDescription:EnumerateElementDescriptions() do
        local configID = elementDescription:GetData();
        local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID);
        if ok and configInfo then
            elementDescription:HookOnEnter(function(frame)
                if frame ~= GameTooltip:GetOwner() or not GameTooltip:IsShown() then
                    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
                end
                GameTooltip:AddLine(L["Right-click to share"]);
                GameTooltip:Show();
            end);
            elementDescription:AddInitializer(function(button, description, menu)
                -- all this crap, is only because blizzard doesn't reset the button's script when it's reused :/
                local attachment = button:AttachFrame('FRAME');
                attachment:SetAllPoints();
                self:ApplyLoadoutMenuItemOverlay(attachment, configID);
            end);
        end
    end
end

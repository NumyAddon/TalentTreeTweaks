local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @type LibUIDropDownMenuNumy-4.0
local LibDD = LibStub('LibUIDropDownMenuNumy-4.0');

if Util.isDF then
    TalentTreeTweaks_DropDownControlReplacementMixin = CreateFromMixins(DropDownControlMixin);
end

--- @class TalentTreeTweaks_ReduceTaintModule: AceModule, AceHook-3.0
local Module = Main:NewModule('ReduceTaint', 'AceHook-3.0');

function Module:OnInitialize()
    if Util.isDF then return; end
    Menu.ModifyMenu('MENU_CLASS_TALENT_PROFILE', function(dropdown, rootDescription, contextData)
        if not self:IsEnabled() then return; end
        self:OnLoadoutMenuOpen(dropdown, rootDescription);
    end);
end

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupHook();
    end, 1); -- load before any other module
    self:HandleActionBarEventTaintSpread();
end

function Module:OnDisable()
    if self.db.replaceDropDown and Util.isDF then
        self:DisableDropDownReplacement();
    end
    self:UnhookAll();
end

function Module:GetDescription()
    return
        L['Implements various workarounds around taint.']
        .. '\n\n' ..
        (Util.isDF and L['Fully replace the loadout dropdown, to avoid tainting the edit mode dropdown.'] or '')
        .. (Util.isDF and '\n\n' or '') ..
        L['A workaround for one of the ways that Talent Tree taint can block action buttons from working.']
        .. '\n\n' ..
        L['Replace the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when needed.'];
end

function Module:GetName()
    return L['Reduce Taint'];
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        replaceDropDown = Util.isDF,
        disableMultiActionBarShowHide = true,
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
    end
    defaultOptionsTable.args.extra_info = {
        type = 'description',
        name = L['You have to reload your UI after disabling this module, for some of the change to take effect.'],
        order = 5,
    };
    if Util.isDF then
        defaultOptionsTable.args.replaceDropDown = {
            type = 'toggle',
            name = L['Replace Loadout Dropdown'],
            desc = L['Replace the loadout dropdown, to avoid tainting the edit mode dropdown.'],
            order = counter(),
            get = get,
            set = function(info, value)
                set(info, value);
                if value then
                    self:EnableDropDownReplacement();
                else
                    self:DisableDropDownReplacement();
                end
            end,
        };
    else
        self.db.replaceDropDown = nil;
    end
    defaultOptionsTable.args.alwaysReplaceShareButton = {
        type = 'toggle',
        name = L['Always Replace Share Button'],
        desc = L['Replace the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when possible.'],
        order = counter(),
        get = get,
        set = set,
    };
    defaultOptionsTable.args.disableMultiActionBarShowHide = {
        type = 'toggle',
        name = L['Disable MultiActionBar_ShowAllGrids on Show'],
        desc = L['Disables the MultiActionBar_ShowAllGrids function, which can cause action buttons to break.'],
        order = counter(),
        get = get,
        set = function(info, value)
            set(info, value);
            self:HandleMultiActionBarTaint();
        end,
    }

    return defaultOptionsTable;
end

function Module:SetupHook()
    if Util.isDF and self.db.replaceDropDown then
        self:EnableDropDownReplacement();
    end

    local talentsTab = Util:GetTalentFrame();
    talentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    for talentButton in talentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton);
    end
    self:SecureHook(talentsTab, 'ShowSelections', 'OnShowSelections');

    if Util.isDF then -- todo: remove after 11.0 release
        -- GetSentinelKeyInfoFromSelectionID happens just before callbacks are executed, so that's as good a place as any, to replace the callback
        self:SecureHook(talentsTab.LoadoutDropDown, 'GetSentinelKeyInfoFromSelectionID', function(dropdown, selectionID) self:ReplaceShareButton(dropdown, selectionID) end);
    end

    -- ToggleTalentFrame starts of with a talentContainerFrame:SetInspecting call, which has a high likelihood of tainting execution
    self:SecureHook('ShowUIPanel', 'OnShowUIPanel')
    self:SecureHook('HideUIPanel', 'OnHideUIPanel')

    self:SecureHook(talentsTab, 'UpdateInspecting', 'OnUpdateInspecting');
    self:ReplaceCopyLoadoutButton(talentsTab);

    self:HandleMultiActionBarTaint();
end

function Module:OnUpdateInspecting(talentsTab)
    local isInspecting = talentsTab:IsInspecting();
    if not isInspecting then
        self.cachedInspectExportString = nil;

        return;
    end
    self.cachedInspectExportString = talentsTab:GetInspectUnit() and C_Traits.GenerateInspectImportString(talentsTab:GetInspectUnit()) or talentsTab:GetInspectString();
end

function Module:ReplaceCopyLoadoutButton(talentsTab)
    talentsTab.InspectCopyButton:SetOnClickHandler(function()
        local loadoutString =
            self.cachedInspectExportString
            or (talentsTab:GetInspectUnit() and C_Traits.GenerateInspectImportString(talentsTab:GetInspectUnit()) or talentsTab:GetInspectString());
        if loadoutString and (loadoutString ~= '') then
            Util:CopyText(loadoutString, L['Inspected Build']);
        end
    end);
end

local function purgeKey(table, key)
    TextureLoadingGroupMixin.RemoveTexture({textures = table}, key);
end
local function makeFEnvReplacement(original, replacement)
    local fEnv = {};
    setmetatable(fEnv, { __index = function(t, k)
        return replacement[k] or original[k];
    end});
    return fEnv;
end

function Module:HandleMultiActionBarTaint()
    local talentContainerFrame = Util:GetTalentContainerFrame();
    if self.db.disableMultiActionBarShowHide then
        self.originalOnShowFEnv = self.originalOnShowFEnv or getfenv(talentContainerFrame.OnShow);

        if
            not (TalentMicroButton and TalentMicroButton.EvaluateAlertVisibility)
            and not (PlayerSpellsMicroButton and PlayerSpellsMicroButton.EvaluateAlertVisibility)
        then
            Util:DebugPrint('cannot find the Talent MicroButton, it can spread taint to action bars if not handled properly');
        end

        setfenv(talentContainerFrame.OnShow, makeFEnvReplacement(self.originalOnShowFEnv, {
            TalentMicroButton = {
                EvaluateAlertVisibility = function()
                    HelpTip:HideAllSystem('MicroButtons');
                end,
            },
            PlayerSpellsMicroButton = {
                EvaluateAlertVisibility = function()
                    HelpTip:HideAllSystem('MicroButtons');
                end,
            },
            MultiActionBar_ShowAllGrids = nop,
            UpdateMicroButtons = function() self:TriggerMicroButtonUpdate() end,
        }));

        self:SecureHook(FrameUtil, 'UnregisterFrameForEvents', function(frame)
            if frame == talentContainerFrame then
                self:MakeOnHideSafe();
            end
        end);
    elseif self.originalOnShowFEnv then
        setfenv(talentContainerFrame.OnShow, self.originalOnShowFEnv);
        self:Unhook(FrameUtil, 'UnregisterFrameForEvents');
    end
    local microButton = TalentMicroButton or PlayerSpellsMicroButton;
    if
        self.originalOnShowFEnv
        and microButton and microButton.HasTalentAlertToShow
        and not self:IsHooked(microButton, 'HasTalentAlertToShow')
    then
        self:SecureHook(microButton, 'HasTalentAlertToShow', function()
            purgeKey(microButton, 'canUseTalentUI');
            purgeKey(microButton, 'canUseTalentSpecUI');
        end);
    end
end

function Module:MakeOnHideSafe()
    local talentContainerFrame = Util:GetTalentContainerFrame();
    if not issecurevariable(talentContainerFrame, 'lockInspect') then
        if not talentContainerFrame.lockInspect then
            purgeKey(talentContainerFrame, 'lockInspect');
        else
            -- get blizzard to set the value to true
            TextureLoadingGroupMixin.AddTexture({textures = talentContainerFrame}, 'lockInspect');
        end
    end
    local isInspecting = talentContainerFrame:IsInspecting();
    if not issecurevariable(talentContainerFrame, 'inspectUnit') then
        purgeKey(talentContainerFrame, 'inspectUnit');
    end
    if not issecurevariable(talentContainerFrame, 'inspectString') then
        purgeKey(talentContainerFrame, 'inspectString');
    end
    if isInspecting then
        purgeKey(talentContainerFrame, 'inspectString');
        purgeKey(talentContainerFrame, 'inspectUnit');
        RunNextFrame(function()
            talentContainerFrame:SetInspecting(nil, nil, nil);
        end);
    end
end

function Module:TriggerMicroButtonUpdate()
    local cvarName = 'Numy_TalentTreeTweaks';
    -- the LFDMicroButton will trigger UpdateMicroButtons() in its OnEvent, without checking the event itself.
    -- CVAR_UPDATE is easy enough to trigger at will, so we make use of that
    LFDMicroButton:RegisterEvent('CVAR_UPDATE');
    if not self.cvarRegistered then
        C_CVar.RegisterCVar(cvarName);
        self.cvarRegistered = true;
    end
    C_CVar.SetCVar(cvarName, GetCVar(cvarName) == '1' and '0' or '1');
    LFDMicroButton:UnregisterEvent('CVAR_UPDATE');
end

function Module:EnableDropDownReplacement()
    local talentsTab = Util:GetTalentFrame();
    local loadoutDropDown = talentsTab.LoadoutDropDown;
    if not self.replacementDropDownControl then
        self.replacementDropDownControl = self:CreateReplacementDropDownControl(loadoutDropDown);
    end
    loadoutDropDown.DropDownControlOrig = loadoutDropDown.DropDownControlOrig or loadoutDropDown.DropDownControl;
    loadoutDropDown.DropDownControl = self.replacementDropDownControl;

    loadoutDropDown.DropDownControlOrig:Hide();
    self.replacementDropDownControl:Show();
    self.replacementDropDownControl:OnLoad();
    loadoutDropDown:OnLoad();

    wipe(talentsTab.configIDs);
    talentsTab:InitializeLoadoutDropDown();
    self.replacementDropDownControl:SetSelectedValue(loadoutDropDown.DropDownControlOrig:GetSelectedValue());
end

function Module:CreateReplacementDropDownControl(parent)
    local replacementDropDownControl = CreateFrame('Frame', nil, parent, 'TalentTreeTweaks_DropDownControlTemplate');
    replacementDropDownControl:SetSize(150, 30);
    replacementDropDownControl:SetPoint('LEFT');
    replacementDropDownControl.DropDownMenu = LibDD:Create_UIDropDownMenu('TalentTreeTweaksDropDownMenu', parent);
    replacementDropDownControl.DropDownMenu:SetParent(replacementDropDownControl);
    replacementDropDownControl.DropDownMenu:SetPoint('CENTER', 0, -2);

    return replacementDropDownControl;
end

function Module:DisableDropDownReplacement()
    local talentsTab = Util:GetTalentFrame(true);
    if talentsTab and self.replacementDropDownControl then
        local loadoutDropDown = talentsTab.LoadoutDropDown;
        self.replacementDropDownControl:Hide();
        loadoutDropDown.DropDownControl = loadoutDropDown.DropDownControlOrig or loadoutDropDown.DropDownControl;
        loadoutDropDown.DropDownControl:Show();
        wipe(talentsTab.configIDs);
        talentsTab:InitializeLoadoutDropDown();
        loadoutDropDown.DropDownControl:SetSelectedValue(self.replacementDropDownControl:GetSelectedValue());
    end
end

function Module:OnShowUIPanel(frame)
    if frame ~= Util:GetTalentContainerFrame(true) then return end
    if (frame.IsShown and not frame:IsShown()) then
        -- if possible, force show the frame, ignoring the INTERFACE_ACTION_BLOCKED message
        frame:Show()
    end
end

function Module:OnHideUIPanel(frame)
    if frame ~= Util:GetTalentContainerFrame(true) then return end
    if (frame.IsShown and frame:IsShown()) then
        -- if possible, force hide the frame, ignoring the INTERFACE_ACTION_BLOCKED message
        frame:Hide()
    end
end

function Module:OnShowSelections()
    for _, button in pairs(Util:GetTalentFrame().SelectionChoiceFrame.selectionFrameArray) do
        self:OnTalentButtonAcquired(button);
    end
end

local function replacedShareButtonCallback()
    local exportString = Util:GetTalentFrame():GetLoadoutExportString();
    Util:CopyText(exportString, L['Talent Loadout String']);
end

local skipHook = false;
function Module:ReplaceShareButton(dropdown, selectionID)
    if skipHook then return; end

    skipHook = true;
    local _, sentinelInfo = dropdown:GetSentinelKeyInfoFromSelectionID(selectionID);
    skipHook = false;
    if sentinelInfo and (sentinelInfo.text == TALENT_FRAME_DROP_DOWN_EXPORT or sentinelInfo.text == TALENT_FRAME_DROP_DOWN_EXPORT_CLIPBOARD) then
        local callback = sentinelInfo.callback;
        if callback then
            sentinelInfo.callback = replacedShareButtonCallback;
        end
    end
end

function Module:OnLoadoutMenuOpen(dropdown, rootDescription)
    if not self:ShouldReplaceShareButton() then return; end

    for _, elementDescription in rootDescription:EnumerateElementDescriptions() do
        if elementDescription.text == TALENT_FRAME_DROP_DOWN_EXPORT then
            for _, subElementDescription in elementDescription:EnumerateElementDescriptions() do
                -- for unlock restrictions module: subElementDescription:SetEnabled(function() return true end); -- try without func wrapper too
                if subElementDescription.text == TALENT_FRAME_DROP_DOWN_EXPORT_CLIPBOARD then
                    subElementDescription:SetResponder(replacedShareButtonCallback);
                end
            end
        end
    end
end

function Module:ShouldReplaceShareButton()
    return
        self.db.alwaysReplaceShareButton
        or not issecurevariable(Util:GetTalentFrame(), 'configID');
end

function Module:HandleActionBarEventTaintSpread()
    local events = {
        ['PLAYER_ENTERING_WORLD'] = true,
        ['ACTIONBAR_SLOT_CHANGED'] = true,
        ['UPDATE_BINDINGS'] = true,
        ['GAME_PAD_ACTIVE_CHANGED'] = true,
        ['UPDATE_SHAPESHIFT_FORM'] = true,
        ['ACTIONBAR_UPDATE_COOLDOWN'] = true,
        ['PET_BAR_UPDATE'] = true,
        ['PLAYER_MOUNT_DISPLAY_CHANGED'] = true,
    };
    local petUnitEvents = {
        ['UNIT_FLAGS'] = true,
        ['UNIT_AURA'] = true,
    }
    for _, actionButton in pairs(ActionBarButtonEventsFrame.frames) do
        --@debug@
        hooksecurefunc(actionButton, 'UnregisterEvent', function(_, event)
            if events[event] then
                Util:DebugPrint(actionButton:GetName(), 'UnregisterEvent', event);
            end
        end);
        --@end-debug@
        for event in pairs(events) do
            actionButton:RegisterEvent(event);
        end
        for petUnitEvent in pairs(petUnitEvents) do
            actionButton:RegisterUnitEvent(petUnitEvent, 'pet');
        end
    end
    for event in pairs(events) do
        ActionBarButtonEventsFrame:UnregisterEvent(event);
    end
    for petUnitEvent in pairs(petUnitEvents) do
        ActionBarButtonEventsFrame:UnregisterEvent(petUnitEvent, 'pet');
    end
end

function Module:SetActionBarHighlights(talentButton, shown)
    local notMissing =
        TalentButtonUtil and TalentButtonUtil.ActionBarStatus and TalentButtonUtil.ActionBarStatus.NotMissing -- DF
        or ActionButtonUtil and ActionButtonUtil.ActionBarActionStatus and ActionButtonUtil.ActionBarActionStatus.NotMissing; -- TWW
    local spellID = talentButton:GetSpellID();
    if (
        spellID
        and (
            talentButton.IsMissingFromActionBar and not talentButton:IsMissingFromActionBar()
            or talentButton.GetActionBarStatus and talentButton:GetActionBarStatus() == notMissing
        )
    ) then
        self:HandleBlizzardActionButtonHighlights(shown and spellID);
        self:HandleLibActionButtonHighlights(shown and spellID);
    end
end

function Module:HandleBlizzardActionButtonHighlights(spellID)
    local ON_BAR_HIGHLIGHT_MARKS = spellID and tInvert(C_ActionBar.FindSpellActionButtons(spellID) or {}) or {};
    for _, actionButton in pairs(ActionBarButtonEventsFrame.frames) do
        if ( actionButton.SpellHighlightTexture and actionButton.SpellHighlightAnim ) then
            SharedActionButton_RefreshSpellHighlight(actionButton, ON_BAR_HIGHLIGHT_MARKS[actionButton.action]);
        end
    end
end

function Module:HandleLibActionButtonHighlights(spellID)
    local name = 'LibActionButton-1.';
    for mayor, lib in LibStub:IterateLibraries() do
        if mayor:sub(1, string.len(name)) == name then
            for button in pairs(lib:GetAllButtons()) do
                if button.SpellHighlightTexture and button.SpellHighlightAnim and button.GetSpellId then
                    local shown = spellID and button:GetSpellId() == spellID;
                    SharedActionButton_RefreshSpellHighlight(button, shown);
                end
            end
        end
    end
end

local function ShowActionBarHighlightsReplacement(talentButton)
    Module:SetActionBarHighlights(talentButton, true);
end
local function HideActionBarHighlightsReplacement(talentButton)
    Module:SetActionBarHighlights(talentButton, false);
end

function Module:OnTalentButtonAcquired(button)
    button.ShowActionBarHighlights = ShowActionBarHighlightsReplacement;
    button.HideActionBarHighlights = HideActionBarHighlightsReplacement;
end

if Util.isDF then
    --- copied from DropDownControlMixin
    function TalentTreeTweaks_DropDownControlReplacementMixin:OnLoad()
        local function InitializeDropDownFrame(frame, level)
            self:Initialize(level);
        end

        LibDD:UIDropDownMenu_Initialize(self.DropDownMenu, InitializeDropDownFrame);

        self:UpdateDropDownWidth(self:GetWidth());
        self:UpdateSavedDefaultTextColor();
    end

    function TalentTreeTweaks_DropDownControlReplacementMixin:UpdateDropDownWidth(width)
        LibDD:UIDropDownMenu_SetWidth(self.DropDownMenu, width - 20);
    end

    function TalentTreeTweaks_DropDownControlReplacementMixin:Initialize(level)
        if self.options == nil then
            return;
        end

        local function DropDownControlButton_OnClick(button)
            local isUserInput = true;
            self:SetSelectedValue(button.value, isUserInput);
        end

        for i, option in ipairs(self.options) do
            local optionLevel = option.level or 1;
            if not level or optionLevel == level then
                if option.isSeparator then
                    LibDD:UIDropDownMenu_AddSeparator(option.level);
                else
                    local info = LibDD:UIDropDownMenu_CreateInfo();
                    if not self.skipNormalSetup then
                        info.text = option.text;
                        info.tooltipTitle = option.tooltipTitle;
                        info.tooltipText = option.tooltipText;
                        info.tooltipInstruction = option.tooltipInstruction;
                        info.tooltipWarning = option.tooltipWarning;
                        info.tooltipOnButton = option.tooltipOnButton;
                        info.iconTooltipTitle = option.iconTooltipTitle;
                        info.iconTooltipText = option.iconTooltipText;
                        info.minWidth = self.dropDownListMinWidth or 108;
                        info.value = option.value;
                        info.checked = self.selectedValue == option.value;
                        info.func = DropDownControlButton_OnClick;
                    end

                    info.data = option.data;
                    info.level = optionLevel;

                    if self.customSetupCallback ~= nil then
                        self.customSetupCallback(info, DropDownControlButton_OnClick);
                    end

                    LibDD:UIDropDownMenu_AddButton(info, option.level);
                end
            end
        end
    end

    function TalentTreeTweaks_DropDownControlReplacementMixin:UpdateSelectedText()
        local selectedValue = self.selectedValue;
        if selectedValue == nil then
            LibDD:UIDropDownMenu_SetText(self.DropDownMenu, self.noneSelectedText);
        elseif self.options ~= nil then
            for i, option in ipairs(self.options) do
                if option.value == selectedValue then
                    LibDD:UIDropDownMenu_SetText(self.DropDownMenu, option.selectedText or option.text);
                end
            end
        end

        self:UpdateSelectedTextColor();
    end

    function TalentTreeTweaks_DropDownControlReplacementMixin:SetEnabled(enabled, disabledTooltip)
        LibDD:UIDropDownMenu_SetDropDownEnabled(self.DropDownMenu, enabled, disabledTooltip);
        if enabled then
            self:UpdateSelectedTextColor();
        end
    end
end


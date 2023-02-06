local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;

--- @type LibUIDropDownMenu
local LibDD = LibStub('LibUIDropDownMenu-4.0');

TalentTreeTweaks_DropDownControlReplacementMixin = CreateFromMixins(DropDownControlMixin);

local Module = Main:NewModule('ReduceTaint', 'AceHook-3.0');

function Module:OnEnable()
    Util:OnClassTalentUILoad(function()
        self:SetupHook();
    end, 1); -- load before any other module
end

function Module:OnDisable()
    if self.db.replaceDropDown then
        self:DisableDropDownReplacement();
    end
    self:UnhookAll();
end

function Module:GetDescription()
    return [[Implements various workarounds around taint.

Fully replace the loadout dropdown, to avoid tainting the edit mode dropdown.

A workaround for one of the ways that Talent Tree taint can block action buttons from working.

Replaces the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when needed.
]];
end

function Module:GetName()
    return 'Reduce Taint';
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        replaceDropDown = true,
    };
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    defaultOptionsTable.args.extra_info = {
        type = 'description',
        name = 'You have to reload your UI after disabling this module, for it to be disabled.',
        order = 5,
    };
    defaultOptionsTable.args.replaceDropDown = {
        type = 'toggle',
        name = 'Replace Loadout Dropdown',
        desc = 'Replace the loadout dropdown, to avoid tainting the edit mode dropdown.',
        order = 10,
        get = function()
            return self.db.replaceDropDown;
        end,
        set = function(_, value)
            self.db.replaceDropDown = value;
            if value then
                self:EnableDropDownReplacement();
            else
                self:DisableDropDownReplacement();
            end
        end,
    };

    return defaultOptionsTable;
end

function Module:SetupHook()
    if self.db.replaceDropDown then
        self:EnableDropDownReplacement();
    end

    ClassTalentFrame.TalentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    for talentButton in ClassTalentFrame.TalentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton);
    end
    self:SecureHook(ClassTalentFrame.TalentsTab, 'ShowSelections', 'OnShowSelections');

    -- GetSentinelKeyInfoFromSelectionID happens just before callbacks are executed, so that's the ideal place to check for taint
    self:SecureHook(ClassTalentFrame.TalentsTab.LoadoutDropDown, 'GetSentinelKeyInfoFromSelectionID', function(dropdown, selectionID) self:CheckShareButton(dropdown, selectionID) end);

    -- ToggleTalentFrame starts of with a ClassTalentFrame:SetInspecting call, which has a high likelihood of tainting execution
    self:SecureHook('ShowUIPanel', 'OnShowUIPanel')
    self:SecureHook('HideUIPanel', 'OnHideUIPanel')
end

function Module:EnableDropDownReplacement()
    local talentsTab = ClassTalentFrame.TalentsTab;
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
    replacementDropDownControl.DropDownMenu = LibDD:Create_UIDropDownMenu("TalentTreeTweaksDropDownMenu", parent);
    replacementDropDownControl.DropDownMenu:SetParent(replacementDropDownControl);
    replacementDropDownControl.DropDownMenu:SetPoint("CENTER", 0, -2);

    return replacementDropDownControl;
end

function Module:DisableDropDownReplacement()
    if ClassTalentFrame and ClassTalentFrame.TalentsTab and self.replacementDropDownControl then
        local talentsTab = ClassTalentFrame.TalentsTab;
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
    if frame ~= ClassTalentFrame then return end
    if (frame.IsShown and not frame:IsShown()) then
        -- if possible, force show the frame, ignoring the INTERFACE_ACTION_BLOCKED message
        frame:Show()
    end
end

function Module:OnHideUIPanel(frame)
    if frame ~= ClassTalentFrame then return end
    if (frame.IsShown and frame:IsShown()) then
        -- if possible, force hide the frame, ignoring the INTERFACE_ACTION_BLOCKED message
        frame:Hide()
    end
end

function Module:OnShowSelections()
    for _, button in pairs(ClassTalentFrame.TalentsTab.SelectionChoiceFrame.selectionFrameArray) do
        self:OnTalentButtonAcquired(button);
    end
end

local function replacedShareButtonCallback()
    local exportString = ClassTalentFrame.TalentsTab:GetLoadoutExportString();
    Util:CopyText(exportString, 'Talent Loadout String');
end

local skipHook = false;
function Module:CheckShareButton(dropdown, selectionID)
    if skipHook then return; end

    skipHook = true;
    local _, sentinelInfo = dropdown:GetSentinelKeyInfoFromSelectionID(selectionID);
    skipHook = false;
    if sentinelInfo and sentinelInfo.text == TALENT_FRAME_DROP_DOWN_EXPORT then
        -- actually.. we can't properly test for taint here, since there's a lot of things in the callback that could be tainted
        -- and we're not able to check if the current execution path is tainted either. So we'll just assume that we're tainted
        -- and replace the callback.
        local callback = sentinelInfo.callback;
        if callback then
            sentinelInfo.callback = replacedShareButtonCallback;
        end
    end
end

function Module:SetActionBarHighlights(talentButton, shown)
    local spellID = talentButton:GetSpellID();
    if (
        spellID
        and (
            talentButton.IsMissingFromActionBar and not talentButton:IsMissingFromActionBar()
            or talentButton.GetActionBarStatus and talentButton:GetActionBarStatus() == TalentButtonUtil.ActionBarStatus.NotMissing
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

do
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


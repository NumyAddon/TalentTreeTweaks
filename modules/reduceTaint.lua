--- @class TTT_NS
local TTT = select(2, ...);

local Main = TTT.Main;
local Util = TTT.Util;
local L = TTT.L;

--- @class TTT_ReduceTaintModule: TTT_Module, AceHook-3.0
local Module = Main:NewModule('ReduceTaint', 'AceHook-3.0');

function Module:OnInitialize()
    Menu.ModifyMenu('MENU_CLASS_TALENT_PROFILE', function(dropdown, rootDescription, contextData)
        if not self:IsEnabled() then return; end
        self:OnLoadoutMenuOpen(dropdown, rootDescription);
    end);
end

function Module:OnEnable()
    Util:OnTalentUILoad(function() self:SetupHook(); end, 1); -- load before any other module
    self:HandleActionBarEventTaintSpread();
    self:HandleOnBarHighlightMarkTaint();
end

function Module:OnDisable()
    self:UnhookAll();
end

function Module:GetDescription()
    return
        L['Implements various workarounds around taint.']
        .. '\n\n' ..
        L['A workaround for one of the ways that Talent Tree taint can block action buttons from working.']
        .. '\n\n' ..
        L['Replace the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when needed.'];
end

function Module:GetName()
    return L['Reduce Taint'];
end

--- @param configBuilder TTT_ConfigBuilder
--- @param db TTT_ReduceTaintModuleDB
function Module:BuildConfig(configBuilder, db)
    self.db = db;
    --- @class TTT_ReduceTaintModuleDB
    local defaults = {
        alwaysReplaceShareButton = false,
        disableMultiActionBarShowHide = true,
    };
    self.db.replaceDropDown = nil;
    configBuilder:SetDefaults(defaults, true);

    configBuilder:MakeText(L['You have to reload your UI after disabling this module, for some of the change to take effect.']);
    configBuilder:MakeCheckbox(
        L['Always Replace Share Button'],
        'alwaysReplaceShareButton',
        L['Replace the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when possible.']
    );
    configBuilder:MakeCheckbox(
        L['Disable MultiActionBar_ShowAllGrids on Show'],
        'disableMultiActionBarShowHide',
        L['Disables the MultiActionBar_ShowAllGrids function, which can cause action buttons to break.'],
        function()
            self:HandleMultiActionBarTaint();
        end
    );
end

function Module:SetupHook()
    local talentsTab = Util:GetTalentFrame();
    talentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    for talentButton in talentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton);
    end
    self:SecureHook(talentsTab, 'ShowSelections', 'OnShowSelections');

    -- ToggleTalentFrame starts of with a talentContainerFrame:SetInspecting call, which has a high likelihood of tainting execution
    self:SecureHook('ShowUIPanel', 'OnShowUIPanel')
    self:SecureHook('HideUIPanel', 'OnHideUIPanel')

    self:SecureHook(talentsTab, 'UpdateInspecting', 'OnUpdateInspecting');
    self:ReplaceCopyLoadoutButton(talentsTab);

    self:HandleMultiActionBarTaint();
end

function Module:HandleOnBarHighlightMarkTaint()
    -- this may not be needed anymore after 11.0.5

    C_AddOns.LoadAddOn('Blizzard_ProfessionsBook');
    local name = 'TalentTreeTweaks_ActionBarHighlightMarkTaintCleanser';
    --- @type ProfessionButtonTemplate|SecureHandlerBaseTemplate|table
    local cleanser = CreateFrame('CheckButton', name, nil, 'ProfessionButtonTemplate,SecureHandlerBaseTemplate');
    cleanser.cooldown:Hide();
    for _, region in pairs({ cleanser:GetRegions() }) do
        if region.Hide then region:Hide(); end
    end
    cleanser:Hide();
    cleanser:ClearAllPoints();
    cleanser:SetSize(2, 2);
    cleanser:SetFrameStrata('TOOLTIP');
    cleanser:ClearHighlightTexture();
    cleanser:ClearDisabledTexture();
    cleanser:ClearNormalTexture();
    cleanser:SetScript("OnShow", function()
        Util:AddToCombatLockdownQueue(function()
            cleanser:SetAttribute('_wrapentered', true);
        end);
    end);
    cleanser:SetScript("OnHide", nil);
    cleanser:SetScript("OnClick", nil);
    cleanser:SetScript("OnEnter", function()
        if InCombatLockdown() then return; end
        cleanser:Execute([[ self:Hide(); ]]);
    end);
    cleanser:HookScript("OnLeave", function()
        Util:AddToCombatLockdownQueue(function()
            if issecurevariable('ON_BAR_HIGHLIGHT_MARKS') then
                cleanser:Hide();
                cleanser:SetAttribute('_wrapentered', true);
            end
        end);
    end);
    -- the OnLeave script for ProfessionButtonTemplate will securely call `ClearOnBarHighlightMarks`, cleansing the taint.

    -- sadly OnEnter and OnLeave will only ever be called securely if they're triggered by mouse motion,
    -- so this fix requires the user to move their mouse a pixel or two
    SecureHandlerWrapScript(cleanser, 'OnLeave', cleanser, [[
        self:Hide();
    ]]);
    cleanser:SetAttribute('_wrapentered', true); -- ensures the secure wrapped OnLeave will actually run

    --@debug@
    --cleanser:SetSize(20, 20);
    --cleanser:SetNormalTexture(134532);
    --@end-debug@
    local function tryClearTaint()
        if issecurevariable('ON_BAR_HIGHLIGHT_MARKS') then return; end

        Util:DebugPrint('ON_BAR_HIGHLIGHT_MARKS is tainted, attempting to cleanse');

        if InCombatLockdown() then
            Util:AddToCombatLockdownQueue(tryClearTaint);

            return;
        end
        cleanser:SetAttribute('_wrapentered', true); -- ensures the secure wrapped OnLeave will actually run
        cleanser:ClearAllPoints();
        local x, y = GetCursorPosition();
        cleanser:SetPoint('CENTER', nil, 'BOTTOMLEFT', x, y);
        cleanser:Show();
    end

    Util:OnTalentUILoad(function()
        Util:AddToCombatLockdownQueue(function()
            local helper = CreateFrame('Frame', nil, Util:GetTalentContainerFrame(), 'SecureHandlerShowHideTemplate');
            local nilOverlay = CreateFrame('Frame', nil, nil, 'SecureHandlerBaseTemplate');
            nilOverlay:SetAllPoints();
            helper:SetFrameRef('cleanser', cleanser);
            helper:SetFrameRef('nilOverlay', nilOverlay);
            helper:SetAttribute('_onhide', [[
                if not PlayerInCombat() then return; end

                local cleanser = self:GetFrameRef('cleanser');
                local nilOverlay = self:GetFrameRef('nilOverlay');
                local x, y = nilOverlay:GetMousePosition(); -- x and y are in the range of 0 to 1
                local width, height = nilOverlay:GetWidth(), nilOverlay:GetHeight();
                cleanser:ClearAllPoints();
                cleanser:SetPoint('CENTER', nilOverlay, 'BOTTOMLEFT', width * x, height * y);
                cleanser:Show();
            ]]);
        end);
    end);

    hooksecurefunc('ClearOnBarHighlightMarks', tryClearTaint);
    hooksecurefunc('UpdateOnBarHighlightMarksBySpell', tryClearTaint);
    hooksecurefunc('UpdateOnBarHighlightMarksByFlyout', tryClearTaint);
    hooksecurefunc('UpdateOnBarHighlightMarksByPetAction', tryClearTaint);
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
            not (PlayerSpellsMicroButton and PlayerSpellsMicroButton.EvaluateAlertVisibility)
        then
            Util:DebugPrint('cannot find the Talent MicroButton, it can spread taint to action bars if not handled properly');
        end

        setfenv(talentContainerFrame.OnShow, makeFEnvReplacement(self.originalOnShowFEnv, {
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
    local microButton = PlayerSpellsMicroButton;
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
            -- Addons like NoAutoClose will allow calling this in combat, but otherwise we're screwed :/
            if InCombatLockdown() and UIPanelWindows[talentContainerFrame:GetName()] then return; end
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

--- @param frame Frame
function Module:OnShowUIPanel(frame)
    if frame ~= Util:GetTalentContainerFrameIfLoaded() then return end
    if not frame:IsShown() and not (InCombatLockdown() and frame:IsProtected()) then
        -- if possible, force show the frame, ignoring the INTERFACE_ACTION_BLOCKED message
        frame:Show()
    end
end

--- @param frame Frame
function Module:OnHideUIPanel(frame)
    if frame ~= Util:GetTalentContainerFrameIfLoaded() then return end
    if frame:IsShown() and not (InCombatLockdown() and frame:IsProtected()) then
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
    -- no longer works after 11.1.0, but hopefully hasn't been needed since 11.0.7 either
    if select(4, GetBuildInfo()) >= 110100 then return; end

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
    local function registerActionButtonEvents(actionButton)
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
    for _, actionButton in pairs(ActionBarButtonEventsFrame.frames) do
        registerActionButtonEvents(actionButton);
    end
    hooksecurefunc(ActionBarButtonEventsFrame, 'RegisterFrame', function(_, actionButton)
        registerActionButtonEvents(actionButton);
    end);
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

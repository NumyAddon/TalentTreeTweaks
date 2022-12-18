local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;

local Module = Main:NewModule('ReduceTaint', 'AceHook-3.0');

function Module:OnEnable()
    EventUtil.ContinueOnAddOnLoaded('Blizzard_ClassTalentUI', function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
end

function Module:GetDescription()
    return [[Implements various workarounds around taint.

A workaround for one of the ways that Talent Tree taint can block action buttons from working.

Replaces the Share Loadout button, to open a copy/paste popup instead of automatically copying to clipboard when needed.
]];
end

function Module:GetName()
    return 'Reduce Taint';
end

function Module:GetOptions(defaultOptionsTable, db)
    defaultOptionsTable.args.extra_info = {
        type = 'description',
        name = 'You have to reload your UI after disabling this module, for it to be disabled.',
        order = 5,
    };

    return defaultOptionsTable;
end

function Module:SetupHook()
    ClassTalentFrame.TalentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    for talentButton in ClassTalentFrame.TalentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton);
    end
    self:SecureHook(ClassTalentFrame.TalentsTab, 'ShowSelections', 'OnShowSelections');

    -- GetSentinelKeyInfoFromSelectionID happens just before callbacks are executed, so that's the ideal place to check for taint
    self:SecureHook(ClassTalentFrame.TalentsTab.LoadoutDropDown, 'GetSentinelKeyInfoFromSelectionID', function(dropdown, selectionID) self:CheckShareButton(dropdown, selectionID) end);
end

function Module:OnShowSelections()
    for _, button in pairs(ClassTalentFrame.TalentsTab.SelectionChoiceFrame.selectionFrameArray) do
        self:OnTalentButtonAcquired(button);
    end
end

local function replacedShareButtonCallback()
    local exportString = ClassTalentFrame.TalentsTab:GetLoadoutExportString();
    Util:CopyText(exportString);
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
    if spellID and not talentButton:IsMissingFromActionBar() then
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

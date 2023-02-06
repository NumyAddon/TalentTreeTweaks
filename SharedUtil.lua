local _, TTT = ...
--- @class TalentTreeTweaks_Util
local Util = {};
TTT.Util = Util;

--- @type LibTalentTree
local LTT = LibStub('LibTalentTree-1.0');
Util.LibTalentTree = LTT;

function Util:OnInitialize()
    self.dialogName = 'TalentTreeTweaksCopyTextDialog';
    StaticPopupDialogs['TalentTreeTweaksCopyTextDialog'] = {
        text = 'CTRL-C to copy %s',
        button1 = CLOSE,
        OnShow = function(dialog, data)
            local function HidePopup()
                dialog:Hide();
            end
            dialog.editBox:SetScript('OnEscapePressed', HidePopup);
            dialog.editBox:SetScript('OnEnterPressed', HidePopup);
            dialog.editBox:SetScript('OnKeyUp', function(_, key)
                if IsControlKeyDown() and key == 'C' then
                    HidePopup();
                end
            end);
            dialog.editBox:SetMaxLetters(0);
            dialog.editBox:SetText(data);
            dialog.editBox:HighlightText();
        end,
        hasEditBox = true,
        editBoxWidth = 240,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    };
    self:ResetRegistry();
end

function Util:ResetRegistry()
    self.classTalentUILoadCallbacks = {
        minPriority = 1,
        maxPriority = 1,
        registered = false,
    };
end

--- @param callback function
--- @param priority number - lower numbers are called first
function Util:OnClassTalentUILoad(callback, priority)
    local actualPriority = priority or 10;
    local registry = self.classTalentUILoadCallbacks;
    registry[actualPriority] = registry[actualPriority] or {};
    table.insert(registry[actualPriority], callback);
    registry.minPriority = math.min(registry.minPriority, actualPriority);
    registry.maxPriority = math.max(registry.maxPriority, actualPriority);

    if IsAddOnLoaded('Blizzard_ClassTalentUI') then
        self:RunOnLoadCallbacks()
    elseif not registry.registered then
        registry.registered = true;
        EventUtil.ContinueOnAddOnLoaded('Blizzard_ClassTalentUI', function()
            self:RunOnLoadCallbacks()
        end);
    end
end

function Util:RunOnLoadCallbacks()
    local registry = self.classTalentUILoadCallbacks;
    for priority = registry.minPriority, registry.maxPriority do
        if registry[priority] then
            for _, callback in ipairs(registry[priority]) do
                callback();
            end
        end
    end
    self:ResetRegistry();
end

function Util:CopyText(text, optionalTitleSuffix)
    StaticPopup_Show(self.dialogName, optionalTitleSuffix or '', nil, text);
end

local LOADOUT_SERIALIZATION_VERSION = 1;
function Util:GetLoadoutExportString(talentsTab, configIDOverride)
    local exportStream = ExportUtil.MakeExportDataStream();
    local configID = configIDOverride or talentsTab:GetConfigID();
    local currentSpecID = talentsTab:GetSpecID();
    local treeID = LTT:GetClassTreeId(talentsTab:GetClassID())

    -- write header
    exportStream:AddValue(talentsTab.bitWidthHeaderVersion, LOADOUT_SERIALIZATION_VERSION);
    exportStream:AddValue(talentsTab.bitWidthSpecID, currentSpecID);
    -- treeHash is a 128bit hash, passed as an array of 16, 8-bit values
    -- empty tree hash will disable validation on import
    exportStream:AddValue(8 * 16, 0);

    talentsTab:WriteLoadoutContent(exportStream, configID, treeID);

    return exportStream:GetExportString();
end

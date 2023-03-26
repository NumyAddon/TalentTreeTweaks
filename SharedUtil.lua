local _, TTT = ...
--- @class TalentTreeTweaks_Util
local Util = {};
TTT.Util = Util;

--- @type LibTalentTree
local LTT = LibStub('LibTalentTree-1.0');
Util.LibTalentTree = LTT;

Util.specToClassMap = {
    [71] = 1, [72] = 1, [73] = 1, [1446] = 1,
    [65] = 2, [66] = 2, [70] = 2, [1451] = 2,
    [253] = 3, [254] = 3, [255] = 3, [1448] = 3,
    [259] = 4, [260] = 4, [261] = 4, [1453] = 4,
    [256] = 5, [257] = 5, [258] = 5, [1452] = 5,
    [250] = 6, [251] = 6, [252] = 6, [1455] = 6,
    [262] = 7, [263] = 7, [264] = 7, [1444] = 7,
    [62] = 8, [63] = 8, [64] = 8, [1449] = 8,
    [265] = 9, [266] = 9, [267] = 9, [1454] = 9,
    [268] = 10, [270] = 10, [269] = 10, [1450] = 10,
    [102] = 11, [103] = 11, [104] = 11, [105] = 11, [1447] = 11,
    [577] = 12, [581] = 12, [1456] = 12,
    [1467] = 13, [1468] = 13, [1465] = 13,
};
Util.bitWidthHeaderVersion = 8;
Util.bitWidthSpecID = 16;
Util.bitWidthRanksPurchased = 6;
local LOADOUT_SERIALIZATION_VERSION = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or 1;

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

function Util:GetLoadoutExportString(talentsTab, configIDOverride)
    local exportStream = ExportUtil.MakeExportDataStream();
    local configID = configIDOverride or talentsTab:GetConfigID();
    local currentSpecID = talentsTab:GetSpecID();
    local treeID = LTT:GetClassTreeId(talentsTab:GetClassID())

    -- write header
    exportStream:AddValue(talentsTab.bitWidthHeaderVersion, LOADOUT_SERIALIZATION_VERSION);
    exportStream:AddValue(talentsTab.bitWidthSpecID, currentSpecID);
    for _, hashVal in ipairs(C_Traits.GetTreeHash(treeID)) do
        exportStream:AddValue(8, hashVal);
    end

    talentsTab:WriteLoadoutContent(exportStream, configID, treeID);

    return exportStream:GetExportString();
end

---@class TalentTreeTweaks_Util_LoadoutContent
---@field isNodeSelected boolean
---@field isPartiallyRanked boolean
---@field partialRanksPurchased number
---@field isChoiceNode boolean
---@field choiceNodeSelection number
---@field nodeID number

--- @return ( boolean|number, string|number, nil|TalentTreeTweaks_Util_LoadoutContent[]) # specID, classID, loadoutInfo; in case of errors: false, errorMessage
function Util:ParseTalentBuildString(importString)
    local importStream = ExportUtil.MakeImportDataStream(importString);

    local headerValid, serializationVersion, specIDFromString, treeHash = self:ReadLoadoutHeader(importStream);
    local classIDFromString = self.specToClassMap[specIDFromString];

    if(not headerValid) then
        return false, LOADOUT_ERROR_BAD_STRING;
    end

    if(serializationVersion ~= LOADOUT_SERIALIZATION_VERSION) then
        return false, LOADOUT_ERROR_SERIALIZATION_VERSION_MISMATCH;
    end

    local treeID = LTT:GetClassTreeId(classIDFromString);
    if not self:IsHashValid(treeHash, treeID) then
        return false, LOADOUT_ERROR_TREE_CHANGED;
    end

    return tonumber(specIDFromString), tonumber(classIDFromString), self:ReadLoadoutContent(importStream, treeID);
end

function Util:ReadLoadoutHeader(importStream)
    local headerBitWidth = self.bitWidthHeaderVersion + self.bitWidthSpecID + 128;
    local importStreamTotalBits = importStream:GetNumberOfBits();
    if( importStreamTotalBits < headerBitWidth) then
        return false, 0, 0, 0;
    end
    local serializationVersion = importStream:ExtractValue(self.bitWidthHeaderVersion);
    local specID = importStream:ExtractValue(self.bitWidthSpecID);

    -- treeHash is a 128bit hash, passed as an array of 16, 8-bit values
    local treeHash = {};
    for i=1,16,1 do
        treeHash[i] = importStream:ExtractValue(8);
    end
    return true, serializationVersion, specID, treeHash;
end

local nodeCache = {};
local function GetTreeNodes(treeID)
    if not nodeCache[treeID] then
        nodeCache[treeID] = C_Traits.GetTreeNodes(treeID);
    end
    return nodeCache[treeID];
end

local treeHashCache = {}
local function GetTreeHash(treeID)
    if not treeHashCache[treeID] then
        treeHashCache[treeID] = C_Traits.GetTreeHash(treeID);
    end
    return treeHashCache[treeID];
end

function Util:IsHashValid(treeHash, treeID)
    if not #treeHash == 16 then
        return false;
    end
    local expectedHash = GetTreeHash(treeID);
    local allZero = true;
    for i, value in ipairs(treeHash) do
        if value ~= 0 then
            allZero = false;
        end
        if not allZero and value ~= expectedHash[i] then
            return false;
        end
    end

    return true;
end

function Util:ReadLoadoutContent(importStream, treeID)
    local results = {};

    local treeNodes = GetTreeNodes(treeID);
    for i, nodeID in ipairs(treeNodes) do
        local nodeSelectedValue = importStream:ExtractValue(1)
        local isNodeSelected =  nodeSelectedValue == 1;
        local isPartiallyRanked = false;
        local partialRanksPurchased = 0;
        local isChoiceNode = false;
        local choiceNodeSelection = 0;

        if(isNodeSelected) then
            local isPartiallyRankedValue = importStream:ExtractValue(1);
            isPartiallyRanked = isPartiallyRankedValue == 1;
            if(isPartiallyRanked) then
                partialRanksPurchased = importStream:ExtractValue(self.bitWidthRanksPurchased);
            end
            local isChoiceNodeValue = importStream:ExtractValue(1);
            isChoiceNode = isChoiceNodeValue == 1;
            if(isChoiceNode) then
                choiceNodeSelection = importStream:ExtractValue(2);
            end
        end

        local result = {};
        result.isNodeSelected = isNodeSelected;
        result.isPartiallyRanked = isPartiallyRanked;
        result.partialRanksPurchased = partialRanksPurchased;
        result.isChoiceNode = isChoiceNode;
        -- entry index is stored as zero-index, so convert back to lua index
        result.choiceNodeSelection = choiceNodeSelection + 1;
        result.nodeID = nodeID;
        results[i] = result;

    end

    return results;
end


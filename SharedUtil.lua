local _, TTT = ...
--- @class TalentTreeTweaks_Util
local Util = {};
TTT.Util = Util;
local L = TTT.L;

--- @type LibTalentTree
local LTT = LibStub('LibTalentTree-1.0');
Util.LibTalentTree = LTT;

Util.specToClassMap = {};
do
    for classID = 1, GetNumClasses() do
        for specIndex = 1, GetNumSpecializationsForClassID(classID) do
            Util.specToClassMap[(GetSpecializationInfoForClassID(classID, specIndex))] = classID;
        end
    end
end
Util.bitWidthHeaderVersion = 8;
Util.bitWidthSpecID = 16;
Util.bitWidthRanksPurchased = 6;
local LOADOUT_SERIALIZATION_VERSION = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or 1;

Util.configIDLookup = {};

function Util:OnInitialize()
    self.dialogName = 'TalentTreeTweaksCopyTextDialog';
    StaticPopupDialogs['TalentTreeTweaksCopyTextDialog'] = {
        text = L['CTRL-C to copy %s'],
        button1 = CLOSE,
        OnShow = function(dialog, data)
            local function HidePopup()
                dialog:Hide();
            end
            dialog.editBox:SetScript('OnEscapePressed', HidePopup);
            dialog.editBox:SetScript('OnEnterPressed', HidePopup);
            dialog.editBox:SetScript('OnKeyUp', function(_, key)
                if IsControlKeyDown() and (key == 'C' or key == 'X') then
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

    local eventFrame = CreateFrame('FRAME');
    eventFrame:RegisterEvent('ADDON_LOADED');
    eventFrame:SetScript('OnEvent', function(_, event, ...)
        if event == 'ADDON_LOADED' then
            local addonName = ...;
            if addonName == 'Blizzard_ClassTalentUI' and self.classTalentUILoadCallbacks.registered then
                eventFrame:UnregisterEvent('ADDON_LOADED');
                self:RunOnLoadCallbacks();
            end
        end
        if event == 'TRAIT_CONFIG_LIST_UPDATED' then
            self:RefreshConfigIDLookup();
        end
    end);
    self:RefreshConfigIDLookup();
end

function Util:PrepareModuleDb(module, db, defaults)
    module.db = db;
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end
end

function Util:GetterSetterIncrementFactory(db, postSetCallback)
    local getter = function(info) return db[info[#info]]; end
    local setter = function(info, value) db[info[#info]] = value; if postSetCallback then postSetCallback(); end end
    local increment = CreateCounter(5);

    return getter, setter, increment;
end

function Util:ResetRegistry()
    self.classTalentUILoadCallbacks = {
        minPriority = 1,
        maxPriority = 1,
        registered = false,
    };
end

--- @param callback function
--- @param priority ?number - lower numbers are called first
function Util:OnClassTalentUILoad(callback, priority)
    local actualPriority = priority or 10;
    local registry = self.classTalentUILoadCallbacks;
    registry[actualPriority] = registry[actualPriority] or {};
    table.insert(registry[actualPriority], callback);
    registry.minPriority = math.min(registry.minPriority, actualPriority);
    registry.maxPriority = math.max(registry.maxPriority, actualPriority);
    registry.registered = true;

    if IsAddOnLoaded('Blizzard_ClassTalentUI') then
        self:RunOnLoadCallbacks()
    end
end

function Util:RunOnLoadCallbacks()
    local registry = self.classTalentUILoadCallbacks;
    for priority = registry.minPriority, registry.maxPriority do
        if registry[priority] then
            for _, callback in ipairs(registry[priority]) do
                securecallfunction(callback);
            end
        end
    end
    self:ResetRegistry();
end

function Util:CopyText(text, optionalTitleSuffix)
    StaticPopup_Show(self.dialogName, optionalTitleSuffix or '', nil, text);
end

function Util:RefreshConfigIDLookup()
    wipe(self.configIDLookup);
    local classID = PlayerUtil.GetClassID();
    for specIndex = 1, GetNumSpecializationsForClassID(classID) do
        local specID = GetSpecializationInfoForClassID(classID, specIndex);
        for _, configID in pairs(C_ClassTalents.GetConfigIDsBySpecID(specID)) do
        	self.configIDLookup[configID] = specID;
        end
    end
end

function Util:GetSpecIDFromConfigID(configID)
    local specID = self.configIDLookup[configID] or nil;
    if specID then return specID; end

    local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID);
    if ok and configInfo and configInfo.type == 1 and configInfo.name then
        local classID = PlayerUtil.GetClassID();
        for specIndex = 1, GetNumSpecializationsForClassID(classID) do
            local specID, name = GetSpecializationInfoForClassID(classID, specIndex);
            if name == configInfo.name then
                self.configIDLookup[configID] = specID;

                return specID;
            end
        end
    end
end

local function fixLoadoutString(loadoutString, specID)
   local exportStream = ExportUtil.MakeExportDataStream();
   local importStream = ExportUtil.MakeImportDataStream(loadoutString);

   if importStream:ExtractValue(Util.bitWidthHeaderVersion) ~= 1 then
      return nil; -- only version 1 is supported
   end

   local headerSpecID = importStream:ExtractValue(Util.bitWidthSpecID);
   if headerSpecID == specID then
      return loadoutString; -- no update needed
   end

   exportStream:AddValue(Util.bitWidthHeaderVersion, 1);
   exportStream:AddValue(Util.bitWidthSpecID, specID);
   local remainingBits = importStream:GetNumberOfBits() - Util.bitWidthHeaderVersion - Util.bitWidthSpecID;
   -- copy the remaining bits in batches of 16
   while remainingBits > 0 do
      local bitsToCopy = math.min(remainingBits, 16);
      exportStream:AddValue(bitsToCopy, importStream:ExtractValue(bitsToCopy));
      remainingBits = remainingBits - bitsToCopy;
   end

   return exportStream:GetExportString();
end

function Util:GetLoadoutExportString(talentsTab, configIDOverride)
    if (self:GetSpecIDFromConfigID(configIDOverride)) then
        local specID = self:GetSpecIDFromConfigID(configIDOverride);
        local loadoutString = C_Traits.GenerateImportString(configIDOverride);
        if loadoutString and loadoutString ~= '' then
            return fixLoadoutString(loadoutString, specID);
        end
    end
    if not talentsTab then
        return nil;
    end

    local exportStream = ExportUtil.MakeExportDataStream();
    local configID = configIDOverride or talentsTab:GetConfigID();
    local currentSpecID = talentsTab:GetSpecID();
    local treeID = LTT:GetClassTreeId(talentsTab:GetClassID())

    -- write header
    exportStream:AddValue(self.bitWidthHeaderVersion, LOADOUT_SERIALIZATION_VERSION);
    exportStream:AddValue(self.bitWidthSpecID, currentSpecID);
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


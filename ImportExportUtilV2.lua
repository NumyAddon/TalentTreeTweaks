local LOADOUT_SERIALIZATION_VERSION = 2;
if C_Traits.GetLoadoutSerializationVersion() ~= LOADOUT_SERIALIZATION_VERSION then return; end -- Only load for serialization version 2

local _, TTT = ...
--- @class TalentTreeTweaks_ImportExportUtilV2
local ImportExportUtil = {};
TTT.ImportExportUtil = ImportExportUtil;

local LTT = LibStub('LibTalentTree-1.0');
ImportExportUtil.LibTalentTree = LTT;

ImportExportUtil.bitWidthHeaderVersion = 8;
ImportExportUtil.bitWidthSpecID = 16;
ImportExportUtil.bitWidthRanksPurchased = 6;

local function fixLoadoutString(loadoutString, specID)
   local exportStream = ExportUtil.MakeExportDataStream();
   local importStream = ExportUtil.MakeImportDataStream(loadoutString);

   if importStream:ExtractValue(ImportExportUtil.bitWidthHeaderVersion) ~= LOADOUT_SERIALIZATION_VERSION then
      return nil; -- only version 2 is supported
   end

   local headerSpecID = importStream:ExtractValue(ImportExportUtil.bitWidthSpecID);
   if headerSpecID == specID then
      return loadoutString; -- no update needed
   end

   exportStream:AddValue(ImportExportUtil.bitWidthHeaderVersion, LOADOUT_SERIALIZATION_VERSION);
   exportStream:AddValue(ImportExportUtil.bitWidthSpecID, specID);
   local remainingBits = importStream:GetNumberOfBits() - ImportExportUtil.bitWidthHeaderVersion - ImportExportUtil.bitWidthSpecID;
   -- copy the remaining bits in batches of 16
   while remainingBits > 0 do
      local bitsToCopy = math.min(remainingBits, 16);
      exportStream:AddValue(bitsToCopy, importStream:ExtractValue(bitsToCopy));
      remainingBits = remainingBits - bitsToCopy;
   end

   return exportStream:GetExportString();
end

function ImportExportUtil:GetLoadoutExportString(talentsTab, configIDOverride)
    if (TTT.Util:GetSpecIDFromConfigID(configIDOverride)) then
        local specID = TTT.Util:GetSpecIDFromConfigID(configIDOverride);
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

--- @return false|number # specID or false on error
--- @return number|string # classID or errorMessage on error
--- @return nil|TalentTreeTweaks_Util_LoadoutContent[] # loadoutInfo or nothing on error
function ImportExportUtil:ParseTalentBuildString(importString)
    local importStream = ExportUtil.MakeImportDataStream(importString);

    local headerValid, serializationVersion, specIDFromString, treeHash = self:ReadLoadoutHeader(importStream);
    local classFileName = select(6, GetSpecializationInfoByID(specIDFromString));
    local classIDFromString = TTT.Util.classMap[classFileName];

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

function ImportExportUtil:ReadLoadoutHeader(importStream)
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

function ImportExportUtil:IsHashValid(treeHash, treeID)
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

function ImportExportUtil:ReadLoadoutContent(importStream, treeID)
    local results = {};

    local treeNodes = GetTreeNodes(treeID);
    for i, nodeID in ipairs(treeNodes) do
        local nodeSelectedValue = importStream:ExtractValue(1);
        local isNodeSelected = nodeSelectedValue == 1;
        local isNodePurchased = false;
        local isPartiallyRanked = false;
        local partialRanksPurchased = 0;
        local isChoiceNode = false;
        local choiceNodeSelection = 0;

        if(isNodeSelected) then
            local nodePurchasedValue = importStream:ExtractValue(1);

            isNodePurchased = nodePurchasedValue == 1;
            if(isNodePurchased) then
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
        end

        local result = {};
        result.isNodeSelected = isNodeSelected;
        result.isNodeGranted = isNodeSelected and not isNodePurchased;
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



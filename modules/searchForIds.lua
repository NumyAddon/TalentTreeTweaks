local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local LTT = Util.LibTalentTree;

--- @class TalentTreeTweaks_SearchForIds: AceModule, AceHook-3.0
local Module = Main:NewModule('SearchForIds', 'AceHook-3.0');

local TALENT_TREE_VIEWER = 1;
local BLIZZARD_TALENT_UI = 2;

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupHook(BLIZZARD_TALENT_UI);
    end);
    EventUtil.ContinueOnAddOnLoaded(TalentViewerLoader and TalentViewerLoader:GetLodAddonName() or 'TalentTreeViewer', function()
        self:SetupHook(TALENT_TREE_VIEWER);
    end)
end

function Module:OnDisable()
    self:UnhookAll();
end

function Module:GetDescription()
    return L['Allows you to search for talents by their spellID, nodeID, entryID, and definitionID.'];
end

function Module:GetName()
    return L['Search by ID'];
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;

    return defaultOptionsTable;
end

function Module:SetupHook(addon)
    local talentFrame;
    if addon == BLIZZARD_TALENT_UI then
    	talentFrame = Util:GetTalentFrame();
    elseif addon == TALENT_TREE_VIEWER then
        talentFrame = TalentViewer and TalentViewer.GetTalentFrame and TalentViewer:GetTalentFrame();
    end
    local searchController = talentFrame.searchController;
    local textSearchFilter = searchController.searchFilters[SpellSearchUtil.FilterType.Text];
    self:RawHook(textSearchFilter, 'InternalGetExactSearchMatchDescription', 'InternalGetExactSearchMatchDescriptionHook', true);
    self:RawHook(textSearchFilter, 'DerivedGetMatchTypeForTraitNodeEntry', 'DerivedGetMatchTypeForTraitNodeEntryHook', true);
end

function Module:MatchesID(traitSearchSource, searchString, nodeID, specificEntryID)
    local entryIDs = specificEntryID and {specificEntryID} or LTT:GetNodeInfo(nodeID).entryIDs;
    for _, entryID in ipairs(entryIDs) do
        local definitionInfo = traitSearchSource:GetEntryDefinitionInfo(entryID);
        if
            searchString == tostring(entryID)
            or (definitionInfo and searchString == tostring(definitionInfo.spellID))
            or searchString == tostring(nodeID)
            or searchString == tostring(LTT:GetEntryInfo(entryID).definitionID)
        then
            return SpellSearchUtil.MatchType.ExactMatch;
        end
    end
end

function Module:InternalGetExactSearchMatchDescriptionHook(object)
    local result = self.hooks[object].InternalGetExactSearchMatchDescription(object);
    if result then
        return result;
    end
    local searchString = object.searchString;
    if not searchString or not string.match(searchString, '^%d+$') then return; end

    local allNodeInfos = object:GetAllSourceDataEntriesByType(SpellSearchUtil.SourceType.Trait);
    if allNodeInfos then
        local traitSearchSource = object:GetSearchSourceByType(SpellSearchUtil.SourceType.Trait);
        local matchingDescriptions = '';
        for _, nodeInfo in pairs(allNodeInfos) do
            if nodeInfo and nodeInfo.entryIDs then
                -- Evaluating every entryID as some nodes have multiple choice entries
                for _, entryID in ipairs(nodeInfo.entryIDs) do
                    local entryDescription = nil;
                    local definitionInfo = traitSearchSource:GetEntryDefinitionInfo(entryID);
                    if definitionInfo then
                        entryDescription = TalentUtil.GetTalentDescriptionFromInfo(definitionInfo);
                    end

                    if entryDescription and self:MatchesID(traitSearchSource, searchString, nodeInfo.ID, entryID) then
                        matchingDescriptions = matchingDescriptions .. entryDescription;
                    end
                end
            end
        end

        return matchingDescriptions;
    end
end

function Module:DerivedGetMatchTypeForTraitNodeEntryHook(object, entryID)
    local results = self.hooks[object].DerivedGetMatchTypeForTraitNodeEntry(object, entryID);
    if results and (results.matchType == SpellSearchUtil.MatchType.ExactMatch or not results.name) then
        return results;
    end

    local nodeID = LTT:GetNodeIDForEntry(entryID);
    local traitSearchSource = object:GetSearchSourceByType(SpellSearchUtil.SourceType.Trait);
    if self:MatchesID(traitSearchSource, object.searchString, nodeID, entryID) then
        results.matchType = SpellSearchUtil.MatchType.ExactMatch;
    end

    return results;
end

function Module:GetExactSearchMatchDescriptionHook(searchMixin)
    local value = self.hooks[searchMixin].GetExactSearchMatchDescription(searchMixin);
    if value then
        return value;
    end
    for talentButton in searchMixin:EnumerateAllTalentButtons() do
        local nodeInfo = talentButton:GetNodeInfo();
        if nodeInfo and nodeInfo.entryIDs then
            -- Evaluating every entryID as some buttons have multiple choice talents
            for _, entryID in ipairs(nodeInfo.entryIDs) do
                local definitionInfo = searchMixin:GetTalentFrame():GetDefinitionInfoForEntry(entryID);
                if
                    searchMixin.searchString == tostring(entryID)
                    or (definitionInfo and searchMixin.searchString == tostring(definitionInfo.spellID))
                    or searchMixin.searchString == tostring(nodeInfo.ID)
                    or searchMixin.searchString == tostring(searchMixin:GetTalentFrame():GetAndCacheEntryInfo(entryID).definitionID)
                then
                    return TalentUtil.GetTalentDescriptionFromInfo(definitionInfo):lower();
                end
            end
        end
    end
    return nil;
end

function Module:GetSearchMatchTypeForEntryHook(searchMixin, nodeID, entryID)
    if not searchMixin:GetIsActiveAndEnabled() or not searchMixin.searchString then
        return nil;
    end
    local definitionInfo = searchMixin:GetTalentFrame():GetDefinitionInfoForEntry(entryID);
    if
        searchMixin.searchString == tostring(entryID)
        or (definitionInfo and searchMixin.searchString == tostring(definitionInfo.spellID))
        or searchMixin.searchString == tostring(nodeID)
        or searchMixin.searchString == tostring(searchMixin:GetTalentFrame():GetAndCacheEntryInfo(entryID).definitionID)
    then
        return TalentButtonUtil.SearchMatchType.ExactMatch
    end

    return self.hooks[searchMixin].GetSearchMatchTypeForEntry(searchMixin, nodeID, entryID);
end


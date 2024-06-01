local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @class TalentTreeTweaks_SearchForIds: AceModule, AceHook-3.0
local Module = Main:NewModule('SearchForIds', 'AceHook-3.0');

local TALENT_TREE_VIEWER = 1;
local BLIZZARD_TALENT_UI = 2;

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupHook(BLIZZARD_TALENT_UI);
    end);
    EventUtil.ContinueOnAddOnLoaded('TalentTreeViewer', function()
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
    if talentFrame and talentFrame.textSearch then
        self:RawHook(talentFrame.textSearch, 'GetExactSearchMatchDescription', 'GetExactSearchMatchDescriptionHook', true);
        self:RawHook(talentFrame.textSearch, 'GetSearchMatchTypeForEntry', 'GetSearchMatchTypeForEntryHook', true);
    end
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


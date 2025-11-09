--- @class TTT_NS
local ns = select(2, ...);

--- @class TalentTreeTweaks_Util
local Util = {};
ns.Util = Util;
local L = ns.L;
local ImportExportUtil = ns.ImportExportUtil;

local talentAddonName = 'Blizzard_PlayerSpells';

local LTT = LibStub('LibTalentTree-1.0');
Util.LibTalentTree = LTT;

Util.PlayerKey = UnitName('player') .. '-' .. GetRealmName();
Util.RightClickAtlasMarkup = CreateAtlasMarkup('NPE_RightClick', 18, 18);
Util.LeftClickAtlasMarkup = CreateAtlasMarkup('NPE_LeftClick', 18, 18);
Util.debug = false;
--@debug@
Util.debug = true;
--@end-debug@

Util.specToClassMap = {};
Util.classMap = {};
do
    for classID = 1, GetNumClasses() do
        Util.classMap[select(2, GetClassInfo(classID))] = classID;
        for specIndex = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
            Util.specToClassMap[(GetSpecializationInfoForClassID(classID, specIndex))] = classID;
        end
    end
end

Util.configIDLookup = {};
Util.addonLoadedRegistry = {};

function Util:DebugPrint(...)
    if not self.debug then return; end

    print('TalentTreeTweaks Debug:', ...);
end

function Util:OnInitialize()
    self.dialogName = 'TalentTreeTweaksCopyTextDialog';
    StaticPopupDialogs['TalentTreeTweaksCopyTextDialog'] = {
        text = L['CTRL-C to copy %s'],
        button1 = CLOSE,
        --- @param dialog StaticPopupTemplate
        --- @param data string
        OnShow = function(dialog, data)
            local function HidePopup()
                dialog:Hide();
            end
            --- @type StaticPopupTemplate_EditBox
            local editBox = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox;
            editBox:SetScript('OnEscapePressed', HidePopup);
            editBox:SetScript('OnEnterPressed', HidePopup);
            editBox:SetScript('OnKeyUp', function(_, key)
                if IsControlKeyDown() and (key == 'C' or key == 'X') then
                    HidePopup();
                end
            end);
            editBox:SetMaxLetters(0);
            editBox:SetText(data);
            editBox:HighlightText();
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
            if addonName == talentAddonName and self.classTalentUILoadCallbacks.registered then
                self:RunOnLoadCallbacks();
            end
            if self.addonLoadedRegistry[addonName] then
                for _, callback in ipairs(self.addonLoadedRegistry[addonName]) do
                    securecallfunction(callback);
                end
                self.addonLoadedRegistry[addonName] = nil;
            end
        end
        if event == 'TRAIT_CONFIG_LIST_UPDATED' then
            self:RefreshConfigIDLookup();
        end
    end);
    self:RefreshConfigIDLookup();
end

function Util:ContinueOnAddonLoaded(addonName, callback)
    if C_AddOns.IsAddOnLoaded(addonName) then
        callback();
        return;
    end

    self.addonLoadedRegistry[addonName] = self.addonLoadedRegistry[addonName] or {};
    table.insert(self.addonLoadedRegistry[addonName], callback);
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
function Util:OnTalentUILoad(callback, priority)
    local actualPriority = priority or 10;
    local registry = self.classTalentUILoadCallbacks;
    registry[actualPriority] = registry[actualPriority] or {};
    table.insert(registry[actualPriority], callback);
    registry.minPriority = math.min(registry.minPriority, actualPriority);
    registry.maxPriority = math.max(registry.maxPriority, actualPriority);
    registry.registered = true;

    if C_AddOns.IsAddOnLoaded(talentAddonName) then
        self:RunOnLoadCallbacks();
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

local eventFrame = CreateFrame("Frame");
do
    eventFrame.combatLockdownQueue = {};
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if self[event] then
            self[event](self, ...);
        end
    end);
    function eventFrame:PLAYER_REGEN_ENABLED()
        self:UnregisterEvent("PLAYER_REGEN_ENABLED");
        if #self.combatLockdownQueue == 0 then return; end

        for _, item in pairs(self.combatLockdownQueue) do
            item.func(unpack(item.args));
        end
        self.combatLockdownQueue = {};
    end
end

--- @param func function
--- @param ... any # arguments
function Util:AddToCombatLockdownQueue(func, ...)
    if not InCombatLockdown() then
        func(...);
        return;
    end
    if #eventFrame.combatLockdownQueue == 0 then
        eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
    end

    tinsert(eventFrame.combatLockdownQueue, { func = func, args = { ... } });
end


function Util:CopyText(text, optionalTitleSuffix)
    StaticPopup_Show(self.dialogName, optionalTitleSuffix or '', nil, text);
end

--- @return PlayerSpellsFrame
function Util:GetTalentContainerFrame()
    local frameName = 'PlayerSpellsFrame';
    if not _G[frameName] then
        C_AddOns.LoadAddOn(talentAddonName);
    end

    return _G[frameName];
end

--- @return PlayerSpellsFrame|nil
function Util:GetTalentContainerFrameIfLoaded()
    return PlayerSpellsFrame;
end

--- @return PlayerSpellsFrame_TalentsFrame
function Util:GetTalentFrame()
    return self:GetTalentContainerFrame().TalentsFrame;
end

--- @return PlayerSpellsFrame_TalentsFrame|nil
function Util:GetTalentFrameIfLoaded()
    local containerFrame = self:GetTalentContainerFrameIfLoaded();
    if not containerFrame then return; end

    return containerFrame.TalentsFrame;
end

function Util:RefreshConfigIDLookup()
    wipe(self.configIDLookup);
    local classID = PlayerUtil.GetClassID();
    for specIndex = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
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
        for specIndex = 1, C_SpecializationInfo.GetNumSpecializationsForClassID(classID) do
            local specID, name = GetSpecializationInfoForClassID(classID, specIndex);
            if name == configInfo.name then
                self.configIDLookup[configID] = specID;

                return specID;
            end
        end
    end
end

function Util:GetActiveSubTreeIDByNodeInfo(nodeInfo)
    local activeEntryID = nodeInfo and nodeInfo.activeEntry and nodeInfo.activeEntry.entryID;
    if not activeEntryID then return; end

    local entryInfo = LTT:GetEntryInfo(activeEntryID);

    return entryInfo and entryInfo.subTreeID;
end

function Util:GetLoadoutExportString(talentsTab, configIDOverride)
    return ImportExportUtil:GetLoadoutExportString(talentsTab, configIDOverride);
end

--- @return false|number # specID or false on error
--- @return number|string # classID or errorMessage on error
--- @return nil|TTT_Util_LoadoutContent[] # loadoutInfo or nothing on error
function Util:ParseTalentBuildString(importString)
    return ImportExportUtil:ParseTalentBuildString(importString);
end

function Util:ReadLoadoutHeader(importStream)
    return ImportExportUtil:ReadLoadoutHeader(importStream);
end

function Util:IsHashValid(treeHash, treeID)
    return ImportExportUtil:IsHashValid(treeHash, treeID);
end

function Util:ReadLoadoutContent(importStream, treeID)
    return ImportExportUtil:ReadLoadoutContent(importStream, treeID);
end


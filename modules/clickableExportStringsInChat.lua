local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @class TalentTreeTweaks_ClickableExportStringsInChat: AceModule, AceHook-3.0
local Module = Main:NewModule('ClickableExportStringsInChat', 'AceHook-3.0');
Module.bitWidthHeaderVersion = 8;
Module.bitWidthSpecID = 16;
Module.bitWidthRanksPurchased = 6;
local LEVELING_EXPORT_STRING_PATERN = ".+%-LVL%-.+";

local LTT = Util.LibTalentTree;

local events = {
    CHAT_MSG_BATTLEGROUND = true,
    CHAT_MSG_BATTLEGROUND_LEADER = true,
    CHAT_MSG_BN_WHISPER = true,
    CHAT_MSG_BN_WHISPER_INFORM = true,
    CHAT_MSG_CHANNEL = true,
    CHAT_MSG_EMOTE = true,
    CHAT_MSG_GUILD = true,
    CHAT_MSG_INSTANCE_CHAT = true,
    CHAT_MSG_INSTANCE_CHAT_LEADER = true,
    CHAT_MSG_OFFICER = true,
    CHAT_MSG_PARTY = true,
    CHAT_MSG_PARTY_LEADER = true,
    CHAT_MSG_RAID = true,
    CHAT_MSG_RAID_LEADER = true,
    CHAT_MSG_RAID_WARNING = true,
    CHAT_MSG_SAY = true,
    CHAT_MSG_WHISPER = true,
    CHAT_MSG_WHISPER_INFORM = true,
    CHAT_MSG_YELL = true,
};

local function Filter(_, _, message, ...) return false, Module:ReplaceChatMessage(message), ... end

local LOADOUT_SERIALIZATION_VERSION;
local SUPPORTED_SERIALIZATION_VERSIONS = {[1] = true, [2] = true};
function Module:OnInitialize()
    self.debug = false;
    LOADOUT_SERIALIZATION_VERSION = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or 1;
end

function Module:OnEnable()
    for event in pairs(events) do
        ChatFrame_AddMessageEventFilter(event, Filter)
    end
    self:SecureHook('SetItemRef');
    for _, frameName in pairs(CHAT_FRAMES) do
        local frame = _G[frameName];
        self:SecureHookScript(frame, 'OnHyperlinkEnter');
        self:SecureHookScript(frame, 'OnHyperlinkLeave');
    end
    self:SecureHook('FloatingChatFrame_OnLoad', function(frame)
        self:SecureHookScript(frame, 'OnHyperlinkEnter');
        self:SecureHookScript(frame, 'OnHyperlinkLeave');
    end);
end

function Module:OnDisable()
    for event in pairs(events) do
        ChatFrame_RemoveMessageEventFilter(event, Filter);
    end
    self:UnhookAll();
end

function Module:GetDescription()
    return L['Talent Loadout links are improved, to allow you to use modifiers, to copy the link, import it as a loadout, open it in Talent Tree Viewer (if installed) etc.\nOptionally, it can also scan your chat for any loadout string that was sent as normal regular text.'];
end

function Module:GetName()
    return L['Improved Loadout Links'];
end

function Module:GetOptions(defaultOptionsTable, db)
    Util:PrepareModuleDb(self, db, {
        disableDetectionFromStrings = true,
    });

    local getter, setter, increment = Util:GetterSetterIncrementFactory(db, function() end);
    defaultOptionsTable.args.disableDetectionFromStrings = {
        order = increment(),
        type = 'toggle',
        width = 'double',
        name = L['Disable detection for loadout strings in chat'],
        desc = L['Disables the module from scanning your chat for any loadout string that was sent as normal regular text. This can potentially reduce performance issues, especially on bussier realms.'],
        get = getter,
        set = setter,
    };

    defaultOptionsTable.args.showExample = {
        order = increment(),
        type = 'execute',
        width = 'double',
        name = L['Show Example link in chat'],
        desc = L['Shows an example of a clickable link in chat.'],
        func = function()
            local talentTab = Util:GetTalentFrame();
            local exportString = Util:GetLoadoutExportString(talentTab);
            print(L['Example of a regular string'], self:ReplaceChatMessage(exportString), self.db.disableDetectionFromStrings and '' or L['(was %s)']:format(exportString));

            local linkDisplayText = ('[%s]'):format(TALENT_BUILD_CHAT_LINK_TEXT:format(PlayerUtil.GetSpecName(), PlayerUtil.GetClassName()));
            local linkText = LinkUtil.FormatLink('talentbuild', linkDisplayText, PlayerUtil.GetCurrentSpecID(), UnitLevel('player'), exportString);
            local chatLink = PlayerUtil.GetClassColor():WrapTextInColorCode(linkText);
            print(L['Example of a loadout link'], self:ReplaceChatMessage(chatLink), L['(was %s)']:format(chatLink));
        end,
    };

    return defaultOptionsTable;
end

function Module:DebugPrint(...)
    if self.debug then
        print(...)
    end
end

function Module:WrapTooltipTextInColor(clickText, action)
    return ('|cffeda55f%s|r %s'):format(clickText, (action));
end

function Module:OnHyperlinkEnter(chatFrame, link)
    local linkType, addon, specID, level, exportString = string.split(':', link)
    if not (linkType == 'addon' and addon == 'TalentTreeTweaks') then return end
    specID = tonumber(specID);
    level = tonumber(level);

    local hasLevelingBuild = not not exportString:match(LEVELING_EXPORT_STRING_PATERN);
    local talentViewerEnabled = Main:IsTalentTreeViewerEnabled();
    local classID = Util.specToClassMap[specID];
    local className, classFileName = GetClassInfo(classID);
    local classColor = RAID_CLASS_COLORS[classFileName];
    local specName = select(2, GetSpecializationInfoByID(specID));
    local prettyLinkText = classColor:WrapTextInColorCode(('%s %s (lvl %d)'):format(specName, className, level));

    local click = L['Click:'];
    local altClick = L['ALT + Click:'];
    local ctrlClick = L['CTRL + Click:'];
    local shiftLeftClick = L['Shift + Left-Click:'];
    local shiftRightClick = L['Shift + Right-Click:'];

    local actionCopyLoadout = L['Copy Loadout'];
    local actionImportLoadout = L['Import Loadout'];

    self.showingTooltip = true;
    GameTooltip:SetOwner(chatFrame, 'ANCHOR_CURSOR');
    GameTooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(('Talent Tree Tweaks - %s'):format(prettyLinkText)));
    if hasLevelingBuild then
        GameTooltip:AddLine(CreateAtlasMarkup("GarrMission_CurrencyIcon-Xp", 16, 16) .. L['This loadout includes leveling information.']);
    end
    if talentViewerEnabled then
        GameTooltip:AddLine(self:WrapTooltipTextInColor(click, L['Open in Talent Tree Viewer']))
        GameTooltip:AddLine(self:WrapTooltipTextInColor(altClick, L['Open loadout in default Inspect UI']))
        GameTooltip:AddLine(self:WrapTooltipTextInColor(ctrlClick, actionImportLoadout))
    else
        GameTooltip:AddLine(self:WrapTooltipTextInColor(click, L['Open loadout in default Inspect UI']))
        GameTooltip:AddLine(self:WrapTooltipTextInColor(ctrlClick, actionImportLoadout))
    end
    GameTooltip:AddLine(self:WrapTooltipTextInColor(shiftLeftClick, L['Link in chat']))
    GameTooltip:AddLine(self:WrapTooltipTextInColor(shiftRightClick, actionCopyLoadout))
    GameTooltip:Show();
end

function Module:OnHyperlinkLeave()
    if not self.showingTooltip then return end
    GameTooltip:Hide();
end

function Module:SetItemRef(link, text, button)
    local linkType, addon, specID, level, exportString = string.split(':', link)
    if not (linkType == 'addon' and addon == 'TalentTreeTweaks') then return end

    if IsShiftKeyDown() then
        if 'LeftButton' == button then
            local fixedLink = GetFixedLink(text:gsub('addon:TalentTreeTweaks', 'talentbuild'));
            ChatEdit_InsertLink(fixedLink);
            return;
        else
            Util:CopyText(exportString, L['Talent Loadout String']);
            return;
        end
    end
    if IsControlKeyDown() then
        self:OpenInImportUI(exportString);
    elseif IsAltKeyDown() then
        self:OpenInDefaultUI(level, exportString);
    else
        if Main:IsTalentTreeViewerEnabled() then
            self:OpenInTalentTreeViewer(level, exportString);
        else
            self:OpenInDefaultUI(level, exportString);
        end
    end
end

function Module:OpenInTalentTreeViewer(level, exportString)
    if TalentViewerLoader then
        TalentViewerLoader:LoadTalentViewer();
    else
        C_AddOns.LoadAddOn('TalentTreeViewer');
    end
    if not TalentViewer or not TalentViewer.ImportLoadout then
        self:OpenInDefaultUI(level, exportString);
        print(L['Error opening in TalentTreeViewer. Showing default Blizzard inspect UI instead.']);

        return;
    end
    TalentViewer:ImportLoadout(exportString);
end

function Module:OpenInImportUI(exportString)
    local talentFrame = Util:GetTalentContainerFrame();
    if not talentFrame:IsShown() then
        ShowUIPanel(talentFrame);
    end
    ClassTalentLoadoutImportDialog.NameControl:GetEditBox():SetAutoFocus(true);
    ClassTalentLoadoutImportDialog.ImportControl:GetEditBox():SetAutoFocus(false);
    ClassTalentLoadoutImportDialog:ShowDialog();
    ClassTalentLoadoutImportDialog.ImportControl:GetEditBox():SetText(exportString);
    ClassTalentLoadoutImportDialog.NameControl:GetEditBox():SetAutoFocus(false);
    ClassTalentLoadoutImportDialog.ImportControl:GetEditBox():SetAutoFocus(true);
end

function Module:OpenInDefaultUI(level, exportString)
    local talentFrame = Util:GetTalentContainerFrame();
    if not talentFrame or not talentFrame.SetInspectString then return end
    talentFrame:SetInspectString(exportString, level);
    if not talentFrame:IsShown() then
        ShowUIPanel(talentFrame);
    end
end

local function replaceSubString(str, sStart, sEnd, replacement)
    return string.sub(str, 1, sStart-1) .. replacement .. string.sub(str, sEnd+1)
end

function Module:ReplaceChatMessage(message)
    message = message:gsub('(|Htalentbuild:(%d+):(%d+):([^|]+)|h)', '|Haddon:TalentTreeTweaks:%2:%3:%4|h');
    if self.db.disableDetectionFromStrings then
        return (message:gsub('(|Haddon:TalentTreeTweaks:%d+:%d+:[^|]+%-LVL%-[^|]+|h%[)', '%1' .. CreateAtlasMarkup("GarrMission_CurrencyIcon-Xp", 16, 16)));
    end

    local importStringPattern = '([A-Za-z0-9+/=]+)';
    local prefixPattern = '|Haddon:TalentTreeTweaks:(%d+):(%d+):$';

    local toReplace = {};

    local sStart, sEnd, importString = message:find(importStringPattern);
    local prefixExistsSomewhere = sStart and message:find(prefixPattern:gsub('%$', ''));
    local lEnd;
    while (sStart) do
        local lStart;
        if prefixExistsSomewhere then
            lStart = message:sub(lEnd or 1, sStart-1):find(prefixPattern);
            if lStart then
                lStart = lStart + (lEnd or 1) - 1;
                lEnd = message:sub(lStart):find('|h');
                if lEnd then
                    lEnd = lEnd + lStart;
                    sEnd = math.max(lEnd, sEnd); -- sEnd must never go down, or we get into an infinite loop
                end
            end
        end

        if not lStart then
            local specID, requiredLevel;
            local valid = false;
            if importString:len() > 40 and importString:len() < 120 then
                --- A druid with lots of options picked, uses 103 characters
                --- and an empty DH uses 47
                --- the number of characters roughly corresponds to the number of talents in the class overall
                --- and is increased for the talents picked, and whether they are choice nodes, or partially purchased nodes
                valid = true;
            end
            if valid then
                valid, specID, requiredLevel = self:ParseImportString(importString);
            end
            if valid then
                self:DebugPrint('Valid import string, specID:', specID);

                table.insert(toReplace, {
                    rStart = sStart,
                    rEnd = sEnd,
                    specID = specID,
                    level = requiredLevel,
                    importString = importString,
                    wrapInLink = true,
                });
            end
        end

        sStart, sEnd, importString = message:find(importStringPattern, sEnd+1);
    end

    for i = #toReplace, 1, -1 do
        local item = toReplace[i];
        local replacement = string.format(
            '|Haddon:TalentTreeTweaks:%d:%d:%s|h',
            item.specID,
            item.level,
            item.importString
        );
        if item.wrapInLink then
            local classID = Util.specToClassMap[item.specID];
            local className, classFileName = GetClassInfo(classID);
            local classColor = RAID_CLASS_COLORS[classFileName];
            local specName = select(2, GetSpecializationInfoByID(item.specID));
            local linkTextFormat = ('[%s]|h'):format(TALENT_BUILD_CHAT_LINK_TEXT or 'Talents: %s %s')
            replacement = classColor:WrapTextInColorCode(replacement .. linkTextFormat:format(specName, className));
        end
        message = replaceSubString(message, item.rStart, item.rEnd, replacement);
    end

    return (message:gsub('(|Haddon:TalentTreeTweaks:%d+:%d+:[^|]+%-LVL%-[^|]+|h%[)', '%1' .. CreateAtlasMarkup("GarrMission_CurrencyIcon-Xp", 16, 16)));
end

local validStringsCache = {};
function Module:ParseImportString(importText)
    if validStringsCache[importText] then return unpack(validStringsCache[importText]); end
    local importStream = ExportUtil.MakeImportDataStream(importText);

    local headerValid, serializationVersion, specID, treeHash = self:ReadLoadoutHeader(importStream);
    self:DebugPrint('serialization version:', serializationVersion, 'specID:', specID)

    if(not headerValid) then
        self:DebugPrint('Invalid header');
        return false;
    end

    if(serializationVersion ~= LOADOUT_SERIALIZATION_VERSION) then
        self:DebugPrint('Invalid serialization version');
        return false;
    end

    if(not SUPPORTED_SERIALIZATION_VERSIONS[serializationVersion]) then
        self:DebugPrint('Unsupported serialization version');
        return false;
    end

    local treeID = specID and Util.specToClassMap[specID] and LTT:GetClassTreeId(Util.specToClassMap[specID]);
    if (not treeID) then
        self:DebugPrint('Invalid tree ID');
        return false;
    end

    if(not self:IsHashValid(treeHash, treeID)) then
        self:DebugPrint('Invalid tree hash');
        return false;
    end

    local valid, pointsSpent = self:ValidateLoadoutContent(importStream, treeID);
    if (not valid) then
        self:DebugPrint('Invalid loadout content');
        return false;
    end

    validStringsCache[importText] = {true, specID, pointsSpent};

    return true, specID, pointsSpent;
end

function Module:ReadLoadoutHeader(importStream)
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

function Module:ValidateLoadoutContent(importStream, treeID)
    local treeNodes = GetTreeNodes(treeID);
    local classPointsSpent, specPointsSpent = 0, 0;
    for i = 1, #treeNodes do
        local nodeSelectedValue = importStream:ExtractValue(1)
        if nodeSelectedValue == nil then
            self:DebugPrint('Invalid nodeSelected value', i);
            return false
        end

        if(nodeSelectedValue == 1) then
            local isNodePurchased = true;
            if LOADOUT_SERIALIZATION_VERSION == 2 then
                local isNodePurchasedValue = importStream:ExtractValue(1);
                if isNodePurchasedValue == nil then
                    self:DebugPrint('Invalid isNodePurchased value', i);
                    return false
                end
                isNodePurchased = isNodePurchasedValue == 1;
            end
            if isNodePurchased then
                local isPartiallyRankedValue = importStream:ExtractValue(1);
                if isPartiallyRankedValue == nil then
                    self:DebugPrint('Invalid isPartiallyRanked value', i);
                    return false
                end

                local nodeInfo = LTT:GetLibNodeInfo(treeID, treeNodes[i]);
                local isClassNode = nodeInfo and nodeInfo.isClassNode;
                local pointsSpent = nodeInfo and nodeInfo.maxRanks or 1;

                if(isPartiallyRankedValue == 1) then
                    local partialRanksPurchased = importStream:ExtractValue(self.bitWidthRanksPurchased);
                    if partialRanksPurchased == nil then
                        self:DebugPrint('Invalid partialRanksPurchased value', i);
                        return false
                    end
                    pointsSpent = partialRanksPurchased;
                end

                local isChoiceNodeValue = importStream:ExtractValue(1);
                if isChoiceNodeValue == nil then
                    self:DebugPrint('Invalid isChoiceNode value', i);
                    return false
                end
                if(isChoiceNodeValue == 1) then
                    local choiceNodeSelection = importStream:ExtractValue(2);
                    -- 0-indexed, so only 0 and 1 are valid
                    if choiceNodeSelection == nil or choiceNodeSelection > 1 then
                        self:DebugPrint('Invalid choiceNodeSelection value', i, choiceNodeSelection);
                        return false
                    end
                end

                if(isClassNode) then
                    classPointsSpent = classPointsSpent + pointsSpent;
                else
                    specPointsSpent = specPointsSpent + pointsSpent;
                end
            end
        end
    end

    local requiredLevel = math.max(10, 8 + (classPointsSpent * 2), 9 + (specPointsSpent * 2));

    local indexValuesDiff = importStream.currentIndex - #importStream.dataValues

    return indexValuesDiff == 0 or indexValuesDiff == 1, requiredLevel;
end

function Module:IsHashValid(treeHash, treeID)
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

local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local Module = Main:NewModule('ClickableExportStringsInChat', 'AceHook-3.0');
Module.bitWidthHeaderVersion = 8;
Module.bitWidthSpecID = 16;
Module.bitWidthRanksPurchased = 6;

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

local function Filter(...) return Module:Filter(...) end

local LOADOUT_SERIALIZATION_VERSION;
function Module:OnInitialize()
    self.debug = false;
    LOADOUT_SERIALIZATION_VERSION = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or 1;
end

function Module:OnEnable()
    for event in pairs(events) do
        ChatFrame_AddMessageEventFilter(event, Filter)
    end
    self:SecureHook('SetItemRef');
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i];
        self:SecureHookScript(frame, "OnHyperlinkEnter");
        self:SecureHookScript(frame, "OnHyperlinkLeave");
    end
end

function Module:OnDisable()
    for event in pairs(events) do
        ChatFrame_RemoveMessageEventFilter(event, Filter);
    end
    self:UnhookAll();
end

function Module:GetDescription()
    return L["Attempts to turn loadout export strings found in chat, into clickable links. You can use modifiers, to copy the link, import it as a loadout, open it in Talent Tree Viewer (if installed) etc.\nDefault talent links are also extended to allow this behaviour."];
end

function Module:GetName()
    return L['Clickable Export Strings In Chat'];
end

function Module:GetOptions(defaultOptionsTable, db)
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = L['Show Example link in chat'],
        desc = L['Shows an example of a clickable link in chat.'],
        func = function()
            LoadAddOn('Blizzard_ClassTalentUI');
            local talentTab = ClassTalentFrame.TalentsTab;
            local exportString = Util:GetLoadoutExportString(talentTab);
            print(select(2, self:Filter(_, _, exportString)));
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
    return ("|cffeda55f%s|r %s"):format(clickText, (action));
end

function Module:OnHyperlinkEnter(chatFrame, link)
    local linkType, addon, specID, level, exportString = string.split(":", link)
    if not (linkType == "garrmission" and addon == "TalentTreeTweaks") then return end
    specID = tonumber(specID);
    level = tonumber(level);

    local talentViewerEnabled = Main:IsTalentTreeViewerEnabled();
    local classID = Util.specToClassMap[specID];
    local className, classFileName = GetClassInfo(classID);
    local classColor = RAID_CLASS_COLORS[classFileName];
    local specName = select(2, GetSpecializationInfoByID(specID));
    local prettyLinkText = classColor:WrapTextInColorCode(("%s %s (lvl %d)"):format(specName, className, level));

    local click = L["Click:"];
    local altClick = L["ALT + Click:"];
    local ctrlClick = L["CTRL + Click:"];
    local shiftLeftClick = L["Shift + Left-Click:"];
    local shiftRightClick = L["Shift + Right-Click:"];

    local actionCopyLink = L["Copy Link"];
    local actionImportLoadout = L["Import Loadout"];

    self.showingTooltip = true;
    GameTooltip:SetOwner(chatFrame, "ANCHOR_CURSOR");
    GameTooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(("Talent Tree Tweaks - %s"):format(prettyLinkText)));
    if talentViewerEnabled then
        GameTooltip:AddLine(self:WrapTooltipTextInColor(click, L["Open in Talent Tree Viewer"]))
        GameTooltip:AddLine(self:WrapTooltipTextInColor(altClick, L["Open loadout in default Inspect UI"]))
        GameTooltip:AddLine(self:WrapTooltipTextInColor(ctrlClick, actionImportLoadout))
    else
        GameTooltip:AddLine(self:WrapTooltipTextInColor(click, L["Open loadout in default Inspect UI"]))
        GameTooltip:AddLine(self:WrapTooltipTextInColor(ctrlClick, actionImportLoadout))
    end
    GameTooltip:AddLine(self:WrapTooltipTextInColor(shiftLeftClick, L["Link in chat"]))
    GameTooltip:AddLine(self:WrapTooltipTextInColor(shiftRightClick, actionCopyLink))
    GameTooltip:Show();
end

function Module:OnHyperlinkLeave()
    if not self.showingTooltip then return end
    GameTooltip:Hide();
end

function Module:SetItemRef(link, text, button)
    local linkType, addon, specID, level, exportString = string.split(":", link)
    if not (linkType == "garrmission" and addon == "TalentTreeTweaks") then return end

    if IsShiftKeyDown() then
        if "LeftButton" == button then
            local fixedLink = GetFixedLink(text:gsub('garrmission:TalentTreeTweaks', 'talentbuild'));
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
    LoadAddOn('TalentTreeViewer');
    if not TalentViewer or not TalentViewer.ImportLoadout then
        self:OpenInDefaultUI(level, exportString);
        print(L['Error opening in TalentTreeViewer. Showing default Blizzard inspect UI instead.']);

        return;
    end
    TalentViewer:ImportLoadout(exportString);
end

function Module:OpenInImportUI(exportString)
    LoadAddOn('Blizzard_ClassTalentUI');
    if not ClassTalentFrame:IsShown() then
        ToggleTalentFrame();
    end
    ClassTalentLoadoutImportDialog.NameControl:GetEditBox():SetAutoFocus(true);
    ClassTalentLoadoutImportDialog.ImportControl:GetEditBox():SetAutoFocus(false);
    ClassTalentLoadoutImportDialog:ShowDialog();
    ClassTalentLoadoutImportDialog.ImportControl:GetEditBox():SetText(exportString);
    ClassTalentLoadoutImportDialog.NameControl:GetEditBox():SetAutoFocus(false);
    ClassTalentLoadoutImportDialog.ImportControl:GetEditBox():SetAutoFocus(true);
end

function Module:OpenInDefaultUI(level, exportString)
    ClassTalentFrame_LoadUI();

    if not ClassTalentFrame or not ClassTalentFrame.SetInspectString then return end
    ClassTalentFrame:SetInspectString(exportString, level);
    if not ClassTalentFrame:IsShown() then
        ShowUIPanel(ClassTalentFrame);
    end
end

local function replaceSubString(str, sStart, sEnd, replacement)
    return string.sub(str, 1, sStart-1) .. replacement .. string.sub(str, sEnd+1)
end

function Module:Filter(_, _, message, ...)
    local importStringPattern = '([A-Za-z0-9+/=]+)';
    local prefixPattern = '|Htalentbuild:(%d+):(%d+):$';

    local specID, requiredLevel;
    local toReplace = {};

    local sStart, sEnd, importString = message:find(importStringPattern);
    local prefixExistsSomewhere = sStart and message:find(prefixPattern:gsub('%$', ''));
    while (sStart) do
        local lStart, lEnd;
        if prefixExistsSomewhere then
            lStart, lEnd, specID, requiredLevel = message:sub(1, sStart-1):find(prefixPattern);
        end

        if lStart then
            --- coming from a talentbuild link, don't validate it, just blindly accept, and rewrite the link
            table.insert(toReplace, {
                rStart = lStart,
                rEnd = sEnd + 2, -- string.len('|h')
                specID = specID,
                level = requiredLevel,
                importString = importString,
                wrapInLink = false,
            });
        else
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
                self:DebugPrint("Valid import string, specID:", specID);

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
                '|Hgarrmission:TalentTreeTweaks:%d:%d:%s|h',
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

    return false, message, ...;
end


local validStringsCache = {};
function Module:ParseImportString(importText)
    if validStringsCache[importText] then return unpack(validStringsCache[importText]); end
    local importStream = ExportUtil.MakeImportDataStream(importText);

    local headerValid, serializationVersion, specID, treeHash = self:ReadLoadoutHeader(importStream);
    self:DebugPrint('serialization version:', serializationVersion, 'specID:', specID)

    if(not headerValid) then
        self:DebugPrint("Invalid header");
        return false;
    end

    if(serializationVersion ~= LOADOUT_SERIALIZATION_VERSION) then
        self:DebugPrint("Invalid serialization version");
        return false;
    end

    local treeID = specID and Util.specToClassMap[specID] and LTT:GetClassTreeId(Util.specToClassMap[specID]);
    if (not treeID) then
        self:DebugPrint("Invalid tree ID");
        return false;
    end

    if(not self:IsHashValid(treeHash, treeID)) then
        self:DebugPrint("Invalid tree hash");
        return false;
    end

    local valid, pointsSpent = self:ValidateLoadoutContent(importStream, treeID);
    if (not valid) then
        self:DebugPrint("Invalid loadout content");
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
            self:DebugPrint("Invalid nodeSelected value", i);
            return false
        end

        if(nodeSelectedValue == 1) then
            local isPartiallyRankedValue = importStream:ExtractValue(1);
            if isPartiallyRankedValue == nil then
                self:DebugPrint("Invalid isPartiallyRanked value", i);
                return false
            end

            local nodeInfo = LTT:GetLibNodeInfo(treeID, treeNodes[i]);
            local isClassNode = nodeInfo and nodeInfo.isClassNode;
            local pointsSpent = nodeInfo and nodeInfo.maxRanks or 1;

            if(isPartiallyRankedValue == 1) then
                local partialRanksPurchased = importStream:ExtractValue(self.bitWidthRanksPurchased);
                if partialRanksPurchased == nil then
                    self:DebugPrint("Invalid partialRanksPurchased value", i);
                    return false
                end
                pointsSpent = partialRanksPurchased;
            end

            local isChoiceNodeValue = importStream:ExtractValue(1);
            if isChoiceNodeValue == nil then
                self:DebugPrint("Invalid isChoiceNode value", i);
                return false
            end
            if(isChoiceNodeValue == 1) then
                local choiceNodeSelection = importStream:ExtractValue(2);
                -- 0-indexed, so only 0 and 1 are valid
                if choiceNodeSelection == nil or choiceNodeSelection > 1 then
                    self:DebugPrint("Invalid choiceNodeSelection value", i, choiceNodeSelection);
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

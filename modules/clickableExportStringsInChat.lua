local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;

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
local specToClassMap = {
    [71] = 1,
    [72] = 1,
    [73] = 1,
    [1446] = 1,
    [65] = 2,
    [66] = 2,
    [70] = 2,
    [1451] = 2,
    [253] = 3,
    [254] = 3,
    [255] = 3,
    [1448] = 3,
    [259] = 4,
    [260] = 4,
    [261] = 4,
    [1453] = 4,
    [256] = 5,
    [257] = 5,
    [258] = 5,
    [1452] = 5,
    [250] = 6,
    [251] = 6,
    [252] = 6,
    [1455] = 6,
    [262] = 7,
    [263] = 7,
    [264] = 7,
    [1444] = 7,
    [62] = 8,
    [63] = 8,
    [64] = 8,
    [1449] = 8,
    [265] = 9,
    [266] = 9,
    [267] = 9,
    [1454] = 9,
    [268] = 10,
    [270] = 10,
    [269] = 10,
    [1450] = 10,
    [102] = 11,
    [103] = 11,
    [104] = 11,
    [105] = 11,
    [1447] = 11,
    [577] = 12,
    [581] = 12,
    [1456] = 12,
    [1467] = 13,
    [1468] = 13,
    [1465] = 13,
}

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
    self:SecureHook('SetItemRef')
end

function Module:OnDisable()
    for event in pairs(events) do
        ChatFrame_RemoveMessageEventFilter(event, Filter)
    end
    self:UnhookAll()
end

function Module:GetDescription()
    return [[Attempts to turn loadout export strings found in chat, into clickable links.

Shift+Click to copy the export string to your clipboard.

Opens in TalentTreeViewer if installed. Ctrl+Click to import as loadout instead.
    ]]
end

function Module:GetName()
    return 'Clickable Export Strings In Chat'
end

function Module:GetOptions(defaultOptionsTable, db)
    defaultOptionsTable.args.showExample = {
        type = 'execute',
        name = 'Show Example link in chat',
        desc = 'Shows an example of a clickable link in chat.',
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

function Module:SetItemRef(link)
    local linkType, addon, exportString = string.split(":", link)
    if linkType == "garrmission" and addon == "TTT" then
        if IsShiftKeyDown() then
            Util:CopyText(exportString);
            return;
        end
        if Main:IsTalentTreeViewerEnabled() and not IsControlKeyDown() then
            self:OpenInTalentTreeViewer(exportString)
        else
            self:OpenInDefaultTalentUI(exportString)
        end
    end
end

function Module:OpenInTalentTreeViewer(exportString)
    LoadAddOn('TalentTreeViewer');
    if not TalentViewer or not TalentViewer.ImportLoadout then
        self:OpenInDefaultTalentUI(exportString);
        print('Error opening in TalentTreeViewer. Showing default blizzard import UI instead.');

        return;
    end
    TalentViewer:ImportLoadout(exportString);
end

function Module:OpenInDefaultTalentUI(exportString)
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

function Module:Filter(_, _, message, ...)
    for word in message:gmatch('[A-Za-z0-9+/=]+') do
        -- if the word is a valid export string
        local valid, specID, requiredLevel = self:ParseImportString(word);
        if valid then
            self:DebugPrint("Valid import string, specID:", specID);
            -- replace the word with a clickable link
            local class = specToClassMap[specID];
            local classColor = RAID_CLASS_COLORS[select(2, GetClassInfo(class))];
            local specName = select(2, GetSpecializationInfoByID(specID));
            message = message:gsub(
                word:gsub('%+', '%%+'),
                string.format(
                    '|Hgarrmission:TTT:%s|h%s|h',
                    word,
                    NORMAL_FONT_COLOR:WrapTextInColorCode(
                        string.format(
                        '[Talent Tree Build (%s lvl %d)]',
                            classColor:WrapTextInColorCode(specName),
                            requiredLevel
                        )
                    )
                )
            );
        end
    end

    return false, message, ...
end

function Module:ParseImportString(importText)
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

    if(not self:IsHashPossiblyValid(treeHash)) then
        self:DebugPrint("Invalid tree hash");
        return false;
    end

    local treeID = specID and specToClassMap[specID] and LTT:GetClassTreeId(specToClassMap[specID]);
    if (not treeID) then
        self:DebugPrint("Invalid tree ID");
        return false;
    end

    local valid, pointsSpent = self:ValidateLoadoutContent(importStream, treeID);
    if (not valid) then
        self:DebugPrint("Invalid loadout content");
        return false;
    end

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

function Module:ValidateLoadoutContent(importStream, treeID)
    local treeNodes = C_Traits.GetTreeNodes(treeID);
    local classPointsSpent, specPointsSpent = 0, 0;
    for i = 1, #treeNodes do
        local nodeSelectedValue = importStream:ExtractValue(1)
        if nodeSelectedValue == nil then
            self:DebugPrint("Invalid node selected value", i);
            return false
        end

        if(nodeSelectedValue == 1) then
            local isPartiallyRankedValue = importStream:ExtractValue(1);
            if isPartiallyRankedValue == nil then
                self:DebugPrint("Invalid is partially ranked value", i);
                return false
            end

            local nodeInfo = LTT:GetLibNodeInfo(treeID, treeNodes[i]);
            local isClassNode = nodeInfo and nodeInfo.isClassNode;
            local pointsSpent = nodeInfo and nodeInfo.maxRanks or 1;

            if(isPartiallyRankedValue == 1) then
                local partialRanksPurchased = importStream:ExtractValue(self.bitWidthRanksPurchased);
                if partialRanksPurchased == nil then
                    self:DebugPrint("Invalid partial ranks purchased value", i);
                    return false
                end
                pointsSpent = partialRanksPurchased;
            end

            local isChoiceNodeValue = importStream:ExtractValue(1);
            if isChoiceNodeValue == nil then
                self:DebugPrint("Invalid is choice node value", i);
                return false
            end
            if(isChoiceNodeValue == 1) then
                local choiceNodeSelection = importStream:ExtractValue(2);
                -- 0-indexed, so only 0 and 1 are valid
                if choiceNodeSelection == nil or choiceNodeSelection > 1 then
                    self:DebugPrint("Invalid choice node selection value", i, choiceNodeSelection);
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

    if self.debug and ViragDevTool_AddData then
        ViragDevTool_AddData(importStream, "importStream");
    end

    local requiredLevel = math.max(10, 8 + (classPointsSpent * 2), 9 + (specPointsSpent * 2));

    return importStream.currentIndex == #importStream.dataValues, requiredLevel;
end

function Module:IsHashPossiblyValid(treeHash)
    if not #treeHash == 16 then
        return false;
    end
    for i, value in ipairs(treeHash) do
        if not (value >= 0 and value <= 255) then
            return false;
        end
    end

    return true;
end

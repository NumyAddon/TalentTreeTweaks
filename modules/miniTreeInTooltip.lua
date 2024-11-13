local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @class TalentTreeTweaks_MiniTreeInTooltip: AceModule, AceHook-3.0
local Module = Main:NewModule('MiniTreeInTooltip', 'AceHook-3.0');

local LTT = Util.LibTalentTree;

-- these numbers have no meaning
local VISUAL_STYLE_FULL = 1;
local VISUAL_STYLE_EMPTY = 2;
local VISUAL_STYLE_HALF = 3;
local VISUAL_STYLE_HALF_FLIPPED = 8;
local VISUAL_STYLE_LEFT = 4;
local VISUAL_STYLE_RIGHT = 5;
local VISUAL_STYLE_ONE_THIRD = 6;
local VISUAL_STYLE_TWO_THIRD = 7;

local TEXTURE_FILE = [[interface\addons\talenttreetweaks\media\mini-tree-orbs]]

-- these strings are saved as settings
local DISPLAY_STYLE_SIMPLE = 'simple';
local DISPLAY_STYLE_SIMPLE_WITH_DEFAULT_DIFF = 'simple-default-diff';
local DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF = 'simple-custom-diff';
local DISPLAY_STYLE_SPELL_ICON = 'spell_icon';

-- these numbers have no meaning
local DIFF_DEFAULT_YELLOW = 1; -- same talents/default color
local DIFF_DEFAULT_RED = 2; -- you have a talent they don't
local DIFF_DEFAULT_GREEN = 3; -- they have a talent you don't
local DIFF_DEFAULT_ORANGE = 4; -- different talent choice/rank

local GetSpellInfo;
do -- todo: remove after 11.0 release
	GetSpellInfo = _G.GetSpellInfo or function(spellID)
		if not spellID then
			return nil;
		end

		local spellInfo = C_Spell.GetSpellInfo(spellID);
		if spellInfo then
			return spellInfo.name, nil, spellInfo.iconID, spellInfo.castTime, spellInfo.minRange, spellInfo.maxRange, spellInfo.spellID, spellInfo.originalIconID;
		end
	end
end

function TalentTreeTweaks_EmbedMiniTreeIntoTooltip(tooltip, exportString, configID)
    if not exportString and configID then
        local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID);
        if not ok or not configInfo then return; end

        exportString = Util:GetLoadoutExportString(nil, configID);
        if not exportString then return false; end -- happens for example when using inspect or starter build configID
    end
    Module:AddBuildToTooltip(tooltip, exportString);
end

function Module:OnInitialize()
    self.debug = false;
    self.containers = {};
    Menu.ModifyMenu('MENU_CLASS_TALENT_PROFILE', function(dropdown, rootDescription, contextData)
        if not self:IsEnabled() then return; end
        self:OnLoadoutMenuOpen(dropdown, rootDescription);
    end);
end

function Module:OnEnable()
    for _, frameName in pairs(CHAT_FRAMES) do
        local frame = _G[frameName];
        self:SecureHookScript(frame, "OnHyperlinkEnter");
        self:SecureHookScript(frame, "OnHyperlinkLeave");
    end
    self:SecureHook("FloatingChatFrame_OnLoad", function(frame)
        self:SecureHookScript(frame, "OnHyperlinkEnter");
        self:SecureHookScript(frame, "OnHyperlinkLeave");
    end)
    self:SecureHook(GameTooltip, "Show", "OnTooltipShow");

    Util:ContinueOnAddonLoaded("Blizzard_InspectUI", function()
        self:HookInspectTalentsButton();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
end

function Module:GetDescription()
    return L["Adds a mini tree in various tooltips for Talent Tree Builds"];
end

function Module:GetName()
    return L["Mini Tree in Tooltips"];
end

function Module:GetOptions(defaultOptionsTable, db)
    local defaults = {
        displayStyle = DISPLAY_STYLE_SIMPLE_WITH_DEFAULT_DIFF,
        upgradedDisplayStyle = 0,
        scale = 1,
        diffGreen = {r = 0, g = 1, b = 0},
        diffOrange = {r = 1, g = 1, b = 0},
        diffRed = {r = 1, g = 0, b = 0},
        diffYellow = {r = 1, g = 1, b = 1},
        inactiveSubTreeAlpha = 0.5,
    }
    self.db = db;
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end
    if self.db.upgradedDisplayStyle < 1 then
        self.db.upgradedDisplayStyle = 1;
        if self.db.displayStyle == DISPLAY_STYLE_SIMPLE then
            self.db.displayStyle = DISPLAY_STYLE_SIMPLE_WITH_DEFAULT_DIFF;
        end
    end
    self.customColors = {
        [DIFF_DEFAULT_RED] = self.db.diffRed,
        [DIFF_DEFAULT_GREEN] = self.db.diffGreen,
        [DIFF_DEFAULT_ORANGE] = self.db.diffOrange,
        [DIFF_DEFAULT_YELLOW] = self.db.diffYellow,
    }

    local increment = CreateCounter(5);

    local function getColor(info)
        local color = self.db[info[#info]];
        return color.r, color.g, color.b, color.a;
    end
    local function setColor(info, r, g, b)
        local color = self.db[info[#info]];
        color.r, color.g, color.b = r, g, b;
    end
    local getter = function(info)
        return self.db[info[#info]];
    end;
    local setter = function(info, value)
        self.db[info[#info]] = value;
    end;

    defaultOptionsTable.args.displayStyle = {
        order = increment(),
        type = "select",
        name = L["Display Style"],
        desc = L["Choose how the mini tree is displayed. 'with diff' means that the mini tree will show the difference between your current build and the build in the tooltip."],
        values = {
            [DISPLAY_STYLE_SIMPLE] = L["Simple dots"],
            [DISPLAY_STYLE_SPELL_ICON] = L["Spell Icon"],
            [DISPLAY_STYLE_SIMPLE_WITH_DEFAULT_DIFF] = L["Simple dots with default diff colors"],
            [DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF] = L["Simple dots with custom diff colors"],
        },
        sorting = {
            DISPLAY_STYLE_SIMPLE,
            DISPLAY_STYLE_SPELL_ICON,
            DISPLAY_STYLE_SIMPLE_WITH_DEFAULT_DIFF,
            DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF,
        },
        width = "double",
        get = getter,
        set = setter,
    }

    defaultOptionsTable.args.customDiffWarning = {
        order = increment(),
        type = 'description',
        name = L['Warning: Custom colors may look weird, this cannot be fixed.'],
        hidden = function() return self.db.displayStyle ~= DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF; end,
    };
    defaultOptionsTable.args.diffRed = {
        order = increment(),
        type = 'color',
        name = L['You have a talent they don\'t'],
        hasAlpha = false,
        hidden = function() return self.db.displayStyle ~= DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF; end,
        get = getColor,
        set = setColor,
    };
    defaultOptionsTable.args.diffGreen = {
        order = increment(),
        type = 'color',
        name = L['They have a talent you don\'t'],
        hasAlpha = false,
        hidden = function() return self.db.displayStyle ~= DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF; end,
        get = getColor,
        set = setColor,
    };
    defaultOptionsTable.args.diffOrange = {
        order = increment(),
        type = 'color',
        name = L['You have selected a different choice, or different number of points in a talent'],
        hasAlpha = false,
        hidden = function() return self.db.displayStyle ~= DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF; end,
        get = getColor,
        set = setColor,
    };
    defaultOptionsTable.args.diffYellow = {
        order = increment(),
        type = 'color',
        name = L['You have the same talents'],
        hasAlpha = false,
        hidden = function() return self.db.displayStyle ~= DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF; end,
        get = getColor,
        set = setColor,
    };
    defaultOptionsTable.args.reset = {
        order = increment(),
        type = 'execute',
        name = RESET,
        desc = L['Reset the colors to default'],
        hidden = function() return self.db.displayStyle ~= DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF; end,
        func = function()
            self.db.diffRed = defaults.diffRed;
            self.db.diffGreen = defaults.diffGreen;
            self.db.diffOrange = defaults.diffOrange;
            self.db.diffYellow = defaults.diffYellow;
            self.customColors = {
                [DIFF_DEFAULT_RED] = self.db.diffRed,
                [DIFF_DEFAULT_GREEN] = self.db.diffGreen,
                [DIFF_DEFAULT_ORANGE] = self.db.diffOrange,
                [DIFF_DEFAULT_YELLOW] = self.db.diffYellow,
            }
        end,
    };

    defaultOptionsTable.args.scale = {
        order = increment(),
        type = "range",
        name = L["Scale"],
        desc = L["Scale of the mini tree."],
        min = 0.5,
        max = 2,
        step = 0.1,
        get = getter,
        set = setter,
    };
    defaultOptionsTable.args.inactiveSubTreeAlpha = {
        order = increment(),
        type = "range",
        name = L["Fade Inactive Hero Trees"],
        desc = L["Fade Inactive Hero Trees, to more easily see which one is active."],
        min = 0,
        max = 1,
        step = 0.1,
        get = getter,
        set = setter,
    };
    defaultOptionsTable.args.example = {
        order = increment(),
        type = "execute",
        name = L["Show Example"],
        desc = L["Show an example of the mini tree for your current spec."],
        func = function()
            local configID = C_ClassTalents.GetActiveConfigID();
            if not configID then return end;
            ItemRefTooltip:SetOwner(UIParent, 'ANCHOR_CURSOR');
            ItemRefTooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(("Talent Tree Tweaks")));
            ItemRefTooltip:Show();
            ItemRefTooltip:SetOwner(UIParent, 'ANCHOR_PRESERVE');
            ItemRefTooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(("Talent Tree Tweaks")));
            ItemRefTooltip:Show();
            TalentTreeTweaks_EmbedMiniTreeIntoTooltip(ItemRefTooltip, nil, configID)
        end,
        disabled = function() return not C_ClassTalents.GetActiveConfigID(); end,
    };

    return defaultOptionsTable;
end

function Module:DebugPrint(...)
    if self.debug then
        print(...)
    end
end

function Module:OnLoadoutMenuOpen(dropdown, rootDescription)
    for i, elementDescription in rootDescription:EnumerateElementDescriptions() do
        local configID = elementDescription:GetData();
        local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID);
        if not ok or not configInfo then return; end
        -- todo: replace with elementDescription:HookOnEnter
        hooksecurefunc(elementDescription, 'onEnter', function(frame)
            local exportString = Util:GetLoadoutExportString(Util:GetTalentFrame(), configID);

            if frame ~= GameTooltip:GetOwner() or not GameTooltip:IsShown() then
                GameTooltip:SetOwner(frame, "ANCHOR_RIGHT");
            end
            self:AddBuildToTooltip(GameTooltip, exportString);
        end);
    end
end

function Module:HookCustomSetupCallback(dropdownControl)
    if not self:IsHooked(dropdownControl, 'customSetupCallback') then
        self:SecureHook(dropdownControl, 'customSetupCallback', function(info)
            local originalFuncOnEnter = info.funcOnEnter;
            local originalFuncOnLeave = info.funcOnLeave;
            info.funcOnEnter = function(dropdownButton, ...)
                self:LoadoutDropdownOnEnter(dropdownButton);
                if(originalFuncOnEnter) then originalFuncOnEnter(dropdownButton, ...); end
            end
            info.funcOnLeave = function(dropdownButton, ...)
                self:LoadoutDropdownOnLeave(dropdownButton);
                if(originalFuncOnLeave) then originalFuncOnLeave(dropdownButton, ...); end
            end
        end);
    end
end

function Module:HookInspectTalentsButton()
    local button = InspectPaperDollItemsFrame.InspectTalents;
    self:SecureHookScript(button, "OnEnter", function()
        if not C_Traits.HasValidInspectData() then return; end
        local inspectUnit = InspectFrame.unit;
        local loadoutString = C_Traits.GenerateInspectImportString(inspectUnit);
        if not loadoutString then return; end

        if not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= button then
            GameTooltip:SetOwner(button, "ANCHOR_RIGHT");
        end
        self:AddBuildToTooltip(GameTooltip, loadoutString);
        GameTooltip:Show();
    end);
end

function Module:LoadoutDropdownOnEnter(dropdownButton)
    local configID = dropdownButton.value
    local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID);
    if not ok or not configInfo then return; end
    local exportString = Util:GetLoadoutExportString(Util:GetTalentFrame(), configID);

    if dropdownButton ~= GameTooltip:GetOwner() or not GameTooltip:IsShown() then
        self.loadoutDropdownTooltipShown = true;
        GameTooltip:SetOwner(dropdownButton, "ANCHOR_RIGHT");
    end
    self:AddBuildToTooltip(GameTooltip, exportString);
end

function Module:LoadoutDropdownOnLeave(dropdownButton)
    if self.loadoutDropdownTooltipShown then GameTooltip:Hide(); end
    self.loadoutDropdownTooltipShown = false
end

function Module:OnHyperlinkEnter(chatFrame, link)
    local linkType, part1, part2, part3, part4 = string.split(":", link);
    local specID, level, exportString;
    if (linkType == "addon" and part1 == "TalentTreeTweaks") then
        specID = part2;
        level = part3;
        exportString = part4;
    elseif(linkType == "talentbuild") then
        specID = part1;
        level = part2;
        exportString = part3;
    else
        return;
    end
    specID = tonumber(specID);
    level = tonumber(level);

    self.showingTooltip = true;
    if not GameTooltip:IsShown() or GameTooltip:GetOwner() ~= chatFrame then
        local _, specName, _, _, _, classFileName, className = GetSpecializationInfoByID(specID);
        local classColor = RAID_CLASS_COLORS[classFileName];
        local prettyLinkText = classColor:WrapTextInColorCode(("%s %s (lvl %d)"):format(specName, className, level));

        GameTooltip:SetOwner(chatFrame, "ANCHOR_CURSOR");
        GameTooltip:AddLine(HIGHLIGHT_FONT_COLOR:WrapTextInColorCode(("Talent Tree Tweaks - %s"):format(prettyLinkText)));
    end

    self:AddBuildToTooltip(GameTooltip, exportString);
end

function Module:OnHyperlinkLeave()
    if not self.showingTooltip then return end
    GameTooltip:Hide();
end

local ignoreShowHook = false;
function Module:OnTooltipShow(tooltip)
    if ignoreShowHook then return; end

    local owner = tooltip:GetOwner();
    if not owner or not owner.TalentBuildExportString then return; end

    ignoreShowHook = true;
    self:AddBuildToTooltip(tooltip, owner.TalentBuildExportString);
    ignoreShowHook = false;
end

function Module:AddBuildToTooltip(tooltip, exportString)
    local falseOrSpecID, errorOrClassID, nilOrLoadoutInfo = Util:ParseTalentBuildString(exportString);
    if false == falseOrSpecID then
        --@debug@
        print('Error parsing exportString, message:', errorOrClassID);
        --@end-debug@
        return;
    end
    local specID = falseOrSpecID;
    local classID = errorOrClassID;
    local treeID = LTT:GetClassTreeId(classID);

    local calculateDiff =
        (self.db.displayStyle == DISPLAY_STYLE_SIMPLE_WITH_DEFAULT_DIFF or self.db.displayStyle == DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF)
        and specID == PlayerUtil.GetCurrentSpecID();

    local container = self:GetOrCreateContainer(tooltip);
    container:Reset();
    container:SetScale(self.db.scale);
    local containerWidth, containerHeight = container:GetSize();
    container:SetSize(containerWidth * self.db.scale, containerHeight * self.db.scale);

    local dots = {};
    local dotsBySubTree = {};
    local activeSubTreeID;
    local subTrees = LTT:GetSubTreeIDsForSpecID(specID);
    table.sort(subTrees);
    local subTreeMap = tInvert(subTrees);

    --- @type TalentTreeTweaks_Util_LoadoutContent
    for _, nodeSelectionInfo in ipairs(nilOrLoadoutInfo) do
        local nodeID = nodeSelectionInfo.nodeID;
        if LTT:IsNodeVisibleForSpec(specID, nodeSelectionInfo.nodeID) then
            local column, row = LTT:GetNodeGridPosition(treeID, nodeID);
            if column and row then
                local nodeInfo = LTT:GetNodeInfo(treeID, nodeID);
                if nodeInfo.subTreeID and subTreeMap[nodeInfo.subTreeID] then
                    row = row + (subTreeMap[nodeInfo.subTreeID] - 1) * 5;
                end
                local style = VISUAL_STYLE_EMPTY;
                local rank = 0;
                local entryID = nodeInfo.entryIDs[nodeSelectionInfo.choiceNodeSelection];
                local entryInfo = LTT:GetEntryInfo(entryID);
                local definitionInfo = entryInfo.definitionID and C_Traits.GetDefinitionInfo(entryInfo.definitionID);
                local spellID = definitionInfo and definitionInfo.spellID;
                local spellIcon = spellID and select(8, GetSpellInfo(spellID));
                local isAtlas = false;

                if (
                    (nodeSelectionInfo.isNodeSelected and not nodeSelectionInfo.isChoiceNode and not nodeSelectionInfo.isPartiallyRanked)
                    or LTT:IsNodeGrantedForSpec(specID, nodeID)
                ) then
                    style = VISUAL_STYLE_FULL;
                    rank = nodeInfo.maxRanks;
                elseif nodeSelectionInfo.isPartiallyRanked then
                    local maxRanks = nodeInfo.maxRanks
                    rank = nodeSelectionInfo.partialRanksPurchased;
                    if maxRanks == 2 then
                        style = VISUAL_STYLE_HALF;
                    elseif maxRanks == 3 and rank == 1 then
                        style = VISUAL_STYLE_ONE_THIRD;
                    elseif maxRanks == 3 and rank == 2 then
                        style = VISUAL_STYLE_TWO_THIRD;
                    end
                elseif nodeSelectionInfo.isChoiceNode and nodeSelectionInfo.isNodeSelected then
                    rank = 1;
                    style = nodeSelectionInfo.choiceNodeSelection == 1 and VISUAL_STYLE_LEFT or VISUAL_STYLE_RIGHT;
                    if nodeInfo.isSubTreeSelection or nodeInfo.type == Enum.TraitNodeType.SubTreeSelection then
                        activeSubTreeID = entryInfo.subTreeID;
                        local subTreeInfo = activeSubTreeID and LTT:GetSubTreeInfo(activeSubTreeID);
                        spellIcon = subTreeInfo and subTreeInfo.iconElementID;
                        isAtlas = true;
                        local subTreeIndex = subTreeMap[activeSubTreeID];
                        if subTreeIndex == 1 then
                            style = VISUAL_STYLE_HALF;
                        elseif subTreeIndex == 2 then
                            style = VISUAL_STYLE_HALF_FLIPPED;
                        end
                    end
                end
                local diff = calculateDiff and self:GetDiffForNode(nodeID, entryID, rank) or nil;

                local dot = container:MakeDot(column, row, style, spellIcon, isAtlas, diff);
                dots[nodeID] = dot;
                if nodeInfo.subTreeID then
                    dotsBySubTree[nodeInfo.subTreeID] = dotsBySubTree[nodeInfo.subTreeID] or {};
                    table.insert(dotsBySubTree[nodeInfo.subTreeID], dot);
                end
            else
                self:DebugPrint('column and/or row not found for nodeID', nodeID)
            end
        end
    end

    for subTreeID, subTreeDots in pairs(dotsBySubTree) do
        local isActive = subTreeID == activeSubTreeID;
        for _, dot in pairs(subTreeDots) do
            dot:SetAlpha(isActive and 1 or (1 - self.db.inactiveSubTreeAlpha));
        end
    end
    for nodeID, dot in pairs(dots) do
        local edges = LTT:GetNodeEdges(treeID, nodeID);
        for _, edge in pairs(edges or {}) do
            local targetDot = dots[edge.targetNode];
            if targetDot then
                container:MakeLine(dot, targetDot, dot.isMaxed);
            end
        end
    end

    GameTooltip_InsertFrame(tooltip, container);
    tooltip:Show();
end

function Module:GetDiffForNode(nodeID, targetEntry, targetRank)
    local selfNodeInfo = C_Traits.GetNodeInfo(C_ClassTalents.GetActiveConfigID(), nodeID);
    local selfEntry = selfNodeInfo and selfNodeInfo.activeEntry and selfNodeInfo.activeEntry.entryID;
    local selfRank = selfNodeInfo and selfNodeInfo.activeEntry and selfNodeInfo.activeEntry.rank or 0;

    local diff;
    if targetRank == selfRank then
        if selfRank == 0 and targetRank == 0 then
            diff = nil; -- both empty
        elseif targetEntry == selfEntry then
            diff = DIFF_DEFAULT_YELLOW; -- same entry, same rank
        else
            diff = DIFF_DEFAULT_ORANGE; -- different entry
        end
    elseif targetRank ~= 0 and selfRank ~= 0 then
        diff = DIFF_DEFAULT_ORANGE; -- same entry, different rank
    elseif targetRank == 0 then
        diff = DIFF_DEFAULT_RED; -- target has entry, self doesn't
    elseif selfRank == 0 then
        diff = DIFF_DEFAULT_GREEN; -- self has entry, target doesn't
    end
    local useCustomColors = self.db.displayStyle == DISPLAY_STYLE_SIMPLE_WITH_CUSTOM_DIFF;

    return useCustomColors and self.customColors[diff] or diff;
end

--- @class TalentTreeTweaks_TreeInMinimapContainerMixin
local containerMixin = {};
function containerMixin:Init()
    self.spacing = 20;
    self.dotSize = 12;
    self.expectedMaxRows = 10;
    self.expectedMaxCols = 23;

    self:SetSize(self.expectedMaxCols * self.spacing, self.expectedMaxRows * self.spacing);
    self:Hide();

    self.dotPool = CreateFramePool("FRAME", self);
    self.linePool = CreateObjectPool(
        function() return self:CreateLine(); end,
        function(_, line) line:Hide(); end
    );
end

function containerMixin:ApplyTexture(texture, visualStyle, diff)
    texture:SetTexture(TEXTURE_FILE);
    texture:SetVertexColor(1, 1, 1);

    local row = 1; -- yellow / default
    if type(diff) == 'table' then
    	row = 4; -- white
    	texture:SetVertexColor(diff.r, diff.g, diff.b);
    elseif diff == DIFF_DEFAULT_ORANGE then
        row = 5; -- orange
    elseif diff == DIFF_DEFAULT_YELLOW then
        row = 1; -- yellow
    elseif diff == DIFF_DEFAULT_RED then
        row = 2; -- red
    elseif diff == DIFF_DEFAULT_GREEN then
        row = 3; -- green
    end

    if diff and visualStyle == VISUAL_STYLE_EMPTY then
    	visualStyle = VISUAL_STYLE_FULL;
    end

    local col;
    if visualStyle == VISUAL_STYLE_TWO_THIRD then
        col = 1;
    elseif visualStyle == VISUAL_STYLE_HALF then
        col = 2;
    elseif visualStyle == VISUAL_STYLE_ONE_THIRD then
        col = 3;
    elseif visualStyle == VISUAL_STYLE_FULL then
        col = 4;
    elseif visualStyle == VISUAL_STYLE_EMPTY then
        -- special case
        col = 5;
        row = 1;
    end
    local factor = 66/512 -- texture file is 512x512, each orb is 64x64 + 2px spacing

    local rotation;
    if visualStyle == VISUAL_STYLE_LEFT then
        col = 2;
        rotation = 'left';
    elseif visualStyle == VISUAL_STYLE_RIGHT then
        col = 2;
        rotation = 'right';
    elseif visualStyle == VISUAL_STYLE_HALF_FLIPPED then
        col = 2;
        rotation = 'flip';
    end

    local left = (col - 1) * factor;
    local right = col * factor;
    local top = (row - 1) * factor;
    local bottom = row * factor;

    if not rotation then
        texture:SetTexCoord(left, right, top, bottom);
    elseif rotation == 'left' then
        texture:SetTexCoord(
            right, top, -- top left corner is top right of the image
            left, top, -- bottom left corner is top left of the image
            right, bottom, -- top right corner is bottom right of the image
            left, bottom -- bottom right corner is bottom left of the image
        )
    elseif rotation == 'right' then
        texture:SetTexCoord(
            right, bottom, -- top left corner is bottom right of the image
            left, bottom, -- bottom left corner is bottom left of the image
            right, top, -- top right corner is top right of the image
            left, top -- bottom right corner is top left of the image
        )
    elseif rotation == 'flip' then
        texture:SetTexCoord(
            left, bottom, -- top left corner is bottom left of the image
            left, top, -- bottom left corner is top left of the image
            right, bottom, -- top right corner is bottom right of the image
            right, top -- bottom right corner is top right of the image
        )
    end
end

function containerMixin:MakeDot(column, row, visualStyle, spellIcon, isAtlas, diff)
    local dot, isNew = self.dotPool:Acquire();
    if isNew then
        dot:SetSize(self.dotSize, self.dotSize);
        dot.texture = dot:CreateTexture(nil, "ARTWORK");
        dot.texture:SetAllPoints(dot);
    end
    dot:SetAlpha(1);
    dot:SetPoint("TOPLEFT", (column - 1) * self.spacing, -((row - 1) * self.spacing));

    if Module.db.displayStyle == DISPLAY_STYLE_SPELL_ICON then
        dot.texture:SetVertexColor(1, 1, 1);
        if isAtlas then
            dot.texture:SetTexCoord(0, 1, 0, 1);
            dot.texture:SetAtlas(spellIcon);
        else
            dot.texture:SetTexture(spellIcon);
            dot.texture:SetTexCoord(0, 1, 0, 1);
        end
        dot.texture:SetDesaturated(visualStyle == VISUAL_STYLE_EMPTY);
    else
        self:ApplyTexture(dot.texture, visualStyle, diff);
        dot.texture:SetDesaturated(false);
    end
    dot:Show();

    dot.isMaxed = visualStyle == VISUAL_STYLE_FULL or visualStyle == VISUAL_STYLE_LEFT or visualStyle == VISUAL_STYLE_RIGHT;

    return dot;
end

function containerMixin:MakeLine(dot1, dot2, isActive)
    local line, isNew = self.linePool:Acquire();
    if isNew then
        line:SetThickness(2);
    end
    local r, g, b = 0.26, 0.26, 0.26; -- #434343 - greyish
    if isActive then
        r, g, b = 1, 0.82, 0; -- #ffd100 -- yellow
    end
    local lineAlpha = isActive and 0.7 or 1;
    lineAlpha = lineAlpha * dot1:GetAlpha();
    line:SetAlpha(lineAlpha);
    line:SetColorTexture(r, g, b);
    line:SetStartPoint("CENTER", dot1);
    line:SetEndPoint("CENTER", dot2);
    line:Show();

    return line;
end

function containerMixin:ReleaseAllDots()
    self.dotPool:ReleaseAll();
end

function containerMixin:ReleaseAllLines()
    self.linePool:ReleaseAll();
end

function containerMixin:Reset()
    self:ReleaseAllLines();
    self:ReleaseAllDots();
    self:SetSize(self.expectedMaxCols * self.spacing, self.expectedMaxRows * self.spacing);
end

--- @return TalentTreeTweaks_TreeInMinimapContainerMixin
function Module:CreateContainer()
    --- @type TalentTreeTweaks_TreeInMinimapContainerMixin
    local container = CreateFrame("FRAME");
    Mixin(container, containerMixin);
    container:Init();

    return container;
end

--- @return TalentTreeTweaks_TreeInMinimapContainerMixin
function Module:GetOrCreateContainer(tooltip)
    if not self.containers[tooltip] then
        self.containers[tooltip] = self:CreateContainer();
    end

    return self.containers[tooltip];
end

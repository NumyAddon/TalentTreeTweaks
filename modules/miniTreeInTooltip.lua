local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local Module = Main:NewModule('MiniTreeInTooltip', 'AceHook-3.0');

--- @type LibTalentTree
local LTT = Util.LibTalentTree;

local VISUAL_STYLE_FULL = [[interface\addons\talenttreetweaks\media\mini-tree\full]]
local VISUAL_STYLE_EMPTY = [[interface\addons\talenttreetweaks\media\mini-tree\empty]]
local VISUAL_STYLE_HALF = [[interface\addons\talenttreetweaks\media\mini-tree\half]]
local VISUAL_STYLE_LEFT = [[interface\addons\talenttreetweaks\media\mini-tree\left]]
local VISUAL_STYLE_RIGHT = [[interface\addons\talenttreetweaks\media\mini-tree\right]]
local VISUAL_STYLE_ONE_THIRD = [[interface\addons\talenttreetweaks\media\mini-tree\one-third]]
local VISUAL_STYLE_TWO_THIRD = [[interface\addons\talenttreetweaks\media\mini-tree\two-third]]

local DISPLAY_STYLE_SIMPLE = "simple";
local DISPLAY_STYLE_SPELL_ICON = "spell_icon";

function Module:OnInitialize()
    self.debug = false;
end

function TalentTreeTweaks_EmbedMiniTreeIntoTooltip(tooltip, exportString, configID)
    if not exportString and configID then
        local ok, configInfo = pcall(C_Traits.GetConfigInfo, configID);
        if not ok or not configInfo then return; end
        return false -- not yet supported, WIP
        -- exportString = Util:GetLoadoutExportString(nil, configID);
    end
    Module:AddBuildToTooltip(tooltip, exportString);
end

function Module:OnEnable()
    for _, frameName in pairs(CHAT_FRAMES) do
        local frame = _G[frameName];
        self:SecureHookScript(frame, "OnHyperlinkEnter");
        self:SecureHookScript(frame, "OnHyperlinkLeave");
    end
    self:SecureHook(GameTooltip, "Show", "OnTooltipShow")

    if not self.container then
        self.container = self:CreateContainer();
    end

    Util:OnClassTalentUILoad(function()
        local talentsTab = ClassTalentFrame.TalentsTab;
        local dropdown = talentsTab.LoadoutDropDown;
        self:SecureHook(dropdown.DropDownControl, 'SetCustomSetup', 'HookCustomSetupCallback');
        self:HookCustomSetupCallback(dropdown.DropDownControl);
    end)

    EventUtil.ContinueOnAddOnLoaded("Blizzard_InspectUI", function()
        self:HookInspectTalentsButton();
    end)
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
        displayStyle = DISPLAY_STYLE_SIMPLE,
        scale = 1,
    }
    self.db = db;
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    local increment = CreateCounter(5);

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
        desc = L["Choose how the mini tree is displayed."],
        values = {
            [DISPLAY_STYLE_SIMPLE] = L["Simple dots"],
            [DISPLAY_STYLE_SPELL_ICON] = L["Spell Icon"],
        },
        get = getter,
        set = setter,
    }
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
    }
    --- @todo add options to show an example, using currently selected talents

    return defaultOptionsTable;
end

function Module:DebugPrint(...)
    if self.debug then
        print(...)
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
    local exportString = Util:GetLoadoutExportString(ClassTalentFrame.TalentsTab, configID);

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
    if (linkType == "garrmission" and part1 == "TalentTreeTweaks") then
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
        local classID = Util.specToClassMap[specID];
        local className, classFileName = GetClassInfo(classID);
        local classColor = RAID_CLASS_COLORS[classFileName];
        local specName = select(2, GetSpecializationInfoByID(specID));
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

    local container = self:GetOrCreateContainer();
    container:Reset();
    container:SetScale(self.db.scale);
    local containerWidth, containerHeight = container:GetSize();
    container:SetSize(containerWidth * self.db.scale, containerHeight * self.db.scale);

    local dots = {};

    --- @type TalentTreeTweaks_Util_LoadoutContent
    for _, nodeSelectionInfo in ipairs(nilOrLoadoutInfo) do
        local nodeID = nodeSelectionInfo.nodeID;
        if LTT:IsNodeVisibleForSpec(specID, nodeSelectionInfo.nodeID) then
            local column, row = LTT:GetNodeGridPosition(treeID, nodeID);
            if column and row then
                local nodeInfo = LTT:GetNodeInfo(treeID, nodeID);
                local style = VISUAL_STYLE_EMPTY;
                if (
                    (nodeSelectionInfo.isNodeSelected and not nodeSelectionInfo.isChoiceNode and not nodeSelectionInfo.isPartiallyRanked)
                    or LTT:IsNodeGrantedForSpec(specID, nodeID)
                ) then
                    style = VISUAL_STYLE_FULL;
                elseif nodeSelectionInfo.isPartiallyRanked then
                    local maxRanks = nodeInfo.maxRanks
                    if maxRanks == 2 then
                        style = VISUAL_STYLE_HALF;
                    elseif maxRanks == 3 and nodeSelectionInfo.partialRanksPurchased == 1 then
                        style = VISUAL_STYLE_ONE_THIRD;
                    elseif maxRanks == 3 and nodeSelectionInfo.partialRanksPurchased == 2 then
                        style = VISUAL_STYLE_TWO_THIRD;
                    end
                elseif nodeSelectionInfo.isChoiceNode and nodeSelectionInfo.isNodeSelected then
                    style = nodeSelectionInfo.choiceNodeSelection == 1 and VISUAL_STYLE_LEFT or VISUAL_STYLE_RIGHT;
                end
                local entryInfo = LTT:GetEntryInfo(nodeInfo.entryIDs[nodeSelectionInfo.choiceNodeSelection]);
                local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID);
                local spellID = definitionInfo.spellID;
                local spellIcon = select(8, GetSpellInfo(spellID));

                local dot = container:MakeDot(column, row, style, spellIcon);
                dots[nodeID] = dot;
            else
                self:DebugPrint('column and/or row not found for nodeID', nodeID)
            end
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

--- @class TalentTreeTweaks_TreeInMinimapContainerMixin
local containerMixin = {};
function containerMixin:Init()
    self.spacing = 20;
    self.dotSize = 12;
    self.expectedMaxRows = 10;
    self.expectedMaxCols = 20;

    self:SetSize(self.expectedMaxCols * self.spacing, self.expectedMaxRows * self.spacing);
    self:Hide();

    self.dotPool = CreateFramePool("FRAME", self);
    self.linePool = CreateObjectPool(
        function() return self:CreateLine(); end,
        function(_, line) line:Hide(); end
    );
end

function containerMixin:MakeDot(column, row, visualStyle, spellIcon)
    local dot, isNew = self.dotPool:Acquire();
    if isNew then
        dot:SetSize(self.dotSize, self.dotSize);
        dot.texture = dot:CreateTexture(nil, "ARTWORK");
        dot.texture:SetAllPoints(dot);
    end
    dot:SetPoint("TOPLEFT", (column - 1) * self.spacing, -((row - 1) * self.spacing));

    if Module.db.displayStyle == DISPLAY_STYLE_SIMPLE then
        dot.texture:SetTexture(visualStyle);
        dot.texture:SetDesaturated(false);
    elseif Module.db.displayStyle == DISPLAY_STYLE_SPELL_ICON then
        dot.texture:SetTexture(spellIcon);
        dot.texture:SetDesaturated(visualStyle == VISUAL_STYLE_EMPTY);
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
    line:SetAlpha(isActive and 0.7 or 1);
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
function Module:GetOrCreateContainer()
    if not self.container then
        self.container = self:CreateContainer();
    end

    return self.container;
end

local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;

local Module = Main:NewModule('MiniTreeInTooltip', 'AceHook-3.0');

local LTT = Util.LibTalentTree;

function Module:OnInitialize()
    self.debug = false;
end

function Module:OnEnable()
    for i = 1, NUM_CHAT_WINDOWS do
        local frame = _G["ChatFrame" .. i];
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
    return "Adds a mini tree in various tooltips for Talent Tree Builds"
end

function Module:GetName()
    return "Mini Tree in Tooltips";
end

function Module:GetOptions(defaultOptionsTable, db)
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
        self:DebugPrint('Error parsing exportString, message:', errorOrClassID);
    end
    local specID = falseOrSpecID;
    local classID = errorOrClassID;
    local treeID = LTT:GetClassTreeId(classID);

    local container = self:GetOrCreateContainer();
    container:Reset();

    local dots = {};

    --- @type TalentTreeTweaks_Util_LoadoutContent
    for _, nodeSelectionInfo in ipairs(nilOrLoadoutInfo) do
        local nodeID = nodeSelectionInfo.nodeID;
        if Util.LibTalentTree:IsNodeVisibleForSpec(specID, nodeSelectionInfo.nodeID) then
            local column, row = LTT:GetNodeGridPosition(treeID, nodeID);
            if column and row then
                local isActive = nodeSelectionInfo.isNodeSelected or LTT:IsNodeGrantedForSpec(specID, nodeID)
                local dot = container:MakeDot(column, row, isActive);
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
                container:MakeLine(dot, targetDot, dot.isActive);
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
    self.dotSize = 10;
    local expectedMaxRows = 10;
    local expectedMaxCols = 20;

    self:SetSize(expectedMaxCols * self.spacing, expectedMaxRows * self.spacing);
    self:Hide();

    self.dotPool = CreateFramePool("FRAME", self);
    self.linePool = CreateObjectPool(
        function() return self:CreateLine(); end,
        function(_, line) line:Hide(); end
    );
end

function containerMixin:MakeDot(column, row, isActive)
    local dot, isNew = self.dotPool:Acquire();
    if isNew then
        dot:SetSize(self.dotSize, self.dotSize);
        dot.texture = dot:CreateTexture(nil, "ARTWORK");
        dot.texture:SetAllPoints(dot);
        dot.texture:SetTexture("Interface\\Buttons\\WHITE8x8");
        dot.mask = dot:CreateMaskTexture();
        dot.mask:SetAllPoints(dot.texture);
        dot.mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE");
        dot.texture:AddMaskTexture(dot.mask);
    end
    dot:SetPoint("TOPLEFT", (column - 1) * self.spacing, -((row - 1) * self.spacing));
    local r, g, b = 0.26, 0.26, 0.26; -- #434343 - greyish
    if isActive then
        r, g, b = 1, 0.82, 0; -- #ffd100 -- yellow
    end
    dot.texture:SetVertexColor(r, g, b);
    dot:Show();

    dot.isActive = isActive;

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

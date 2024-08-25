local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

--- @class TalentTreeTweaks_HeroTalents: AceModule, AceHook-3.0
local Module = Main:NewModule('HeroTalents', 'AceHook-3.0');

local function RunScript(frame, script, ...)
    if frame and frame:GetScript(script) then
        frame:GetScript(script)(frame, ...);
    end
end

function Module:OnInitialize()
    local btn = CreateFrame('BUTTON');
    btn:RegisterForClicks('RightButtonDown');
    btn:RegisterForClicks('RightButtonUp');
    btn:SetPassThroughButtons('LeftButton');
    btn:SetPropagateMouseMotion(true);
    btn:SetScript('OnClick', function()
        local container = self:GetHeroContainer();
        if not container or not container.activeSubTreeSelectionNodeInfo or container:IsInspecting() then return; end
        self:ToggleHeroSpec();
        RunScript(btn:GetParent(), 'OnLeave');
        RunScript(btn:GetParent(), 'OnEnter');
    end);
    btn:Hide();
    self.heroTalentToggleButton = btn;
end

function Module:OnEnable()
    Util:OnTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    self.heroTalentToggleButton:Hide();
end

function Module:GetDescription()
    return
        L['Allows you to right-click the Hero Talent button to quickly switch hero specs.'];
end

function Module:GetName()
    return L['Hero Talents'];
end

function Module:GetOptions(defaultOptionsTable, db)
    return defaultOptionsTable;
end


function Module:SetupHook()
    local talentsTab = Util:GetTalentFrame();
    self:SetupHeroTalentToggleButton(talentsTab);
end

function Module:SetupHeroTalentToggleButton(talentsTab)
    local container = talentsTab and talentsTab.HeroTalentsContainer;
    local button = container and container.HeroSpecButton;
    local btn = self.heroTalentToggleButton;
    if button and btn then
        self:SecureHookScript(button, 'OnEnter', function()
            if
                not container.activeSubTreeSelectionNodeInfo
                or container:IsInspecting()
                or not self:GetTargetHeroSpec(container)
            then
                return;
            end
            if GameTooltip:GetOwner() ~= button or not GameTooltip:IsShown() then
                GameTooltip:SetOwner(button, 'ANCHOR_RIGHT');
            end
            GameTooltip:SetText(L['%s Switch to %s']:format(
                Util.RightClickAtlasMarkup,
                WHITE_FONT_COLOR:WrapTextInColorCode(self:GetTargetHeroSpecName(container))
            ));
            GameTooltip:Show();
        end);
        self:SecureHookScript(button, 'OnLeave', function()
            if GameTooltip:GetOwner() == button then
                GameTooltip:Hide();
            end
        end);
        btn:SetParent(button);
        btn:SetAllPoints();
        btn:Show();
    end
end

function Module:GetHeroContainer()
    local talentsTab = Util:GetTalentFrame();
    return talentsTab and talentsTab.HeroTalentsContainer;
end

function Module:ToggleHeroSpec()
    local container = self:GetHeroContainer();
    if not container then return; end

    local configID = C_ClassTalents.GetActiveConfigID();
    local nodeID, targetEntryID = self:GetTargetHeroSpec(container);
    if not nodeID or not targetEntryID or not configID then return; end

    C_Traits.SetSelection(configID, nodeID, targetEntryID);
end

--- @return number?, number?, TraitSubTreeInfo? # nodeID, targetEntryID, subTreeInfo; nil if something went wrong
function Module:GetTargetHeroSpec(container)
    local configID = C_ClassTalents.GetActiveConfigID();
    --- @type TraitNodeInfo
    local nodeInfo = container.activeSubTreeSelectionNodeInfo;
    if not nodeInfo or not configID then return; end

    local activeTreeID = C_ClassTalents.GetActiveHeroTalentSpec();
    local subTreeIDs = C_ClassTalents.GetHeroTalentSpecsForClassSpec(configID, Util:GetTalentFrame():GetSpecID());
    if not activeTreeID or not subTreeIDs then return; end

    local targetSubTreeID;
    for _, subTreeID in pairs(subTreeIDs) do
        if subTreeID ~= activeTreeID then
            targetSubTreeID = subTreeID;
            break;
        end
    end
    if not targetSubTreeID then return; end

    local targetEntryID;
    for _, entryID in ipairs(nodeInfo.entryIDs) do
        local entryInfo = C_Traits.GetEntryInfo(configID, entryID);
        if entryInfo and entryInfo.subTreeID == targetSubTreeID then
            targetEntryID = entryID;
            break;
        end
    end
    if not targetEntryID then return; end

    local subTreeInfo = C_Traits.GetSubTreeInfo(configID, targetSubTreeID);
    if not subTreeInfo then return; end

    return nodeInfo.ID, targetEntryID, subTreeInfo;
end

function Module:GetTargetHeroSpecName(container)
    local _, _, subTreeInfo = self:GetTargetHeroSpec(container);
    if not subTreeInfo then return ''; end

    return CreateAtlasMarkup(subTreeInfo.iconElementID, 16, 16) .. ' ' .. subTreeInfo.name;
end


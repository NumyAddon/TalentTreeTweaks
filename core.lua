local name = ...;
--- @class TTT_NS: NumyConfigNS
local ns = select(2, ...);

--@debug@
_G.TalentTreeTweaks = ns;
if not _G.TTT then _G.TTT = ns; end
--@end-debug@

--- @class TTT_Main: NumyConfig_AceAddon, AceConsole-3.0, AceHook-3.0, AceEvent-3.0
local Main = LibStub('AceAddon-3.0'):NewAddon(name, 'AceConsole-3.0', 'AceHook-3.0', 'AceEvent-3.0');
if not Main then return; end
ns.Main = Main;
ns.L = LibStub('AceLocale-3.0'):GetLocale(name);

function Main:OnInitialize()
    if NumyProfiler then
        NumyProfiler:WrapModules(name, 'Main', self);
        NumyProfiler:WrapModules(name, 'Util', ns.Util);
        for moduleName, module in self:IterateModules() do
            NumyProfiler:WrapModules(name, moduleName, module);
        end
    end

    TalentTreeTweaksDB = TalentTreeTweaksDB or {};
    self.db = TalentTreeTweaksDB;
    self.version = C_AddOns.GetAddOnMetadata(name, "Version") or "";
    self:InitDefaults();
    ns.Util:OnInitialize();
    for moduleName, module in self:IterateModules() do
        if self.db.modules[moduleName] == false then
            module:Disable();
        end
    end

    local Config = ns.Config;
    Config:Init("Talent Tree Tweaks", "TalentTreeTweaks", self.db, nil, ns.L, self, {
        "Skyriding Auto Purchaser",
        "Drive Auto Purchaser",
        "MiniTreeInTooltip",
        "InspectDiff",
        "ClickableExportStringsInChat",
        "ExportInspectedBuild",
        "RespecButtons",
        "AlwaysShowGates",
        "ChangeBackground",
        "TooltipIds",
        "ImportIntoCurrentLoadout",
        "ScaleTalentFrame",
        "HighlightCascadeRepurchable",
        "UnlockRestrictions",

        "CopyTalentButtonInfo",
        "ReduceSpam",
        "HeroTalents",
        "SearchForIds",

        "MiscFixes",
        "DebugNodeInfo",
        "ReduceTaint",
    });

    SLASH_TALENT_TREE_TWEAKS1 = '/ttt';
    SLASH_TALENT_TREE_TWEAKS2 = '/talenttreetweaks';
    SlashCmdList['TALENT_TREE_TWEAKS'] = function()
        ns.Config:OpenSettings();
    end
end

function Main:InitDefaults()
    local defaults = {
        modules = {},
        moduleDb = {},
    };

    for key, value in pairs(defaults) do
        if self.db[key] == nil then
            self.db[key] = value;
        end
    end
end

function Main:SetModuleState(moduleName, enabled)
    if enabled then
        self:EnableModule(moduleName);
    else
        self:DisableModule(moduleName);
    end
    self.db.modules[moduleName] = enabled;
end

function Main:IsModuleEnabled(moduleName)
    local module = self:GetModule(moduleName);

    return module and module:IsEnabled() or false;
end

function Main:IsTalentTreeViewerEnabled()
    return C_AddOns.GetAddOnEnableState(TalentViewerLoader and TalentViewerLoader:GetLodAddonName() or 'TalentTreeViewer', UnitName('player')) == 2;
end

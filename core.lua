local name, TTT = ...;

--@debug@
_G.TalentTreeTweaks = TTT;
if not _G.TTT then _G.TTT = TTT; end
--@end-debug@

--- @class TalentTreeTweaks_Main
local Main = LibStub('AceAddon-3.0'):NewAddon(name, 'AceConsole-3.0', 'AceHook-3.0', 'AceEvent-3.0');
if not Main then return; end
TTT.Main = Main;
TTT.L = LibStub('AceLocale-3.0'):GetLocale(name);
local L = TTT.L;

function Main:OnInitialize()
    if NumyProfiler then
        NumyProfiler:WrapModules(name, 'Main', self);
        NumyProfiler:WrapModules(name, 'Util', TTT.Util);
        for moduleName, module in self:IterateModules() do
            NumyProfiler:WrapModules(name, moduleName, module);
        end
    end

    TalentTreeTweaksDB = TalentTreeTweaksDB or {};
    self.db = TalentTreeTweaksDB;
    self.version = C_AddOns.GetAddOnMetadata(name, "Version") or "";
    self:InitDefaults();
    TTT.Util:OnInitialize();
    for moduleName, module in self:IterateModules() do
        --- @type TalentTreeTweaks_Module
        local module = module;
        if self.db.modules[moduleName] == false then
            module:Disable();
        end
    end

    self:InitConfig();

    self:RegisterChatCommand('ttt', function() self:OpenConfig(); end);
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

function Main:InitConfig()
    local count = 1;
    local function increment() count = count + 1; return count end;
    self.options = {
        type = 'group',
        name = 'Talent Tree Tweaks',
        desc = L['Various tweaks and improvements to the talent tree UI'],
        childGroups = 'tab',
        args = {
            version = {
                order = increment(),
                type = 'description',
                name = string.format(L['Version: %s'], self.version),
            },
            modules = {
                order = increment(),
                type = 'group',
                name = L['Modules'],
                childGroups = 'tree',
                args = {
                    desc = {
                        order = increment(),
                        type = 'description',
                        name = L['This addon consists of a number of modules, each of which can be enabled or disabled, to fine-tune your experience.'],
                    },
                },
            }
        }
    };
    local function GetFormattedModuleName(moduleName, disabledSuffix)
        --- @type TalentTreeTweaks_Module
        local module = self:GetModule(moduleName);

        local prettyName = module.GetName and module:GetName() or moduleName;
        if not self:IsModuleEnabled(moduleName) then
            return RED_FONT_COLOR:WrapTextInColorCode(prettyName .. (disabledSuffix or ''));
        end
        return prettyName;
    end

    local defaultModuleOptions = {
        type = 'group',
        name = function(info)
            local moduleName = info[#info];
            return GetFormattedModuleName(moduleName);
        end,
        desc = function(info)
            local moduleName = info[#info];
            if not self:IsModuleEnabled(moduleName) then
                return RED_FONT_COLOR:WrapTextInColorCode(ADDON_DISABLED);
            end
        end,
        args = {
            name = {
                order = 1,
                type = 'header',
                name = function(info)
                    local moduleName = info[#info - 1];
                    return GetFormattedModuleName(moduleName);
                end,
            },
            description = {
                order = 2,
                type = 'description',
                name = function(info)
                    --- @type TalentTreeTweaks_Module
                    local module = self:GetModule(info[#info - 1]);
                    return module.GetDescription and module:GetDescription() or '';
                end,
                hidden = function(info)
                    return '' == info.option.name(info)
                end,
            },
            enable = {
                order = 3,
                name = ENABLE,
                desc = L['Enable this module'],
                type = 'toggle',
                get = function(info) return self:IsModuleEnabled(info[#info - 1]); end,
                set = function(info, enabled) self:SetModuleState(info[#info - 1], enabled); end,
            },
        },
    };
    for moduleName, module in self:IterateModules() do
        --- @type TalentTreeTweaks_Module
        local module = module;
        local copy = CopyTable(defaultModuleOptions);
        self.db.moduleDb[moduleName] = self.db.moduleDb[moduleName] or {};
        local moduleOptions = module.GetOptions and module:GetOptions(copy, self.db.moduleDb[moduleName]) or copy;
        moduleOptions.order = increment();
        self.options.args.modules.args[moduleName] = moduleOptions;
    end

    self.configCategory = 'Talent Tree Tweaks';
    LibStub('AceConfig-3.0'):RegisterOptionsTable(self.configCategory, self.options);
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(self.configCategory);
end

function Main:OpenConfig()
    Settings.OpenToCategory(self.configCategory);
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
    return GetAddOnEnableState(UnitName('player'), 'TalentTreeViewer') == 2;
end

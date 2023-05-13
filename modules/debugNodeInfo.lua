local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
local L = TTT.L;

local Module = Main:NewModule('DebugNodeInfo');

function Module:OnEnable()
    EventRegistry:RegisterCallback('TalentButton.OnClick', self.OnButtonClick, self);
end

function Module:OnDisable()
    EventRegistry:UnregisterCallback('TalentButton.OnClick', self);
end

function Module:GetDescription()
    return L['CTRL-clicking a talent will open a table inspector of your choice, with the nodeInfo associated with the node.'];
end

function Module:GetName()
    return L['Debug Talent.nodeInfo'];
end

function Module:GetOptions(defaultOptionsTable, db)
    local defaultDb = {
        tinspect = true,
        viragDevTool = true,
        luaBrowser = true,
        slashDump = false,
        addButtonToTable = true,
    }
    self.db = db;
    for k, v in pairs(defaultDb) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    local set = function(info, value)
        self.db[info[#info]] = value;
    end;
    local get = function(info)
        return self.db[info[#info]];
    end;
    local order = 5;
    local function increment() order = order + 1; return order; end;

    defaultOptionsTable.args.extraDescription = {
        type = 'description',
        name = L['You can toggle any of the following on/off to enable/disable the integration with that debug tool.'],
        order = increment(),
    };
    defaultOptionsTable.args.addButtonToTable = {
        type = 'toggle',
        name = L['Add the button to NodeInfo table when dumped'],
        desc = L['Adds a _button property to the nodeInfo table, which is a reference to the talent button.'],
        get = get,
        set = set,
        order = increment(),
    };
    defaultOptionsTable.args.tinspect = {
        type = 'toggle',
        name = '/tinspect',
        desc = L['Opens Blizzard\'s table inspect window.'],
        get = get,
        set = set,
        order = increment(),
    };
    defaultOptionsTable.args.viragDevTool = {
        type = 'toggle',
        name = '(Virag-)DevTool',
        desc = L['Use (Virag-)DevTool to inspect the nodeInfo table.'],
        get = get,
        set = set,
        disabled = not select(4, GetAddOnInfo('ViragDevTool')) and not select(4, GetAddOnInfo('DevTool')), -- 4-> loadable
        order = increment(),
    };
    defaultOptionsTable.args.luaBrowser = {
        type = 'toggle',
        name = 'LuaBrowser',
        desc = L['Use LuaBrowser to inspect the nodeInfo table.'],
        get = get,
        set = set,
        disabled = not select(4, GetAddOnInfo('LuaBrowser')), -- 4-> loadable
        order = increment(),
    };
    defaultOptionsTable.args.slashDump = {
        type = 'toggle',
        name = '/dump',
        desc = L['Dump the nodeInfo table to chat.'],
        get = get,
        set = set,
        order = increment(),
    };

    return defaultOptionsTable;
end

function Module:OnButtonClick(buttonFrame, mouseButton)
    if mouseButton ~= 'LeftButton' or not IsControlKeyDown() then
        return;
    end
    local nodeInfo = buttonFrame.nodeInfo or buttonFrame.GetNodeInfo and buttonFrame:GetNodeInfo() or {};
    if self.db.addButtonToTable then
        nodeInfo = Mixin({}, nodeInfo);
        nodeInfo._button = buttonFrame;
    end

    if self.db.tinspect then
        UIParentLoadAddOn("Blizzard_DebugTools");
        DisplayTableInspectorWindow(nodeInfo);
    end

    if self.db.viragDevTool and ViragDevTool_AddData then
        ViragDevTool_AddData(nodeInfo, 'NodeInfo ID ' .. (nodeInfo.ID or 'nil'));
    end
    if self.db.viragDevTool and DevTool and DevTool.AddData then
        DevTool:AddData(nodeInfo, 'NodeInfo ID ' .. (nodeInfo.ID or 'nil'));
    end

    if self.db.luaBrowser and SlashCmdList.LuaBrowser then
        _G['TalentTreeTweaksDebugNodeInfo'] = nodeInfo;
        SlashCmdList.LuaBrowser('code TalentTreeTweaksDebugNodeInfo');
    end

    if self.db.slashDump then
        DevTools_Dump(nodeInfo, 'value');
    end
end

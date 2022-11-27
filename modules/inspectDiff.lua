local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;

local Module = Main:NewModule('InspectDiff', 'AceHook-3.0');

function Module:OnEnable()
    self.buttonTextures = self.buttonTextures or {};
    EventUtil.ContinueOnAddOnLoaded('Blizzard_ClassTalentUI', function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll();
    if(self.buttonTextures) then
        for _, texture in pairs(self.buttonTextures) do
            texture:Hide();
        end
    end
end

function Module:GetDescription()
    return 'Shows the difference between your talent choices, and the inspected player\'s talent choices.';
end

function Module:GetName()
    return 'Inspect Diff';
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;

    local defaults = {
        colorGreen = {
            r = 0,
            g = 1,
            b = 0.3,
            a = 0.58,
        },
        colorRed = {
            r = 1,
            g = 0,
            b = 0,
            a = 0.5,
        },
        colorYellow = {
            r = 1,
            g = 0.67,
            b = 0,
            a = 0.75,
        },
    }
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    local function GetColor(info)
        local color = self.db[info[#info]];
        return color.r, color.g, color.b, color.a;
    end
    local function SetColor(info, r, g, b, a)
        local color = self.db[info[#info]];
        color.r, color.g, color.b, color.a = r, g, b, a;
        self:UpdateColors();
    end
    defaultOptionsTable.args.colorRed = {
        type = 'color',
        name = 'You have a talent they don\'t',
        hasAlpha = true,
        get = GetColor,
        set = SetColor,
        order = 5,
    };
    defaultOptionsTable.args.colorGreen = {
        type = 'color',
        name = 'They have a talent you don\'t',
        hasAlpha = true,
        get = GetColor,
        set = SetColor,
        order = 6,
    };
    defaultOptionsTable.args.colorYellow = {
        type = 'color',
        name = 'You have selected a different choice, or different number of points in a talent',
        hasAlpha = true,
        get = GetColor,
        set = SetColor,
        order = 7,
    };
    defaultOptionsTable.args.reset = {
        type = 'execute',
        name = 'Reset',
        desc = 'Reset the colors to default',
        func = function()
            self.db.colorRed = defaults.colorRed;
            self.db.colorGreen = defaults.colorGreen;
            self.db.colorYellow = defaults.colorYellow;
            self:UpdateColors();
        end,
        order = 10,
    };

    return defaultOptionsTable;
end

function Module:SetupHook()
    self:SecureHook(ClassTalentFrame.TalentsTab, 'UpdateInspecting');
    self:UpdateInspecting();

    self:SecureHook(ClassTalentFrame.TalentsTab, 'ShowSelections');

    ClassTalentFrame.TalentsTab:RegisterCallback(TalentFrameBaseMixin.Event.TalentButtonAcquired, self.OnTalentButtonAcquired, self);
    for talentButton in ClassTalentFrame.TalentsTab:EnumerateAllTalentButtons() do
        self:OnTalentButtonAcquired(talentButton);
    end
end

function Module:UpdateInspecting()
    local talentsTab = ClassTalentFrame.TalentsTab;

    self.isInspectingSameSpec = talentsTab:IsInspecting() and talentsTab:GetSpecID() == PlayerUtil.GetCurrentSpecID();

    self:UpdateColors();
end

function Module:ShowSelections()
    for _, button in pairs(ClassTalentFrame.TalentsTab.SelectionChoiceFrame.selectionFrameArray) do
        self:OnTalentButtonAcquired(button);
    end
end

function Module:OnTalentButtonAcquired(button)
    if not self.buttonTextures[button] then
        self.buttonTextures[button] = button:CreateTexture(nil, 'OVERLAY')
        local texture = self.buttonTextures[button];
        texture:SetAllPoints(button);
        texture:SetTexture('Interface/Tooltips/UI-Tooltip-Background');
        texture:SetVertexColor(self.db.colorRed.r, self.db.colorRed.g, self.db.colorRed.b, self.db.colorRed.a);
        texture:AddMaskTexture(button.IconMask);
        texture:Hide();
    end

    self:SetButtonState(button);
end

function Module:UpdateColors()
    for button, _ in pairs(self.buttonTextures) do
        self:SetButtonState(button);
    end
end

function Module:SetButtonState(button)
    local texture = self.buttonTextures[button];
    if not texture then return; end
    if not self.isInspectingSameSpec then
        texture:Hide();
        return;
    end

    local isChoiceButton = not not button.selectionIndex

    local colorToUse
    local inspectNodeInfo = button.nodeInfo or button.GetNodeInfo and button:GetNodeInfo() or {};
    local inspectEntry = inspectNodeInfo and inspectNodeInfo.activeEntry and inspectNodeInfo.activeEntry.entryID;
    local inspectRank = inspectNodeInfo and inspectNodeInfo.activeEntry and inspectNodeInfo.activeEntry.rank or 0;

    local selfNodeInfo = C_Traits.GetNodeInfo(C_ClassTalents.GetActiveConfigID(), inspectNodeInfo.ID);
    local selfEntry = selfNodeInfo and selfNodeInfo.activeEntry and selfNodeInfo.activeEntry.entryID;
    local selfRank = selfNodeInfo and selfNodeInfo.activeEntry and selfNodeInfo.activeEntry.rank or 0;

    if inspectEntry and selfEntry and inspectEntry == selfEntry then
        if inspectRank == selfRank then
            colorToUse = nil;
        elseif inspectRank ~= 0 and selfRank ~= 0 then
            colorToUse = self.db.colorYellow; -- same entry, different rank
        elseif inspectRank == 0 then
            colorToUse = self.db.colorRed; -- inspect has entry, self doesn't
        elseif selfRank == 0 then
            colorToUse = self.db.colorGreen; -- self has entry, inspect doesn't
        end
    else
        local buttonEntryID = button.entryID;
        if inspectRank ~= 0 and selfRank ~= 0 then -- both have entries, but different
            if not isChoiceButton then
                colorToUse = self.db.colorYellow; -- different entry, base button
            else
                if buttonEntryID == inspectEntry then
                    colorToUse = self.db.colorGreen; -- specific button, inspect has entry, self doesn't
                else
                    colorToUse = self.db.colorRed; -- specific button, inspect doesn't have entry, self does
                end
            end
        else -- one or both don't have entries
            if ((inspectRank == 0 and selfRank == 0) or (buttonEntryID ~= inspectEntry and buttonEntryID ~= selfEntry)) then
                colorToUse = nil; -- neither has entry
            elseif inspectRank == 0 then
                colorToUse = self.db.colorRed; -- inspect doesn't have entry, self does
            elseif selfRank == 0 then
                colorToUse = self.db.colorGreen; -- self has entry, inspect doesn't
            end
        end
    end
    if not colorToUse then
        texture:Hide();
    else
        texture:SetVertexColor(colorToUse.r, colorToUse.g, colorToUse.b, colorToUse.a);
        texture:Show();
    end
end

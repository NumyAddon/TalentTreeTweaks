local _, TTT = ...;
--- @type TalentTreeTweaks_Main
local Main = TTT.Main;
--- @type TalentTreeTweaks_Util
local Util = TTT.Util;
local L = TTT.L;

local Module = Main:NewModule('ImportIntoCurrentLoadout', 'AceHook-3.0');

local LOADOUT_SERIALIZATION_VERSION;
function Module:OnInitialize()
    LOADOUT_SERIALIZATION_VERSION = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or 1;

    StaticPopupDialogs["TALENT_TREE_TWEAKS_LOADOUT_IMPORT_ERROR_DIALOG"] = {
        text = "%s",
        button1 = OKAY,
        button2 = nil,
        timeout = 0,
        OnAccept = function() end,
        OnCancel = function() end,
        whileDead = 1,
        hideOnEscape = 1,
    };
end

function Module:OnEnable()
    Util:OnClassTalentUILoad(function()
        self:SetupHook();
    end);
end

function Module:OnDisable()
    self:UnhookAll()
    if self.checkbox then
        self.checkbox:Hide();
        ClassTalentLoadoutImportDialog.NameControl:SetShown(true);
        ClassTalentLoadoutImportDialog:UpdateAcceptButtonEnabledState();
    end
end

function Module:GetDescription()
    return L['Allows you to import talent loadouts into the currently selected loadout.'];
end

function Module:GetName()
    return L['Import into current loadout'];
end

function Module:GetOptions(defaultOptionsTable, db)
    self.db = db;
    local defaults = {
        defaultCheckboxState = false,
        unlockImportButton = true,
    };
    for k, v in pairs(defaults) do
        if db[k] == nil then
            db[k] = v;
        end
    end

    defaultOptionsTable.args.defaultCheckboxState = {
        type = 'toggle',
        name = L['Import into current loadout by default'],
        desc = L['When enabled, the "Import into current loadout" checkbox will be checked by default.'],
        width = 'double',
        get = function() return db.defaultCheckboxState; end,
        set = function(_, value)
            db.defaultCheckboxState = value;
            if self.checkbox then
                self.checkbox:SetChecked(value);
                self:OnCheckboxClick(self.checkbox);
            end
        end,
    };
    defaultOptionsTable.args.unlockImportButton = {
        type = 'toggle',
        name = L['Unlocks the import button, even if at max loadouts'],
        desc = L['When enabled, the import button will be unlocked even if you have reached the maximum number of loadouts. Since you can still import into your current loadout'],
        width = 'double',
        get = function() return db.unlockImportButton; end,
        set = function(_, value)
            db.unlockImportButton = value;
            if self.checkbox then
                self:OnUnlockImportButtonValueChanged();
            end
        end,
    };

    return defaultOptionsTable;
end

function Module:SetupHook()
    local dialog = ClassTalentLoadoutImportDialog;
    self:CreateCheckbox(dialog);
    self:CreateAcceptButton(dialog);
    self.checkbox:SetChecked(self.db.defaultCheckboxState);
    self:OnCheckboxClick(self.checkbox);

    self.disabledCallback = function() return false; end;
    self:OnUnlockImportButtonValueChanged();
end

function Module:OnUnlockImportButtonValueChanged()
    local dropdown = ClassTalentFrame.TalentsTab.LoadoutDropDown;
    for _, sentinelInfo in pairs(dropdown.sentinelKeyToInfo) do
        if sentinelInfo.text == TALENT_FRAME_DROP_DOWN_IMPORT then
            if not self.oldDisabledCallback then
                self.oldDisabledCallback = sentinelInfo.disabledCallback;
            end
            if self.db.unlockImportButton then
                sentinelInfo.disabledCallback = self.disabledCallback;
            elseif sentinelInfo.disabledCallback ~= self.oldDisabledCallback then
                sentinelInfo.disabledCallback = self.oldDisabledCallback;
            end
            break;
        end
    end
end

function Module:OnCheckboxClick(checkbox)
    local dialog = checkbox:GetParent();
    dialog.NameControl:SetShown(not checkbox:GetChecked());
    dialog.NameControl:SetText(checkbox:GetChecked() and 'TalentTreeTweaks' or '');
    self.acceptButton:SetShown(checkbox:GetChecked());
    dialog.AcceptButton:SetShown(not checkbox:GetChecked());
    if checkbox:GetChecked() then
        self.acceptButton:SetEnabled(dialog.ImportControl:HasText());
    else
        dialog:UpdateAcceptButtonEnabledState();
    end
end

function Module:CreateCheckbox(dialog)
    if self.checkbox then
        self.checkbox:Show();
        return
    end

    local text = string.format(L['Import into current loadout (click "%s" afterwards)'], TALENT_FRAME_APPLY_BUTTON_TEXT);
    local checkbox = CreateFrame('CheckButton', nil, dialog, 'UICheckButtonTemplate');
    checkbox:SetPoint('TOPLEFT', dialog.NameControl, 'BOTTOMLEFT', 0, 5);
    checkbox:SetSize(24, 24);
    checkbox:SetScript('OnClick', function(cb) self:OnCheckboxClick(cb); end);
    checkbox:SetScript('OnEnter', function(self)
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT');
        GameTooltip:SetText(text);
        GameTooltip:AddLine(L['If checked, the imported build will be imported into the currently selected loadout.'], 1, 1, 1);
        GameTooltip:Show();
    end);
    checkbox:SetScript('OnLeave', function()
        GameTooltip:Hide();
    end);
    checkbox.text = checkbox:CreateFontString(nil, 'ARTWORK', 'GameFontNormal');
    checkbox.text:SetPoint('LEFT', checkbox, 'RIGHT', 0, 1);
    checkbox.text:SetText(text);
    checkbox:SetHitRectInsets(-10, -checkbox.text:GetStringWidth(), -5, 0);

    self.checkbox = checkbox;
end

function Module:CreateAcceptButton(dialog)
    self:SecureHook(dialog, 'OnTextChanged', function() self.acceptButton:SetEnabled(dialog.ImportControl:HasText()); end)
    if self.acceptButton then
        self.acceptButton:Show();
        return
    end

    local acceptButton = CreateFrame('Button', nil, dialog, 'ClassTalentLoadoutDialogButtonTemplate');
    acceptButton:SetPoint('BOTTOMRIGHT', dialog.ContentArea, 'BOTTOM', -5, 0);
    acceptButton:SetText(HUD_CLASS_TALENTS_IMPORT_LOADOUT_ACCEPT_BUTTON);
    acceptButton.disabledTooltip = HUD_CLASS_TALENTS_IMPORT_ERROR_IMPORT_STRING_AND_NAME;
    acceptButton:SetScript('OnClick', function()
        local importString = dialog.ImportControl:GetText();
        if self:ImportLoadout(importString) then
            ClassTalentLoadoutImportDialog:OnCancel();
        end
    end);

    self.acceptButton = acceptButton;
end

function Module:GetTreeID()
    local configInfo = C_Traits.GetConfigInfo(C_ClassTalents.GetActiveConfigID());

    return configInfo and configInfo.treeIDs and configInfo.treeIDs[1];
end

function Module:PurchaseLoadoutEntryInfo(configID, loadoutEntryInfo)
    local removed = 0
    for i, nodeEntry in pairs(loadoutEntryInfo) do
        local success = false
        if nodeEntry.selectionEntryID then
            success = C_Traits.SetSelection(configID, nodeEntry.nodeID, nodeEntry.selectionEntryID);
        elseif nodeEntry.ranksPurchased then
            for rank = 1, nodeEntry.ranksPurchased do
                success = C_Traits.PurchaseRank(configID, nodeEntry.nodeID);
            end
        end
        if success then
            removed = removed + 1
            loadoutEntryInfo[i] = nil
        end
    end

    return removed
end

function Module:DoImport(loadoutEntryInfo)
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
        return false;
    end
    C_Traits.ResetTree(configID, self:GetTreeID());
    while(true) do
        local removed = self:PurchaseLoadoutEntryInfo(configID, loadoutEntryInfo);
        if(removed == 0) then
            break;
        end
    end

    --[[
    don't apply changes, the talent tree UI just... doesn't like it :( the user will just have to do this themselves
    it will result in taint if we simulate a click on the "Apply" button, and making a secure click, using the click
    from the "Import" button, is just way more effort than it's worth
    --]]

    return true;
end


----- copied and adapted from Blizzard_ClassTalentImportExport.lua -----
function Module:ShowImportError(errorString)
    StaticPopup_Show("TALENT_TREE_TWEAKS_LOADOUT_IMPORT_ERROR_DIALOG", errorString);
end

function Module:ImportLoadout(importText)
    local ImportExportMixin = ClassTalentImportExportMixin;

    local importStream = ExportUtil.MakeImportDataStream(importText);

    local headerValid, serializationVersion, specID, treeHash = ImportExportMixin:ReadLoadoutHeader(importStream);

    if(not headerValid) then
        self:ShowImportError(LOADOUT_ERROR_BAD_STRING);
        return false;
    end

    if(serializationVersion ~= LOADOUT_SERIALIZATION_VERSION) then
        self:ShowImportError(LOADOUT_ERROR_SERIALIZATION_VERSION_MISMATCH);
        return false;
    end

    if(specID ~= PlayerUtil.GetCurrentSpecID()) then
        self:ShowImportError(LOADOUT_ERROR_WRONG_SPEC);
        return false;
    end

    local treeID = self:GetTreeID();
    if not ImportExportMixin:IsHashEmpty(treeHash) then
        -- allow third-party sites to generate loadout strings with an empty tree hash, which bypasses hash validation
        if not ImportExportMixin:HashEquals(treeHash, C_Traits.GetTreeHash(treeID)) then
            self:ShowImportError(LOADOUT_ERROR_TREE_CHANGED);
            return false;
        end
    end

    local loadoutContent = ImportExportMixin:ReadLoadoutContent(importStream, treeID);
    local loadoutEntryInfo = self:ConvertToImportLoadoutEntryInfo(treeID, loadoutContent);

    return self:DoImport(loadoutEntryInfo);
end

-- converts from compact bit-packing format to LoadoutEntryInfo format to pass to ImportLoadout API
function Module:ConvertToImportLoadoutEntryInfo(treeID, loadoutContent)
    local results = {};
    local treeNodes = C_Traits.GetTreeNodes(treeID);
    local configID = C_ClassTalents.GetActiveConfigID();
    local count = 1;
    for i, treeNodeID in ipairs(treeNodes) do

        local indexInfo = loadoutContent[i];

        if (indexInfo.isNodeSelected) then
            local treeNode = C_Traits.GetNodeInfo(configID, treeNodeID);
            local isChoiceNode = treeNode.type == Enum.TraitNodeType.Selection;
            local choiceNodeSelection = indexInfo.isChoiceNode and indexInfo.choiceNodeSelection or nil;
            if indexInfo.isNodeSelected and isChoiceNode ~= indexInfo.isChoiceNode then
                -- guard against corrupt import strings
                print(string.format(L["Import string is corrupt, node type mismatch at nodeID %d. First option will be selected."], treeNodeID));
                choiceNodeSelection = 1;
            end
            local result = {};
            result.nodeID = treeNode.ID;
            result.ranksPurchased = indexInfo.isPartiallyRanked and indexInfo.partialRanksPurchased or treeNode.maxRanks;
            -- minor change from default UI, only add in case of choice nodes
            result.selectionEntryID = indexInfo.isNodeSelected and isChoiceNode and treeNode.entryIDs[choiceNodeSelection] or nil;
            results[count] = result;
            count = count + 1;
        end

    end

    return results;
end

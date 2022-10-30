--- @class TalentTreeTweaks_Module
local Module = {};

function Module:Enable()
    -- defined in AceAddon
end

function Module:Disable()
    -- defined in AceAddon
end

function Module:OnInitialize() end

function Module:OnEnable() end

function Module:OnDisable() end

--- @return string # The description of the module. Will be displayed in the options.
function Module:GetDescription() end

--- @return string # The short name of the module. Will be used as option header.
function Module:GetName() end

--- @param defaultOptionsTable table # The default module options table.
--- @param db table # The module's private database.
--- @return table # Options table with any module specific options added in
function Module:GetOptions(defaultOptionsTable, db) end


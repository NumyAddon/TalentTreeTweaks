--- @meta _

--- @class TTT_Util_LoadoutContent
--- @field isNodeSelected boolean
--- @field isNodeGranted boolean|nil # only present in V2
--- @field isPartiallyRanked boolean
--- @field partialRanksPurchased number
--- @field isChoiceNode boolean
--- @field choiceNodeSelection number
--- @field nodeID number

--- @class TTT_ColorSwatchButton: Button, ColorSwatchTemplate

--- @class TTT_Config_ColorControlMixin : SettingsListElementTemplate, SettingsControlMixin
--- @field ColorSwatch TTT_ColorSwatchButton
--- @field data TTT_Config_SettingData

--- @class TTT_Config_ButtonControlMixin : SettingsListElementTemplate
--- @field Button UIPanelButtonTemplate
--- @field data TTT_Config_ButtonSettingData

--- @class TTT_Config_ButtonSettingData
--- @field name string
--- @field tooltip string
--- @field buttonText string
--- @field OnButtonClick fun(button: Button)

--- @class TTT_Config_DoubleButtonControlMixin : SettingsListElementTemplate
--- @field Button1 UIPanelButtonTemplate
--- @field Button2 UIPanelButtonTemplate
--- @field data TTT_Config_DoubleButtonSettingData

--- @class TTT_Config_DoubleButtonSettingData
--- @field name string
--- @field tooltip string
--- @field button1Text string
--- @field button2Text string
--- @field OnButtonClick fun(buttonIndex: number)

--- @class TTT_Config_TextMixin: Frame, DefaultTooltipMixin
--- @field Text FontString

--- @class TTT_Config_SettingData
--- @field setting AddOnSettingMixin
--- @field name string
--- @field options table
--- @field tooltip string

--- @class TTT_Config_SliderOptions: SettingsSliderOptionsMixin
--- @field minValue number
--- @field maxValue number
--- @field steps number

--- @param minValue number? # Minimum value (default: 0)
--- @param maxValue number? # Maximum value (default: 1)
--- @param rate number? # Size between steps; Defaults to 100 steps
--- @return TTT_Config_SliderOptions
function Settings.CreateSliderOptions(minValue, maxValue, rate) end

--- @alias TTT_Config_DropDownOptions { text: string, label: string?, tooltip: string?, value: any }[]

--- @class TTT_Module: AceAddon
local Module = {};

--- @return string # The description of the module. Will be displayed in the options
function Module:GetDescription() end

--- @return string # The short name of the module. Will be used as option header
function Module:GetName() end

--- @param configBuilder TTT_ConfigBuilder
--- @param db table # The module's private database
function Module:BuildConfig(configBuilder, db) end

--- @param defaultOptionsTable table # The default module options table
--- @param db table # The module's private database
--- @return table # Options table with any module specific options added in
function Module:GetOptions(defaultOptionsTable, db) end

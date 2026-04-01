--- @meta _

--- @class NumyConfig_ColorSwatchButton: Button, ColorSwatchTemplate

--- @class NumyConfig_ColorControlMixin : SettingsListElementTemplate, SettingsControlMixin
--- @field ColorSwatch NumyConfig_ColorSwatchButton
--- @field data NumyConfig_SettingData

--- @class NumyConfig_InputControlMixin : SettingsListElementTemplate, SettingsControlMixin
--- @field InputBox InputBoxTemplate
--- @field OkayButton Button
--- @field data NumyConfig_SettingData

--- @class NumyConfig_ButtonControlMixin : SettingsListElementTemplate
--- @field Button UIPanelButtonTemplate
--- @field data NumyConfig_ButtonSettingData

--- @class NumyConfig_ButtonSettingData
--- @field name string
--- @field tooltip string
--- @field buttonText string
--- @field OnButtonClick fun(button: Button)

--- @class NumyConfig_MultiButtonControlMixin : SettingsListElementTemplate
--- @field ButtonContainer NumyConfig_MultiButton_ButtonContainer
--- @field data NumyConfig_MultiButtonSettingData

--- @class NumyConfig_MultiButton_ButtonContainer
--- @field buttonPool FramePool<UIPanelButtonTemplate>
--- @field plainButtonPool FramePool<Button>

--- @class NumyConfig_MultiButtonSettingData
--- @field name string
--- @field tooltip string
--- @field buttonTexts table<number, string|{atlas: string}|{texture: string}>
--- @field OnButtonClick fun(button: Button, buttonIndex: number)

--- @class NumyConfig_SoundSelectorMixin: SettingsDropdownControlTemplate
--- @field PreviewIcon Button

--- @class NumyConfig_ExpandSettingData
--- @field name string
--- @field nameGetter fun(): string
--- @field tooltip string?
--- @field checkboxTooltip string?
--- @field expanded boolean
--- @field setting AddOnSettingMixin?

--- @class NumyConfig_ExpandMixin: EventFrame
--- @field Button NumyConfig_Expand_Button
--- @field Tooltip DefaultTooltipMixin

--- @class NumyConfig_Expand_Button: Button
--- @field Left Texture
--- @field Right Texture
--- @field Text FontString
--- @field Checkbox NumyConfig_Expand_Checkbox

--- @class NumyConfig_Expand_Checkbox: CheckButton, SettingsCheckboxMixin

--- @class NumyConfig_TextMixin: Frame, DefaultTooltipMixin
--- @field Text FontString

--- @class NumyConfig_HeaderMixin: Frame, DefaultTooltipMixin
--- @field Title FontString

--- @class NumyConfig_SoundData: NumyConfig_SettingData
--- @field playSoundCallback fun(sound: string)
--- @field options fun(): NumyConfig_DropDownOptions

--- @class NumyConfig_SettingData
--- @field setting AddOnSettingMixin
--- @field name string
--- @field options table
--- @field tooltip string

--- @class NumyConfig_SliderOptions: SettingsSliderOptionsMixin
--- @field minValue number
--- @field maxValue number
--- @field steps number

--- @param minValue number? # Minimum value (default: 0)
--- @param maxValue number? # Maximum value (default: 1)
--- @param rate number? # Size between steps; Defaults to 100 steps
--- @return NumyConfig_SliderOptions
function Settings.CreateSliderOptions(minValue, maxValue, rate) end

--- @alias NumyConfig_DropDownOptions table<number, string|{ text: string, label: string?, tooltip: string?, value: any }>

-------------------------------------------------------------
--- @class NumyConfig_AceAddon: AceAddon
local NumyConfig_AceAddon = {}

---@param name string
---@param ... string List of libraries to embed into the addon
--- @return NumyConfig_Module
function NumyConfig_AceAddon:NewModule(name, ...) end

---@return fun(table: table<string, NumyConfig_Module>, index?: string): string, NumyConfig_Module iterator
---@return table<string, NumyConfig_Module> table # moduleName -> module
function NumyConfig_AceAddon:IterateModules() end

--- @class NumyConfig_Module: AceAddon
--- @field BuildConfig nil|fun(self: NumyConfig_Module, configBuilder: NumyConfigBuilder, db: table) # db = the module's private database
local Module = {};

Module.NewModule = NumyConfig_AceAddon.NewModule;
Module.IterateModules = NumyConfig_AceAddon.IterateModules;

--- @return string # The description of the module. Will be displayed in the options
function Module:GetDescription() end

--- @return string # The short name of the module. Will be used as option header
function Module:GetName() end

--- @return SettingsCategoryMixin category
--- @return SettingsVerticalLayoutMixin layout
function Settings.RegisterVerticalLayoutCategory(name) end


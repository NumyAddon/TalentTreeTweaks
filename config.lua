local name = ...;
--- @class TTT_NS
local ns = select(2, ...);

--- @class TTT_Config
local Config = {}
ns.Config = Config;

local L = ns.L;

local settingPrefix = "Talent Tree Tweaks ";

local PAYPAL_TEXTURE = "|TInterface\\AddOns\\TalentTreeTweaks\\media\\paypal.tga:18|t";
local COFFEE_TEXTURE = "|TInterface\\AddOns\\TalentTreeTweaks\\media\\coffee.tga:18|t";

local moduleOrder = {
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
};

function Config:GetModuleOrder(moduleName)
    local map = tInvert(moduleOrder);

    return map[moduleName] or error('Unknown order for module: ' .. moduleName);
end

function Config:Init()
    TalentTreeTweaksDB = TalentTreeTweaksDB or {};
    self.db = TalentTreeTweaksDB;
    self.version = C_AddOns.GetAddOnMetadata(name, "Version") or "";

    self.category, self.layout = Settings.RegisterVerticalLayoutCategory("Talent Tree Tweaks");

    self:MakeText(L["Version:"] .. " " .. WHITE_FONT_COLOR:WrapTextInColorCode(self.version));

    self:MakeDonationPrompt();

    do
        local modulesWithConfig = {};
        local modulesWithoutConfig = {};
        for moduleName, module in ns.Main:IterateModules() do
            --- @type TTT_Module
            local module = module;
            local moduleInfo = { module = module, moduleName = moduleName, order = self:GetModuleOrder(moduleName) };
            if module.BuildConfig then
                table.insert(modulesWithConfig, moduleInfo);
            else
                table.insert(modulesWithoutConfig, moduleInfo);
            end
        end

        if modulesWithoutConfig[1] then
            table.sort(modulesWithoutConfig, function(a, b) return a.order < b.order; end);

            local expandInitializer, isExpanded = self:MakeExpandableSection(L["Basic Modules"]);
            local configBuilder = self:MakeConfigBuilder(self.db.modules, isExpanded);
            configBuilder:SetEnableInitializer(expandInitializer); -- not quite accurate, but whatever
            for _, moduleInfo in ipairs(modulesWithoutConfig) do
                local moduleName, module = moduleInfo.moduleName, moduleInfo.module;
                configBuilder:MakeCheckbox(
                    module:GetName(),
                    moduleName,
                    module:GetDescription(),
                    function(_, value)
                        if value then
                            module:Enable();
                        else
                            module:Disable();
                        end
                    end,
                    true
                );
            end
        end

        local function formatModuleName(moduleName, enabled)
            return enabled
                and moduleName
                or moduleName .. RED_FONT_COLOR:WrapTextInColorCode(' (' .. ADDON_DISABLED .. ')');
        end
        table.sort(modulesWithConfig, function(a, b) return a.order < b.order; end);
        for _, moduleInfo in ipairs(modulesWithConfig) do
            local moduleName, module = moduleInfo.moduleName, moduleInfo.module;
            local expandInitializer, isExpanded = self:MakeExpandableSection(function() return formatModuleName(module:GetName(), self.db.modules[moduleName]); end);
            local changingExpandText = false;
            expandInitializer:AddShownPredicate(function() return not changingExpandText; end);

            self.db.moduleDb[moduleName] = self.db.moduleDb[moduleName] or {};
            local moduleDb = self.db.moduleDb[moduleName];
            local configBuilder = self:MakeConfigBuilder(moduleDb, isExpanded);

            configBuilder:MakeText(module:GetDescription());
            local enableInitializer = configBuilder:MakeCheckbox(
                ENABLE,
                moduleName,
                L['Enable this module'],
                function(_, value)
                    if value then
                        module:Enable();
                    else
                        module:Disable();
                    end

                    changingExpandText = true;
                    self:NotifyChange();
                    changingExpandText = false;
                    self:NotifyChange();
                end,
                true,
                self.db.modules
            );
            configBuilder:SetEnableInitializer(enableInitializer);

            securecallfunction(module.BuildConfig, module, configBuilder, moduleDb);
        end
    end

    Settings.RegisterAddOnCategory(self.category);
end

function Config:NotifyChange(forceUpdateSliders)
    if not SettingsPanel or self.category ~= SettingsPanel:GetCurrentCategory() then return end
    if forceUpdateSliders then
        -- show and hide the sliders to force them to update
        self.updatingSliders = true;
        SettingsInbound.RepairDisplay();
        self.updatingSliders = false;
    end
    SettingsInbound.RepairDisplay();
end

function Config:OpenSettings()
    Settings.OpenToCategory(self.category:GetID());
end

function Config:GetUniqueVariable()
    self.counter = self.counter or CreateCounter();

    return settingPrefix .. self.counter();
end

--- @class TTT_ConfigBuilder
local ConfigBuilderMixin = {};
do
    --- @param moduleDb table
    --- @param category SettingsCategoryMixin
    --- @param layout SettingsVerticalLayoutMixin
    --- @param isExpanded fun(): boolean
    function ConfigBuilderMixin:Init(moduleDb, category, layout, isExpanded)
        self.db = moduleDb;
        self.category = category;
        self.layout = layout;
        self.isExpanded = isExpanded;
    end

    --- @param initializer SettingsSearchableElementMixin
    function ConfigBuilderMixin:SetEnableInitializer(initializer)
        self.enableInitializer = initializer;
    end

    --- @param defaults table
    --- @param applyDefaultsToNilValues boolean? # If true, any nil values in self.db will be set to the default value
    function ConfigBuilderMixin:SetDefaults(defaults, applyDefaultsToNilValues)
        self.defaults = defaults;
        if applyDefaultsToNilValues then
            for k, v in pairs(defaults) do
                if self.db[k] == nil then
                    self.db[k] = v;
                end
            end
        end
    end

    local hidePredicate = function() return false; end;

    --- @param initializersToRemove SettingsSearchableElementMixin[]
    function ConfigBuilderMixin:RemoveInitializers(initializersToRemove)
        -- actually removing the predicates from the layout caused some error that I didn't feel like investigating
        for _, initializerToRemove in pairs(initializersToRemove) do
            initializerToRemove:AddShownPredicate(hidePredicate);
        end
        Config:NotifyChange();
    end

    --- Moves the given initializers to be after the target initializer in the layout. Automatically redraws the layout.
    --- @param initializersToMove SettingsSearchableElementMixin[] # initializers will end up in the order they are given
    --- @param targetInitializer SettingsSearchableElementMixin? # defaults to the enable initializer
    function ConfigBuilderMixin:MoveInitializersAfter(initializersToMove, targetInitializer)
        targetInitializer = targetInitializer or self.enableInitializer;
        local initializers = self.layout:GetInitializers();
        local targetIndex = tIndexOf(initializers, targetInitializer);
        if not targetIndex then
            error("Target initializer not found in layout");
        end
        for _, initializerToMove in ipairs_reverse(initializersToMove) do
            if initializerToMove == targetInitializer then
                error("Cannot move initializer after itself");
            end
            tDeleteItem(initializers, initializerToMove);
            table.insert(initializers, targetIndex + 1, initializerToMove);
        end

        Config:NotifyChange();
    end

    --- @param text string
    --- @param tooltip string?
    --- @param indent number? # default 0
    --- @return SettingsListElementInitializer initializer
    function ConfigBuilderMixin:MakeHeader(text, tooltip, indent)
        local initializer = Config:MakeHeader(text, tooltip, indent);
        initializer:AddShownPredicate(self.isExpanded);

        return initializer;
    end

    --- @param text string
    --- @param indent number? # default 0
    --- @return SettingsListElementInitializer initializer
    function ConfigBuilderMixin:MakeText(text, indent)
        local initializer = Config:MakeText(text, indent);
        initializer:AddShownPredicate(self.isExpanded);

        return initializer;
    end

    --- @param label string
    --- @param onClick fun(self: Button)
    --- @param tooltip string?
    --- @return SettingsListElementInitializer initializer
    function ConfigBuilderMixin:MakeButton(label, onClick, tooltip)
        local initializer = Config:MakeButton(label, onClick, tooltip);
        initializer:AddShownPredicate(self.isExpanded);

        return initializer;
    end

    --- @param label string
    --- @param settingKey string|number
    --- @param tooltip string?
    --- @param callback fun(setting: AddOnSettingMixin, value: boolean)?
    --- @param defaultValue boolean?
    --- @param overrideTable table?
    --- @return SettingsListElementInitializer initializer
    --- @return AddOnSettingMixin setting
    function ConfigBuilderMixin:MakeCheckbox(label, settingKey, tooltip, callback, defaultValue, overrideTable)
        if defaultValue == nil then
            defaultValue = self.defaults[settingKey];
        end
        local initializer, setting = Config:MakeCheckbox(label, settingKey, tooltip, defaultValue, overrideTable or self.db);
        initializer:AddShownPredicate(self.isExpanded);
        if callback then
            setting:SetValueChangedCallback(callback);
        end

        return initializer, setting;
    end

    --- @param minValue number? # default 0
    --- @param maxValue number? # default 1
    --- @param rate number? # Size between steps; Defaults to 100 steps
    --- @param displayFormatter nil|fun(value: number): string # optional Right text formatter
    --- @return TTT_Config_SliderOptions
    function ConfigBuilderMixin:MakeSliderOptions(minValue, maxValue, rate, displayFormatter)
        local sliderOptions = Settings.CreateSliderOptions(minValue, maxValue, rate);
        if displayFormatter then
            sliderOptions:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, displayFormatter);
        end

        return sliderOptions;
    end

    --- @param label string
    --- @param settingKey string|number
    --- @param tooltip string?
    --- @param options TTT_Config_SliderOptions
    --- @param callback fun(setting: AddOnSettingMixin, value: number)?
    --- @param defaultValue number?
    --- @param overrideTable table?
    --- @return SettingsListElementInitializer initializer
    --- @return AddOnSettingMixin setting
    function ConfigBuilderMixin:MakeSlider(label, settingKey, tooltip, options, callback, defaultValue, overrideTable)
        if defaultValue == nil then
            defaultValue = self.defaults[settingKey];
        end
        local initializer, setting = Config:MakeSlider(label, settingKey, tooltip, options, defaultValue, overrideTable or self.db);
        initializer:AddShownPredicate(self.isExpanded);
        if callback then
            setting:SetValueChangedCallback(callback);
        end

        return initializer, setting;
    end

    --- @param label string
    --- @param settingKey string|number
    --- @param tooltip string?
    --- @param options TTT_Config_DropDownOptions|fun(): TTT_Config_DropDownOptions
    --- @param callback fun(setting: AddOnSettingMixin, value: any)?
    --- @param defaultValue any?
    --- @param overrideTable table?
    --- @return SettingsListElementInitializer initializer
    --- @return AddOnSettingMixin setting
    function ConfigBuilderMixin:MakeDropdown(label, settingKey, tooltip, options, callback, defaultValue, overrideTable)
        if defaultValue == nil then
            defaultValue = self.defaults[settingKey];
        end
        local initializer, setting = Config:MakeDropdown(label, settingKey, tooltip, options, defaultValue, overrideTable or self.db);
        initializer:AddShownPredicate(self.isExpanded);
        if callback then
            setting:SetValueChangedCallback(callback);
        end

        return initializer, setting;
    end

    --- @param label string
    --- @param settingKey string|number
    --- @param tooltip string?
    --- @param callback fun(setting: AddOnSettingMixin, value: ColorRGBData|ColorRGBAData)?
    --- @param defaultValue ColorRGBData|ColorRGBAData|nil
    --- @param overrideTable table?
    --- @return SettingsListElementInitializer initializer
    --- @return AddOnSettingMixin setting
    function ConfigBuilderMixin:MakeColorPicker(label, settingKey, tooltip, callback, defaultValue, overrideTable)
        if defaultValue == nil then
            defaultValue = self.defaults[settingKey];
        end
        local initializer, setting = Config:MakeColorPicker(label, settingKey, tooltip, defaultValue, overrideTable or self.db);
        initializer:AddShownPredicate(self.isExpanded);
        if callback then
            setting:SetValueChangedCallback(callback);
        end

        return initializer, setting;
    end
end

--- @param moduleDb table
--- @param isExpanded fun(): boolean
--- @return TTT_ConfigBuilder configBuilder
function Config:MakeConfigBuilder(moduleDb, isExpanded)
    return CreateAndInitFromMixin(ConfigBuilderMixin, moduleDb, self.category, self.layout, isExpanded);
end

do
    --- @param text string
    --- @param tooltip string?
    --- @param indent number? # default 0
    --- @return SettingsListElementInitializer
    function Config:MakeHeader(text, tooltip, indent)
        local data = { name = text, tooltip = tooltip, indent = indent or 0 };
        --- @type SettingsListElementInitializer
        local headerInitializer = Settings.CreateElementInitializer("TalentTreeTweaks_SettingsHeaderTemplate", data);

        self.layout:AddInitializer(headerInitializer);

        return headerInitializer;
    end

    local calculateHeight;
    do
        local heightCalculator = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormal");
        local deferrer = CreateFrame("Frame");
        deferrer:Hide();
        deferrer.callbacks = {};
        deferrer:SetScript("OnUpdate", function()
            for _, callback in pairs(deferrer.callbacks) do
                securecallfunction(callback);
            end
            deferrer.callbacks = {};
        end);
        function deferrer:Defer(callback)
            table.insert(self.callbacks, callback);
            self:Show();
        end
        calculateHeight = function(data, deferred)
            local text, indent = data.name, data.indent;
            heightCalculator:SetWidth(635 - (indent * 15));
            heightCalculator:SetText(text);

            data.extent = heightCalculator:GetStringHeight();
            if not deferred then
                deferrer:Defer(function() calculateHeight(data, true); end);
            end
        end
    end

    --- @param text string
    --- @param indent number? # default 0
    --- @return SettingsListElementInitializer
    function Config:MakeText(text, indent)
        local data = {
            name = text,
            indent = indent or 0,
        };
        calculateHeight(data);
        --- @type SettingsListElementInitializer
        local textInitializer = Settings.CreateElementInitializer("TalentTreeTweaks_SettingsTextTemplate", data);

        function textInitializer:GetExtent() return self.data.extent; end

        self.layout:AddInitializer(textInitializer);

        return textInitializer;
    end

    local function sliderForcedUpdatePredicate()
        return not Config.updatingSliders;
    end

    --- @param label string
    --- @param settingKey string|number
    --- @param tooltip string?
    --- @param options TTT_Config_SliderOptions # see Settings.CreateSliderOptions
    --- @param defaultValue number?
    --- @param dbTableOverride table?
    --- @return SettingsListElementInitializer initializer
    --- @return AddOnSettingMixin setting
    function Config:MakeSlider(label, settingKey, tooltip, options, defaultValue, dbTableOverride)
        local variable = self:GetUniqueVariable();
        if defaultValue == nil then
            error('No default value provided');
        end

        local setting = Settings.RegisterAddOnSetting(
            self.category,
            variable,
            settingKey,
            dbTableOverride or self.db,
            Settings.VarType.Number,
            label,
            defaultValue
        );

        local initializer = Settings.CreateSlider(self.category, setting, options, tooltip);
        initializer:AddShownPredicate(sliderForcedUpdatePredicate);

        return initializer, setting;
    end

    --- @param label string
    --- @param settingKey string|number
    --- @param tooltip string?
    --- @param defaultValue boolean?
    --- @param dbTableOverride table?
    --- @return SettingsListElementInitializer initializer
    --- @return AddOnSettingMixin setting
    function Config:MakeCheckbox(label, settingKey, tooltip, defaultValue, dbTableOverride)
        local variable = self:GetUniqueVariable();
        if defaultValue == nil then
            error('No default value provided');
        end

        local setting = Settings.RegisterAddOnSetting(
            self.category,
            variable,
            settingKey,
            dbTableOverride or self.db,
            Settings.VarType.Boolean,
            label,
            defaultValue
        );

        return Settings.CreateCheckbox(self.category, setting, tooltip), setting;
    end

    --- @param label string
    --- @param settingKey string|number
    --- @param tooltip string?
    --- @param options TTT_Config_DropDownOptions|fun(): TTT_Config_DropDownOptions
    --- @param defaultValue any?
    --- @param dbTableOverride table?
    --- @return SettingsListElementInitializer initializer
    --- @return AddOnSettingMixin setting
    function Config:MakeDropdown(label, settingKey, tooltip, options, defaultValue, dbTableOverride)
        local variable = self:GetUniqueVariable();
        if defaultValue == nil then
            error('No default value provided')
        end

        local function getOptions()
            if type(options) == "function" then
                options = options()
            end
            local container = Settings.CreateControlTextContainer();
            for _, option in pairs(options) do
                local added = container:Add(option.value, option.label or option.text, option.tooltip);
                added.text = option.text;
            end

            return container:GetData();
        end
        local setting = Settings.RegisterAddOnSetting(self.category, variable, settingKey, dbTableOverride or self.db, type(defaultValue), label, defaultValue);

        return Settings.CreateDropdown(self.category, setting, getOptions, tooltip), setting;
    end

    --- @param label string
    --- @param onClick fun(self: Button)
    --- @param tooltip string?
    --- @return SettingsListElementInitializer initializer
    function Config:MakeButton(label, onClick, tooltip)
        local data = {
            name = label,
            tooltip = tooltip,
            buttonText = label,
            OnButtonClick = onClick,
        };
        data.buttonText = label;
        data.OnButtonClick = onClick;
        local initializer = Settings.CreateSettingInitializer('TalentTreeTweaks_SettingsButtonControlTemplate', data);
        initializer:AddSearchTags(label);
        self.layout:AddInitializer(initializer);

        return initializer;
    end

    --- @param label string
    --- @param onClick fun(button: Button, buttonIndex: number)
    --- @param tooltip string?
    --- @param buttonTexts string[]
    --- @return SettingsListElementInitializer initializer
    function Config:MakeMultiButton(label, onClick, tooltip, buttonTexts)
        local data = {
            name = label,
            tooltip = tooltip,
            buttonTexts = buttonTexts,
            OnButtonClick = onClick,
        };
        local initializer = Settings.CreateSettingInitializer('TalentTreeTweaks_SettingsMultiButtonControlTemplate', data);
        initializer:AddSearchTags(label);
        self.layout:AddInitializer(initializer);

        return initializer;
    end

    --- @param sectionName string|fun(): string
    --- @return SettingsExpandableSectionInitializer initializer
    --- @return fun(): boolean isExpanded
    function Config:MakeExpandableSection(sectionName)
        local nameGetter = sectionName;
        if type(sectionName) == "string" then
            nameGetter = function() return sectionName; end
        end
        local expandInitializer = CreateSettingsExpandableSectionInitializer(nameGetter());
        expandInitializer.data.nameGetter = nameGetter;
        function expandInitializer:GetExtent()
            return 25;
        end

        local origInitFrame = expandInitializer.InitFrame;
        function expandInitializer:InitFrame(frame)
            self.data.name = self.data.nameGetter();

            origInitFrame(self, frame);

            function frame:OnExpandedChanged(expanded)
                self:EvaluateVisibility(expanded);
                SettingsInbound.RepairDisplay();
            end

            function frame:EvaluateVisibility(expanded)
                -- elvui wants this function to exist
                if expanded then
                    self.Button.Right:SetAtlas("Options_ListExpand_Right_Expanded", TextureKitConstants.UseAtlasSize);
                else
                    self.Button.Right:SetAtlas("Options_ListExpand_Right", TextureKitConstants.UseAtlasSize);
                end
            end

            function frame:CalculateHeight()
                local initializer = self:GetElementData();

                return initializer:GetExtent();
            end

            frame:EvaluateVisibility(self.data.expanded);
        end

        self.layout:AddInitializer(expandInitializer);

        return expandInitializer, function() return expandInitializer.data.expanded; end;
    end

    --- @param label string
    --- @param settingKey string|number
    --- @param tooltip string?
    --- @param defaultValue ColorRGBData?
    --- @param dbTableOverride table?
    --- @return SettingsListElementInitializer initializer
    --- @return AddOnSettingMixin setting
    function Config:MakeColorPicker(label, settingKey, tooltip, defaultValue, dbTableOverride)
        local variable = self:GetUniqueVariable();
        if defaultValue == nil then
            error('No default value provided');
        end

        --- @type AddOnSettingMixin
        local setting = Settings.RegisterAddOnSetting(
            self.category,
            variable,
            settingKey,
            dbTableOverride or self.db,
            'table',
            label,
            defaultValue
        );
        local data = Settings.CreateSettingInitializerData(setting, nil, tooltip);

        local initializer = Settings.CreateSettingInitializer('TalentTreeTweaks_SettingsColorControlTemplate', data);
        self.layout:AddInitializer(initializer);

        return initializer, setting;
    end

    --- @return SettingsListElementInitializer initializer
    function Config:MakeDonationPrompt(layout)
        self:MakeText(L["Addon development takes a large amount of time and effort. If you enjoy using Talent Tree Tweaks, please consider supporting its development by donating. Your support helps ensure the continued improvement and maintenance of the addon. Thank you for your generosity!"]);

        local function onClick(_, buttonIndex)
            if buttonIndex == 1 then
                ns.Util:CopyText("https://www.paypal.com/cgi-bin/webscr?hosted_button_id=C8HP9WVKPCL8C&item_name=Talent+Tree+Tweaks&cmd=_s-xclick");
            else
                ns.Util:CopyText("https://buymeacoffee.com/numy");
            end
        end

        return self:MakeMultiButton(
            L["Donate"],
            onClick,
            L["If you enjoy using Talent Tree Tweaks, consider supporting its development with a donation."],
            {
                PAYPAL_TEXTURE .. "PayPal",
                COFFEE_TEXTURE .. "BuyMeACoffee",
            }
        );
    end

    TalentTreeTweaks_SettingsColorControlMixin = CreateFromMixins(SettingsControlMixin);
    do
        --- @class TTT_Config_ColorControlMixin
        local mixin = TalentTreeTweaks_SettingsColorControlMixin;

        --- @param colorData ColorRGBData
        function mixin:SetColorVisual(colorData)
            local r, g, b = colorData.r, colorData.g, colorData.b;
            self.Text:SetTextColor(r, g, b);
            self.ColorSwatch.Color:SetVertexColor(r, g, b);
        end

        function mixin:Init(initializer)
            SettingsControlMixin.Init(self, initializer);

            -- "SetCallback" actually registers the callback, it doesn't replace it
            self.data.setting:SetValueChangedCallback(function(_, value) self:SetColorVisual(value) end);
            self:SetColorVisual(self.data.setting:GetValue());

            self.ColorSwatch:SetScript("OnClick", function() self:OpenColorPicker() end);
            self.ColorSwatch:SetScript("OnEnter", function(button)
                GameTooltip:SetOwner(button, "ANCHOR_TOP");
                GameTooltip_AddHighlightLine(GameTooltip, initializer:GetName());
                GameTooltip_AddNormalLine(GameTooltip, initializer:GetTooltip());
                GameTooltip:Show();
            end);
            self.ColorSwatch:SetScript("OnLeave", function() GameTooltip:Hide(); end);

            self:EvaluateState();
        end

        function mixin:EvaluateState()
            SettingsControlMixin.EvaluateState(self);
            local enabled = self:IsEnabled();

            self.ColorSwatch:SetEnabled(enabled);
            if enabled then
                self.Text:SetTextColor(self.ColorSwatch.Color:GetVertexColor());
            else
                self.Text:SetTextColor(GRAY_FONT_COLOR:GetRGB());
            end
        end

        function mixin:OpenColorPicker()
            local color = self.data.setting:GetValue();

            ColorPickerFrame:SetupColorPickerAndShow({
                r = color.r,
                g = color.g,
                b = color.b,
                opacity = color.a or nil,
                hasOpacity = color.a ~= nil,
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB();
                    local a = ColorPickerFrame:GetColorAlpha();

                    self.data.setting:SetValue({ r = r, g = g, b = b, a = a, });
                end,
                cancelFunc = function()
                    local r, g, b, a = ColorPickerFrame:GetPreviousValues();

                    self.data.setting:SetValue({ r = r, g = g, b = b, a = a, });
                end,
            });
        end
    end

    TalentTreeTweaks_SettingsButtonControlMixin = CreateFromMixins(SettingsListElementMixin);
    do
        --- @class TTT_Config_ButtonControlMixin
        local mixin = TalentTreeTweaks_SettingsButtonControlMixin;

        function mixin:Init(initializer)
            SettingsListElementMixin.Init(self, initializer);

            self.Button:SetText(self.data.buttonText);
            self.Button:SetScript("OnClick", self.data.OnButtonClick);
            self.Button:SetScript("OnEnter", function(button)
                GameTooltip:SetOwner(button, "ANCHOR_TOP");
                GameTooltip_AddHighlightLine(GameTooltip, initializer:GetName());
                GameTooltip_AddNormalLine(GameTooltip, initializer:GetTooltip());
                GameTooltip:Show();
            end);
            self.Button:SetScript("OnLeave", function() GameTooltip:Hide(); end);

            self:EvaluateState();
        end

        function mixin:EvaluateState()
            SettingsListElementMixin.EvaluateState(self);
            local enabled = SettingsControlMixin.IsEnabled(self);

            self.Button:SetEnabled(enabled);
            self:DisplayEnabled(enabled);
        end
    end

    TalentTreeTweaks_SettingsMultiButtonControlMixin = CreateFromMixins(SettingsListElementMixin);
    do
        --- @class TTT_Config_MultiButtonControlMixin
        local mixin = TalentTreeTweaks_SettingsMultiButtonControlMixin;

        function mixin:Init(initializer)
            SettingsListElementMixin.Init(self, initializer);
            --- @param button Button
            local function onClick(button)
                self.data.OnButtonClick(button, button:GetID());
            end
            --- @param button Button
            local function onEnter(button)
                GameTooltip:SetOwner(button, "ANCHOR_TOP");
                GameTooltip_AddHighlightLine(GameTooltip, initializer:GetName());
                GameTooltip_AddNormalLine(GameTooltip, initializer:GetTooltip());
                GameTooltip:Show();
            end
            local function onLeave() GameTooltip:Hide(); end
            self.ButtonContainer.buttonPool:ReleaseAll();

            local anchorTarget;
            for i, buttonText in ipairs(self.data.buttonTexts) do
                local button = self.ButtonContainer.buttonPool:Acquire();
                button:SetID(i);
                button:SetTextToFit(buttonText);
                button:Show();
                if i == 1 then
                    button:SetPoint("LEFT", self.ButtonContainer, "LEFT", 0, 0);
                else
                    button:SetPoint("LEFT", anchorTarget, "RIGHT", 5, 0);
                end
                button:SetScript("OnClick", onClick);
                button:SetScript("OnEnter", onEnter);
                button:SetScript("OnLeave", onLeave);
                anchorTarget = button;
            end

            self:EvaluateState();
        end

        function mixin:EvaluateState()
            SettingsListElementMixin.EvaluateState(self);
            local enabled = SettingsControlMixin.IsEnabled(self);

            for button in self.ButtonContainer.buttonPool:EnumerateActive() do
                button:SetEnabled(enabled);
            end
            self:DisplayEnabled(enabled);
        end
    end

    TalentTreeTweaks_SettingsTextMixin = CreateFromMixins(DefaultTooltipMixin);
    do
        --- @class TTT_Config_TextMixin
        local mixin = TalentTreeTweaks_SettingsTextMixin;

        function mixin:Init(initializer)
            local data = initializer:GetData();
            self.Text:SetText(data.name);
            self.Text:SetHeight(data.extent);
            self:SetHeight(data.extent);
            local indent = data.indent or 0;
            self.Text:SetPoint('TOPLEFT', (7 + (indent * 15)), 0);
        end
    end

    TalentTreeTweaks_SettingsHeaderMixin = CreateFromMixins(DefaultTooltipMixin);
    do
        --- @class TTT_Config_HeaderMixin
        local mixin = TalentTreeTweaks_SettingsHeaderMixin;

        function mixin:Init(initializer)
            local data = initializer:GetData();
            self.Title:SetTextToFit(data.name);
            local indent = data.indent or 0;
            self.Title:SetPoint('TOPLEFT', (7 + (indent * 15)), -16);

            self:SetCustomTooltipAnchoring(self.Title, "ANCHOR_RIGHT");

            self:SetTooltipFunc(function() Settings.InitTooltip(initializer:GetName(), initializer:GetTooltip()) end);
        end
    end
end

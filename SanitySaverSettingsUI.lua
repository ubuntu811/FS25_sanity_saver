-- Injects "Enabled" + "Save interval" into the real ESC -> Settings ->
-- Game Settings page, instead of console commands - a real end user
-- shouldn't need -cheats/dev console access to flip a toggle. Same
-- UIHelper.lua pattern FS25_ImmersiveWeathering's IWSettingsUI.lua uses
-- (community utility, vendored verbatim - see UIHelper.lua's own header).
--
-- autoBind writes straight to config's fields (config.enabled,
-- config.saveIntervalMinutes), bypassing SanitySaverConfig's own
-- setEnabled()/setSaveIntervalMinutes() - so persistence is triggered
-- explicitly in onSettingsChange instead of happening for free.
SanitySaverSettingsUI = {}
local SanitySaverSettingsUI_mt = Class(SanitySaverSettingsUI)

function SanitySaverSettingsUI.new(config)
    local self = setmetatable({}, SanitySaverSettingsUI_mt)

    self.controls = {}
    self.config = config
    self.isInitialized = false

    return self
end

function SanitySaverSettingsUI:injectUiSettings()
    if g_dedicatedServer then
        return
    end

    if self.isInitialized then
        return
    end

    self.isInitialized = true

    local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings

    local controlProperties = {
        { name = "enabled", autoBind = true },
        { name = "saveIntervalMinutes", min = 5, max = 180, step = 5, unit = "min", autoBind = true },
    }

    UIHelper.createControlsDynamically(settingsPage, "ss_setting_title", self, controlProperties, "ss_")
    UIHelper.setupAutoBindControls(self, self.config, SanitySaverSettingsUI.onSettingsChange)

    -- Apply initial values and force the layout to actually lay the new
    -- controls out - without this, controls exist but the page doesn't
    -- reflow to show them.
    self:updateUiElements()
end

function SanitySaverSettingsUI:updateUiElements(skipAutoBindControls)
    if not skipAutoBindControls then
        -- Created dynamically by UIHelper.setupAutoBindControls.
        self.populateAutoBindControls()
    end

    local settingsPage = g_gui.screenControllers[InGameMenu].pageSettings
    settingsPage.gameSettingsLayout:invalidateLayout()
end

function SanitySaverSettingsUI:onSettingsChange()
    self.config:save()
end

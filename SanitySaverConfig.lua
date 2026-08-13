-- Persistent, cross-save mod preference (enable/disable + the save
-- interval) - deliberately NOT per-savegame state, since "I'm testing a
-- mod that might corrupt the world, turn autosave off for a while" is a
-- machine-wide preference, not something tied to one save. Same
-- getUserProfileAppPath()/modSettings + XMLSchema/XMLFile pattern
-- FS25_ImmersiveWeathering's own IWConfig.lua uses (confirmed real,
-- current FS25 API, sourced from Courseplay_FS25's own source there).
SanitySaverConfig = {}
local SanitySaverConfig_mt = Class(SanitySaverConfig)

local CONFIG_SCHEMA = XMLSchema.new("FS25_sanitySaverConfig")
CONFIG_SCHEMA:register(XMLValueType.BOOL, "config#enabled")
CONFIG_SCHEMA:register(XMLValueType.INT, "config#saveIntervalMinutes")

function SanitySaverConfig.new()
    local self = setmetatable({}, SanitySaverConfig_mt)

    self.enabled = true
    self.saveIntervalMinutes = 60

    self.baseDir = getUserProfileAppPath() .. "modSettings/FS25_sanity_saver/"
    createFolder(self.baseDir)
    self.filePath = self.baseDir .. "config.xml"

    self:load()

    return self
end

function SanitySaverConfig:load()
    local xmlFile = XMLFile.loadIfExists("SanitySaverConfig", self.filePath, CONFIG_SCHEMA)
    if xmlFile == nil then
        return
    end

    self.enabled = xmlFile:getValue("config#enabled", self.enabled)
    self.saveIntervalMinutes = xmlFile:getValue("config#saveIntervalMinutes", self.saveIntervalMinutes)

    xmlFile:delete()
end

function SanitySaverConfig:save()
    local xmlFile = XMLFile.create("SanitySaverConfig", self.filePath, "config", CONFIG_SCHEMA)
    if xmlFile == nil then
        return
    end

    xmlFile:setValue("config#enabled", self.enabled)
    xmlFile:setValue("config#saveIntervalMinutes", self.saveIntervalMinutes)
    xmlFile:save()
    xmlFile:delete()
end

function SanitySaverConfig:isEnabled()
    return self.enabled
end

function SanitySaverConfig:setEnabled(enabled)
    self.enabled = enabled
    self:save()
end

function SanitySaverConfig:getSaveIntervalMs()
    return self.saveIntervalMinutes * 60 * 1000
end

function SanitySaverConfig:setSaveIntervalMinutes(minutes)
    self.saveIntervalMinutes = minutes
    self:save()
end

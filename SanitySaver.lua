--[[
Sanity Saver

Fixed autosave. Two tiers:
  1. Hard ceiling: force a save every SAVE_INTERVAL, no matter what.
  2. After WARMUP has passed since the last save, start watching for a short
     gap in activity (AFK_THRESHOLD) and sneak a save into that gap instead
     of waiting out the full interval and possibly saving mid-action.

Note: activity is tracked via keyboard/mouse events. A gamepad-only session
won't reset the idle timer, so it just degrades to a plain SAVE_INTERVAL
autosave for those players - still strictly better than never/menu-only.

Config (enabled + the interval, see SanitySaverConfig.lua) is a
persistent, cross-save mod preference, not per-savegame state - "I'm
testing a mod that might trash the world, turn this off for a while" is
a machine-wide call, not something tied to one save.
]]

SanitySaver = {}
local SanitySaver_mt = Class(SanitySaver)

-- WARMUP is a fraction of the configured interval, not a separate
-- absolute setting - e.g. a 60min interval starts the AFK-window watch at
-- the 45min mark (0.75). Keeps the config surface to just "enabled" +
-- "the timer" instead of two numbers that have to be kept sensibly
-- related to each other.
SanitySaver.WARMUP_FACTOR = 0.75
SanitySaver.AFK_THRESHOLD = 60 * 1000 -- this much idle time counts as AFK

function SanitySaver.new()
    local self = setmetatable({}, SanitySaver_mt)
    self.lastActivityTime = g_time
    self.lastSaveTime = g_time
    return self
end

function SanitySaver:registerActivity()
    self.lastActivityTime = g_time
end

function SanitySaver:keyEvent(unicode, sym, modifier, isDown)
    self:registerActivity()
end

function SanitySaver:mouseEvent(posX, posY, isDown, isUp, button)
    self:registerActivity()
end

function SanitySaver:update(dt)
    local mission = g_currentMission
    if mission == nil or mission.missionInfo == nil or not mission:getIsServer() then
        return
    end

    if not SanitySaver.config:isEnabled() then
        return
    end

    if g_gui:getIsGuiVisible() then
        self:registerActivity() -- being in a menu isn't AFK
        return
    end

    local saveInterval = SanitySaver.config:getSaveIntervalMs()
    local warmup = saveInterval * SanitySaver.WARMUP_FACTOR

    local sinceLastSave = g_time - self.lastSaveTime
    local shouldSave = false

    if sinceLastSave >= saveInterval then
        shouldSave = true -- hit the hard ceiling
    elseif sinceLastSave >= warmup then
        if g_time - self.lastActivityTime >= SanitySaver.AFK_THRESHOLD then
            shouldSave = true -- sneak a save into this idle moment
        end
    end

    if shouldSave then
        mission:startSaveCurrentGame()
        self.lastSaveTime = g_time
        Logging.info("[SanitySaver] Autosaved (idle=%ds, sinceLastSave=%ds)",
            math.floor((g_time - self.lastActivityTime) / 1000),
            math.floor(sinceLastSave / 1000))
    end
end

function SanitySaver:onDayChanged()
    local mission = g_currentMission
    if mission == nil or mission.missionInfo == nil or not mission:getIsServer() then
        return
    end

    if not SanitySaver.config:isEnabled() then
        return
    end

    mission:startSaveCurrentGame()
    self.lastSaveTime = g_time
    self.lastActivityTime = g_time
    Logging.info("[SanitySaver] Day changed (slept) - autosaved.")
end

function SanitySaver:consoleCommandDebugSkipWarmup()
    local saveInterval = SanitySaver.config:getSaveIntervalMs()
    self.lastSaveTime = g_time - (saveInterval * SanitySaver.WARMUP_FACTOR)
    self.lastActivityTime = g_time - SanitySaver.AFK_THRESHOLD
    Logging.info("[SanitySaver] Debug: warmup + AFK window skipped. Close any open menu and it should autosave on the next update.")
end

function SanitySaver:consoleCommandToggle()
    local enabled = not SanitySaver.config:isEnabled()
    SanitySaver.config:setEnabled(enabled)
    Logging.info("[SanitySaver] %s", enabled and "Enabled." or "Disabled - won't autosave until re-enabled.")
end

function SanitySaver:consoleCommandSetInterval(minutesStr)
    local minutes = tonumber(minutesStr)
    if minutes == nil or minutes <= 0 then
        Logging.info("[SanitySaver] Usage: sanitySaverSetInterval <minutes> (e.g. 60)")
        return
    end

    SanitySaver.config:setSaveIntervalMinutes(minutes)
    Logging.info("[SanitySaver] Save interval set to %d min (AFK-window watch starts at %d min).",
        minutes, math.floor(minutes * SanitySaver.WARMUP_FACTOR))
end

local function onMissionLoaded(mission, node)
    if mission.cancelLoading then
        return
    end

    SanitySaver.config = SanitySaverConfig.new()

    local saver = SanitySaver.new()
    SanitySaver.instance = saver
    addModEventListener(saver)
    addConsoleCommand("sanitySaverDebugSkipWarmup",
        "Sanity Saver: skip straight past the warmup so the AFK check fires immediately (testing only)",
        "consoleCommandDebugSkipWarmup", saver)
    addConsoleCommand("sanitySaverToggle",
        "Sanity Saver: enable/disable autosaving (persists across sessions)",
        "consoleCommandToggle", saver)
    addConsoleCommand("sanitySaverSetInterval",
        "Sanity Saver: set the save interval in minutes, e.g. 'sanitySaverSetInterval 30' (persists across sessions)",
        "consoleCommandSetInterval", saver)

    -- Sleeping jumps the in-game clock forward, same category of "about to
    -- do something disruptive" as opening the save menu - a natural,
    -- always-foreground save point (unlike the AFK/interval checks, this
    -- one can't be starved by the window being minimized, since sleeping
    -- is a deliberate action that requires the game to be focused).
    g_messageCenter:subscribe(MessageType.DAY_CHANGED, saver.onDayChanged, saver)
end

Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, onMissionLoaded)

-- Fires for ANY completed save, not just ours - a manual pause-menu save
-- or a quicksave hotkey should reset our timers too, same as if we'd
-- triggered it ourselves. Unconditional (not gated on config.enabled) -
-- even while disabled, a real save happening should still update our
-- bookkeeping, so re-enabling later doesn't think a save is overdue and
-- fire immediately. Registered at file-load time (top level, not inside
-- onMissionLoaded) because SavegameController is a menu-system singleton
-- that exists before any mission is loaded - same pattern FS25_PowerTools
-- uses for its own quicksave feature.
SavegameController.onSaveComplete = Utils.appendedFunction(SavegameController.onSaveComplete, function(self, errorCode)
    if SanitySaver.instance ~= nil and errorCode == Savegame.ERROR_OK then
        SanitySaver.instance.lastSaveTime = g_time
        SanitySaver.instance.lastActivityTime = g_time
        Logging.info("[SanitySaver] Detected a completed save (manual or otherwise) - timers reset.")
    end
end)

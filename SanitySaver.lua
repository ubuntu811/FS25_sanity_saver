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
]]

SanitySaver = {}
local SanitySaver_mt = Class(SanitySaver)

SanitySaver.SAVE_INTERVAL = 60 * 60 * 1000 -- always save after this long, regardless of activity
SanitySaver.WARMUP = 45 * 60 * 1000 -- don't bother checking for AFK before this long since last save
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

    if g_gui:getIsGuiVisible() then
        self:registerActivity() -- being in a menu isn't AFK
        return
    end

    local sinceLastSave = g_time - self.lastSaveTime
    local shouldSave = false

    if sinceLastSave >= SanitySaver.SAVE_INTERVAL then
        shouldSave = true -- hit the hard ceiling
    elseif sinceLastSave >= SanitySaver.WARMUP then
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

function SanitySaver:consoleCommandDebugSkipWarmup()
    self.lastSaveTime = g_time - SanitySaver.WARMUP
    self.lastActivityTime = g_time - SanitySaver.AFK_THRESHOLD
    Logging.info("[SanitySaver] Debug: warmup + AFK window skipped. Close any open menu and it should autosave on the next update.")
end

local function onMissionLoaded(mission, node)
    if mission.cancelLoading then
        return
    end
    local saver = SanitySaver.new()
    addModEventListener(saver)
    addConsoleCommand("sanitySaverDebugSkipWarmup",
        "Sanity Saver: skip straight past the 45min warmup so the AFK check fires immediately (testing only)",
        "consoleCommandDebugSkipWarmup", saver)
end

Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, onMissionLoaded)

-- if multiple packages need the same import, put that import here
-- todo write or install a tool to verify that there are no redundant imports in the proj
-- todo replace all func comments w the template generated when --- is typed
-- todo replace type-checking or similar if statements with assert()
-- todo name private fields on objects _var like in the pd sdk
-- todo for all classes, add @property docs to @class docs
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/ui"
import "CoreLibs/animation"

import "gconsts"
import "utils/utils"
import "utils/debugger"
import "utils/crankhandler"
import "rendering/render"

-- Gives all subsequently-imported project files access to state
local state = STATES.LOADING
--- Query for the current app state
---@return boolean true iff app state is LOADING mode
function stateIsLOADING() return state == STATES.LOADING end
---@return boolean true iff app state is CONFiguration mode
function stateIsCONF() return state == STATES.CONF end
---@return boolean true iff app state is MENU mode
function stateIsMENU() return state == STATES.MENU end
---@return boolean true iff app state is RUN_TIMER mode
function stateIsRUN_TIMER() return state == STATES.RUN_TIMER end
---@return boolean true iff app state is DONE_TIMER mode
function stateIsDONE_TIMER() return state == STATES.DONE_TIMER end
import "timer"
import "confmanager"
import "uimanager"
import "musicmanager"

local pd <const> = playdate
local d <const> = debugger
local gfx <const> = pd.graphics
local ui <const> = uimanager
local music <const> = musicmanager
local A <const> = pd.kButtonA
local B <const> = pd.kButtonB

-- TODO can states be a set of update funcs, or do we need the enum?
confs = confmanager.confs
initialDurations = {
    work = 25,
    short = 5,
    long = 20
}

local drawFPS = false
local splashSprite = nil
local timers = {
    work = 'nil',
    short = 'nil',
    long = 'nil',
    snooze = 'nil'
}
local currentTimer = nil
local timerCompleted = false
local c_poms = 0
local c_snoozes = 0
local cachedState = nil -- state prior to entering configuration mode

--TODO replace other calls to these functions
function APressed() return pd.buttonJustPressed(A) end
function BPressed() return pd.buttonJustPressed(B) end

--- Sets up the app environment.
--- If a state save file exists, it will be loaded here.
local function init()
    --debugger.disable() --TODO uncomment
    --render.bakeAll("force bake all future renders")
    render.disableWriting() --TODO once all renders are refactored, go into data folder and delete the assets subfolder
    drawFPS = true --TODO comment out

    -- snooze duration is in the confs data file
    d.log("attempting to load state: durations")
    local loadedDurations = pd.datastore.read("durations")
    if loadedDurations then
        d.log("duration state file exists")
        for k,v in pairs(loadedDurations) do initialDurations[k] = v end
    end
    d.log("duration-loading attempt complete; dumping initialDurations", initialDurations)

    d.log("attempting to load state: confs")
    local sav_confs = pd.datastore.read("confs")
    d.log("conf-loading attempt complete; dumping confs", sav_confs)

    confmanager.init(sav_confs)

    if confs.pomSavingOn then
        d.log("attempting to load state: data")
        c_poms = pd.datastore.read("data")["c_poms"]
        d.log("conf-loading attempt complete; c_poms:", c_poms)
        if not c_poms then c_poms = 0 end
    end

    timers.work = Timer("work", toDone)
    timers.short = Timer("short", toDone)
    timers.long = Timer("long", toDone)
    timers.snooze1 = Timer("snooze1", toDone)
    timers.snooze2 = Timer("snooze2", toDone)
    currentTimer = timers.work --TODO rm

    music.init()
    music.add({
        work = SOUND.notif_workToBreak,
        short = SOUND.notif_breakToWork,
        long = SOUND.notif_breakToWork,
        snooze1 = SOUND.notif_fromSnooze[1],
        snooze2 = SOUND.notif_fromSnooze[2]
    })
 
    ui.init({
        {t = timers.short, label = "short break"},
        {t = timers.work, label = "work"},
        {t = timers.long, label = "long break"},
        {t = timers.snooze1},
        {t = timers.snooze2}
    })
    ui.selectNextTimer() -- autoselects the 2nd timer, 'work'

    d.log("main.init COMPLETE")
end

--TODO replace with a launchImage, configurable in pdxinfo
local function splash()
    local splashImg = gfx.image.new(W_SCREEN, H_SCREEN)
    gfx.pushContext(splashImg)
        gfx.drawText("*POMDATE*", 50, 90)
        gfx.drawText("press A to continue", 50, 140)
    gfx.popContext()
    splashSprite = gfx.sprite.new(splashImg)
    splashSprite:setCenter(0, 0) --anchor top-left
    splashSprite:setZIndex(100)
    splashSprite:add()
    pd.ui.crankIndicator:start()
end

local function sav()
    d.log("attempting to save state")

    -- TODO implement sav func in UIManager
    local sav_durations = {
        work = ui.getDialValue("work"),
        short = ui.getDialValue("short"),
        long = ui.getDialValue("long")
    } -- snooze duration is in the confs data file
    d.log("dumping durations to be saved", sav_durations)
    pd.datastore.write(sav_durations, "durations")
    d.log("duration save attempt complete. Dumping datafile", pd.datastore.read("durations"))

    local sav_confs = confmanager.sav()
    d.log("dumping confs to be saved", sav_confs)
    pd.datastore.write(sav_confs, "confs")
    d.log("conf save attempt complete. Dumping datafile", pd.datastore.read("confs"))

    if confs.pomSavingOn then
        d.log("Elapsed poms to be saved: ", c_poms)
        pd.datastore.write({ c_poms = c_poms }, "data")
        d.log("Elapsed poms save attempt complete. Dumping datafile", pd.datastore.read("data"))
    end
end

--- Auto-selects the next timer in the pomodoro cycle
local function cycleTimers()
    if currentTimer == timers.short then
        ui.selectNextTimer()
    elseif currentTimer == timers.long then
        ui.selectPrevTimer()
    elseif currentTimer == timers.work then
        if c_poms >= confs.pomsPerCycle then
            ui.selectNextTimer()
        else
            ui.selectPrevTimer()
        end
    end
end

--- Pauses currently running timer.
local function pause()
    -- if should also check :isStopped() once pd.timer:pause() is fixed
    if currentTimer:isActive() then
        d.log("current timer " .. currentTimer.name .. " is not active, may already be paused")
    else currentTimer:pause() end
end

--- Unpause current timer.
local function unpause()
    if currentTimer:isActive() then d.log("current timer " .. currentTimer.name .. " is not paused; can't unpause")
    else currentTimer:start() end
end

function toConf()
    pause()
    currentTimer:setVisible(false)
    cachedState = state
    state = STATES.CONF
end

function fromConf()
    confmanager:update()
    state = cachedState
    cachedState = nil
    currentTimer:setVisible(true)
    unpause()
end

-- performs done -> select transition
-- then inits select
-- then switches update func
-- TODO need to transition run -> select sometimes; refactor
-- TODO rename to toMENU
function toMenu()
    currentTimer:stop()
    c_snoozes = 0

    if timerCompleted then
        cycleTimers()
        timerCompleted = false
    end
    if c_poms >= confs.pomsPerCycle then
        --TODO alert user that the cycle pom count has been reached
    end

    pd.setAutoLockDisabled(false) --TODO verify this is still needed
    state = STATES.MENU
end

---TODO desc
function toRun(t, duration)
    currentTimer = t
    currentTimer:setDuration(duration)
    currentTimer:start()
    
    pd.setAutoLockDisabled(true)
    state = STATES.RUN_TIMER
end

function toDone()
    currentTimer:stop() --currentTimer:remove()
    
    timerCompleted = true
    if currentTimer == timers.long then
        c_poms = 0
    elseif currentTimer == timers.work then
        c_poms = c_poms + 1
    end

    state = STATES.DONE_TIMER
end

--- Runs generic snooze timer.
function snooze()
    -- if/else below won't work while pd.timer:pause() is buggy
    --if currentTimer:isStopped() then
        --d.log("current timer " .. currentTimer.name .. " is not stopped; can't snooze yet")
    --else
        currentTimer:stop()
        if c_snoozes < SNOOZE_LVL[1] then
            toRun(currentTimer, confs.snoozeDuration) -- replays normal notif music
        elseif c_snoozes < SNOOZE_LVL[2] then
            toRun(timers.snooze1, confs.snoozeDuration) -- distinct snooze music
        else
            toRun(timers.snooze2, confs.snoozeDuration) -- distinct snooze music
        end
        c_snoozes = c_snoozes + 1
    --end
end

--- Get the name of the current, or most recent, timer
function getTimerName() return currentTimer.name end

--- Get the number of times the current timer has been snoozed
---@return integer
function getSnoozeCount() return c_snoozes end

--- Get the number of completed pomodoros
---@return integer
function getPomCount() return c_poms end

--- Reset the pom cycle by resetting the completed-pomodoro count
function resetPomCount() c_poms = 0 end

-- pd.update() is called right before every frame is drawn onscreen.
function pd.update()
    --TODO replace this with playdate's builtin init screen system
    if stateIsLOADING() then
        --d.log("hit stateIsLOADING")
        pd.ui.crankIndicator:update()
        if pd.buttonJustPressed(A) then
            splashSprite:remove()
            toMenu()
        end
    end

    timer.update()
    ui.update()
    music.update()
    gfx.sprite.update() --TODO rm once all sprites are from ui lib
end

pd.cranked = crankhandler.cranked

function pd.gameWillTerminate()
    sav()
end
function pd.deviceWillSleep()
    sav()
end

-- debugDraw() is called immediately after update()
-- Only white pixels are drawn; black transparent
function pd.debugDraw()
    gfx.pushContext()
        gfx.setImageDrawMode(DRAWMODE_DEBUG)
        if drawFPS then pd.drawFPS(380,220) end
        d.drawLog()
        d.drawIllustrations()
    gfx.popContext()
end

------- APP START -------

gfx.setBackgroundColor(COLOR_0)
gfx.setColor(COLOR_1)
gfx.setImageDrawMode(DRAWMODE_BITMAP)
splash()
init()
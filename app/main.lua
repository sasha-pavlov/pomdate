-- if multiple packages need the same import, put that import here
-- todo write or install a tool to verify that there are no redundant imports in the proj
-- todo replace all func comments w the template generated when --- is typed
-- todo replace type-checking or similar if statements with assert()
-- todo name private fields on objects _var like in the pd sdk
-- todo for all classes, add @property docs to @class doc
import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/ui"

import "utils/utils";
import "configs"
import "utils/debugger"
import "timer"
import "uimanager"

local pd <const> = playdate
local d <const> = debugger
local gfx <const> = pd.graphics
local A <const> = pd.kButtonA
local B <const> = pd.kButtonB

-- TODO can states be a set of update funcs, or do we need the enum?
STATES = configs.STATES
state = STATES.LOADING

initialDurations = {
    work = 25,
    short = 5,
    long = 20,
    snooze = 2
}
local splashSprite = nil
local timers = {
    work = 'nil',
    short = 'nil',
    long = 'nil',
    snooze = 'nil'
}
local currentTimer = nil
local notifSound = nil
local c_pauses = 0
local c_snoozes = 0

local snoozeMins = 2 --TODO make configurable

--TODO move below asset path info to config or smth
local soundPathPrefix = "assets/sound/"
local notifSoundPath = "notif.wav"

--- Sets up the app environment.
--- If a state save file exists, it will be loaded here.
local function init()
    --utils.disableReadOnly()
    --debugger.disable()
    d.log("attempting to loadState")
    local loadedState = pd.datastore.read("durations")
    if loadedState then
        d.log("state file exists")
        initialDurations.work = loadedState.work
        initialDurations.short = loadedState.short
        initialDurations.long = loadedState.long
    end
    d.log("loading attempt complete; dumping loadedState table", loadedState)

    timers.work = Timer("work")
    timers.short = Timer("short")
    timers.long = Timer("long")
    timers.snooze = Timer("snooze")
    timers = utils.makeReadOnly(timers, "timers")
    timer.setNotifSound(pd.sound.sampleplayer.new(soundPathPrefix .. notifSoundPath))
    for _, t in pairs(timers) do t:setZIndex(50) end
    currentTimer = timers.work

    uimanager.init({timers.work, timers.short, timers.long})
end

--TODO replace with a launchImage, configurable in pdxinfo
local function splash()
    -- TODO maybe the configs really should just be globals in main. or in configs.lua w/o namespacing
    local splashImg = gfx.image.new(configs.W_SCREEN, configs.H_SCREEN)
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

local function saveState()
    d.log("attempting to saveState")

    local durations = {
        work = uimanager.getDialValue("work"),
        short = uimanager.getDialValue("short"),
        long = uimanager.getDialValue("long")
    }
    for name, duration in pairs(durations) do
        if duration <= -1 then
            durations[name] = initialDurations[name]
        end
    end
    d.log("dumping durations to be saved", durations)

    pd.datastore.write(durations, "durations")
    d.log("save attempt complete. Dumping datastore contents", pd.datastore.read("durations"))
end

-- performs done -> select transition
-- then inits select
-- then switches update func
-- TODO need to transition run -> select sometimes; refactor
-- TODO align semantics of menu w pause
function toMenu()
    currentTimer:remove()
    c_pauses = 0
    c_snoozes = 0
    pd.setAutoLockDisabled(false)
    pd.getCrankTicks(1) --TODO move this crank-data-dump to uimanager file
    state = STATES.MENU
end

---TODO desc
function toRun(t, duration)   
    currentTimer = t
    currentTimer:setDuration(duration)
    currentTimer:moveTo(50, 70)
    currentTimer:add()
    currentTimer:start()
    pd.setAutoLockDisabled(true)
    state = STATES.RUN_TIMER
end

--- Runs generic snooze timer.
function snooze()
    -- if/else below won't work while pd.timer:pause() is buggy
    --if currentTimer:isStopped() then
        --d.log("current timer " .. currentTimer.name .. " is not stopped; can't snooze yet")
    --else
        c_snoozes = c_snoozes + 1
        currentTimer:remove()
        toRun(timers.snooze, snoozeMins)
    --end
end

--- Pauses currently running timer.
function pause()
    -- if should also check :isStopped() once pd.timer:pause() is fixed
    if currentTimer:isPaused() then
        d.log("current timer " .. currentTimer.name .. " is already paused")
    else
        c_pauses = c_pauses + 1
        currentTimer:pause()
    end
end

--- Unpause current timer.
function unpause()
    if not currentTimer:isPaused() then d.log("current timer " .. currentTimer.name .. " is not paused; can't unpause")
    else currentTimer:start() end
end

--- Get the number of times the current timer has been paused
---@return integer
function getPauseCount()
    return c_pauses
end

--- Get the number of times the current timer has been snoozed
---@return integer
function getSnoozeCount()
    return c_snoozes
end

-- pd.update() is called right before every frame is drawn onscreen.
function pd.update()
    --TODO replace this with playdate's builtin init screen system
    if state == STATES.LOADING then
        pd.ui.crankIndicator:update() --TODO why isnt this working??
        if pd.buttonJustPressed(A) then
            splashSprite:remove()
            toMenu()
        end
    end

    uimanager.update()
    pd.timer.updateTimers()
    gfx.sprite.update()
end

function pd.gameWillTerminate()
    saveState()
end
function pd.deviceWillSleep()
    saveState()
end

-- debugDraw() is called immediately after update()
-- Only white pixels are drawn; black transparent
function pd.debugDraw()
    gfx.pushContext()
        gfx.setImageDrawMode(gfx.kDrawModeInverted)
        d.drawLog()
        d.drawIllustrations()
    gfx.popContext()
end

------- APP START -------

splash()
init()
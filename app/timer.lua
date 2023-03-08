-- timer provides value-based timers, rendered as sprites
local P = {}; local _G = _G
timer = {}

import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/easing" --TODO rm

local pd <const> = playdate
local d <const> = debugger
local gfx <const> = pd.graphics
local utils <const> = utils
local floor <const> = math.floor -- TODO may be able to replace this w // floor division lua operator?

-- Timer packs a timer with its UI.
class('Timer').extends(gfx.sprite)
local Timer <const> = Timer

local MSEC_PER_SEC <const> = 1000
local SEC_PER_MIN <const> = 60

local notifSound = nil

local _ENV = P
name = "timer"

--- Converts the msec argument into the clock time, rounded down
---@param msec integer milliseconds
---@return integer minutes
---@return integer seconds remaining after msec is converted to min 
local function convertToClock(msec)
    local sec = msec / MSEC_PER_SEC
    local min = floor(sec / SEC_PER_MIN)
    sec = floor(sec - min * SEC_PER_MIN)
    return min, sec
end

--- Notifies user that timer is complete
local function notify()
    --d.log("notification pushed")
    if notifSound then notifSound:play(0) end
    --TODO do we want to let this mod state directly?
    _G.state = _G.STATES.DONE_TIMER
end

--- Initializes, but does not start, a Timer.
---@param name string timer's name for graybox and debugging
function Timer:init(name)
    -- TODO give each timer a name
    Timer.super.init(self)
    self.name = name

    self._duration = 0.0 -- float timer duration in msec
    self._img = gfx.image.new(200,150)
    self:setImage(self.img)
    
    self._timer = nil -- "value-based" pd timer w linear interpolation
    self._isPaused = false -- true iff the timer is paused

    self:setCenter(0, 0) --anchor top-left
end

--[[
    :update() is called before :draw is called on all sprites
    Suspected conditions for redrawing a sprite if getAlwaysRedraw() == false
        - associated gfx.image has changed
        - sprite has had some transform applied to it
    So if we need to update a sprite every frame, do something in its :update()
--]]
-- Timer:update() draws the current time in the timer countdown
function Timer:update()
    local msec = 0 
    if self._timer then msec = self._timer.value
    elseif self._isPaused then msec = self._duration end

    -- if timer has completed
    if msec <= 0 then
        gfx.pushContext(self._img)
            gfx.clear()
            gfx.drawText("*DONE*", 0, 0)
        gfx.popContext()
        self._timer = nil
        notify()
    else
        local min, sec = convertToClock(msec)
        -- debugger.log("min: " .. min .. " sec: " .. sec)
        -- debugger.log(self._timer.value)
        local timeString = ""
        if min < 10 then timeString = "0" end
        timeString = timeString .. min .. ":"
        if sec < 10 then timeString = timeString .. "0" end
        timeString = timeString .. sec

        gfx.pushContext(self._img)
            gfx.clear()
            gfx.drawText("*"..timeString.."*", 0, 0)
        gfx.popContext()
    end

    --DEBUG doing this prevents the sprite from auto-refreshing when self._img changes
    --TODO set a larger font instead of upscaling default text
    self:setImage(self._img:scaledImage(4))

    Timer.super.update(self)
    --d.illustrateBounds(self)
end

--- Stop a Timer.
--- Stopped timers can be restarted by calling start().
function Timer:stop()
    notifSound:stop()
    self._timer = nil
    self._isPaused = false
end

--- Stop a Timer and remove its sprite.
--- Removed timers must be added back with add() before they can start().
function Timer:remove()
    d.log("removing timer "..self.name)
    self:stop()
    Timer.super.remove(self)
end

--- Pause a Timer.
--- Paused timers can be continued with start().
function Timer:pause()
    if self._timer then
        -- self._timer:pause() -- doesn't work; when started the value 'fast-forwards' according to the current time
        self._isPaused = true

        --TODO below is workaround for pd.timer:pause() being broken.
        -- Rm/refactor when bugfix
        self._duration = self._timer.value -- cache time-at-pause as new duration
        self._timer = nil
    else d.log(self.name .. " timer is nil; can't pause") end
end

--- Start a timer from a paused *or* stopped state.
--- Supports starting from both states to mimic pd.timer's docs.
--- However running timers cannot be started. Call reset() instead.
function Timer:start()
    if self._timer then
        d.log("forbidden to reset timer " .. self.name)
    else
        self._timer = pd.timer.new(self._duration, self._duration, 0)
        self._isPaused = false
    end
end

--- Returns true if this timer is paused.
function Timer:isPaused()
    return self._isPaused
end

--[[ Won't work while pd.timer:pause() is buggy
--- (re)Starts a Timer that will run for its configured duration
function Timer:reset()
    self.timer:stop()
    self.timer:start()
end

--- Returns true if the timer is stopped, ex. if it has completed.
function Timer:isStopped()
    return self._timer == nil
end
--]]

--- Set the sound to be played when a timer finishes
---@param sound pd.sound.sampleplayer or pd.sound.fileplayer
function setNotifSound(sound)
    if not sound.play or not sound.stop then
        d.log("attempting to set unplayable notif sound", sound)
        return
    end
    notifSound = sound
end

--- Set the duration the timer should run for (in minutes).
---@param mins integer duration
function Timer:setDuration(mins)
    self._duration = (mins + 0.0) * SEC_PER_MIN * MSEC_PER_SEC
end

local _ENV = _G
timer = utils.makeReadOnly(P)
return timer
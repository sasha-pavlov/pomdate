-- timer provides value-based timers, rendered as sprites
local P = {}; local _G = _G
timer = {}

import "CoreLibs/sprites"
import "CoreLibs/timer"

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

local _ENV = P
name = "timer"

-- convertTime(msec) returns a (min, sec) conversion of the argument, rounded down
local function convertTime(msec)
    local sec = msec / MSEC_PER_SEC
    local min = floor(sec / SEC_PER_MIN)
    sec = floor(sec - min * SEC_PER_MIN)
    return min, sec
end

--- Initializes, but does not start, a Timer.
---@param name string timer's name for graybox and debugging
function Timer:init(name)
    -- TODO give each timer a name
    Timer.super.init(self)
    self.name = name

    self.timer = nil
    self.img = gfx.image.new(100, 50)
    self:setImage(self.img)

    self:setCenter(0, 0) --anchor top-left
    self = utils.makeReadOnly(self, "timer instance")
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
    if self.timer then
        local msec = self.timer.value
        local min, sec = convertTime(msec)
        -- debugger.log("min: " .. min .. " sec: " .. sec)
        -- debugger.log(self.timer.value)

        local timeString = ""
        if min < 10 then timeString = "0" end
        timeString = timeString .. min .. ":"
        if sec < 10 then timeString = timeString .. "0" end
        timeString = timeString .. sec

        gfx.lockFocus(self.img)
            gfx.clear()
            gfx.drawText(timeString, 0, 0)
        gfx.unlockFocus()

        -- if timer has completed
        if msec <= 0 then
            self.timer = nil
            gfx.lockFocus(self.img)
                gfx.clear()
                gfx.drawText("DONE", 0, 0)
            gfx.unlockFocus()
        end
    end

    Timer.super.update(self)
    --debugger.illustrateBounds(self)
end

function Timer:start(minsDuration)
    if not self.timer then -- TODO do  completed timers pass this? if not, test for playdate.timer.timeLeft instead
        -- Returns a new playdate.timer that will run for duration milliseconds. 
        -- callback is a function closure that will be called when the timer is complete.
        -- TODO see playdate.timer.timerEndedCallback
        local msecDuration = minsDuration * SEC_PER_MIN * MSEC_PER_SEC
        d.log(msecDuration)
        _G.rawset(self, "timer", pd.timer.new(msecDuration, msecDuration, 0)) -- "value-based" timer w linear interpolation

        if self.timer then d.log("timer '" .. self.name .. "' was nil - now created") end
    else
        self.timer:start() -- TODO check that this autostarts the timer
        --debugger.log("timer not nil - started")
    end
end

function Timer:stop()
    self.timer = nil
end

--[[ not needed yet
function Timer:pause()
    if self:timerIsNil("pause()") then return end
    self.timer:pause()
end
--]]

--[[ not needed yet
function Timer:reset()
    if not self.timer then
        debugger.log("self.timer is nil. Can't call Timer:reset().")
        return
    end
    self.timer:reset()
    debugger.log("timer reset")
end
--]]

--[[ not needed yet
-- this function may not need to be named here
-- define it in the pd.timer.new closure?
local function notify(t)
    -- call when countdown ends
end
--]]

local _ENV = _G
timer = utils.makeReadOnly(P)
return timer
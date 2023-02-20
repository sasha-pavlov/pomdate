--- pkg 'dial' provides a dial UIElement that
--- visualizes a continuous value for the user to configure.

import 'ui/uielement'

-- pkg header: define pkg namespace
local P = {}; local _G = _G
dial = {}

local pd <const> = playdate
local d <const> = debugger
local gfx <const> = pd.graphics
local utils <const> = utils
local configs <const> = configs
local d <const> = debugger
--local externalfunc <const> = somepkg.func --TODO any other external vars go here

---TODO Dial desc
class('Dial').extends(UIElement)
local Dial <const> = Dial
local _ENV = P      -- enter pkg namespace
name = "dial"

--local localstatic <const> = val --TODO non-imported statics go here

--local localvar = val --TODO local vars go here

--local function localfunc() end --TODO local funcs go here

--- Initializes a new Dial instance.
---@param name string instance name for debugging
---@param unit string unit being enumerated, ex. "min"
---@param step integer step to inc/decrement the value on the dial by
---@param lowerLimit integer (optional) cease dialing back past this value
---@param upperLimit integer (optional) cease dialing forward past this value
function Dial:init(name, unit, step, lowerLimit, upperLimit)
    Dial.super.init(self, name) --should always be at top of init func
    
    self.step = step    -- step to inc/decrement value by
    self.lowerLimit = lowerLimit
    self.upperLimit = upperLimit
    if lowerLimit and upperLimit then
        self.value = (lowerLimit + upperLimit) // 2
    else
        self.value = 0
    end
    self.unit = unit    -- unit being enumerated

    self._prevValue = 0
    self._img = gfx.image.new(100, 80)
    self:setImage(self._img)

    --- Declare dial behaviour, to be configured elsewhere, prob by UI Manager
    ---@return integer amount to dial. pos for forward, neg for backward, 0 for no change
    self.getDialChange = function ()
        d.log("dial '" .. self.name .. "' dial-change measures not configured")
        return 0
    end

    self._isConfigured = true
    self = utils.makeReadOnly(self, "Dial instance")
end

---TODO desc
function Dial:update()
    if self.isSelected() then
        -- only redraw if val has changed
        if self.value ~= self._prevValue then
            gfx.pushContext(self._img)
                gfx.clear()
                gfx.drawText("*".. self.value .. " " .. self.unit .."*", 2, 2)
            gfx.popContext()
            self:setImage(self._img:scaledImage(2))
        end

        self._prevValue = self.value
        self.value = self.value + self.getDialChange() * self.step
        if self.lowerLimit and self.value <= self.lowerLimit then
            self.value = self.lowerLimit
        elseif self.upperLimit and self.value >= self.upperLimit then
            self.value = self.upperLimit
        end
    end

    Dial.super.update(self)
    --d.illustrateBounds(self)
end

--TODO needed?
function Dial:set(value)
    local low = self.lowerLimit
    local upp = self.upperLimit
    if low and value < low then
        self.value = low
    elseif upp and value > upp then
        self.value = upp
    else
        self.value = value
    end
    d.log(self.name .. " duration set to " .. value)
end

-- pkg footer: pack and export the namespace.
local _ENV = _G
dial = utils.makeReadOnly(P)
return dial
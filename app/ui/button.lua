--- pkg 'button' provides a button UIElement that
--- triggers an action when selected and pressed.

import 'ui/uielement'

local P = {}; local _G = _G
button = {}

local pd <const> = playdate
local gfx <const> = pd.graphics
local utils <const> = utils
local d <const> = debugger
local newVector <const> = utils.newVector
local COLOR_0 <const> = COLOR_0
local COLOR_1 <const> = COLOR_1
local COLOR_CLEAR <const> = COLOR_CLEAR
local pairs = pairs

---@class Button is a UI element governing some behaviour if selected.
--- A button, when pressed, may modify global state indicators and animate itself.
--- The scope of what it knows should otherwise be limited.
class('Button').extends(UIElement)
local Button <const> = Button

-- local consts go here

local _ENV = P
name = "button"

--- Initializes a button UIElement.
---@param coreProps table containing the following core properties, named or array-indexed:
---         'name' or 1: (string) button name for debugging
---         'w' or 2: (integer; optional) initial width, defaults to screen width
---         'h' or 3: (integer; optional) initial height, defaults to screen height
---@param invisible boolean whether to make the button invisible. Defaults to false, ie. visible
function Button:init(coreProps, invisible)
    -- TODO give each timer a name
    Button.super.init(self, coreProps)

    self._isVisible = true
    if invisible then
        self._isVisible = false
        self._img = gfx.image.new(1, 1, COLOR_CLEAR)
        self:setImage(self._img)
    end

    -- declare button behaviours, to be configured elsewhere, prob by UI Manager
    self.isPressed = function ()
        if not self._isConfigured then d.log("button '" .. self.name .. "' press criteria not set") end
        return false
    end
    self._wasPressed = false
    self.pressedAction = function ()
        if not self._isConfigured then d.log("button '" .. self.name .. "' pressedAction not set") end
    end
    self.position.offsets.pressed = nil
    self.justReleasedAction = function () end -- optional action to take when button is released, one time per press

    self._isConfigured = true
    self = utils.makeReadOnly(self, "button instance")
end

--- Updates the button UIElement.
function Button:update()
    if not Button.super.update(self) then return end
    
    if self.isSelected() then
        if self.isPressed() then
            --d.log(self.name .. " is pressed")
            local pressedOffset = newVector(0,0)
            if self.position.offsets.pressed then pressedOffset = self.position.offsets.pressed
            elseif self.position.offsets.selected then pressedOffset = self.position.offsets.selected
            end

            self:reposition(self:getPointPosition(), self.position.default + pressedOffset)
            self.position._arrivalCallback = self.pressedAction
            self._wasPressed = true
        elseif self._wasPressed then
            self:reposition(self:getPointPosition(), self.position.default)
            self.position._arrivalCallback = self.justReleasedAction
            self._wasPressed = false
        end
    end
    --d.illustrateBounds(self)
end

local _ENV = _G
button = utils.makeReadOnly(P)
return button
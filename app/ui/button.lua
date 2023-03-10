--- pkg 'button' provides a button UIElement that
--- triggers an action when selected and pressed.

import 'ui/uielement'

local P = {}; local _G = _G
button = {}

local pd <const> = playdate
local gfx <const> = pd.graphics
local utils <const> = utils
local d <const> = debugger

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
        self._img = gfx.image.new(1,1)
        self:setImage(self._img)
    end

    -- declare button behaviours, to be configured elsewhere, prob by UI Manager
    self.isPressed = function ()
        if not self._isConfigured then d.log("button '" .. self.name .. "' press criteria not set") end
        return false
    end
    self.pressedAction = function ()
        if not self._isConfigured then d.log("button '" .. self.name .. "' pressedAction not set") end
    end

    if self._isVisible then
        self:setLabel(self.name)
    end

    self._isConfigured = true
    self = utils.makeReadOnly(self, "button instance")
end

--- Updates the button UIElement.
function Button:update()
    if self.isSelected() then
        if self._isVisible then
            self:setImage(self._img:invertedImage()) --invert img when button is selected
        end
        if self.isPressed() then
            --d.log(self.name .. " is pressed")
            self.pressedAction()
        end 
    else
        self:setImage(self._img) --revert img when button is not selected
    end
    Button.super.update(self)
    --debugger.bounds(self)
end

--- Set the label to show on the button
---@param label string
function Button:setLabel(label)
    gfx.pushContext(self._img)
        gfx.clear()
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(self:getBounds())
        gfx.setColor(gfx.kColorBlack)
        gfx.drawText("*"..label.."*", 2, 2) -- TODO refactor
    gfx.popContext()
end

local _ENV = _G
button = utils.makeReadOnly(P)
return button
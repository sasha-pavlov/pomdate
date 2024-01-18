--- pkg 'button' provides a button UIElement that
--- triggers an action when selected and pressed.
button = {}
local _G = _G

import 'ui/uielement'
import 'ui/middleware/lock'

local pd <const> = playdate
local gfx <const> = pd.graphics
local utils <const> = utils
local d <const> = debugger
local newVector <const> = utils.newVector
local getPrevState <const> = getPrevState
local COLOR_0 <const> = COLOR_0
local COLOR_1 <const> = COLOR_1
local COLOR_CLEAR <const> = COLOR_CLEAR
local pairs = pairs
local Lock <const> = Lock

---@class Button is a UI element governing some behaviour if selected.
--- A button, when pressed, may modify global state indicators and animate itself.
--- The scope of what it knows should otherwise be limited.
class('Button').extends(UIElement)
local Button <const> = Button
local _ENV = button
name = "button"

--- Initializes a button UIElement.
---@param configs table adhering to the format of uielement.getDefaultConfigs().
---                 Note that Button will override configs.isInteractable to become true.
---@param invisible boolean whether to make the button invisible. Defaults to false, ie. visible
function Button:init(configs, invisible)
    -- TODO give each timer a name
    configs.isInteractable = true
    Button.super.init(self, configs)

    self._isVisible = true
    if invisible then
        self._isVisible = false
        self._img = gfx.image.new(1, 1, COLOR_CLEAR)
        self:setImage(self._img)
    end

    -- declare button behaviours, to be configured elsewhere, prob by UI Manager
    --- Determines if this button is selected, ie. "focused on".
    ---@return boolean true iff the button's selection criteria are met
    self.isSelected = function()
        if not self._isConfigured then d.log("button '" .. self.name .. "' select criteria not set") end
        return true
    end
    self._wasSelected = false -- isSelected() was true on previous update
    --- Called once each time a deselected button becomes selected
    self.justSelectedAction = function () end
    --- Called once each time selected button becomes deselected
    self.justDeselectedAction = function () end

    --- Determines if this button is pressed.
    ---@return boolean true iff the button's press criteria are met.
    self.isPressed = function ()
        if not self._isConfigured then d.log("button '" .. self.name .. "' press criteria not set") end
        return false
    end
    self._wasPressed = false
    self.pressedAction = function ()
        if not self._isConfigured then d.log("button '" .. self.name .. "' pressedAction not set") end
    end
    self.position.offsets.pressed = newVector(0,0)
    self.justReleasedAction = function () end -- optional action to take when button is released, one time per press

    self.dependableActions.pressed = "pressed"
    local lock = Lock(self.name .. "IsPressed")
    self:lockWhile(self.dependableActions.pressed, lock)
    self:addInteractivityCondition(lock.checkIfUnlocked)

    self._isConfigured = true
end

--- Updates the button UIElement.
function Button:update()
    Button.super.update(self)

    if not self._isInteractable then return end
    if self.isSelected() then
        local selectedPosition = self.position.default
        if self.position.offsets.selected then selectedPosition = selectedPosition + self.position.offsets.selected end

        if not self._wasSelected then
            self.justSelectedAction()
            self:reposition(self:getPointPosition(), selectedPosition)
        end
        self._wasSelected = true

        if self.isPressed() then
            d.log(self.name .. " is pressed")
            self:_lockDependents(self.dependableActions.pressed)

            if not self._wasPressed then
                if self.sounds.touched then self.sounds.touched:play(1) end
            end
            
            local reverses = false
            if self.position.options.pressed and self.position.options.pressed.reverses then reverses = true end

            self:reposition(
                self:getPointPosition(),
                selectedPosition + self.position.offsets.pressed,
                function ()
                    if self.sounds.clicked then self.sounds.clicked:play(1) end
                    self.pressedAction()
                    self:_unlockDependents(self.dependableActions.pressed)
                end,
                reverses)
            self._wasPressed = true
        elseif self._wasPressed then
            if self.sounds.held then self.sounds.held:stop() end
            self:reposition(self:getPointPosition(), selectedPosition, self.justReleasedAction)
            self._wasPressed = false
        end
    else
        --TODO POTENTIAL BUG if crank circuit B switch is fucky, the problem is probs that:
        -- the button is being locked until it completes animation, so this line is not being reached until posn anim finishes
        if self._wasSelected then
            self.justDeselectedAction()
            self:reposition(self:getPointPosition(), self.position.default)
        end
        self._wasSelected = false
    end
    --d.illustrateBounds(self)
end

local _ENV = _G
return button
--- pkg 'uielement' provides an abstract class for interactive
--- UI sprites.
--- TODO may want to add justSelected and justDeselected to
---     improve efficiency and permit custom anims

import 'CoreLibs/easing'
import 'CoreLibs/animator'
import 'ui/switch'

-- pkg header: define pkg namespace
local P = {}; local _G = _G
uielement = {}

local pd <const> = playdate
local gfx <const> = pd.graphics
local utils <const> = utils
local d <const> = debugger
local newVector <const> = utils.newVector
local newPoint <const> = utils.newPoint
local Switch <const> = Switch
local type <const> = type
local pairs <const> = pairs
local ipairs <const> = ipairs
local insert <const> = table.insert
local centered = kTextAlignment.center

local W_SCREEN <const> = W_SCREEN
local H_SCREEN <const> = H_SCREEN
local COLOR_CLEAR <const> = COLOR_CLEAR
local ANIM_DURATION <const> = UI_ANIM_DURATION / 400
local ANIM_DELAY <const> = UI_ANIM_DELAY

-- configure UIElement position transformation math here
-- For all easing functions: func(t,b,c,d) => r
-- t = elapsed time
-- b = val at beginning
-- c = change == val at ending - beginning
-- d = duration (total time)
-- r = next value
local ease <const> = pd.easingFunctions.linear

--- UIElement is an interactive sprite that can parent other UIElements.
--- It can be an abstract class for more specialized UI components, or
---     be the template for simple UIElement objects such as groups/"folders".
class('UIElement').extends(gfx.sprite)
local UIElement <const> = UIElement
local _ENV = P -- enter pkg namespace
name = "uielement"

--- Initializes a new UIElement sprite.
---@param coreProps table containing the following core properties, named or array-indexed:
---         'name' or 1: (string) button name for debugging
---         'w' or 2: (integer; optional) initial width, defaults to screen width
---         'h' or 3: (integer; optional) initial height, defaults to screen height
function UIElement:init(coreProps)
    UIElement.super.init(self)
    self:setCenter(0, 0) --anchor top-left

    -- unpack coreProps
    local name, w, h
    if coreProps then
        if coreProps.name then
            name = coreProps.name
        elseif coreProps[1] then
            name = coreProps[1]
        end

        if coreProps.w then
            w = coreProps.w
        elseif coreProps[2] then
            w = coreProps[2]
        end

        if coreProps.h then
            h = coreProps.h
        elseif coreProps[3] then
            h = coreProps[3]
        end
    end
    if not name or name == "" or type(name) ~= 'string' then
        name = "unnamed-UIElement"
    end
    if not w or w == 0 or type(w) ~= 'number' then
        w = W_SCREEN
    end
    if not h or h == 0 or type(h) ~= 'number' then
        h = H_SCREEN
    end
    w = w // 1 -- ensure int
    h = h // 1
    self.name = name

    -- position props
    self._posn = {
        default = newPoint(200, 100),
        offsets = {
            disabled = newVector(0, 0),
            selected = newVector(0, 0)
        },
        animator = nil, -- gfx.animator that is currently performing repositioning
        arrivalCallback = function() end  -- call this function when the element completes repositioning
    }

    -- visualization props
    self._font = gfx.getFont()
    self._textDrawMode = gfx.kDrawModeCopy
    self._text = nil
    self._bg = nil      -- background
    self._fg_pic = nil  -- non-text foreground
    self._fg_text = nil -- text foreground
    self._img = gfx.image.new(w, h, COLOR_CLEAR)
    self:setImage(self._img)

    --TODO _isConfigured should be a table of checks since many things need configuring
    self._isConfigured = false
    local configWarningComplete = false
    --- Log, once, that the UIElement not had been configured.
    --- Can optionally call in update(). Or ignore completely.
    self._checkConfig = function()
        if not self._isConfigured and not configWarningComplete then
            d.log("uielement '" .. self.name .. "'' not configured")
            configWarningComplete = true
        end
    end

    self._parent = "nil"    -- this backref should only be used in debugging
    self._children = {}     -- list of UIElements this panel parents
    self._i_selectChild = 1 -- index of currently selected child

    --- Determines if this UIElement is selected, ie. "focused on".
    ---@return boolean true if the element's selection criteria are met
    self.isSelected = function()
        if not self._isConfigured then d.log("uielement '" .. self.name .. "' select criteria not set") end
        return true
    end
    self._wasSelected = false -- isSelected() was true on previous update

    --- Enables/disables this UIElement.
    --- If setEnablingCriteria() is not called on this element, it will remain disabled by default.
    self._switch = Switch(self)
    self._switch.shouldClose = function()
        if not self._isConfigured then d.log("uielement '" .. self.name .. "' disabled! Set enabling conditions.") end
        return false
    end
    self._switch:add()
    self._deferringRemove = false -- element is in the process of transitioning into removal

    --- Prepare the text, to later be drawn onto the element by redraw().
    self.renderText = function()
        if not self._isConfigured then d.log("uielement " .. self.name .. "text rendering not set") end
        if not self._text then d.log("no text to render on " .. self.name) return end
        local w, h = self:getSize()
        if not self._fg_text then
            self._fg_text = gfx.image.new(w, h, COLOR_CLEAR)
        end
        
        gfx.pushContext(self._fg_text)
            gfx.setColor(COLOR_CLEAR)
            gfx.fillRect(0, 0, w, h) --TODO would be nice to call gfx.clear() instead
            gfx.setFont(self._font)
            gfx.setImageDrawMode(self._textDrawMode)
            gfx.drawTextAligned(self._text, w/2, (h - self._font:getHeight())/2, centered)
        gfx.popContext()
    end
end

--- Drives the element.
---@return boolean whether the element should take up user input this frame.
function UIElement:update()
    UIElement.super.update(self)

    -- handle animation to position on screen, depending on state of UI
    if self:isSelected() then
        if not self._wasSelected then
            self:reposition(self._posn.default + self._posn.offsets.selected)
        end
        self._wasSelected = true
    else
        if self._wasSelected then
            self:reposition(self._posn.default)
        end
        self._wasSelected = false
    end

    if self._posn.animator then
        if self._posn.animator:ended() then
            self._posn.arrivalCallback()
            self._posn.arrivalCallback = function() end
            self._posn.animator = nil
        end
        return false
    else return true end
end

--- Redraw the UIElement's background and foreground onto its sprite.
function UIElement:redraw()
    gfx.pushContext(self._img)
        gfx.setColor(COLOR_CLEAR)
        gfx.fillRect(0, 0, self.width, self.height)
        if self._bg then self._bg:draw(0, 0) end
        if self._fg_pic then self._fg_pic:draw(0, 0) end
        if self._text then
            self.renderText()
            self._fg_text:draw(0, 0)
        end
    gfx.popContext()
end

--- Set the font and color to use for drawing foregrounded text in this element.
---@param font gfx.font
---@param drawMode gfx.kDrawMode[mode] (optional)
function UIElement:setFont(font, drawMode)
    self._font = font
    self._textDrawMode = drawMode
    self:redraw()
end

--- Draw an image, matching the UIElement's proportions if appropriate.
---@param self UIElement
---@param drawable gfx.nineSlice, OR
---                  function in the drawInRect(width, height) format
---@return gfx.image
local function renderDrawable(self, drawable)
    local w, h = self:getSize()
    local draw = function(width, height) end

    if type(drawable) == 'function' then
        draw = drawable
    elseif drawable.drawInRect then
        if drawable.getSize then
            local w_d, h_d = drawable:getSize()
            if w_d >= w or h_d >= h then
                d.log("can't stretch nineSlice for " .. self.name)
                return
            end
        end
        draw = drawable.drawInRect
    else
        d.log("img for " .. self.name .. "not drawable")
    end

    local img = gfx.image.new(w, h, COLOR_CLEAR)
    gfx.pushContext(img)
        draw(w, h)
    gfx.popContext()
    return img
end

--- Set a foreground image, which will sit above the element's background but below its text.
--- Foreground may need to be redrawn into self._img by extending classes.
---@param drawable gfx.nineSlice, OR
---                  function in the drawInRect(width, height) format
function UIElement:setPicture(drawable)
    self._fg_pic = renderDrawable(self, drawable)
    self:redraw()
end

--- Set a background for UIElement contents to be drawn on top of.
--- Background may need to be redrawn into self._img by extending classes.
---@param drawable gfx.nineSlice, OR
---                  function in the drawInRect(width, height) format
function UIElement:setBackground(drawable)
    self._bg = renderDrawable(self, drawable)
    self:redraw()
end

--- Set the element's default position on the screen when the element is visible.
--- To configure behaviour-specific relocation animations, see offsetPositions()
---@param point pd.geometry.point default position on the screen
function UIElement:setPosition(point)
    if point then
        self._posn.default = point
    end
end

--- Configure the relocation of the element upon change in state/behaviour.
--- If an offset of a given name already exists for this element, the new vector will
---     be added to it, rather than overriding it entirely.
--- Thus you may wish to call resetOffsets() priorly.
---@param vectors table of pd.geometry.vector2D indexed by name, ex. "disabled", "selected"
function UIElement:offsetPositions(vectors)
    if vectors and type(vectors) == "table" then
        for name, v in pairs(vectors) do
            v_o = self._posn.offsets[name]
            if not v_o then v_o = newVector(0,0) end
            self._posn.offsets[name] = v_o + v
        end
    end
end

--- Reset position offset(s) to the zero vector.
---@param offsets string OR array of string offset names, ex. {"disabled", "selected"}
function UIElement:resetOffsets(names)
    local zero = newVector(0,0)
    if type(names) == 'table' then
        for _, name in ipairs(offsets) do
            if self._posn.offsets[name] then self._posn.offsets[name] = zero end
        end
    elseif type(names) == 'string' then
        if self._posn.offsets[names] then self._posn.offsets[names] = zero end
    end
end

--- Animate element into a new position
---@param destination pd.geometry.point
---@param origin pd.geometry.point (optional) defaults to current position
function UIElement:reposition(destination, origin)
    if not origin then origin = newPoint(self:getPosition()) end
    self._posn.animator = gfx.animator.new(
        ANIM_DURATION * origin:distanceToPoint(destination), --TODO need to make this val tiny
        origin, destination, ease, ANIM_DELAY
    )
    self:setAnimator(self._posn.animator)
end

--- Parents another UIElement.
---@param e table of child UIElements, or a single UIElement
---@param parentEnables boolean (option) child is enabled/disabled when parent is enabled/disabled
---@return table of successfully added child UIElements
---SPEC EFFECT  overrides each child's ZIndex to be relative to parent above its new parent
function UIElement:addChildren(e, parentEnables)
    if not e or type(e) == 'boolean' then
        d.log("no children to add to " .. self.name)
        return {}
    end

    local newChildren = {}
    local function addChild(element)
        if not element:isa(UIElement) then
            local name = element.name
            if not name then name = 'no_name' end
            d.log("element " .. name .. " is not a UIElement; can't be child to " .. self.name)
            return
        end

        element._parent = self
        insert(self._children, element)
        insert(newChildren, element)
        if parentEnables then
            element:setEnablingCriteria(function() return self:isEnabled() end)
        end
        element:moveTo(self.x + element.x, self.y + element.y) --TODO offsetPositions({"parent" = self._posn.default})
        element:setZIndex(element:getZIndex() + self:getZIndex())
    end

    if e.isa then
        addChild(e)           -- a single playdate Object
    else
        for _, element in pairs(e) do
            addChild(element)
        end
    end
    return newChildren
end

--- Add element to global sprites list and animate it into position.
function UIElement:add()
    UIElement.super.add(self)
    self:reposition(self._posn.default, self._posn.default + self._posn.offsets.disabled)
end

function UIElement:remove()
    self:reposition(self._posn.default + self._posn.offsets.disabled)
    self._posn.arrivalCallback = function()
        UIElement.super.remove(self)
        self._wasSelected = false
    end
end

--- Moves the UIElement and its children
---@param xOrP integer x-position OR pd.geometry.point OR pd.geometry.vector2D
---@param y integer y-position
---@param dontMoveChildren boolean (optional) false by default, set to true if children should be left in position
---@return integer,integer new coordinates (x1,y1) of the top-left corner
---@return integer,integer new coordinates (x2,y2) of the bottom-right corner
function UIElement:moveTo(xOrP, y, dontMoveChildren)
    local x_o, y_o = self:getPosition()
    local x = xOrP
    if type(xOrP) ~= "number" then
        x = xOrP.x
        y = xOrP.y
    end
    UIElement.super.moveTo(self, x, y)

    if not dontMoveChildren and self._children then
        for _, child in ipairs(self._children) do
            -- globally reposition child, keeping local posn (ie. distance from parent's prev locn)
            child:moveTo(self.x + child.x - x_o, self.y + child.y - y_o)
        end
    end

    return x, y, x + self.width, y + self.height
end

--- Set the Z index for the UIElement.
--- Its children will also be re-indexed,
---     but they will retain their zIndex *relative to* this parent element
---     and one another.
---@param z integer the value to set Z to
function UIElement:setZIndex(z)
    UIElement.super.setZIndex(self, z)
    if self._children then
        for _, child in ipairs(self._children) do
            child:setZIndex(child:getZIndex() + z)
        end
    end
end

--- Forcefully flag the UIElement as having been configured, supressing related warnings.
function UIElement:forceConfigured()
    self._isConfigured = true
end

--- Set the conditions under which this UIElement should be visible and enabled
---@param conditions function that returns a boolean if the conditions have been met
function UIElement:setEnablingCriteria(conditions)
    if type(conditions) ~= 'function' then
        d.log(self.name .. "-enabling conditions must be func", conditions)
        return
    end

    -- existing switch will be garbage-collected
    if self._switch then self._switch:remove() end
    self._switch = Switch(self)
    self._switch.shouldClose = conditions
    self._switch:add()
end

function UIElement:isEnabled()
    --if self._switch.isClosed then d.log(self.name .. " is enabled.") end
    return self._switch.isClosed
end

-- pkg footer: pack and export the namespace.
local _ENV = _G
uielement = utils.makeReadOnly(P)
return uielement

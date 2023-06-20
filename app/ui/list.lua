--- pkg 'list' provides a list UIElement, which can list other UIElements within it,
---     and may enable the user to select between items in the list.

import 'ui/uielement'

local P = {}; local _G = _G
list = {}

local pd <const> = playdate
local gfx <const> = pd.graphics
local utils <const> = utils
local d <const> = debugger
local newPoint <const> = utils.newPoint
local ipairs <const> = ipairs
local abs <const> = math.abs
local type <const> = type

local AXES <const> = AXES
local UP <const> = pd.kButtonUp
local DOWN <const> = pd.kButtonDown
local LEFT <const> = pd.kButtonLeft
local RIGHT <const> = pd.kButtonRight

--- List is a UI element that arranges its children in a
--- sequence that can be navigated with directional buttons.
class('List').extends(UIElement)
local List <const> = List
local _ENV = P
name = "list"
local Class = List

orientations = {
    horizontal = 1,
    vertical = 2
}

--      bug in current app is caused by the text not fitting in the list
--- Initializes a list UIElement.
---@param coreProps table containing the following core properties, named or array-indexed:
---         'name' or 1: (string) button name for debugging
---         'w' or 2: (integer; optional) initial width, defaults to screen width
---         'h' or 3: (integer; optional) initial height, defaults to screen height
---@param orientiation enum (optional) member of list.orientations. Defaults to vert.
---@param spacing integer (optional) number of pixels between UIElements (this list & its children)
function List:init(coreProps, orientiation, spacing)
    if not spacing or type(spacing) ~= 'number' then spacing = 0 end
    List.super.init(self, coreProps)

    self._spacing = spacing
    self._orientation = orientiation
    self._nextLocalX = nil -- next available x pos, relative to this List's top-left corner
    self._nextLocalY = nil -- next available y pos, relative to this List's top-left corner

    -- orientation-based orientations
    -- could be split into orientation-specific subclasses,
    --      but atm I don't want to spare the extra __index lookup
    if self._orientation == orientations.horizontal then
        self._inputPrev = LEFT
        self._inputNext = RIGHT
        --- Prepare the next available position in the list
        ---@param x2 integer bottom-right corner of most recent child
        ---@param y2 integer bottom-right corner of most recent child
        self._setNextLocalXY = function(x2, y2)
            self._nextLocalX = x2 + self._spacing
            self._nextLocalY = self.position.default.y + self._spacing
        end
    else -- default to vertical layout
        self._orientation = orientations.vertical
        self._inputPrev = UP
        self._inputNext = DOWN
        --- Prepare the next available position in the list
        ---@param x2 integer bottom-right corner of most recent child
        ---@param y2 integer bottom-right corner of most recent child
        self._setNextLocalXY = function(x2, y2)
            self._nextLocalX = self.position.default.x + self._spacing
            self._nextLocalY = y2 + self._spacing
        end
    end

    self._isConfigured = true
    self = utils.makeReadOnly(self, "list instance")
end

--- Updates the list sprite.
--- Cycles through its children on button-press.
--- Not all lists/list-children make use of this functionality.
--- Depends on what the children's isSelected criteria are configured to.
function List:update()
    if not utils.assertMembership(self, Class)
    or not Class.super.update(self) then return end

    if self.isSelected() then
        if pd.buttonJustPressed(self._inputPrev) then self:prev()
        elseif pd.buttonJustPressed(self._inputNext) then self:next() end
    end
    --d.illustrateBounds(self)
end

--- Parents another UIElement, .
--- No option to keep child's global posn,
---     since the list *must* control child layout.
---@specEffect overwrites children's isSelected method.
---@param e table of child UIElements, or a single UIElement
---@param parentEnables boolean (option) child is enabled/disabled when parent is enabled/disabled
---@return table of successfully added child UIElements
function List:addChildren(e, parentEnables)
    local newChildren = List.super.addChildren(self, e, parentEnables)
    local px1 = self.position.default.x
    local py1 = self.position.default.y

    if not self._nextLocalX or not self._nextLocalY then self._setNextLocalXY(px1, py1) end
    local x1    local y1    local x2    local y2
    for _, child in ipairs(newChildren) do
        child.isSelected = function ()
            return child == self._children[self._i_selectChild]
        end

        x1 = self._nextLocalX
        y1 = self._nextLocalY
        child:setPosition(x1, y1)
        child:offsetPositions({disabled = self.position.offsets.disabled})

        x2 = x1 + child.width
        y2 = y1 + child.height
        self._setNextLocalXY(x2, y2)

        --[[TODO debug this code isnt working
        local px2 = px1 + self.width
        local py2 = py1 + self.height
        if (x2 > px2 - self._spacing) or (y2 > py2 - self._spacing) then
            d.log("UIElement '" .. child.name .. "' out-of-bounds in layout. Illustrating bounds.")
            d.log("child: top-left ("..x1..", "..y1..") bottom-right ("..x2..", "..y2..")")
            d.log("parent: top-left ("..self.x..", "..self.y..") bottom-right ("..px2..", "..py2..")")
            d.illustrateBounds(self)
            d.illustrateBounds(child)
        end
        --]]
    end

    return newChildren
end

--TODO this returns floats, want int pixels
--- Get the maximum dimensions of an element that would fit 
---     in this list without triggering the 'out-of-bounds'
---     debug warning.
--- Accounts for space occupied by elements presently in the list.
--- These dimensions are not enforced anywhere; using them is suggested, 
---     but voluntary.
---@param nNewElements integer (optional) the number of identically-sized new children to 'slice' for
---@return integer maximum width
---@return integer maximum height
function List:getMaxContentDim(nNewElements)
    if not nNewElements or nNewElements == 0 then
        nNewElements = 1
    end

    local orientation = self._orientation
    local spacing = self._spacing
    local lastChild = self._lastChild

    --- Return empty space remaining after accounting for existing children in the list
    ---@return integer remaining pixels
    local function spaceAfterChildren()

        local measure = nil
        local axis = nil
        if orientation == orientations.horizontal then
            measure = "width"
            axis = "x"
        elseif orientation == orientations.vertical then
            measure = "height"
            axis = "y"
        else
            d.log("can't position along '" .. orientation .. "' dimension")
            return 0
        end

        local remaining = 0
        if lastChild then
            remaining = (self[axis] + self[measure]) - (lastChild[axis] + lastChild[measure])
        else
            remaining = self[measure]
        end
        return (remaining - spacing * (nNewElements + 1))
    end

    local available = spaceAfterChildren()
    local leftover = available % nNewElements
    if leftover ~= 0 then d.log(leftover .. " pix will be left over within " .. self.name .. " list") end

    local w = 0 ; local h = 0
    if orientation == orientations.horizontal then
        w = available // nNewElements
        h = self.height - 2 * spacing
    else
        w = self.width - 2 * spacing
        h = available // nNewElements
    end

    return w , h
end

--- Selects the next child in the list.
function List:prev()
    self._i_selectChild = (self._i_selectChild - 2) % #self._children + 1
end

--- Selects the next child in the list.
function List:next()
    self._i_selectChild = self._i_selectChild % #self._children + 1
end

local _ENV = _G
list = utils.makeReadOnly(P)
return list
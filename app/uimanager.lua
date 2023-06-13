--- pkg 'uimanager' is responsible for setting up and driving the UI
--- For dev convenience and runtime speed, this package accesses the global namespace,
---     but is not intended to modify any global vars

import 'CoreLibs/crank'
import 'CoreLibs/nineslice'
import 'ui/button'
import 'ui/list'
import 'ui/dial'
import 'ui/textbox'
import 'ui/cursor'
import 'ui/uielement'
import 'ui/animation'

--[[
    TODO 
    1. move all UI related code (ex button gen) to this file
            go slow; refactor a small part, test, repeat
    2. override key sprite class funcs such as moveTo, add, remove
        to trickle the command down to all buttons, as well as the UI superclass itself
    3. set up the other menu buttons
    4. set up the timer-state "buttons"
    5. add rough transition anims to menu, just to architect how it would work
]]--

local pd <const> = playdate
local d <const> = debugger
local gfx <const> = pd.graphics
local A <const> = pd.kButtonA
local B <const> = pd.kButtonB
local newVector <const> = utils.newVector
local newPoint <const> = utils.newPoint
local pi <const> = math.pi
local sin <const> = math.sin
local cos <const> = math.cos

local CRANKS_REVOLS_PER_HOUR <const> = 3
local WIRE_WIDTH <const> = 13
local SWITCH_LENGTH <const> = 80
local BUTTON_WIDTH_L <const> = 140        -- for a Large *horizontal* button. Use as height for vertical button
local BUTTON_HEIGHT_L <const> = 46        -- for a Large *horizontal* button. Use as width for vertical button
local BUTTON_WIDTH_M <const> = 60
local BUTTON_HEIGHT_M <const> = 32
local BUTTON_TRAVEL_DISTANCE <const> = 60
local DIAL_WIDTH <const> = 220
local DIAL_HEIGHT <const> = 140
local COUNTER_DIAMETER <const> = 15
local LINE_CAP_STYLE <const> = gfx.kLineCapStyleRound
local imgPathPrefix = "assets/ui/"

--TODO rm most of these - those that are not needed outside of specific funcs
local timersMenu = nil  -- contains the buttons for selecting timers --TODO move to init
local durationDials = {} -- visualize/manipulate timer durations --TODO move to init
-- TODO rm timerSelectButton when addTimerSelector() is implemented
local timerSelectButtons = {} -- select timer to run --TODO move to init
local pomCountDisplay = nil
local menuInst = nil -- instructions shown in MENU --TODO move to init

local toMenuButton = nil -- return to timer-select menu
local pauseButton = nil -- pause active timer
local unpauseButton = nil -- unpause active timer
local runInst = nil -- instructions shown in RUN_TIMER state --TODO move to init

local snoozeButton = nil -- invisible snooze button --TODO move to init
local doneInst = nil -- instructions shown in DONE_TIMER state --TODO move to init
local scoreboard = nil -- visualizes pause and snooze scores for this timer session

local function bakeSwitchAnimation()
    local w_frame = SWITCH_LENGTH + 10
    local h_frame = SWITCH_LENGTH + MARGIN + BUTTON_WIDTH_M/2
    local n_frames = 20
    local C = 3/4 * pi                  -- phase shift
    local x_button = 0.1 * SWITCH_LENGTH
    local y_button = SWITCH_LENGTH + MARGIN + 2

    local A = 0.8 * SWITCH_LENGTH       -- amplitude
    local radPerFrame = pi/4 / (n_frames - 1)
    local buttonTravelPerFrame = BUTTON_TRAVEL_DISTANCE / n_frames

    local switchImagetable = gfx.imagetable.new(n_frames)
    local theta     local x     local y     local i_frame
    for j = 0, n_frames - 1 do
        local frame = gfx.image.new(w_frame, h_frame, COLOR_CLEAR)
        theta = j * radPerFrame
        x = A * cos(-theta - C)
        y = A * sin(-theta - C)
        gfx.pushContext(frame)
            gfx.setColor(COLOR_1)
            gfx.setLineWidth(WIRE_WIDTH)
            gfx.setLineCapStyle(gfx.kLineCapStyleRound)
            -- draw wire from (x,y) to the unit-circle origin, transposed by (SWITCH_LENGTH, SWITCH_LENGTH)
            gfx.drawLine(x + SWITCH_LENGTH, y + SWITCH_LENGTH, SWITCH_LENGTH, SWITCH_LENGTH)
            gfx.setLineWidth(4)
            -- draw tether from the switch wire to the B button
            x = x_button + BUTTON_HEIGHT_L/2
            y = y + SWITCH_LENGTH + 5
            gfx.drawLine(x, y, x, 242)
            -- draw B button
            x = x_button
            y = y_button + j*buttonTravelPerFrame
            gfx.fillRoundRect(x, y, BUTTON_HEIGHT_L, BUTTON_WIDTH_M, BUTTON_HEIGHT_L/2)
            gfx.setImageDrawMode(gfx.kDrawModeInverted)
            gfx.drawTextAligned("B", x + BUTTON_HEIGHT_L/2, y + 10, kTextAlignment.center)
        gfx.popContext()

        i_frame = j + 1
        pd.datastore.writeImage(frame, imgPathPrefix .. "switch-table-" .. i_frame)
        switchImagetable:setImage(i_frame, frame)
    end
    

    return switchImagetable
end

--- Make and write the frames for the LED animations
---@return gfx.imagetable containing the preSwitchLED frames
---@return gfx.imagetable containing the postSwitchLED frames
local function bakeLEDAnimations()
    local period = 60                       -- period in terms of frames, rather than seconds
    local n_spokes = 5
    local w_frame = 60
    local h_frame = 60
    local A = 20                            -- amplitude, scale
    local C = pi/2                          -- phase shift

    local n_frames = (period / 2) // n_spokes  -- only show the front-facing half of the cycle
    local radPerFrame = 2 * pi / period
    local radPerSpoke = pi / n_spokes

    local preSwitchLEDImagetable = gfx.imagetable.new(n_frames)
    local postSwitchLEDImagetable = gfx.imagetable.new(n_frames)
    local theta     local x     local y     local i_frame
    for j = 0, n_frames-1 do
        local frame = gfx.image.new(w_frame, h_frame, COLOR_CLEAR)
        
        for k = 0, n_spokes-1 do
            theta = k*radPerSpoke + j*radPerFrame
            x = 6 * cos(theta - C)
            y = A * sin(theta - C) + h_frame//2
            gfx.pushContext(frame)
                gfx.setColor(COLOR_1)
                gfx.setLineCapStyle(gfx.kLineCapStyleRound)
                gfx.setLineWidth(x)
                gfx.drawLine((w_frame - x*3)/2, y, (w_frame + x*3)/2, y)
                -- Other unit circle-visualizers below
                --gfx.setLineWidth(6)
                --gfx.drawLine(2.5*w_frame - x*1.5, y, 2.5*w_frame + x*1.5, y)
                --x = A * cos(theta - C) + w_frame//2
                --gfx.drawLine(w_frame//2, h_frame//2, x, y)
                --gfx.fillCircleAtPoint(x + w_frame, y, 4)
            gfx.popContext()
        end
        
        local rotatedFrame = frame:rotatedImage(90)
        --TODO which direction should be forward?? reconfigure all dials if needed
        -- frames are saved in backwards order to match CW forwards motion
        i_frame = n_frames - j
        pd.datastore.writeImage(frame, imgPathPrefix .. "preSwitchLED-table-" .. i_frame)
        preSwitchLEDImagetable:setImage(i_frame, frame)
        pd.datastore.writeImage(rotatedFrame, imgPathPrefix .. "postSwitchLED-table-" .. i_frame)
        postSwitchLEDImagetable:setImage(i_frame, rotatedFrame)
    end
    return preSwitchLEDImagetable, postSwitchLEDImagetable
end

local function initCrankDialCircuit()
    -- These var names borrow similar-function circuitry vocab,
    --      don't necessarily represent how the sprite looks
    local wire = UIElement({"wire", 420, 140})
    local switch = Button({"switch", 60, 60})
    local preSwitchLED = Dial({"preSwitchLED", 40, 80})
    local postSwitchLED = Dial({"postSwitchLED", 80, 40})
    local function stateIsMENU() return state == STATES.MENU end --TODO these types of funcs can be declared in main, allowing hidind of state var

    local p = { -- wire junctures to draw, in crank -> dial face order
        {x=410, y=100},
        {x = X_B_BUTTON + SWITCH_LENGTH - 8},
        {x = X_B_BUTTON},
        {x=60},
        {x=40, y=80},
        {y=0}
    }
    wire:setForeground(function(x, y, width, height)
        gfx.setColor(COLOR_1)
        gfx.setLineWidth(WIRE_WIDTH)
        gfx.setLineCapStyle(LINE_CAP_STYLE)
        gfx.drawLine(p[1].x, p[1].y, p[2].x, p[1].y)
        gfx.drawLine(p[3].x, p[1].y, p[4].x, p[1].y)
        gfx.drawLine(p[4].x, p[1].y, p[5].x, p[5].y)
        gfx.drawLine(p[5].x, p[5].y, p[5].x, p[6].y)
    end)
    wire:setPosition(0, 100)
    wire:setEnablingCriteria(stateIsMENU)
    wire:forceConfigured()

    -- TODO we're searching for these files in the wrong place.
    -- They'll be saved in the app's folder in Data on the device.
    local switchImagetable = gfx.imagetable.new(imgPathPrefix .. "switch")
    if not switchImagetable then
        d.log("switch images not found; baking")
        switchImagetable = bakeSwitchAnimation()
    end
    switch:setForeground(switchImagetable)
    switch:setPosition(X_B_BUTTON - BUTTON_HEIGHT_L/4, H_SCREEN - switch.height)
    switch.isPressed = function() return pd.buttonIsPressed(B) end
    switch.pressedAction = function ()
        switch._fg_anim:play(1, 0, animation.bookmarks.last) --TODO publish uielement anims
    end
    switch.justReleasedAction = function ()
        switch._fg_anim:play(-1, 1, animation.bookmarks.first)
    end

    local preSwitchLEDImagetable = gfx.imagetable.new(imgPathPrefix .. "preSwitchLED")
    local postSwitchLEDImagetable = gfx.imagetable.new(imgPathPrefix .. "postSwitchLED")
    if not preSwitchLEDImagetable or not postSwitchLEDImagetable then
        d.log("pre- or postSwitchLED images not found; baking")
        preSwitchLEDImagetable, postSwitchLEDImagetable = bakeLEDAnimations()
    end
    preSwitchLED:setForeground(preSwitchLEDImagetable, 16)
    preSwitchLED:setPosition(350, 170)
    preSwitchLED.isSelected = function() return true end
    preSwitchLED.getDialChange = crankhandler.subscribe()
    preSwitchLED:setMode(dial.visualizers.animation)
    postSwitchLED:setForeground(postSwitchLEDImagetable, 16)
    postSwitchLED:setPosition(10, 100)
    postSwitchLED.isSelected = switch.isPressed
    postSwitchLED.getDialChange = crankhandler.subscribe()
    postSwitchLED:setMode(dial.visualizers.animation)

    wire:addChildren({switch, preSwitchLED, postSwitchLED}, 'parentEnables')
end

--TODO much of this no longer needs to be in init
-- ex. a addTimerSelector() could be called by main to add each timer selector
--      the timersMenu.
--- Initializes and returns new UIManager singleton instance.
--- If instance already exists, this func does nothing but returns that instance.
---@param timers table all Timers that the UI should support selecting,
---                 in {t, label} k-v tuples,
---                 in the sequence they should appear.
local function init(timers)
    --- Populate timersMenu with the timer-selecting/-configuring UIElements that are
    ---     to be displayed on the MENU screen.
    ---@param list List to contain the timer-selecting buttons
    ---@param timers table all Timers to make selectors for,
    ---                 in {t, label} k-v tuples,
    ---                 in the sequence they should appear.
    ---@param cursor Cursor (optional) to point to the buttons
    local function fillTimersMenu (list, timers, cursor)
        local function makeTimerSelector(t, label)
            local name = t.name

            local button = Button({name .. "Button", BUTTON_WIDTH_L, BUTTON_HEIGHT_M})
            timerSelectButtons[name] = button
            button.isPressed = function() return pd.buttonJustPressed(A) end
            button:setBackground(function(width, height)
                local w_line = 8 -- must be even
                gfx.setColor(COLOR_1)
                gfx.fillRoundRect(0, 0, width, height, height//2)
                gfx.setColor(COLOR_0)
                gfx.fillRoundRect(w_line//2, w_line//2, width - w_line, height - w_line, (height - w_line)/2)
            end)
            button:setFont(gfx.getFont())
            button:setText(label)
            button:offsetPositions({selected = newVector(-BUTTON_TRAVEL_DISTANCE, 0)})
            button.justSelectedAction = function()
                button:setImageDrawMode(gfx.kDrawModeInverted)
            end
            button.justDeselectedAction = function()
                button:setImageDrawMode(gfx.kDrawModeCopy)
            end

            if cursor then
                cursor:addTarget(button, function ()
                    return button:getConfiguredPosition("selected") + newVector(button.width + MARGIN, 0)
                end)
            end

            local dial = Dial({name .. "Dial", DIAL_WIDTH, DIAL_HEIGHT}, 1, 60)
            durationDials[name] = dial
            dial:setEnablingCriteria(function() return
                button:isEnabled()
                and button.isSelected()
            end)
            dial.isSelected = function () return pd.buttonIsPressed(B) end
            dial.getDialChange = crankhandler.subscribe(60//CRANKS_REVOLS_PER_HOUR)
            dial:setUnit("min")
            dial:setValue(initialDurations[name])
            dial:setBackground(function(width, height)
                gfx.setColor(COLOR_1)
                gfx.fillRect(0, 0, width, height)
            end)
            dial:setFont(gfx.getFont(), gfx.kDrawModeInverted)
            dial:setPosition(MARGIN, MARGIN)

            dial:setZIndex(timersMenu:getZIndex() - 10)
            -- TODO move func def below to be local func more visible at root of this file
            button.pressedAction = function ()
                toRun(t, dial.value)
            end
            return button
        end

        for _, timer in pairs(timers) do
            list:addChildren(makeTimerSelector(timer.t, timer.label), 'parentEnables')
        end
    end

    local ntimers = #timers
    timersMenu = List(
        {"timersMenu",
        BUTTON_WIDTH_L + MARGIN * 2,
        (BUTTON_HEIGHT_L + MARGIN) * ntimers + MARGIN},
        list.orientations.vertical,
        MARGIN
    )
    timersMenu:setEnablingCriteria(function () return state == STATES.MENU end)
    timersMenu.isSelected = function() return state == STATES.MENU end
    timersMenu:setPosition(W_SCREEN - (BUTTON_WIDTH_L + MARGIN*2), MARGIN)
    timersMenu:offsetPositions({disabled = newVector(BUTTON_TRAVEL_DISTANCE, 0)})

    --[[
    local cursor = Cursor({"timerSelectCursor", BUTTON_TRAVEL_DISTANCE - MARGIN, BUTTON_HEIGHT_L})
    cursor:setEnablingCriteria(function () return state == STATES.MENU end)
    cursor:setBackground(function(width, height)
        gfx.setColor(COLOR_1)
        gfx.fillRoundRect(0, 0, width, height, height/2)
    end)
    cursor:setFont(gfx.getFont(), gfx.kDrawModeInverted)
    cursor:setText("A")
    cursor:setPosition(250, MARGIN)
    cursor:offsetPositions({disabled = newVector(BUTTON_TRAVEL_DISTANCE * 2, 0)})
    cursor:setZIndex(timersMenu:getZIndex() + 10)
    cursor:forceConfigured()
    --]]

    fillTimersMenu(timersMenu, timers)


    --- Initialize a button that sits directly above the A or B buttons
    ---@param name string button name
    ---@param input A or B from the global namespace
    ---@return Button
    local function makeABButton (name, input)
        local button = Button({name .. "Button", BUTTON_HEIGHT_L, BUTTON_TRAVEL_DISTANCE - MARGIN})
        button.isPressed = function () return pd.buttonIsPressed(input) end
        button:setBackground(function(width, height)
            gfx.setColor(COLOR_1)
            gfx.fillRoundRect(0, 0, width, height, width/2)
        end)
        button:setFont(gfx.getFont(), gfx.kDrawModeInverted)
        button:setText(string.sub(name, 1, 1))
        if input == A then
            button:setPosition(X_A_BUTTON, H_SCREEN - button.height * 2/3)
        elseif input == B then
            button:setPosition(X_B_BUTTON, H_SCREEN - button.height * 2/3)
        end
        button:offsetPositions({
            disabled = newVector(0,50),
            pressed = newVector(0,50)
        })
        button:forceConfigured()
        return button
    end

    local paused = false --TODO instead of using this local var, access paused state via STATE or currentTimer.isPaused()
    
    toMenuButton = makeABButton("toMenu", B)
    toMenuButton:setEnablingCriteria(function() return
        state == STATES.RUN_TIMER
        or state == STATES.DONE_TIMER
    end)
    toMenuButton.pressedAction = function()
        paused = false
        toMenu()
    end

    pauseButton = makeABButton("pause", A)
    pauseButton:setEnablingCriteria(function() return
        state == STATES.RUN_TIMER
        and not paused
    end)
    pauseButton.pressedAction = function()
        pause()
        paused = true
    end

    unpauseButton = makeABButton("unpause", A)
    unpauseButton:setEnablingCriteria(function() return
        state == STATES.RUN_TIMER and
        paused
    end)
    unpauseButton.pressedAction = function()
        unpause()
        paused = false
    end

    snoozeButton = makeABButton("snooze", A)
    snoozeButton:setEnablingCriteria(function()
        return state == STATES.DONE_TIMER
        and confs.snoozeOn
    end)
    snoozeButton.pressedAction = function()
        snooze()
    end


    --- Initialize a score display.
    ---@param scoringFunc function that returns the score when called
    ---@return Dial new display dial
    local function makeScoreDisplay(unit, scoringFunc, width, height)
        local display = Dial({unit .. "Score", width, height})
        display.isSelected = function() return true end
        display:setUnit(unit)

        local prevScore = 0
        display.getDialChange = function()
            local currentScore = scoringFunc()
            local scoreDiff = currentScore - prevScore
            prevScore = currentScore
            return scoreDiff
        end
        return display
    end

    --[[
    --TODO redesign, then remake these score displays
    scoreboard = List({"scoreboard", 100, 80})
    scoreboard:setEnablingCriteria(function() return state == STATES.DONE_TIMER end)
    makeScoreDisplays(scoreboard, {
        pause = getPauseCount,
        snooze = getSnoozeCount
    })
    scoreboard:moveTo(300, 60)
    scoreboard:setZIndex(80)
    --]]

    local spacing = 4
    local pomCounter = gfx.image.new(COUNTER_DIAMETER, COUNTER_DIAMETER, COLOR_CLEAR)
    gfx.pushContext(pomCounter)
        gfx.setColor(COLOR_1)
        gfx.fillCircleAtPoint(COUNTER_DIAMETER//2, COUNTER_DIAMETER//2, COUNTER_DIAMETER//2)
    gfx.popContext()
    pomCountDisplay = makeScoreDisplay("pom", getPomCount,
        confs.pomsPerCycle * (COUNTER_DIAMETER + spacing), COUNTER_DIAMETER)
    pomCountDisplay:setEnablingCriteria(function ()
        return state == STATES.MENU
        and getPomCount() ~= 0
    end)
    d.log("setting mode")
    pomCountDisplay:setMode(dial.visualizers.horiCounter) -- visualize poms as counters
    pomCountDisplay:setCounter(pomCounter, spacing)
    pomCountDisplay:setPosition(MARGIN + DIAL_WIDTH - pomCountDisplay.width, MARGIN*2 + DIAL_HEIGHT)
    pomCountDisplay:setZIndex(80)

    initCrankDialCircuit()
end

--- Drives the UI. Call on pd.update().
local function update()
    switch.update()
    animation.update()
end

--- Get the value currently set on a specified dial
---@return integer minutes value on this dial, or -1 if dial is not found
local function getDialValue(name)
    local dial = durationDials[name]
    if not dial then
        d.log("dial '" .. name .. "' not known to uimanager")
        return -1
    end
    return dial.value
end

--- Force the selection of the next timer button
local function selectPrevTimer()
    timersMenu:prev()
end

--- Force the selection of the previous timer button
local function selectNextTimer()
    timersMenu:next()
end

uimanager = {
    name = "uimanager",
    init = init,
    update = update,
    getDialValue = getDialValue,
    selectPrevTimer = selectPrevTimer,
    selectNextTimer = selectNextTimer
}
uimanager = utils.makeReadOnly(uimanager)
return uimanager
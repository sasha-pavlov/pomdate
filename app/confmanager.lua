-- confmanager provides project-wide constants,
--      and it enables user configuration of some app functionality.

--TODO standardize use of conf vs setting vocab

import 'ui/list'
import 'ui/textbox'
import 'ui/button'

local pd <const> = playdate
local d <const> = debugger
local gfx <const> = pd.graphics
local A <const> = pd.kButtonA
local B <const> = pd.kButtonB
local vert <const> = list.orientations.vertical
local hori <const> = list.orientations.horizontal
local pairs <const> = pairs

local sysmenu = nil -- playdate system menu
local confMenuItem = nil
local backMenuItem = nil

--- Published as the active set of confs
local confs = {
    snoozeOn = nil,
    snoozeDuration = nil
}
local defaults = {
    snoozeOn = true,
    snoozeDuration = 2
}
local snooze_max = 10

local enter = function() d.log("conf enter func not set") end
local back = function() d.log("conf back func not set") end

function enter()
    sysmenu:removeMenuItem(confMenuItem)
    backMenuItem = sysmenu:addMenuItem("Back to app", back)
    toConf()
end

function back()
    sysmenu:removeMenuItem(backMenuItem)
    confMenuItem = sysmenu:addMenuItem("Config", enter)
    fromConf()
end

local function init()
    local margin_screen = 20
    local function stateIsCONF() return state == STATES.CONF end

    -- main will load and initialize any saved settings at startup
    -- here, we init any outstanding non-initialized settings
    for k, v in pairs(defaults) do
        if confs[k] == nil then d.log("no conf " ..k) confs[k] = v end
    end

    sysmenu = pd.getSystemMenu()
    local resetPomsMenuItem = sysmenu:addMenuItem("Reset poms", resetPomCount)
    -- The following 2 menu items will alternate
    confMenuItem = sysmenu:addMenuItem("Config", enter)
    backMenuItem = sysmenu:addMenuItem("Back to app", back)
    sysmenu:removeMenuItem(backMenuItem)

    local backButton = Button({"backFromConfButton"}, 'invisible')
    backButton:setEnablingCriteria(stateIsCONF)
    backButton.isPressed = function() return pd.buttonJustPressed(B) end
    backButton.pressedAction = back
    backButton:forceConfigured()
    local inst = Textbox({"backFromConfInst", 300, 20}, "_B returns to app_")
    inst:setEnablingCriteria(function () return backButton:isEnabled() end)
    inst:moveTo(margin_screen, H_SCREEN - margin_screen - inst.height) -- bottom of screen

    --is this table actually useful?
    local settings = {
        snoozeONF = {
            name = "snoozeONF",
            -- the keys below will be present in all setting tables
            item = nil, -- ui.list: the container to represent the setting in the confs table
            label = nil, -- ui.button: the setting description
            setter = nil -- ui element: the interactable element
        },
        savePomCountONF = { name = "savePomCountONF" },
        pomsPerLongBreak = { name = "pomsPerLongBreak" },
        snoozeDuration = { name = "snoozeDuration" },
        toWorkSound = { name = "toWorkSound" },
        toBreakSound = { name ="toBreakSound" },
        snoozeSound = { name ="snoozeSound" }
    }
    local c_settings = 0
    for _ in pairs(settings) do c_settings = c_settings + 1 end

    local w_setting, h_setting
    local w_label, h_label
    local w_labelBonus = 50
    local w_setter, h_setter

    local confList = List(
        {"confList", W_SCREEN - margin_screen*2, inst.y - 10 - margin_screen},
        vert, 2
    )
    confList:moveTo(margin_screen, margin_screen)
    w_setting, h_setting = confList:getMaxContentDim(c_settings)
    confList:setEnablingCriteria(stateIsCONF)

    local function initConfItem(setting, description)
        local item = List({setting.name, w_setting, h_setting}, hori, 1)
        w_setter, h_setter = item:getMaxContentDim(2)
        h_label = h_setter
        w_label = w_setter + w_labelBonus -- give label a bit more room
        w_setter = w_setter - w_labelBonus
        local label = Button({setting.name.."Desc", w_label, h_label})
        local setter = List({setting.name.."Setter", w_setter, h_setter}, hori, 0)
        item:addChildren({label, setter}, 'parentEnables')
        confList:addChildren(item, 'parentEnables')

        label:setLabel(description)
        label.isSelected = function() return item.isSelected() end
        label:forceConfigured() -- label only needs to hilight like a button
        setter.isSelected = function() return item.isSelected() end
        
        setting.item = item
        setting.label = label
        setting.setter = setter
    end

    initConfItem(settings.snoozeONF, "Timers can be snoozed")
    local snoozeONFSetter = settings.snoozeONF.setter
    local w_tmp, h_tmp = snoozeONFSetter:getMaxContentDim(2)
    local snoozeOnBtn = Button({"snoozeOnButton", w_tmp, h_tmp})
    snoozeOnBtn:setLabel("On")
    snoozeOnBtn.isPressed = function() return snoozeOnBtn.isSelected() end
    snoozeOnBtn.pressedAction = function() confs.snooze = true end
    local snoozeOffBtn = Button({"snoozeOffButton", w_tmp, h_tmp})
    snoozeOffBtn:setLabel("Off")
    snoozeOffBtn.isPressed = function() return snoozeOffBtn.isSelected() end
    snoozeOffBtn.pressedAction = function() confs.snooze = false end
    snoozeONFSetter:addChildren({snoozeOnBtn, snoozeOffBtn}, 'parentEnables')
    if not confs.snoozeOn then snoozeONFSetter:next() end -- toggle to loaded setting val

    --TODO need to get the snooze duration off the dial value somehow
    initConfItem(settings.snoozeDuration, "Snooze duration")
    local snoozeDurationSetter = settings.snoozeDuration.setter
    w_tmp, h_tmp = snoozeDurationSetter:getMaxContentDim()
    local snoozeDial = Dial({"snoozeDial", w_tmp, h_tmp}, 1, 1, snooze_max)
    snoozeDial.getDialChange = function ()
        return crankhandler.getCrankTicks(snooze_max)
    end
    snoozeDial:setUnit("min")
    snoozeDial:setValue(confs.snoozeDuration)
    snoozeDurationSetter:addChildren(snoozeDial, 'parentEnables')
    snoozeDial.isSelected = function () return snoozeDurationSetter.isSelected() end
end

confmanager = {
    name = "confmanager",
    confs = confs,
    init = init
}
confmanager = utils.makeReadOnly(confmanager)
return confmanager
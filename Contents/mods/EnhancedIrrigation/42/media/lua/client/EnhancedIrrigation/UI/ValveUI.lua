-- The panel a valve or timer is set from, opened by the menus' Wind Valve and Set Timer once the
-- character has walked over: the oven's timer knob (ISOvenUI), which both use for the minutes it
-- runs, so the run is picked from the knob's few stops; and for a timer the hour it starts, stepped
-- up and down as vanilla's alarm clock sets its hour (ISAlarmClockDialog). Its button queues the
-- job, which turns the knob there, greyed out saying why while the job would be refused. It closes
-- once the character walks off or the valve is gone.

require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "ISUI/Fireplace/ISKnob"
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"
require "luautils"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Valves"
require "EnhancedIrrigation/Timers"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

EnhancedIrrigation = EnhancedIrrigation or {}
local Valves = EnhancedIrrigation.Valves
local Timers = EnhancedIrrigation.Timers

local ValveUI = ISPanelJoypad:derive("EnhancedIrrigationValveUI")
EnhancedIrrigation.ValveUI = ValveUI

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local PAD = 10
local BUTTON_HGT = math.max(25, FONT_HGT_SMALL + 6)
local BUTTON_WID = 100
-- How far, in squares, the character may stand from the valve with its panel open, as the oven's.
local REACH = 3

-- The panel open for each player, by player number.
ValveUI.instances = {}

function ValveUI:initialise()
    ISPanelJoypad.initialise(self)
    local y = PAD + FONT_HGT_SMALL + PAD
    if self.spec.timer then
        local middle = self.width / 2
        self.hourUp = ISButton:new(middle + 40, y, BUTTON_HGT, BUTTON_HGT, "^", self, ValveUI.onClick)
        self.hourUp.internal = "HOUR_UP"
        self.hourDown = ISButton:new(middle + 40 + BUTTON_HGT + 4, y, BUTTON_HGT, BUTTON_HGT, "v", self, ValveUI.onClick)
        self.hourDown.internal = "HOUR_DOWN"
        for _, button in ipairs({ self.hourUp, self.hourDown }) do
            button:initialise()
            button:instantiate()
            button.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
            self:addChild(button)
        end
        self.hourY = y
        y = y + BUTTON_HGT + PAD
    end
    local background = getTexture("media/ui/Knobs/KnobBGOvenTimer.png")
    self.knob = ISKnob:new((self.width - background:getWidthOrig()) / 2, y, getTexture("media/ui/Knobs/KnobDial.png"),
        background, getText("IGUI_Timer"), self.character)
    self.knob:initialise()
    self.knob:instantiate()
    -- The oven's stops, at its angles.
    for i, minutes in ipairs(Valves.KNOB_MINUTES) do
        self.knob:addValue((i - 1) * 18, minutes)
    end
    self.knob:setKnobPosition(self.spec.minutes or 0)
    self:addChild(self.knob)
    y = self.knob:getBottom() + PAD
    self.refusalY = y
    y = y + FONT_HGT_SMALL + PAD
    self.ok = ISButton:new(PAD, y, BUTTON_WID, BUTTON_HGT, getText(self.spec.okKey), self, ValveUI.onClick)
    self.ok.internal = "OK"
    self.close = ISButton:new(self.width - BUTTON_WID - PAD, y, BUTTON_WID, BUTTON_HGT, getText("UI_Close"), self,
        ValveUI.onClick)
    self.close.internal = "CLOSE"
    for _, button in ipairs({ self.ok, self.close }) do
        button:initialise()
        button:instantiate()
        button.borderColor = { r = 1, g = 1, b = 1, a = 0.1 }
        self:addChild(button)
    end
    self:setHeight(self.close:getBottom() + PAD)
    if self.spec.timer then
        self:insertNewLineOfButtons(self.hourUp, self.hourDown)
    end
    self:insertNewLineOfButtons(self.knob)
    self:insertNewLineOfButtons(self.ok, self.close)
end

--- The job's setting the panel shows now: the knob's minutes, and for a timer its hour first.
function ValveUI:setting()
    if self.spec.timer then
        return Valves.encodeTimer(self.hour, self.knob:getValue())
    end
    return tostring(self.knob:getValue())
end

function ValveUI:prerender()
    ISPanelJoypad.prerender(self)
    self:drawTextCentre(self.spec.title, self.width / 2, PAD, 1, 1, 1, 1, UIFont.Small)
    if self.spec.timer then
        self:drawText(getText("IGUI_EnhancedIrrigation_StartsAt"), PAD, self.hourY + (BUTTON_HGT - FONT_HGT_SMALL) / 2,
            1, 1, 1, 1, UIFont.Small)
        self:drawTextRight(Timers.hourText(self.hour), self.width / 2 + 30, self.hourY + (BUTTON_HGT - FONT_HGT_SMALL) / 2,
            1, 1, 1, 1, UIFont.Small)
    end
    if self.refusal then
        self:drawTextCentre(getText(self.refusal), self.width / 2, self.refusalY, 1, 0.3, 0.3, 1, UIFont.Small)
    end
end

function ValveUI:update()
    ISPanelJoypad.update(self)
    local object, job = self.spec.object, self.spec.job
    local now = EnhancedIrrigation.onSquare(object) and self.makeSpec()
    if not (now and now.job == job) or self.character:DistTo(object:getX(), object:getY()) > REACH then
        self:destroy()
        return
    end
    local jobs = EnhancedIrrigationAction.jobsOf(self.spec.feature)
    self.refusal = jobs.blocker(self.character, job, object, self:setting())
    self.ok:setEnable(self.refusal == nil)
end

function ValveUI:onClick(button)
    if button.internal == "HOUR_UP" then
        self.hour = (self.hour + 1) % 24
    elseif button.internal == "HOUR_DOWN" then
        self.hour = (self.hour + 23) % 24
    elseif button.internal == "OK" and self.refusal == nil then
        EnhancedIrrigationAction.queue(self.playerNum, self.spec.feature, self.spec.job, self.spec.object, self:setting())
        self:destroy()
    elseif button.internal == "CLOSE" then
        self:destroy()
    end
end

-- A controller starts on the first row. Up and down turn the knob once it has focus, as the oven's
-- do, so A sets and B closes from anywhere but the hour's buttons and Close, which A presses.
function ValveUI:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self.joypadIndexY = 1
    self.joypadIndex = 1
    self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
    self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function ValveUI:onJoypadDown(button)
    local focused = self.joypadButtons and self.joypadButtons[self.joypadIndex]
    local presses = focused == self.hourUp or focused == self.hourDown or focused == self.close
    if button == Joypad.AButton and not presses then
        self:onClick(self.ok)
    elseif button == Joypad.BButton then
        self:onClick(self.close)
    else
        ISPanelJoypad.onJoypadDown(self, button)
    end
end

function ValveUI:destroy()
    self:setVisible(false)
    self:removeFromUIManager()
    if ValveUI.instances[self.playerNum] == self then
        ValveUI.instances[self.playerNum] = nil
    end
    if JoypadState.players[self.playerNum + 1] then
        setJoypadFocus(self.playerNum, nil)
    end
end

function ValveUI:new(character, spec, makeSpec)
    local width = 260
    local o = ISPanelJoypad:new(0, 0, width, 300)
    setmetatable(o, self)
    self.__index = self
    local playerNum = character:getPlayerNum()
    o.character = character
    o.playerNum = playerNum
    o.spec, o.makeSpec = spec, makeSpec
    o.hour = spec.start or 6
    o.moveWithMouse = true
    o.backgroundColor.a = 0.75
    o:setX(getPlayerScreenLeft(playerNum) + (getPlayerScreenWidth(playerNum) - width) / 2)
    o:setY(getPlayerScreenTop(playerNum) + getPlayerScreenHeight(playerNum) / 4)
    return o
end

--- Opens `character`'s panel for the valve `makeSpec()` describes as it stands now, in place of one
--- already open; it closes once makeSpec() answers nil or another job. A spec: title, the valve's
--- name; object, the tile or Pump House it is on; feature and job, the job its button queues
--- (EnhancedIrrigationAction); okKey, the button's text; timer, whether it sets a start hour;
--- start and minutes, its setting now. Returns the panel, or nil when the valve is gone.
function ValveUI.open(character, makeSpec)
    local spec = makeSpec()
    if not spec then
        return nil
    end
    local playerNum = character:getPlayerNum()
    if ValveUI.instances[playerNum] then
        ValveUI.instances[playerNum]:destroy()
    end
    local panel = ValveUI:new(character, spec, makeSpec)
    panel:initialise()
    panel:addToUIManager()
    ValveUI.instances[playerNum] = panel
    if JoypadState.players[playerNum + 1] then
        setJoypadFocus(playerNum, panel)
    end
    return panel
end

-- Opens the panel once the character stands at its object, as vanilla opens an oven's knobs
-- (ISWorldObjectContextMenu.onStoveSetting, ISOvenUITimedAction): a timed action of no length,
-- this client's alone, as it changes nothing.
local OpenAction = ISBaseTimedAction:derive("EnhancedIrrigationValveUIAction")

function OpenAction:isValid()
    return EnhancedIrrigation.onSquare(self.object)
end

function OpenAction:update()
    self.character:faceThisObject(self.object)
end

function OpenAction:start()
end

function OpenAction:perform()
    ISBaseTimedAction.perform(self)
    ValveUI.open(self.character, self.makeSpec)
end

function OpenAction:new(character, object, makeSpec)
    local o = ISBaseTimedAction.new(self, character)
    o.object, o.makeSpec = object, makeSpec
    o.maxTime = 0
    return o
end

--- Walks `character` over to `object`, then opens the panel `makeSpec()` describes there
--- (ValveUI.open), read then, so a valve taken off meanwhile opens nothing (it answers nil).
function ValveUI.walkAndOpen(character, object, makeSpec)
    if luautils.walkAdj(character, object:getSquare()) then
        ISTimedActionQueue.add(OpenAction:new(character, object, makeSpec))
    end
end

return ValveUI

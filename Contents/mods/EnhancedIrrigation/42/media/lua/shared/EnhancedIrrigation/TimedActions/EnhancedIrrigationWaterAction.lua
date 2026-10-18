require "TimedActions/ISBaseTimedAction"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/Taps"

-- Water from Tank: the character holds a garden line's tap open, and the line runs for as long as
-- they stand there, until they stop or the tank gives out. Modelled on vanilla's open-ended
-- ISAddWaterToTrough: the action has no end of its own; the authority runs the flow for the world
-- time gone by, on a timed event the multiplayer server raises itself (emulateAnimEvent), or from
-- update() in single player, and once more when it stops. One person at a time holds a tap
-- (TapSystem.hold): it frees itself however the action ends. A global, as the server finds the
-- class by its Type (NetTimedAction.parse).
EnhancedIrrigationWaterAction = EnhancedIrrigationWaterAction or ISBaseTimedAction:derive("EnhancedIrrigationWaterAction")

local Action = EnhancedIrrigationWaterAction
local Lines = EnhancedIrrigation.Lines
local Taps = EnhancedIrrigation.Taps

-- How often, in real milliseconds, the multiplayer server runs the flow while the tap is open: often
-- enough that the tank stops the action soon after it runs dry.
Action.RUN_MS = 1000
-- How often, in game minutes, single player runs it.
Action.RUN_MINUTES = 1
Action.RUN_EVENT = "EnhancedIrrigationRun"
-- Vanilla's watering-can sound. Holding a tap open costs no effort: the character just stands.
Action.SOUND = "WaterCrops"

-- The water stops at the authority: the tank ran dry or lost its head. The client hears of it as
-- the action's end.
function Action:finish()
    if isServer() then
        self.netAction:forceComplete()
    else
        self:forceComplete()
    end
end

-- Runs the line for the world time since the last run (`lastHour`, set once the tap opens).
-- Authority only.
function Action:run()
    local hours = EnhancedIrrigation.catchUp(self)
    if self.finished then
        return
    end
    EnhancedIrrigation.TapSystem.renew(self)
    if EnhancedIrrigation.TapSystem.run(self.tap, hours) then
        self.finished = true
        self:finish()
    end
end

-- Opens and holds the tap; the flow counts from here. Returns whether it opened. Authority only.
function Action:open()
    local _, refusal = Taps.tankFor(self.tap)
    if not (self:atTap() and not refusal and EnhancedIrrigation.TapSystem.hold(self.tap, self)) then
        return false
    end
    self.lastHour = EnhancedIrrigation.now()
    return true
end

-- The character let go of the tap, whatever ended the action: the last stretch runs, and the tap is
-- free for the next. Authority only.
function Action:letGo()
    if self.lastHour then
        self:run()
    end
    self.finished = true
    EnhancedIrrigation.TapSystem.release(self)
end

-- Whether the character still stands at the tap: what isValid() checks, which the server never
-- calls, so the authority asks this itself before it opens the tap and before each run.
function Action:atTap()
    return EnhancedIrrigation.withinReach(self.character, self.tap, EnhancedIrrigationAction.REACH)
end

-- The tap held open runs the line; a character who walked off let go of it. Authority only.
function Action:runHeld()
    if self.finished then
        return
    end
    if self:atTap() then
        self:run()
    else
        self.finished = true
        self:finish()
    end
end

function Action:isValid()
    return EnhancedIrrigation.onSquare(self.tap) and Lines.isLine(self.tap) and self:atTap()
end

function Action:waitToStart()
    self.character:faceThisObject(self.tap)
    return self.character:shouldBeTurning()
end

function Action:playWater()
    self.sound = self.character:playSound(Action.SOUND)
end

function Action:update()
    self.character:faceThisObject(self.tap)
    -- The watering sound is one long clip; it starts again while the tap stays open.
    if self.sound and not self.character:getEmitter():isPlaying(self.sound) then
        self:playWater()
    end
    if not isClient() and self.lastHour and not self.finished then
        local now = EnhancedIrrigation.now()
        if (now - self.lastHour) * 60 >= Action.RUN_MINUTES then
            self:runHeld()
        end
    end
end

function Action:start()
    if not isClient() and not self:open() then
        self:forceStop()
        return
    end
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self:playWater()
end

-- The server never calls isValid() or start(), so it checks the tap and the character itself
-- before it opens it.
function Action:serverStart()
    if not self:open() then
        self.finished = true
        self.netAction:forceComplete()
        return
    end
    emulateAnimEvent(self.netAction, Action.RUN_MS, Action.RUN_EVENT, nil)
end

function Action:animEvent(event, parameter)
    if isServer() and event == Action.RUN_EVENT then
        self:runHeld()
    end
end

function Action:stopSound()
    if self.sound and self.character:getEmitter():isPlaying(self.sound) then
        self.character:stopOrTriggerSound(self.sound)
    end
    self.sound = nil
end

function Action:serverStop()
    self:letGo()
end

function Action:stop()
    self:stopSound()
    if not isClient() then
        self:letGo()
    end
    ISBaseTimedAction.stop(self)
end

function Action:perform()
    self:stopSound()
    ISBaseTimedAction.perform(self)
end

function Action:complete()
    self:letGo()
    return true
end

function Action:getDuration()
    return -1
end

-- Parameter names match the fields: the multiplayer server rebuilds the action by passing them to
-- new() in order (NetTimedAction). `tap` is the line tile holding the tap.
function Action:new(character, tap)
    local o = ISBaseTimedAction.new(self, character)
    o.tap = tap
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

--- Walks `playerNum`'s character to the tap tile `tap` and opens it. Client only.
function Action.queue(playerNum, tap)
    local character = getSpecificPlayer(playerNum)
    if luautils.walkAdj(character, tap:getSquare(), true) then
        ISTimedActionQueue.add(Action:new(character, tap))
    end
end

return Action

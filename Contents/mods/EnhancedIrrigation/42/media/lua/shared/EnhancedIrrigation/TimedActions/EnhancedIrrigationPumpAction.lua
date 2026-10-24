require "TimedActions/ISBaseTimedAction"
require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationAction"

-- Pump: the character works a hand pump's handle, and it lifts water into its outlet's tank, or
-- drives the line its outlet feeds, for as long as they keep at it, until they stop, the tank is
-- full, the source runs dry, the seal or the pump wears out, or they are exhausted. Open-ended as
-- Water from Tank (EnhancedIrrigationWaterAction.lua) is: the authority runs the pump for the world
-- time gone by, on a timed event the multiplayer server raises itself (emulateAnimEvent), or from
-- update() in single player, and once more when it stops. The action holds the pump while it works
-- (PumpSystem.hold): it frees itself however the action ends. A global, as the server finds the
-- class by its Type (NetTimedAction.parse).
EnhancedIrrigationPumpAction = EnhancedIrrigationPumpAction or ISBaseTimedAction:derive("EnhancedIrrigationPumpAction")

local Action = EnhancedIrrigationPumpAction
local Pumps, PumpJobs = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs

-- How often, in real milliseconds, the multiplayer server runs the pump while it is worked: often
-- enough that a full tank stops the character soon after. Read as the action starts.
Action.RUN_MS = 1000
-- How often, in game minutes, single player runs it.
Action.RUN_MINUTES = 1
Action.RUN_EVENT = "EnhancedIrrigationPump"
-- Water splashing into the spout's bucket as vanilla's tap plays it, and the wooden pump's squeal
-- (Sounds.txt), each started again while the work goes on.
Action.WATER_SOUND = "GetWaterFromTap"
Action.SQUEAL_SOUND = "EnhancedIrrigationPumpSqueal"

-- The work stops at the authority. The client hears of it as the action's end.
function Action:finish()
    if isServer() then
        self.netAction:forceComplete()
    else
        self:forceComplete()
    end
end

-- Runs the pump for the world time since the last run (`lastHour`, set once the work starts).
-- Authority only.
function Action:run()
    local hours = EnhancedIrrigation.hoursSince(self)
    if self.finished then
        return
    end
    EnhancedIrrigation.Holds.renew(self)
    if EnhancedIrrigation.PumpSystem.pump(self.character, self.pump, hours) then
        self.finished = true
        self:finish()
    end
end

-- Whether the character still stands at the pump: what isValid() checks, which the server never
-- calls, so the authority asks this itself before it starts and before each run.
function Action:atPump()
    return EnhancedIrrigationAction.withinReach(self.character, self.pump, EnhancedIrrigationAction.REACH)
end

-- Starts the work, holding the pump; the water counts from here. Returns whether it started.
-- Authority only.
function Action:open()
    if not (self:atPump() and not PumpJobs.refusal(self.character, PumpJobs.PUMP, self.pump)
            and EnhancedIrrigation.PumpSystem.hold(self.pump, self)) then
        return false
    end
    self.lastHour = EnhancedIrrigation.now()
    return true
end

-- The character let go of the handle, whatever ended the action: the last stretch runs, and the
-- pump is free. Authority only.
function Action:letGo()
    if self.lastHour and not self.finished then
        self:run()
    end
    self.finished = true
    EnhancedIrrigation.Holds.release(self)
end

-- The handle worked lifts water; a character who walked off stopped working it. Authority only.
function Action:runHeld()
    if self.finished then
        return
    end
    if self:atPump() then
        self:run()
    else
        self.finished = true
        self:finish()
    end
end

function Action:isValid()
    return EnhancedIrrigation.onSquare(self.pump) and Pumps.isPump(self.pump) and self:atPump()
end

function Action:waitToStart()
    self.character:faceThisObject(self.pump)
    return self.character:shouldBeTurning()
end

-- Starts `field`'s sound `name` again once it ends.
function Action:keepPlaying(field, name)
    if not (self[field] and self.character:getEmitter():isPlaying(self[field])) then
        self[field] = self.character:playSound(name)
    end
end

function Action:playSounds()
    self:keepPlaying("sound", Action.WATER_SOUND)
    if Pumps.specOf(self.pump).squeals then
        self:keepPlaying("squeal", Action.SQUEAL_SOUND)
    end
end

function Action:update()
    self.character:faceThisObject(self.pump)
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
    if self.sound then
        self:playSounds()
    end
    if not isClient() and self.lastHour and not self.finished then
        if (EnhancedIrrigation.now() - self.lastHour) * 60 >= Action.RUN_MINUTES then
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
    self.character:SetVariable("LootPosition", "Mid")
    self:playSounds()
end

-- The server never calls isValid() or start(), so it checks the pump and the character itself
-- before the work starts.
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

function Action:stopSounds()
    for _, field in ipairs({ "sound", "squeal" }) do
        if self[field] and self.character:getEmitter():isPlaying(self[field]) then
            self.character:stopOrTriggerSound(self[field])
        end
        self[field] = nil
    end
end

function Action:serverStop()
    self:letGo()
end

function Action:stop()
    self:stopSounds()
    if not isClient() then
        self:letGo()
    end
    ISBaseTimedAction.stop(self)
end

function Action:perform()
    self:stopSounds()
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
-- new() in order (NetTimedAction). `pump` is the hand pump worked.
function Action:new(character, pump)
    local o = ISBaseTimedAction.new(self, character)
    o.pump = pump
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = o:getDuration()
    return o
end

--- Walks `playerNum`'s character to the pump `pump` and works it. Client only.
function Action.queue(playerNum, pump)
    local character = getSpecificPlayer(playerNum)
    if luautils.walkAdj(character, pump:getSquare(), true) then
        ISTimedActionQueue.add(Action:new(character, pump))
    end
end

return Action

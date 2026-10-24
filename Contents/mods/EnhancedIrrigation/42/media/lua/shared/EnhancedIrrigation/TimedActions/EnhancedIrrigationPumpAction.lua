require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationHeldAction"

-- Pump: the character works a hand pump's handle, and it lifts water into its outlet's tank, or
-- drives the line its outlet feeds, for as long as they keep at it, until they stop, the tank is
-- full, the source runs dry, the seal or the pump wears out, or they are exhausted.
EnhancedIrrigationPumpAction = EnhancedIrrigationPumpAction or EnhancedIrrigationHeldAction:derive("EnhancedIrrigationPumpAction")

local Action = EnhancedIrrigationPumpAction
local Pumps, PumpJobs = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs

Action.RUN_EVENT = "EnhancedIrrigationPump"
Action.LOOT_POSITION = "Mid"
Action.HEAVY = true
-- Water splashing into the spout's bucket as vanilla's tap plays it, and the wooden pump's squeal
-- (Sounds.txt).
Action.WATER_SOUND = "GetWaterFromTap"
Action.SQUEAL_SOUND = "EnhancedIrrigationPumpSqueal"

function Action:target()
    return self.pump
end

function Action:isTarget(object)
    return Pumps.isPump(object)
end

function Action:refusal()
    return PumpJobs.refusal(self.character, PumpJobs.PUMP, self.pump)
end

function Action:hold()
    return EnhancedIrrigation.PumpSystem.hold(self.pump, self)
end

function Action:runFor(hours)
    return EnhancedIrrigation.PumpSystem.pump(self.character, self.pump, hours)
end

function Action:playSounds()
    self:keepPlaying(Action.WATER_SOUND)
    if Pumps.specOf(self.pump).squeals then
        self:keepPlaying(Action.SQUEAL_SOUND)
    end
end

-- Parameter names match the fields: the multiplayer server rebuilds the action by passing them to
-- new() in order (NetTimedAction). `pump` is the hand pump worked.
function Action:new(character, pump)
    local o = ISBaseTimedAction.new(self, character)
    o.pump = pump
    return o
end

--- Walks `playerNum`'s character to the pump `pump` and works it. Client only.
function Action.queue(playerNum, pump)
    Action:queueAt(playerNum, pump)
end

return Action

require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/Taps"
require "EnhancedIrrigation/TimedActions/EnhancedIrrigationHeldAction"

-- Water from Tank: the character holds a garden line's tap open, and the line runs for as long as
-- they stand there, until they stop or the tank gives out. One person at a time holds a tap
-- (TapSystem.hold).
EnhancedIrrigationWaterAction = EnhancedIrrigationWaterAction or EnhancedIrrigation.HeldAction:derive("EnhancedIrrigationWaterAction")

local Action = EnhancedIrrigationWaterAction
local Lines = EnhancedIrrigation.Lines
local Taps = EnhancedIrrigation.Taps

Action.RUN_EVENT = "EnhancedIrrigationRun"
-- Holding a tap open costs no effort: the character just stands.
Action.LOOT_POSITION = "Low"

function Action:target()
    return self.tap
end

function Action:isTarget(object)
    return Lines.isLine(object)
end

function Action:refusal()
    local _, refusal = Taps.tankFor(self.tap)
    return refusal
end

function Action:hold()
    return EnhancedIrrigation.TapSystem.hold(self.tap, self)
end

function Action:runFor(hours)
    return EnhancedIrrigation.TapSystem.run(self.tap, hours)
end

function Action:playSounds()
    self:keepPlaying(Taps.SOUND)
end

-- `tap` is the line tile holding the tap.
function Action:new(character, tap)
    local o = ISBaseTimedAction.new(self, character)
    o.tap = tap
    return o
end

--- Walks `playerNum`'s character to the tap tile `tap` and opens it. Client only.
function Action.queue(playerNum, tap)
    Action:queueAt(playerNum, tap)
end

return Action

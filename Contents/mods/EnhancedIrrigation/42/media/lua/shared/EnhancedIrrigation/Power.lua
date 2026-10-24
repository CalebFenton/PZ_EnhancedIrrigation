-- Power as vanilla gives an appliance, and what a gap caught up after a wait ran on.

require "EnhancedIrrigation/Utilities"

EnhancedIrrigation = EnhancedIrrigation or {}
local Power = {}
EnhancedIrrigation.Power = Power

--- Whether the grid powers `object` now: before the shutoff, and in a room or beside one
--- (ItemContainer.isSquarePowered), as it powers a washer.
function Power.gridPowered(object)
    return ItemContainer.isObjectPowered(object, false)
end

--- Whether anything powers `object` now: the grid, or a running generator or Renewable Energy bank in
--- reach (IsoGridSquare.haveElectricity).
function Power.powered(object)
    return ItemContainer.isObjectPowered(object, true)
end

--- The world hour after which the grid is off (SandboxOptions.doesPowerGridExist): ElecShutModifier
--- days into the apocalypse, which the world joined TimeSinceApo months in.
function Power.shutoffHour()
    local options = getSandboxOptions()
    return (options:getElecShutModifier() - (options:getTimeSinceApo() - 1) * 30) * 24
end

--- The hours of the world hours [from, to] the grid gave an object it doesn't power now, caught up
--- after a wait: up to the shutoff if it powered the object at its last loaded pass (`wasGrid`),
--- else none, so a gap is never run on a grid the object had no part of.
function Power.gridHours(wasGrid, from, to)
    return wasGrid and math.max(0, math.min(to, Power.shutoffHour()) - from) or 0
end

return Power

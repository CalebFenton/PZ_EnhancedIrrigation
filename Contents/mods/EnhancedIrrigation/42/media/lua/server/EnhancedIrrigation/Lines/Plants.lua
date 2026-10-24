-- Vanilla's crops as garden lines water them and rot their roots: the one place that writes their
-- SFarmingSystem records. A record keeps a change while its chunk is unloaded: saveData then writes
-- nothing, and loading the chunk puts the record on the plant (SPlantGlobalObject.stateToIsoObject).

if isClient() then return end

require "EnhancedIrrigation/Lines/Lines"

EnhancedIrrigation = EnhancedIrrigation or {}
local Plants = {}
EnhancedIrrigation.Plants = Plants

local Lines = EnhancedIrrigation.Lines

--- The live, sown plant on the square x, y, z (its SFarmingSystem record, loaded or not), or nil.
function Plants.at(x, y, z)
    local farming = SFarmingSystem and SFarmingSystem.instance
    local plant = farming and farming:getLuaObjectAt(x, y, z)
    if plant and plant:isAlive() and plant.state ~= "plow" then
        return plant
    end
    return nil
end

--- Gives the plant on x, y, z up to `points` water points, to full, as a watering does. Returns the
--- points it took: 0 without one.
function Plants.water(x, y, z, points)
    local plant = Plants.at(x, y, z)
    local taken = plant and math.min(points, math.max(0, Lines.PLANT_FULL - plant.waterLvl)) or 0
    if taken > 0 then
        plant.waterLvl = plant.waterLvl + taken
        plant.lastWaterHour = SFarmingSystem.instance.hoursElapsed
        plant:saveData()
    end
    return taken
end

--- Takes from the plant on x, y, z, if any, the health `hours` of waterlogged soil cost its roots,
--- down to none, where vanilla's own check kills it (SPlantGlobalObject.checkStat).
function Plants.rot(x, y, z, hours)
    local plant = Plants.at(x, y, z)
    if plant then
        plant.health = math.max(0, plant.health - Lines.ROOT_ROT_PER_HOUR * hours)
        plant:saveData()
    end
end

return Plants

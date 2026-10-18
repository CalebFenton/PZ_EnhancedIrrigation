-- Water running through a tapped garden line: what the tank gives, and what each outlet does with
-- its share. The Water from Tank action runs it for the time the tap was held open.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines"

EnhancedIrrigation = EnhancedIrrigation or {}
local Flow = {}
EnhancedIrrigation.Flow = Flow

local Lines = EnhancedIrrigation.Lines
local Tanks = EnhancedIrrigation.Tanks

-- Litres an hour out of the tile `record` under one storey of head: its holes, a crack and every
-- patch, which weep wherever they are. 0 where no water leaves.
local function rateOf(record)
    local rate = Lines.PATCH_RATE * record.patches
    if record.holed then
        rate = rate + Lines.HOLE_RATE
    end
    if record.cracked then
        rate = rate + Lines.CRACK_RATE
    end
    return rate
end

-- Gives `litres` to the plant on `record`'s square up to full, the rest to the soil.
local function deliver(record, litres)
    local points = litres * Lines.POINTS_PER_LITRE
    local plant = record:plant()
    local toPlant = 0
    if plant then
        toPlant = math.min(points, math.max(0, Lines.PLANT_FULL - plant.waterLvl))
        if toPlant > 0 then
            plant.waterLvl = plant.waterLvl + toPlant
            plant.lastWaterHour = SFarmingSystem.instance.hoursElapsed
            plant:saveData()
        end
    end
    record:addSoak(points - toPlant)
end

--- Runs the line tapped at `tapRecord` from `tank` for `hours` game hours: every outlet asks its
--- rate, pushed by the square root of the tank's head over the line, and the tank gives what it
--- holds of the sum, each outlet the same fraction of what it asked. Callers check the tap first
--- (LineJobs.tapTank). Authority only. Returns the litres drawn from the tank.
function Flow.run(tapRecord, tank, hours)
    local tiles = Lines.component(tapRecord.x, tapRecord.y, tapRecord.z)
    local push = math.sqrt(Tanks.levelOf(tank) - tapRecord.z)
    local outlets, rates, demand = {}, {}, 0
    for _, tile in ipairs(tiles) do
        local record = tile.state
        record:advance(record:elapsedHours())
        local rate = rateOf(record) * push
        if rate > 0 then
            table.insert(outlets, record)
            table.insert(rates, rate)
            demand = demand + rate * math.max(0, hours)
        end
    end
    local drawn = demand > 0 and Tanks.take(tank, demand) or 0
    -- A line that takes nothing still fills from the tap: water stands in it to the last joint.
    local filled = drawn > 0 or (demand == 0 and hours > 0 and Tanks.litres(tank) > 0)
    if drawn > 0 then
        local share = drawn / demand
        local wetUntil = EnhancedIrrigation.now() + Lines.WET_HOURS
        for i, record in ipairs(outlets) do
            local litres = rates[i] * hours * share
            deliver(record, litres)
            if litres > 0 then
                record.wetUntil = wetUntil
            end
        end
        Tanks.sync(tank)
    end
    for _, tile in ipairs(tiles) do
        if filled then
            tile.state.full = true
        end
        tile.state:afterChange()
    end
    return drawn
end

return Flow

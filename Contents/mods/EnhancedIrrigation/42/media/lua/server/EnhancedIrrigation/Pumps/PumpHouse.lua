-- What time does to a Pump House (PumpObject.KINDS.house): while it is switched on, has a pump part
-- fitted that isn't burnt out, and has power, it runs every pass, lifting its part's rate from its
-- source into its outlet's tank as far as its lift, the tank's room and a finite source's water go,
-- and wearing its part by the hour it runs, faster run dry. A full tank stops the water, not the
-- pump.
--
-- Power, as a washer has it: the grid in a room or beside one, which costs nothing; else a running
-- vanilla generator in reach, the nearest, which burns fuel for the part's draw at vanilla's rate
-- (owed while the generator's square isn't loaded, and settled once it is), and is switched off
-- when that empties it; else a Renewable Energy bank, which this stage doesn't bill (docs/design.md,
-- Renewable Energy). The generator's bill is never written to its own (setTotalPowerUsing), which
-- Renewable Energy keeps.
--
-- A gap caught up after the record waited (PumpObject.catchUp) is decided by the power as it stands
-- then, so the mod can only under-count: grid hours count up to the shutoff if the grid powered it at
-- its last loaded pass; a generator's as far as its fuel goes; with no power now, the gap ran nothing.
-- While it runs, zombies hear it every game minute.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Pumps"
require "EnhancedIrrigation/PumpJobs"
require "EnhancedIrrigation/Pumps/PumpObject"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpHouse = {}
EnhancedIrrigation.PumpHouse = PumpHouse

local Pumps, PumpJobs, Tanks = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs, EnhancedIrrigation.Tanks
local PumpObject = EnhancedIrrigation.PumpObject

-- Power ----------------------------------------------------------------------------------------------

--- The world hour after which the grid is off (SandboxOptions.doesPowerGridExist): ElecShutModifier
--- days into the apocalypse, which the world joined TimeSinceApo months in.
function PumpHouse.shutoffHour()
    local options = getSandboxOptions()
    return (options:getElecShutModifier() - (options:getTimeSinceApo() - 1) * 30) * 24
end

-- Whether `generator` is a Renewable Energy battery bank, which is a generator too; none without
-- that mod.
local function isBank(generator)
    local RE = _G["RenewableEnergy"]
    return RE ~= nil and RE.PowerBank ~= nil and RE.PowerBank.isBank(generator)
end

-- Whether a generator at gx, gy, gz powers the square x, y, z, as IsoGenerator.isPoweringSquare
-- reckons it, with the save's reach: the generator class's own copy is read only when one is made.
local function reaches(gx, gy, gz, x, y, z)
    local range = SandboxVars.GeneratorTileRange
    local dx, dy = gx - x, gy - y
    return math.abs(gz - z) <= SandboxVars.GeneratorVerticalPowerRange and dx * dx + dy * dy <= range * range
end

-- The running vanilla generator on `square`, or nil.
local function runningGenerator(square)
    local generator = square and square:getGenerator()
    return generator and generator:isActivated() and not isBank(generator) and generator or nil
end

-- The nearest running vanilla generator whose reach covers the record's square, among the loaded
-- squares, or nil.
local function nearestGenerator(record)
    local range, vertical = SandboxVars.GeneratorTileRange, SandboxVars.GeneratorVerticalPowerRange
    local cell = getCell()
    local best, bestDistance = nil, nil
    for z = record.z - vertical, record.z + vertical do
        for dx = -range, range do
            for dy = -range, range do
                local distance = dx * dx + dy * dy
                if distance <= range * range and (not bestDistance or distance < bestDistance) then
                    local generator = runningGenerator(cell:getGridSquare(record.x + dx, record.y + dy, z))
                    if generator then
                        best, bestDistance = generator, distance
                    end
                end
            end
        end
    end
    return best
end

-- The generator's fuel an hour of `part` running burns.
local function fuelPerHour(part)
    return part.draw * SandboxVars.GeneratorFuelConsumption
end

-- Fuel below which a generator counts as empty: the bill for the hours its fuel lasted is a float
-- sum that can leave a hair of fuel no hour could burn.
local LEAST_FUEL = 0.0001

-- Takes `fuel` off `generator`, switching it off once it is empty, as vanilla's own burn does.
local function burn(generator, fuel)
    local left = generator:getFuel() - fuel
    if left < LEAST_FUEL then
        left = 0
    end
    generator:setFuel(left)
    if left <= 0 then
        generator:setActivated(false)
    end
end

--- Who pays for the record's power now: { generator } when its payer is loaded, settling what it was
--- owed; { away = true } when the payer it last had stands on a square that isn't loaded; or nil when
--- no vanilla generator pays (a bank's power, or a generator it never saw). A search that found none
--- isn't made again within the pass, whose hours all stand as now.
function PumpHouse.payerOf(record)
    if record.payer then
        local square = getCell():getGridSquare(record.payer.x, record.payer.y, record.payer.z)
        if not square then
            return { away = true }
        end
        local generator = runningGenerator(square)
        if generator and (record.owedFuel or 0) > 0 then
            burn(generator, record.owedFuel)
            generator = runningGenerator(square)
        end
        record.owedFuel = nil
        if generator and reaches(record.payer.x, record.payer.y, record.payer.z, record.x, record.y, record.z) then
            record.payerFuel = generator:getFuel()
            return { generator = generator }
        end
        record.payer, record.payerFuel = nil, nil
    end
    local now = EnhancedIrrigation.now()
    if record.foundNoPayerAt == now then
        return nil
    end
    local generator = nearestGenerator(record)
    if not generator then
        record.foundNoPayerAt = now
        return nil
    end
    record.payer = { x = generator:getX(), y = generator:getY(), z = generator:getZ() }
    record.payerFuel = generator:getFuel()
    return { generator = generator }
end

-- The fuel `payer` (PumpHouse.payerOf) has left to give: a loaded generator's, or an away one's as
-- last seen less what it owes; nil when nothing pays.
local function fuelLeft(record, payer)
    if not payer then
        return nil
    end
    if payer.generator then
        return payer.generator:getFuel()
    end
    return math.max(0, (record.payerFuel or 0) - (record.owedFuel or 0))
end

-- Bills `payer` for `hours` of `part` running: a loaded generator burns it now, an away one owes it.
local function bill(record, payer, part, hours)
    local fuel = fuelPerHour(part) * hours
    if not (payer and fuel > 0) then
        return
    end
    if payer.generator then
        burn(payer.generator, fuel)
        record.payerFuel = payer.generator:getFuel()
    else
        record.owedFuel = (record.owedFuel or 0) + fuel
    end
end

-- How many of the `hours` from the world hour `from` the record's pump has power for, as things
-- stand now, and the share of them the grid gives free; and who pays for the rest.
local function poweredHours(record, pump, part, hours, from)
    local gridHours = 0
    if Pumps.gridPowered(pump) then
        gridHours = hours
    elseif record.grid then
        gridHours = math.max(0, math.min(hours, PumpHouse.shutoffHour() - from))
    end
    local rest = hours - gridHours
    if rest <= 0 or not Pumps.powered(pump) then
        return gridHours, gridHours, nil
    end
    local payer = PumpHouse.payerOf(record)
    local fuel, perHour = fuelLeft(record, payer), fuelPerHour(part)
    if fuel and perHour > 0 then
        rest = math.min(rest, fuel / perHour)
    end
    return gridHours + rest, gridHours, payer
end

-- Running --------------------------------------------------------------------------------------------

-- The part's condition `hours` of running takes, `dryHours` of them with nothing to draw.
local function wearOf(part, hours, dryHours)
    return part.wearPerHour * (hours - dryHours + Pumps.DRY_WEAR * dryHours)
end

--- Runs the record's Pump House `pump` with `part` for up to `hours`: lifts the part's rate from
--- its source into its outlet's tank, as far as the lift, the tank's room and a finite source's
--- water go, and wears the part, ten times as fast for the time its source is dry. Stops where the
--- part burns out. Returns the hours it ran.
function PumpHouse.run(record, pump, part, hours)
    local source = Pumps.sourceOf(pump, record.intake, (Pumps.outletOf(record) or {}).b)
    local tank = PumpJobs.deliveryOf(pump, part, record.intake)
    local perHour = part.rate * 60
    local litres, dryHours = 0, hours
    if source and not source.dry then
        dryHours = 0
        if tank then
            litres = math.min(perHour * hours, tank:getFluidContainer():getFreeCapacity())
            -- A finite source that runs out before the tank fills leaves the rest of the time dry.
            if not source.infinite and source.litres < litres then
                litres = source.litres
                dryHours = hours - litres / perHour
            end
        end
    end
    -- The wet time comes first; the part may burn out in it, or in the dry time after. Burnt out in
    -- the wet time, the water is what that time lifts, which a tank that fills first still caps.
    local ran = hours
    local wetWear = wearOf(part, hours - dryHours, 0)
    if wetWear >= record.partCondition then
        ran = (hours - dryHours) * record.partCondition / wetWear
        litres = math.min(litres, perHour * ran)
    elseif wearOf(part, hours, dryHours) >= record.partCondition then
        ran = hours - dryHours + (record.partCondition - wetWear) / (part.wearPerHour * Pumps.DRY_WEAR)
    end
    record.partCondition = math.max(0, record.partCondition - wearOf(part, ran, math.max(0, ran - (hours - dryHours))))
    if record.partCondition < Pumps.LEAST_LITRES then
        record.partCondition = 0
    end
    if tank and litres >= Pumps.LEAST_LITRES then
        PumpObject.draw(source, tank:getFluidContainer(), litres)
        Tanks.sync(tank)
    end
    return ran
end

--- What an hour or less of time from the world hour `from` does to the record's Pump House `pump`:
--- runs it for as long as it has power (PumpHouse.run) while it is switched on with a sound part,
--- and bills its payer for the hours it ran off the grid.
function PumpHouse.step(record, pump, spec, hours, from)
    local part = Pumps.partSpec(record.part)
    if not (part and record.on and not record:isBurntOut()) then
        return
    end
    local powered, free, payer = poweredHours(record, pump, part, hours, from)
    if powered <= 0 then
        return
    end
    local ran = PumpHouse.run(record, pump, part, powered)
    bill(record, payer, part, math.max(0, ran - free))
end

--- How the record's Pump House `pump` stands once caught up, loaded: whether the grid powers it now,
--- for the next gap; switched off once its part is burnt out; and whether it runs now: switched on,
--- with a sound part and power, a generator's with fuel left.
function PumpHouse.settle(record, pump)
    record.grid = Pumps.gridPowered(pump)
    if record:isBurntOut() then
        record.on = nil
    end
    local part = Pumps.partSpec(record.part)
    local running = part ~= nil and record.on == true and Pumps.powered(pump)
    if running and not record.grid then
        local fuel = fuelLeft(record, PumpHouse.payerOf(record))
        running = fuel == nil or fuel > 0
    end
    record.running = running or nil
end

PumpObject.KINDS.house.step = PumpHouse.step
PumpObject.KINDS.house.settle = PumpHouse.settle

-- Noise ----------------------------------------------------------------------------------------------

-- Each game minute, every Pump House running on a loaded square makes its part's noise for zombies,
-- as a running washer does (ClothingWasherLogic.updateSound).
Events.EveryOneMinute.Add(function()
    local system = Pumps.serverSystem
    for i = 1, system and system:getLuaObjectCount() or 0 do
        local record = system:getLuaObjectByIndex(i)
        local part = record.running and Pumps.partSpec(record.part)
        local pump = part and record:getIsoObject()
        if pump then
            addSound(pump, record.x, record.y, record.z, part.noise.radius, part.noise.volume)
        end
    end
end)

return PumpHouse

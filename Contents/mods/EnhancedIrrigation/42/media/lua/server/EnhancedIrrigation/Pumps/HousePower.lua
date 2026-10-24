-- Who pays for a Pump House's power, as a washer has it: the grid in a room or beside one costs
-- nothing; else the nearest running vanilla generator in reach burns fuel for the part's draw at
-- vanilla's rate, owed while the generator's square isn't loaded and settled once it is, and is
-- switched off when that empties it; else a Renewable Energy bank bills the house itself
-- (PumpHouse.bankDraw). The generator's own bill (setTotalPowerUsing) is never written, as
-- Renewable Energy keeps it. The record's payer, payerFuel and owedFuel are this file's.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Power"

EnhancedIrrigation = EnhancedIrrigation or {}
local HousePower = {}
EnhancedIrrigation.HousePower = HousePower

local Power = EnhancedIrrigation.Power

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

-- Who pays for the record's power now: { generator } when its payer is loaded, settling what it was
-- owed; { away = true } when the payer it last had stands on a square that isn't loaded; or nil when
-- no vanilla generator pays (a bank's power, or a generator it never saw). A search that found none
-- isn't made again within the pass, whose hours all stand as now.
local function payerOf(record)
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

-- The fuel `payer` (payerOf) has left to give: a loaded generator's, or an away one's as last seen
-- less what it owes; nil when nothing pays.
local function fuelOf(record, payer)
    if not payer then
        return nil
    end
    if payer.generator then
        return payer.generator:getFuel()
    end
    return math.max(0, (record.payerFuel or 0) - (record.owedFuel or 0))
end

--- How many of the `hours` from the world hour `from` the record's Pump House `pump`, running
--- `part`, has power for, as things stand now; the share of them the grid gives free; and who pays
--- for the rest (for bill).
function HousePower.hours(record, pump, part, hours, from)
    local gridHours = Power.gridPowered(pump) and hours or Power.gridHours(record.grid, from, from + hours)
    local rest = hours - gridHours
    if rest <= 0 or not Power.powered(pump) then
        return gridHours, gridHours, nil
    end
    local payer = payerOf(record)
    local fuel, perHour = fuelOf(record, payer), fuelPerHour(part)
    if fuel and perHour > 0 then
        rest = math.min(rest, fuel / perHour)
    end
    return gridHours + rest, gridHours, payer
end

--- Bills `payer` (HousePower.hours) for `hours` of `part` running: a loaded generator burns it now,
--- an away one owes it.
function HousePower.bill(record, payer, part, hours)
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

--- Pays the fuel the record owes its generator, once that generator's square is loaded.
function HousePower.payDebt(record)
    if record.owedFuel and record.payer then
        payerOf(record)
    end
end

--- The fuel the generator paying for the record's power has left, or nil when no vanilla generator
--- pays.
function HousePower.fuelLeft(record)
    return fuelOf(record, payerOf(record))
end

--- Whether a vanilla generator pays for the record's power, which a bank then leaves alone.
function HousePower.generatorPays(record)
    return record.payer ~= nil
end

return HousePower

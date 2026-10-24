-- What time does to a Pump House (PumpObject.KINDS.house): while it is switched on, or its timer
-- holds it open (Timers.lua), has a pump part fitted that isn't burnt out, and has power, it runs,
-- lifting its part's rate from its source into its outlet's tank as far as its lift, the tank's
-- room and a finite source's water go, or driving the line its outlet feeds with what that takes
-- up to its rate (Lines/Flow.lua), and wearing its part by the hour it runs, faster run dry. A
-- full tank stops the water, not the pump. The switch runs it whatever the timer says; switched
-- off, the timer runs it in its daily window, as a plug-in timer powers what is plugged into it.
--
-- Power, as a washer has it: the grid in a room or beside one, which costs nothing; else a running
-- vanilla generator in reach, the nearest, which burns fuel for the part's draw at vanilla's rate
-- (owed while the generator's square isn't loaded, and settled once it is), and is switched off
-- when that empties it; else a Renewable Energy bank, which bills the part's draw as it bills an
-- appliance in its reach, told of it through its Loads.addConsumer (PumpHouse.bankDraw). The
-- generator's bill is never written to its own (setTotalPowerUsing), which Renewable Energy keeps.
--
-- A gap caught up after the record waited (PumpObject.catchUp) is decided by the power as it stands
-- then, so the mod can only under-count: grid hours count up to the shutoff if the grid powered it at
-- its last loaded pass; a generator's as far as its fuel goes; with no power now, the gap ran nothing.
-- While it runs, zombies hear it every game minute.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Pumps/PumpJobs"
require "EnhancedIrrigation/Pumps/PumpObject"
require "EnhancedIrrigation/Lines/Flow"
require "EnhancedIrrigation/Timers"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpHouse = {}
EnhancedIrrigation.PumpHouse = PumpHouse

local Pumps, PumpJobs, Tanks = EnhancedIrrigation.Pumps, EnhancedIrrigation.PumpJobs, EnhancedIrrigation.Tanks
local Lines, Flow, PumpObject = EnhancedIrrigation.Lines, EnhancedIrrigation.Flow, EnhancedIrrigation.PumpObject
local Timers = EnhancedIrrigation.Timers

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

-- The source of a line a Pump House with `part` feeds from `source` (Pumps.sourceOf), as Flow reads
-- one, giving at most `litres`: what the time it ran wet lifts.
local function lineSource(part, source, litres)
    return {
        push = part.push,
        perHour = part.rate * 60,
        pumped = true,
        holds = true,
        draw = function(asked) return PumpObject.draw(source, nil, math.min(asked, litres)) end,
    }
end

--- Runs the record's Pump House `pump` with `part` for up to `hours`: lifts the part's rate from
--- its source into its outlet's tank, as far as the lift, the tank's room and a finite source's
--- water go, or what the line its outlet feeds takes of it, and wears the part, ten times as fast
--- for the time its source is dry. Stops where the part burns out. Returns the hours it ran.
function PumpHouse.run(record, pump, part, hours)
    local source = Pumps.sourceOf(pump, record.intake, (Pumps.outletOf(record) or {}).b)
    local into = PumpJobs.deliveryOf(pump, part, record.intake)
    local line = into and Lines.isLine(into) and Lines.recordOf(into) or nil
    -- The litres an hour it lifts while it has water, and how many its outlet takes at most.
    local perHour, room = part.rate * 60, math.huge
    if line then
        perHour = Flow.takesPerHour(line, lineSource(part, source, 0))
    elseif into then
        room = into:getFluidContainer():getFreeCapacity()
    end
    local litres, dryHours = 0, hours
    if source and not source.dry then
        dryHours = 0
        if into then
            litres = math.min(perHour * hours, room)
            -- A finite source that runs out before the outlet is served leaves the rest of the
            -- time dry.
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
    if line then
        -- A line that takes nothing is still filled for as long as the pump runs wet.
        local wet = perHour > 0 and litres / perHour or math.min(ran, hours - dryHours)
        if wet > 0 then
            Flow.run(line, lineSource(part, source, litres), wet)
        end
    elseif into and litres >= Pumps.LEAST_LITRES then
        PumpObject.draw(source, into:getFluidContainer(), litres)
        Tanks.sync(into)
    end
    return ran
end

-- Runs the record's Pump House for as long of `hours` from the world hour `from` as it has power,
-- and bills its payer for the hours it ran off the grid.
local function runPowered(record, pump, part, hours, from)
    local powered, free, payer = poweredHours(record, pump, part, hours, from)
    if powered <= 0 then
        return
    end
    local ran = PumpHouse.run(record, pump, part, powered)
    bill(record, payer, part, math.max(0, ran - free))
end

--- Whether the timer of the record's Pump House holds it open at the world hour `hour`.
function PumpHouse.timerOpen(record, hour)
    local timer = record.timer
    return timer ~= nil and Timers.isOpenAt(hour, timer.start, timer.minutes)
end

--- What an hour or less of time from the world hour `from` does to the record's Pump House `pump`
--- with a sound part: runs it (PumpHouse.run) for as long as it has power, the whole time while it
--- is switched on, else the stretches its timer holds it open; and bills its payer for the hours it
--- ran off the grid.
function PumpHouse.step(record, pump, spec, hours, from)
    local part = Pumps.partSpec(record.part)
    if not (part and not record:isBurntOut()) then
        return
    end
    if record.on then
        runPowered(record, pump, part, hours, from)
        return
    end
    local timer = record.timer
    for _, stretch in ipairs(timer and Timers.openHours(from, from + hours, timer.start, timer.minutes) or {}) do
        if record:isBurntOut() then
            return
        end
        runPowered(record, pump, part, stretch.to - stretch.from, stretch.from)
    end
end

--- How the record's Pump House `pump` stands once caught up, loaded: fuel it owes paid once its
--- payer is loaded, however it stands now; whether the grid powers it now, for the next gap;
--- switched off once its part is burnt out; and whether it runs now: switched on or held open by
--- its timer, with a sound part and power, a generator's with fuel left.
function PumpHouse.settle(record, pump)
    if record.owedFuel and record.payer then
        PumpHouse.payerOf(record)
    end
    record.grid = Pumps.gridPowered(pump)
    if record:isBurntOut() then
        record.on = nil
    end
    local part = Pumps.partSpec(record.part)
    local wanted = record.on == true or PumpHouse.timerOpen(record, EnhancedIrrigation.now())
    local running = part ~= nil and not record:isBurntOut() and wanted and Pumps.powered(pump)
    if running and not record.grid then
        local fuel = fuelLeft(record, PumpHouse.payerOf(record))
        running = fuel == nil or fuel > 0
    end
    record.running = running or nil
end

PumpObject.KINDS.house.step = PumpHouse.step
PumpObject.KINDS.house.settle = PumpHouse.settle

-- Noise ----------------------------------------------------------------------------------------------

-- Each game minute, every Pump House with a timer runs its pass, so it starts and stops within the
-- minute its window opens and shuts rather than at the next ten-minute pass; then every one
-- running on a loaded square makes its part's noise for zombies, as a running washer does
-- (ClothingWasherLogic.updateSound).
Events.EveryOneMinute.Add(function()
    local system = Pumps.serverSystem
    for i = 1, system and system:getLuaObjectCount() or 0 do
        local record = system:getLuaObjectByIndex(i)
        if record.timer and record:getIsoObject() then
            record:update()
        end
        local part = record.running and Pumps.partSpec(record.part)
        local pump = part and record:getIsoObject()
        if pump then
            addSound(pump, record.x, record.y, record.z, part.noise.radius, part.noise.volume)
        end
    end
end)

-- Renewable Energy -----------------------------------------------------------------------------------

--- What the Pump House `object` draws from a Renewable Energy bank now, as its Loads.addConsumer
--- asks: the kind its status lists it as and the generator fuel an hour its part burns in vanilla's
--- units, while it would run if powered (a sound part, switched on or its timer open) with no
--- vanilla generator paying for it, as one in reach pays first (PumpHouse.payerOf); else nil. As a
--- vanilla appliance's switch does, it answers whether or not it has power: a bank that cut its
--- power for an overload must still count it, or the power would come back, the house start and
--- the bank cut again. The timer is read at the hour asked, so a bank's pass at the hour a window
--- opens counts it before the house's own pass starts it. The bank decides whether the grid powers
--- it.
function PumpHouse.bankDraw(object)
    if not Pumps.isHouse(object) then
        return nil
    end
    local record = Pumps.recordOf(object)
    local part = record and not record.payer and not record:isBurntOut() and Pumps.partSpec(record.part)
    if not (part and (record.on or PumpHouse.timerOpen(record, EnhancedIrrigation.now()))) then
        return nil
    end
    return "IGUI_EnhancedIrrigation_PumpHouseLoad", part.draw
end

-- Renewable Energy's server files have all loaded by the world's start, whatever the mod order.
Events.OnInitGlobalModData.Add(function()
    local RE = _G["RenewableEnergy"]
    if RE and RE.Loads and RE.Loads.addConsumer then
        RE.Loads.addConsumer(PumpHouse.bankDraw)
    end
end)

return PumpHouse

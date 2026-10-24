-- What time does to a Pump House. The switch runs it whatever the timer says; switched off, the
-- timer runs it in its daily window, as a plug-in timer powers what is plugged into it. A full tank
-- stops the water, not the pump.
--
-- A gap caught up after the record waited is decided by the power as it stands then, so the mod can
-- only under-count: the grid's hours count up to the shutoff if it powered the house at its last
-- loaded pass; a generator's as far as its fuel goes; with no power now, the gap ran nothing.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Lines/Flow"
require "EnhancedIrrigation/Timers"
require "EnhancedIrrigation/Power"
require "EnhancedIrrigation/Pumps/HousePower"

EnhancedIrrigation = EnhancedIrrigation or {}
local PumpHouse = {}
EnhancedIrrigation.PumpHouse = PumpHouse

local Pumps = EnhancedIrrigation.Pumps
local Lines, Flow = EnhancedIrrigation.Lines, EnhancedIrrigation.Flow
local Timers, Power, HousePower = EnhancedIrrigation.Timers, EnhancedIrrigation.Power, EnhancedIrrigation.HousePower

-- Running --------------------------------------------------------------------------------------------

-- The part's condition `hours` of running takes, `dryHours` of them with nothing to draw.
local function wearOf(part, hours, dryHours)
    return part.wearPerHour * (hours - dryHours + Pumps.DRY_WEAR * dryHours)
end

-- Condition below which a part counts as burnt out: the wear for the hours it lasted is a float sum
-- that can leave a hair of condition no hour could wear.
local LEAST_CONDITION = 0.01

-- The source of the line a Pump House with `part` drives from `source` (Pumps.sourceOf), giving at
-- most `litres`: what the time it ran wet lifts.
local function lineSource(part, source, litres)
    return Pumps.lineSource(part, function(asked) return Pumps.draw(source, nil, math.min(asked, litres)) end)
end

-- Runs the record's Pump House `pump` with `part` for up to `hours`: lifts the part's rate from its
-- source into its outlet's tank, as far as the lift, the tank's room and a finite source's water
-- go, or what the line its outlet feeds takes of it, and wears the part, faster for the time its
-- source is dry. Stops where the part burns out. Returns the hours it ran.
local function run(record, pump, part, hours)
    local into, source = Pumps.deliveryOf(pump, part, record.intake)
    if not into then
        -- Refused, it still runs: its source decides how fast it wears.
        source = Pumps.sourceOf(pump, record.intake, Pumps.outletEnd(record))
    end
    local line = into and Lines.isLine(into) and Lines.recordOf(into) or nil
    -- The litres an hour it lifts while it has water, and how many its outlet takes at most.
    local perHour, room = Pumps.perHour(part), math.huge
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
    if record.partCondition < LEAST_CONDITION then
        record.partCondition = 0
    end
    if line then
        -- A line that takes nothing is still filled for as long as the pump runs wet.
        local wet = perHour > 0 and litres / perHour or math.min(ran, hours - dryHours)
        if wet > 0 then
            Flow.run(line, lineSource(part, source, litres), wet)
        end
    elseif into then
        Pumps.fillTank(source, into, litres)
    end
    return ran
end

-- Runs the record's Pump House for as long of `hours` from the world hour `from` as it has power,
-- and bills its payer for the hours it ran off the grid.
local function runPowered(record, pump, part, hours, from)
    local powered, free, payer = HousePower.hours(record, pump, part, hours, from)
    if powered <= 0 then
        return
    end
    local ran = run(record, pump, part, powered)
    HousePower.bill(record, payer, part, math.max(0, ran - free))
end

-- Whether the timer of the record's Pump House holds it open at the world hour `hour`.
local function timerOpen(record, hour)
    local timer = record.timer
    return timer ~= nil and Timers.isOpenAt(hour, timer.start, timer.minutes)
end

--- What an hour or less of time from the world hour `from` does to the record's Pump House `pump`
--- with a sound part: runs it for as long as it has power, the whole time while it is switched on,
--- else the stretches its timer holds it open; and bills its payer for the hours it ran off the
--- grid.
function PumpHouse.step(record, pump, hours, from)
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
    HousePower.payDebt(record)
    record.grid = Power.gridPowered(pump)
    if record:isBurntOut() then
        record.on = nil
    end
    local part = Pumps.partSpec(record.part)
    local wanted = record.on == true or timerOpen(record, EnhancedIrrigation.now())
    local running = part ~= nil and not record:isBurntOut() and wanted and Power.powered(pump)
    if running and not record.grid then
        local fuel = HousePower.fuelLeft(record)
        running = fuel == nil or fuel > 0
    end
    record.running = running or nil
end

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
--- vanilla generator paying for it, as one in reach pays first (HousePower); else nil. As a
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
    local part = record and not HousePower.generatorPays(record) and not record:isBurntOut()
        and Pumps.partSpec(record.part)
    if not (part and (record.on or timerOpen(record, EnhancedIrrigation.now()))) then
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

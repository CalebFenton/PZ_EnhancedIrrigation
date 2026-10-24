-- The authority's side of the valves on taps: each game minute, every tap with a valve runs its
-- line for the stretch its valve held it open since the last time, as a held tap runs it, and says
-- whether it runs now.
--
-- A Wind-up Valve is open until the world hour it was wound to. A Timer Valve or Sprinkler Timer is
-- open in its daily window while it has power: power now covers the whole stretch; without it, the
-- grid's power at its last loaded run covers the stretch up to the shutoff; else nothing. A valve
-- waits, as a pump does, while its tap or the squares around it where its tanks stand aren't
-- loaded, keeping its clock, and catches the stretch up once they are, from the tank as it stands
-- then. While someone holds the tap, their watering counts and the valve's doesn't.
--
-- The record's `valve` (LineObject.SAVED_FIELDS): item, the valve's full type; start and minutes, a
-- timer's setting; untilHour, the world hour a wind-up runs to; lastHour, when the valve last ran;
-- grid, whether the grid powered it then. Unsaved, `valveOpen`: it runs the line now.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Lines/Taps"
require "EnhancedIrrigation/Power"
require "EnhancedIrrigation/Lines/Valves"
require "EnhancedIrrigation/Timers"
require "EnhancedIrrigation/Lines/Flow"

EnhancedIrrigation = EnhancedIrrigation or {}
local ValveSystem = {}
EnhancedIrrigation.ValveSystem = ValveSystem

local Lines, Taps, Valves, Power = EnhancedIrrigation.Lines, EnhancedIrrigation.Taps, EnhancedIrrigation.Valves,
    EnhancedIrrigation.Power
local Flow, Timers = EnhancedIrrigation.Flow, EnhancedIrrigation.Timers

-- The records of the taps with a valve, found again each ten minutes, and added to as one is fitted.
local valved = {}

--- Runs the valve of `record` from now on each game minute.
function ValveSystem.track(record)
    valved[record] = true
end

-- The hours of each stretch of the world hours [from, to], in order, that the valve of `record` at
-- the tap `tap` held the tap open and, for a timer, had power for.
local function openHours(record, tap, from, to)
    local valve = record.valve
    if Valves.kindOf(valve.item) == "windup" then
        local untilHour = valve.untilHour or from
        return untilHour > from and { math.min(to, untilHour) - from } or {}
    end
    local powered = Power.powered(tap)
    local hours = {}
    for _, stretch in ipairs(Timers.openHours(from, to, valve.start, valve.minutes)) do
        table.insert(hours, powered and stretch.to - stretch.from or Power.gridHours(valve.grid, stretch.from, stretch.to))
    end
    return hours
end

-- Whether the valve of `record` at `tap` holds the tap open now: wound and not run down, or a timer
-- in its window with power; with a tank to feed it and nobody holding the tap.
local function isOpen(record, tap, now)
    local valve = record.valve
    if record.holder then
        return false
    end
    local open
    if Valves.kindOf(valve.item) == "windup" then
        open = (valve.untilHour or now) > now
    else
        open = Timers.isOpenAt(now, valve.start, valve.minutes) and Power.powered(tap)
    end
    return open and Taps.tankFor(tap) ~= nil
end

--- Brings the valve of `record` up to now, if its tap and its tanks' squares are loaded: runs the
--- line for each stretch it held the tap open since it last ran, while nobody held the tap and a
--- tank fed it, and notes whether it runs now. Tells the clients what changed. Authority only.
function ValveSystem.update(record)
    local valve = record.valve
    local tap = valve and record:getIsoObject()
    -- The tanks it draws on (Tanks.tanksReaching) stand in the 3x3 around it, on its floor or the
    -- one above, which share its chunks.
    if not (tap and EnhancedIrrigation.loadedAround(record.x, record.y, record.z)) then
        return
    end
    local now = EnhancedIrrigation.now()
    local from = now - EnhancedIrrigation.hoursSince(valve)
    if not record.holder then
        for _, hours in ipairs(openHours(record, tap, from, now)) do
            local tank = Taps.tankFor(tap)
            if not tank then
                break
            end
            if hours > 0 then
                Flow.run(record, Flow.fromTank(tank, tap:getZ()), hours)
            end
        end
    end
    if valve.untilHour and valve.untilHour <= now then
        valve.untilHour = nil
    end
    if Valves.kindOf(valve.item) == "timer" then
        valve.grid = Power.gridPowered(tap)
    end
    record.valveOpen = isOpen(record, tap, now) or nil
    -- Flow.run told the clients of every tile it ran; this tells them whether the valve runs now,
    -- or nothing when that didn't change.
    record:sendSummary()
end

--- Fits the valve `item` to the tap of `record`, with nothing set: a wind-up run down, a timer at
--- no minutes. Authority only.
function ValveSystem.fit(record, item)
    record.valve = { item = item:getFullType(), lastHour = EnhancedIrrigation.now() }
    record.valveOpen = nil
    ValveSystem.track(record)
end

--- Takes the valve off the tap of `record`, after running what it held open up to now. Returns it
--- as an item; its setting is lost. Authority only.
function ValveSystem.takeOff(record)
    ValveSystem.update(record)
    local item = instanceItem(record.valve.item)
    record.valve, record.valveOpen = nil, nil
    valved[record] = nil
    return item
end

--- Winds the Wind-up Valve of `record` to run `minutes` from now, after running what it held open
--- up to now; 0 shuts it. Authority only.
function ValveSystem.wind(record, minutes)
    ValveSystem.update(record)
    local valve = record.valve
    valve.untilHour = minutes > 0 and EnhancedIrrigation.now() + minutes / 60 or nil
    ValveSystem.update(record)
end

--- Sets the timer of `record` to open at the hour `start` each day for `minutes`, after running
--- what it held open up to now. Authority only.
function ValveSystem.setTimer(record, start, minutes)
    ValveSystem.update(record)
    local valve = record.valve
    valve.start, valve.minutes = start, minutes
    ValveSystem.update(record)
end

-- Each ten minutes, and at the first game minute after the world loads, every record with a
-- valve, loaded or not: the system's records are made as the save loads, after the world's own
-- start events (SGlobalObjects.initSystems runs after GlobalModData.init), and a tile can come
-- back with its chunk.
local function findValves()
    local system = Lines.serverSystem
    for i = 1, system and system:getLuaObjectCount() or 0 do
        local record = system:getLuaObjectByIndex(i)
        if record.valve then
            valved[record] = true
        end
    end
end

local found = false

-- Each game minute, every valve tracked that's still on its tap.
local function updateValves()
    if not found then
        found = true
        findValves()
    end
    local gone = {}
    for record in pairs(valved) do
        if record.valve and record.x and Lines.recordAt(record.x, record.y, record.z) == record then
            ValveSystem.update(record)
        else
            table.insert(gone, record)
        end
    end
    for _, record in ipairs(gone) do
        valved[record] = nil
    end
end

Events.EveryOneMinute.Add(updateValves)
Events.EveryTenMinutes.Add(findValves)

return ValveSystem

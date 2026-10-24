-- The authority's side of the valves on taps (shared/EnhancedIrrigation/Valves.lua): each game
-- minute, every tap with a valve runs its line for the stretch its valve held it open since the last
-- time, as a held tap runs it (Flow.run from Taps.tankFor), and says whether it runs now.
--
-- A Wind-up Valve is open until the world hour it was wound to. A Timer Valve or Sprinkler Timer is
-- open in its daily window while it has power: power now covers the whole stretch; without it, the
-- grid's power at its last loaded run covers the stretch up to the shutoff; else nothing. A valve
-- waits, as a pump does, while its tap or the squares around it where its tanks stand aren't
-- loaded, keeping its clock, and catches the stretch up (at most a week) once they are, from the
-- tank as it stands then. While someone holds the tap, their watering counts and the valve's
-- doesn't.
--
-- The record's `valve` (LineObject.SAVED_FIELDS): item, the valve's full type; start and minutes, a
-- timer's setting; untilHour, the world hour a wind-up runs to; lastHour, when the valve last ran;
-- grid, whether the grid powered it then. Unsaved, `valveOpen`: it runs the line now.

if isClient() then return end

require "EnhancedIrrigation/Utilities"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/Taps"
require "EnhancedIrrigation/Pumps"
require "EnhancedIrrigation/Valves"
require "EnhancedIrrigation/Lines/Flow"

EnhancedIrrigation = EnhancedIrrigation or {}
local ValveSystem = {}
EnhancedIrrigation.ValveSystem = ValveSystem

local Lines, Taps, Pumps, Valves = EnhancedIrrigation.Lines, EnhancedIrrigation.Taps, EnhancedIrrigation.Pumps,
    EnhancedIrrigation.Valves
local Flow = EnhancedIrrigation.Flow

-- The records of the taps with a valve, found again each ten minutes, and added to as one is fitted.
local valved = {}

--- Runs the valve of `record` from now on each game minute.
function ValveSystem.track(record)
    valved[record] = true
end

-- Whether the chunks of the tap and the 3x3 around it are loaded, where the tanks it draws on stand
-- (Tanks.tanksReaching), on its floor or the one above, which share its chunks. A square there may
-- not exist even loaded, so the chunk is asked.
local function endsLoaded(record)
    local cell = getCell()
    for dx = -1, 1 do
        for dy = -1, 1 do
            if not cell:getChunkForGridSquare(record.x + dx, record.y + dy, record.z) then
                return false
            end
        end
    end
    return true
end

-- The stretches of [from, to], as { from, to } world hours in order, the valve of `record` at the
-- tap `tap` held the tap open.
local function openStretches(record, tap, from, to)
    local valve = record.valve
    local kind = Valves.kindOf(valve.item)
    if kind == "windup" then
        local untilHour = valve.untilHour or from
        return untilHour > from and { { from = from, to = math.min(to, untilHour) } } or {}
    end
    local stretches = Valves.openHours(from, to, valve.start, valve.minutes)
    if Pumps.powered(tap) then
        return stretches
    end
    if not valve.grid then
        return {}
    end
    -- Read when called: PumpHouse.lua needs LineSystem.lua, which needs this file.
    local shutoff = EnhancedIrrigation.PumpHouse.shutoffHour()
    local powered = {}
    for _, stretch in ipairs(stretches) do
        if stretch.from < shutoff then
            table.insert(powered, { from = stretch.from, to = math.min(stretch.to, shutoff) })
        end
    end
    return powered
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
        open = Valves.isOpenAt(now, valve.start, valve.minutes) and Pumps.powered(tap)
    end
    return open and Taps.tankFor(tap) ~= nil
end

--- Brings the valve of `record` up to now, if its tap and its tanks' squares are loaded: runs the
--- line for each stretch it held the tap open since it last ran, while nobody held the tap and a
--- tank fed it, and notes whether it runs now. Tells the clients what changed. Authority only.
function ValveSystem.update(record)
    local valve = record.valve
    local tap = valve and record:getIsoObject()
    if not (tap and endsLoaded(record)) then
        return
    end
    local now = EnhancedIrrigation.now()
    local from = math.max(valve.lastHour or now, now - EnhancedIrrigation.LONGEST_PASS)
    valve.lastHour = now
    if not record.holder then
        for _, stretch in ipairs(openStretches(record, tap, from, now)) do
            local tank = Taps.tankFor(tap)
            if not tank then
                break
            end
            Flow.run(record, Flow.fromTank(tank, tap:getZ()), stretch.to - stretch.from)
        end
    end
    if valve.untilHour and valve.untilHour <= now then
        valve.untilHour = nil
    end
    if Valves.kindOf(valve.item) == "timer" then
        valve.grid = Pumps.gridPowered(tap)
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

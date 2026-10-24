require "PZHarness/ServerHandlers"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The authority's half of every line test file
-- (EnhancedIrrigationTestsLines, Water, Time and PlantInfo) and of the line and crop fixtures in
-- EnhancedIrrigationTestLib.lua: line tiles and crops placed the way the authority places them,
-- line jobs performed, line records read, aged and run, and the frost; the tanks are
-- EnhancedIrrigationTestServer.lua's.
-- Only registers handlers, so a --stay rerun loads it again (RELOAD_FILES). Everything a handler
-- places goes when its test ends, by its square, so a stale copy left by a reload is no matter. A
-- tile is { x, y, z }; `args.tiles` lists them.

local handler = PZHarness.serverHandler

local function lineSystem()
    return EnhancedIrrigation.LineSystem
end

local function removeLineAt(at)
    local line = EnhancedIrrigation.Lines.lineAt(at.x, at.y, at.z)
    if line then
        lineSystem().remove(line)
    end
end

-- Removes the line tiles on `tiles` when the test ends, however they got there.
local function deferRemoval(tiles, defer)
    for _, at in ipairs(tiles) do
        defer(function() removeLineAt(at) end)
    end
end

-- The names of `isoObject`'s overlays.
local function overlaysOf(isoObject)
    local names = {}
    local attached = isoObject:getAttachedAnimSprite()
    for i = 0, (attached and attached:size() or 0) - 1 do
        table.insert(names, attached:get(i):getName())
    end
    return names
end

-- The plant on `at` as its record has it, or nil.
local function plantAt(at)
    local farming = SFarmingSystem and SFarmingSystem.instance
    local plant = farming and farming:getLuaObjectAt(at.x, at.y, at.z)
    if not plant then
        return nil
    end
    return { state = plant.state, water = plant.waterLvl, health = plant.health, alive = plant:isAlive() }
end

-- What the server has at the tile `at`: `record` (its saved fields, wet, the line's size and who
-- holds its tap) or nil, `sprite` and `overlays` of its loaded tile, `plant`.
local function readTile(at)
    local Lines = EnhancedIrrigation.Lines
    local record = Lines.recordAt(at.x, at.y, at.z)
    local line = Lines.lineAt(at.x, at.y, at.z)
    local reply = { x = at.x, y = at.y, z = at.z, plant = plantAt(at) }
    if record then
        reply.record = Server.fieldsOf(record, EnhancedIrrigation.LineObject.SAVED_FIELDS)
        reply.record.wet = record:isWet()
        reply.record.tiles = #Lines.component(at.x, at.y, at.z)
        reply.record.heldBy = record.heldBy
    end
    if line then
        reply.sprite = line:getSprite():getName()
        reply.overlays = overlaysOf(line)
    end
    return reply
end

local function readTiles(tiles)
    local reply = { tiles = {} }
    for i, at in ipairs(tiles) do
        reply.tiles[i] = readTile(at)
    end
    return reply
end

-- Lines ---------------------------------------------------------------------------------------------

-- Lays a line tile on each of `args.tiles`, of the tile's `material` or `args.material`, with the
-- tile's `fields` (saved fields) set, as Lay Line would lay it.
handler("lines.place", function(player, args, defer)
    for _, at in ipairs(args.tiles) do
        local square = Server.squareAt(at)
        if not square then
            return nil, "a loaded square for a line tile at " .. at.x .. "," .. at.y
        end
        defer(function() removeLineAt(at) end)
        lineSystem().place(square, at.material or args.material, at.fields)
    end
    return readTiles(args.tiles)
end)

-- Takes away whatever line tile the test leaves on `args.tiles`, such as those its jobs lay.
handler("lines.track", function(player, args, defer)
    deferRemoval(args.tiles, defer)
    return {}
end)

handler("lines.read", function(player, args)
    return readTiles(args.tiles)
end)

-- Runs each tile's record as though `args.hours` had passed since its last pass, as the ten-minute
-- pass does, loaded or not; the hours pass for its soil's wet spell too. Answers the tiles after,
-- and in `before` as they were, and `args.squares` as Server.readSquares reads them in
-- `squares.before` and `squares.after`, read in the same call so no vanilla pass lands between.
handler("lines.age", function(player, args)
    local before = readTiles(args.tiles).tiles
    local squaresBefore = Server.readSquares(args.squares)
    for _, at in ipairs(args.tiles) do
        local record, missing = Server.lineRecordAt(at)
        if not record then return nil, missing end
        Server.setFields(record, nil, args.hours)
        record.wetUntil = (record.wetUntil or 0) - args.hours
        record:update()
    end
    local reply = readTiles(args.tiles)
    reply.before = before
    reply.squares = args.squares and { before = squaresBefore, after = Server.readSquares(args.squares) } or nil
    return reply
end)

-- Runs the line tapped at x, y, z for `args.hours` as Water from Tank does (TapSystem.run), then
-- reads `args.tiles`. Answers the litres `drawn` from the tank its tap drew on, nil if none could
-- feed it, `stopped`, why the water stops, if it does, and `args.squares` as Server.readSquares
-- reads them in `squares.before` and `squares.after`.
handler("lines.flow", function(player, args)
    local tap = EnhancedIrrigation.Lines.lineAt(args.x, args.y, args.z)
    if not tap then return nil, "a loaded line tile at " .. args.x .. "," .. args.y .. "," .. args.z end
    local Tanks = EnhancedIrrigation.Tanks
    local tank = EnhancedIrrigation.Taps.tankFor(tap)
    local before = tank and Tanks.litres(tank)
    local squaresBefore = Server.readSquares(args.squares)
    local stopped = EnhancedIrrigation.TapSystem.run(tap, args.hours)
    local reply = readTiles(args.tiles or {})
    reply.drawn = tank and before - Tanks.litres(tank) or nil
    reply.stopped = stopped
    reply.squares = args.squares and { before = squaresBefore, after = Server.readSquares(args.squares) } or nil
    return reply
end)

-- Runs the line job `args.job` with `args.with` at x, y, z through the authority's own perform (what
-- the action's complete() calls): on the square's floor for Lay, else on the line tile. Answers
-- whether it was `done` and `args.tiles` after, so a test sees the server refuse on its own.
handler("lines.perform", function(player, args)
    local LineJobs = EnhancedIrrigation.LineJobs
    local square = Server.squareAt(args)
    local object
    if args.job == LineJobs.LAY then
        object = square and square:getFloor()
    else
        object = EnhancedIrrigation.Lines.lineAt(args.x, args.y, args.z)
    end
    if not object then
        return nil, "the server's object for " .. tostring(args.job) .. " at " .. args.x .. "," .. args.y
    end
    local done = lineSystem().perform(player, args.job, object, args.with)
    local reply = readTiles(args.tiles or { { x = args.x, y = args.y, z = args.z } })
    reply.done = done == true
    return reply
end)

-- Holds the tap at x, y, z for a stand-in for another player named `args.as`, as their Water from
-- Tank holds it once open, and leaves it silent from then on, as a client's action goes that
-- disconnects mid-run: it never runs the tap again nor lets go. Answers whether it held the tap.
handler("lines.holdTap", function(player, args)
    local tap = EnhancedIrrigation.Lines.lineAt(args.x, args.y, args.z)
    if not tap then
        return nil, "the tap tile at " .. args.x .. "," .. args.y
    end
    local standIn = { character = { getUsername = function() return args.as end } }
    return { held = EnhancedIrrigation.TapSystem.hold(tap, standIn) }
end)

-- Dates the hold on the tap at x, y, z back past Holds.LAPSE_MS, as if its action had
-- been silent that long, so the test doesn't wait it out in real time.
handler("lines.lapseHold", function(player, args)
    local tap = EnhancedIrrigation.Lines.lineAt(args.x, args.y, args.z)
    local record = tap and EnhancedIrrigation.Lines.recordOf(tap)
    if not (record and record.heldMs) then
        return nil, "a held tap at " .. args.x .. "," .. args.y
    end
    record.heldMs = getTimestampMs() - EnhancedIrrigation.Holds.LAPSE_MS - 1
    return {}
end)

-- Makes a Water from Tank the multiplayer server starts from now run its flow every `args.ms`
-- real milliseconds until the test ends, so a test sees a walk-off or a dry tank in a frame or
-- two rather than a second. The flow counts world time since its last run, so the water drawn
-- doesn't depend on it.
handler("water.runEvery", function(player, args, defer)
    local Action = EnhancedIrrigationWaterAction
    -- The action's own setting, nil while it reads its base's.
    local before = rawget(Action, "RUN_MS")
    Action.RUN_MS = args.ms
    defer(function() Action.RUN_MS = before end)
    return {}
end)

-- Makes the air `args.celsius` wherever Frost reads it until the test ends.
handler("lines.temperature", function(player, args, defer)
    local Frost = EnhancedIrrigation.Frost
    local before = Frost.celsiusAt
    Frost.celsiusAt = function() return args.celsius end
    defer(function() Frost.celsiusAt = before end)
    return {}
end)

-- Makes the next ZombRandFloat(min, max) on this side roll `min`, a sure hit for any "roll under
-- a chance" (such as a punched hole splitting brittle pipe), then puts the real one back; or puts
-- it back when the test ends, if nothing rolled.
handler("lines.pinRoll", function(player, args, defer)
    local real = ZombRandFloat
    ZombRandFloat = function(min)
        ZombRandFloat = real
        return min
    end
    defer(function() ZombRandFloat = real end)
    return {}
end)

-- Crops ---------------------------------------------------------------------------------------------

-- Sows a crop on `at`, plowed and seeded as the farming system does them, at `water` water points,
-- taken away when the test ends. Returns it as plantAt reads it, or nil and what is missing.
local function sow(at, water, seed, defer)
    local square = Server.squareAt(at)
    if not square then
        return nil, "a loaded square for a crop at " .. at.x .. "," .. at.y
    end
    local farming = SFarmingSystem.instance
    farming:plow(square)
    defer(function()
        local plant = farming:getLuaObjectAt(at.x, at.y, at.z)
        -- Removing the crop's tile takes its record with it (SGlobalObjectSystem); a record whose
        -- tile is gone goes by itself.
        if plant and plant:getIsoObject() then
            plant:removeObject()
        elseif plant then
            farming:removeLuaObject(plant)
        end
        square:getModData().plowDay = nil
    end)
    local plant = farming:getLuaObjectOnSquare(square)
    if not plant then
        return nil, "the plowed furrow's record"
    end
    plant:seed(seed or "Carrots")
    plant.waterLvl = water
    plant:saveData()
    return plantAt(at)
end

-- A sown crop on x, y, z at `args.water` water points, or with `args.tiles` one on each of them,
-- answered in `plants`.
handler("lines.plant", function(player, args, defer)
    if not args.tiles then
        return sow(args, args.water, args.seed, defer)
    end
    local plants = {}
    for i, at in ipairs(args.tiles) do
        local plant, missing = sow(at, args.water, args.seed, defer)
        if not plant then return nil, missing end
        plants[i] = plant
    end
    return { plants = plants }
end)

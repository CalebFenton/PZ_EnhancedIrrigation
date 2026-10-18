require "PZHarness/ServerHandlers"

-- Development only, not published. The authority's half of the garden line tests
-- (EnhancedIrrigationTestsLines.lua) and of the line and crop fixtures in
-- EnhancedIrrigationTestLib.lua: line tiles and crops placed the way the authority places them,
-- line records read, aged and run, and the frost; the tanks are EnhancedIrrigationTestServer.lua's.
-- Only registers handlers, so a --stay rerun loads it again (RELOAD_FILES). Everything a handler
-- places goes when its test ends, by its square, so a stale copy left by a reload is no matter. A
-- tile is { x, y, z }; `args.tiles` lists them.

local handler = PZHarness.serverHandler

local function squareAt(at)
    return getCell():getGridSquare(at.x, at.y, at.z)
end

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

-- The saved fields of a line record, as plain values.
local function fieldsOf(record)
    local fields = {}
    for _, key in ipairs(EnhancedIrrigation.LineObject.SAVED_FIELDS) do
        fields[key] = record[key]
    end
    return fields
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
    return { state = plant.state, water = plant.waterLvl, health = plant.health, mildew = plant.mildewLvl,
        alive = plant:isAlive() }
end

-- What the server has at the tile `at`: `record` (its saved fields, wet, the line's size and who
-- holds its tap) or nil, `sprite` and `overlays` of its loaded tile, `plant`.
local function readTile(at)
    local Lines = EnhancedIrrigation.Lines
    local record = Lines.recordAt(at.x, at.y, at.z)
    local line = Lines.lineAt(at.x, at.y, at.z)
    local reply = { x = at.x, y = at.y, z = at.z, plant = plantAt(at) }
    if record then
        reply.record = fieldsOf(record)
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

local function recordOrMissing(at)
    local record = EnhancedIrrigation.Lines.recordAt(at.x, at.y, at.z)
    if not record then
        return nil, "a line record at " .. at.x .. "," .. at.y .. "," .. at.z
    end
    return record
end

-- Lines ---------------------------------------------------------------------------------------------

-- Lays a line tile on each of `args.tiles`, of the tile's `material` or `args.material`, with the
-- tile's `fields` (saved fields) set, as Lay Line would lay it.
handler("lines.place", function(player, args, defer)
    for _, at in ipairs(args.tiles) do
        local square = squareAt(at)
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

-- Sets each tile's `fields` on its record and shows it.
handler("lines.set", function(player, args)
    for _, at in ipairs(args.tiles) do
        local record, missing = recordOrMissing(at)
        if not record then return nil, missing end
        for key, value in pairs(at.fields or {}) do
            record[key] = value
        end
        record:afterChange()
    end
    return readTiles(args.tiles)
end)

-- Runs each tile's record as though `args.hours` had passed since its last pass, as the ten-minute
-- pass does, loaded or not; the hours pass for its soil's wet spell too. Answers the tiles after,
-- and in `before` as they were, read in the same call so no vanilla pass lands between.
handler("lines.age", function(player, args)
    local before = readTiles(args.tiles).tiles
    for _, at in ipairs(args.tiles) do
        local record, missing = recordOrMissing(at)
        if not record then return nil, missing end
        record.lastHour = EnhancedIrrigation.now() - args.hours
        record.wetUntil = (record.wetUntil or 0) - args.hours
        record:update()
    end
    local reply = readTiles(args.tiles)
    reply.before = before
    return reply
end)

-- Runs the line tapped at x, y, z for `args.hours` (Flow.run) from the tank its tap draws on
-- (LineJobs.tapTank), then reads `args.tiles`. Answers the litres `drawn`, or `stopped`, why no
-- water could run.
handler("lines.flow", function(player, args)
    local record, missing = recordOrMissing(args)
    if not record then return nil, missing end
    local tank, stopped = EnhancedIrrigation.LineJobs.tapTank(EnhancedIrrigation.Lines.lineAt(args.x, args.y, args.z))
    local drawn = tank and EnhancedIrrigation.Flow.run(record, tank, args.hours) or nil
    local reply = readTiles(args.tiles or {})
    reply.drawn, reply.stopped = drawn, stopped
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
    return { held = EnhancedIrrigation.LineSystem.holdTap(tap, standIn) }
end)

-- Makes every line's air `args.celsius` until the test ends.
handler("lines.temperature", function(player, args, defer)
    local LineObject = EnhancedIrrigation.LineObject
    local before = LineObject.temperatureAt
    LineObject.temperatureAt = function() return args.celsius end
    defer(function() LineObject.temperatureAt = before end)
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

-- A sown crop on x, y, z, plowed and seeded as the farming system does them, at `args.water` water
-- points and no mildew.
handler("lines.plant", function(player, args, defer)
    local square = squareAt(args)
    if not square then
        return nil, "a loaded square for a crop at " .. args.x .. "," .. args.y
    end
    local farming = SFarmingSystem.instance
    farming:plow(square)
    defer(function()
        local plant = farming:getLuaObjectAt(args.x, args.y, args.z)
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
    plant:seed(args.seed or "Carrots")
    plant.waterLvl = args.water
    plant.mildewLvl = 0
    plant:saveData()
    return plantAt(args)
end)

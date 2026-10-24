require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"
local Server = require "EnhancedIrrigation/Debug/EnhancedIrrigationTestServer"

-- Development only, not published. The server's half of EnhancedIrrigationTestsPumpHouse.lua: a
-- Pump House's record run for set hours by its own ten-minute pass, a generator set down and read,
-- the grid's shutoff moved to the past, appliances read, and items carried read. Pump Houses are
-- placed and plumbed by EnhancedIrrigationTestServerPumps.lua's handlers. Only registers handlers,
-- so a --stay rerun loads it again.

local handler = PZHarness.serverHandler

local function mod()
    return EnhancedIrrigation
end

local function recordAt(args)
    return mod().Pumps.recordAt(args.x, args.y, args.z)
end

-- The generator on the square at `at`, or nil.
local function generatorAt(at)
    local square = at and Server.squareAt(at)
    return square and square:getGenerator() or nil
end

-- The Pump House at args' x, y, z as plain values: its record's saved fields and summary (nil
-- without one), the tank at `args.tank` as Server.stateAt sees it, and the generator at
-- `args.generator`'s fuel and whether it runs.
local function stateAt(args)
    local record = recordAt(args)
    local state = {}
    if record then
        state.record = {}
        for _, key in ipairs(mod().PumpObject.SAVED_FIELDS) do
            state.record[key] = record[key]
        end
        state.summary = record:buildSummary()
    end
    state.tank = args.tank and Server.stateAt(args.tank) or nil
    local generator = generatorAt(args.generator)
    if generator then
        state.generator = { fuel = generator:getFuel(), running = generator:isActivated() }
    end
    return state
end

handler("pumpHouse.state", function(_, args)
    return stateAt(args)
end)

-- Sets `args.fields` on the Pump House's record, winds its clock back `args.hoursAgo` hours, if
-- given, and runs its ten-minute pass (PumpObject.update). Answers the clock's time, `now`, and the
-- state before and after, all in one call, so no ten-minute event runs in between.
handler("pumpHouse.update", function(_, args)
    local record = recordAt(args)
    if not record then
        return nil, "the record of the Pump House at " .. args.x .. "," .. args.y
    end
    for key, value in pairs(args.fields or {}) do
        record[key] = value
    end
    if args.hoursAgo then
        record.lastHour = mod().now() - args.hoursAgo
    end
    local reply = { now = mod().now(), before = stateAt(args) }
    record:update()
    reply.after = stateAt(args)
    return reply
end)

-- Sets a vanilla generator down on x, y, z, connected, with `args.fuel` in it, and starts it.
-- Answers its fuel. Switched off and taken away when the test ends.
handler("pumpHouse.generator", function(_, args, defer)
    local square = Server.squareAt(args)
    if not square then
        return nil, "a loaded square for the generator at " .. args.x .. "," .. args.y
    end
    local generator = IsoGenerator.new(instanceItem("Base.Generator"), square:getCell(), square)
    defer(function() PZHarness.Fixtures.removePlaced(generator) end)
    generator:setConnected(true)
    generator:setCondition(100)
    generator:setFuel(args.fuel)
    generator:setActivated(true)
    return { fuel = generator:getFuel(), running = generator:isActivated() }
end)

-- Moves the grid's shutoff to the last whole day of the world's age that has passed, so the grid is
-- off now, until the test ends. Answers the world hour it went off, `shutoff`, and `now`.
handler("pumpHouse.shutoff", function(_, args, defer)
    local option = getSandboxOptions():getOptionByName("ElecShutModifier")
    local saved = option:getValue()
    defer(function() option:setValue(saved) end)
    option:setValue(math.floor(getGameTime():getWorldAgeDaysSinceBegin()))
    return { shutoff = mod().PumpHouse.shutoffHour(), now = mod().now(), grid = getSandboxOptions():doesPowerGridExist() }
end)

-- The appliance drawn as `args.sprite` at x, y, z: whether it runs, whether a washer-dryer is set to
-- dry, and whether its pump is gone.
handler("appliances.state", function(_, args)
    local square = Server.squareAt(args)
    local appliance = square and PZHarness.Fixtures.objectWithSprite(square, args.sprite)
    if not appliance then
        return { found = false }
    end
    local combo = instanceof(appliance, "IsoCombinationWasherDryer")
    local switched = combo or instanceof(appliance, "IsoClothingWasher")
    return { found = true, activated = switched and appliance:isActivated() or false,
        dryer = combo and appliance:isModeDryer(), stripped = mod().Appliances.isStripped(appliance) }
end)

-- Runs vanilla's switch of the washer or washer-dryer drawn as `args.sprite` at x, y, z on the
-- authority, as its action's complete() does once a client asks (ISToggleClothingWasher,
-- ISToggleComboWasherDryer), whatever the client checked; a washer-dryer set to `args.mode`
-- ("washer" or "dryer") first, as ISSetComboWasherDryerMode does. Answers whether it ran and the
-- appliance's state after. A refused action on a multiplayer client would clear the test's queue,
-- so the switch is run here rather than queued.
handler("appliances.toggle", function(player, args)
    local square = Server.squareAt(args)
    local washer = square and PZHarness.Fixtures.objectWithSprite(square, args.sprite)
    if not washer then
        return nil, "the washer at " .. args.x .. "," .. args.y
    end
    local combo = instanceof(washer, "IsoCombinationWasherDryer")
    local done
    if combo then
        if args.mode then
            ISSetComboWasherDryerMode:new(player, washer, args.mode):complete()
        end
        done = ISToggleComboWasherDryer:new(player, washer):complete()
    else
        done = ISToggleClothingWasher:new(player, washer):complete()
    end
    return { done = done == true, activated = washer:isActivated(), dryer = combo and washer:isModeDryer(),
        stripped = mod().Appliances.isStripped(washer) }
end)

-- Every item of `args.type` the server's copy of the character carries, bags included: its
-- condition, the ceiling it carries (Pumps.ceilingOf) and, for a drainable, its uses left.
handler("pumpHouse.carried", function(player, args)
    local items = player:getInventory():getAllTypeRecurse(args.type)
    local found = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        table.insert(found, { condition = item:getCondition(), ceiling = mod().Pumps.ceilingOf(item),
            uses = instanceof(item, "DrainableComboItem") and item:getCurrentUses() or nil })
    end
    return { items = found }
end)

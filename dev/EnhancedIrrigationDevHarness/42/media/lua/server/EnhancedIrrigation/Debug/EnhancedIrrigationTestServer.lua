require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"

-- Development only, not published. The server's half of EnhancedIrrigationTestLib.lua: the tanks
-- and the recipe knowledge every system's tests use, the jobs the stand and link tests share, and
-- what the other handler files (EnhancedIrrigationTestServer*.lua) share, which this file returns.
-- Server Lua loads after shared, and the mod's server modules exist only on the authority, so the
-- handlers look them up when they run. Named to sort before the handler files, so that a --stay
-- rerun loads it again (RELOAD_FILES) before the files that require it; it only registers handlers.
--
-- What these place is removed by its square when the test ends, not by the object: the jobs under
-- test replace a stand's object with a barrel's and back, and the vanilla lid swaps it again.

local handler = PZHarness.serverHandler
local Fixtures = PZHarness.Fixtures

local Server = {}

local function mod()
    return EnhancedIrrigation
end

--- The loaded square at args' x, y, z, or nil.
function Server.squareAt(args)
    return args and args.x and getSquare(args.x, args.y, args.z)
end

--- The fields `savedFields` names (a record class's SAVED_FIELDS) of `record`, as plain values.
function Server.fieldsOf(record, savedFields)
    local fields = {}
    for _, key in ipairs(savedFields) do
        fields[key] = record[key]
    end
    return fields
end

--- Sets `fields` (saved fields) on `record` and, given `hoursAgo`, winds its clock to that many
--- hours ago (0: now), so only the hours a handler runs count.
function Server.setFields(record, fields, hoursAgo)
    for key, value in pairs(fields or {}) do
        record[key] = value
    end
    if hoursAgo then
        record.lastHour = mod().now() - hoursAgo
    end
end

--- The line record at `at`'s x, y, z, or nil and what is missing.
function Server.lineRecordAt(at)
    local record = mod().Lines.recordAt(at.x, at.y, at.z)
    if not record then
        return nil, "a line record at " .. at.x .. "," .. at.y .. "," .. at.z
    end
    return record
end
--- The Pump House record at args' x, y, z, or nil.
function Server.pumpHouseRecordAt(args)
    return mod().Pumps.recordAt(args.x, args.y, args.z)
end


--- Whether `object` is one of the things the tank tests place: a stand, with or without its barrel,
--- a tank, a treatment unit, a pump, or a well, which isn't a tank.
function Server.isPlaced(object)
    local EI = mod()
    return EI.Stands.isStand(object) or EI.Stands.isRaised(object) or EI.Tanks.isTank(object)
        or EI.Treatment.isUnit(object) or EI.Pumps.isPump(object) or EI.entityName(object) == "Well"
end

--- Removes the stand or tank at x, y, z the way the game removes an object.
function Server.removeAt(x, y, z)
    local square = getSquare(x, y, z)
    local object = square and mod().findObjectOn(square, Server.isPlaced)
    if object then
        square:transmitRemoveItemFromSquare(object)
    end
end

--- Takes every link with an end on x, y, z out of the list without giving its pipe back, so a link
--- a test made doesn't outlive it.
function Server.unlinkAt(x, y, z)
    local system = mod().LinkSystem.instance
    for _, link in ipairs(mod().Links.linksAt({ x = x, y = y, z = z })) do
        system:removeLink(link)
    end
end

--- Removes, when the test ends, whatever stand or tank stands at args' x, y, z then, and its links.
function Server.removeWhenDone(args, defer)
    defer(function()
        Server.unlinkAt(args.x, args.y, args.z)
        Server.removeAt(args.x, args.y, args.z)
    end)
end

-- The object as plain values: which of the mod's things it is, its tile and entity, and as a tank
-- its level and water.
local function describe(object)
    local EI = mod()
    local state = {
        found = true,
        sprite = object:getSprite() and object:getSprite():getName() or nil,
        entity = EI.entityName(object),
        isStand = EI.Stands.isStand(object),
        isRaised = EI.Stands.isRaised(object),
        isTank = EI.Tanks.isTank(object),
        health = object:getHealth(),
    }
    if state.isTank then
        local fluid = object:getFluidContainer()
        state.level = EI.Tanks.levelOf(object)
        state.litres = fluid:getAmount()
        state.capacity = fluid:getCapacity()
        state.tainted = fluid:isTainted()
    end
    return state
end

--- What stands at args' x, y, z (describe), whether the square is `loaded`, and how many `links`
--- have an end there.
function Server.stateAt(args)
    local square = Server.squareAt(args)
    if not square then
        return { loaded = false, found = false }
    end
    local object = mod().findObjectOn(square, Server.isPlaced)
    local state = object and describe(object) or { found = false }
    state.loaded = true
    state.links = #mod().Links.linksAt({ x = args.x, y = args.y, z = args.z })
    return state
end

-- Squares -------------------------------------------------------------------------------------------

-- What the square `at` holds: its crop's `water` and `health` (nil without one), whether a line
-- tile lies on it (`line`), and its soil's `soak`: that tile's, or off the line what every line
-- record in a sprinkler's reach keeps of it, added up, so a soak kept twice reads twice. Not
-- Sprinklers.holderOf, which stops at the first holder and so would hide a second.
local function readSquare(at)
    local EI = mod()
    local reply = { x = at.x, y = at.y, z = at.z, soak = 0 }
    local plant = SFarmingSystem.instance:getLuaObjectAt(at.x, at.y, at.z)
    if plant and plant.state ~= "plow" then
        reply.water, reply.health = plant.waterLvl, plant.health
    end
    local line = EI.Lines.recordAt(at.x, at.y, at.z)
    if line then
        reply.line, reply.soak = true, line.soak
        return reply
    end
    local reach = EI.Sprinklers.ALONG
    for dx = -reach, reach do
        for dy = -reach, reach do
            local holder = EI.Lines.recordAt(at.x - dx, at.y - dy, at.z)
            local soak = holder and holder.sprinklerSoak and holder.sprinklerSoak[EI.Sprinklers.offsetKey(dx, dy)]
            reply.soak = reply.soak + (soak or 0)
        end
    end
    return reply
end

--- Each of `squares` ({ x, y, z }) as readSquare reads it, or nil without `squares`.
function Server.readSquares(squares)
    if not squares then
        return nil
    end
    local read = {}
    for i, at in ipairs(squares) do
        read[i] = readSquare(at)
    end
    return read
end

--- Sets the crop on each of `squares` to `water` water points, when given, so what a pass gives
--- them is measured from room made in the same call, whatever passes ran before it.
function Server.setWater(squares, water)
    if not water then
        return
    end
    for _, at in ipairs(squares or {}) do
        local plant = SFarmingSystem.instance:getLuaObjectAt(at.x, at.y, at.z)
        if plant and plant.state ~= "plow" then
            plant.waterLvl = water
            plant:saveData()
        end
    end
end

-- Tanks ---------------------------------------------------------------------------------------------

--- Builds the object of the tile `sprite` on `square` as the build menu builds one
--- (ISBuildIsoEntity:setInfo): a thumpable with the entity that owns the tile, holding `litres` of
--- water (tainted when `tainted`), without its OnCreate. Sends it to the clients with its water: a
--- sync sent after can reach a client before the object does, which drops it. With `unsent`, the
--- caller sends it, or what its OnCreate replaces it with, as the build menu does after the
--- OnCreate. Returns it, or nil and what is missing.
function Server.build(square, sprite, litres, tainted, unsent)
    local script = mod().tileEntity(sprite)
    if not script then
        return nil, "the entity of the tile " .. tostring(sprite)
    end
    local thumpable = IsoThumpable.new(getCell(), square, sprite, false, nil)
    GameEntityFactory.CreateIsoObjectEntity(thumpable, script, true)
    if (litres or 0) > 0 then
        thumpable:getFluidContainer():addFluid(tainted and FluidType.TaintedWater or FluidType.Water, litres)
    end
    square:AddSpecialObject(thumpable)
    if not unsent then
        thumpable:transmitCompleteItemToClients()
    end
    return thumpable
end

-- Places the tile `args.sprite` (the stand, a raised barrel, a vanilla barrel) at x, y, z, on a
-- floor laid for it if the square has none (a tank on the storey above), holding `args.litres` of
-- water (tainted when `args.tainted`). Answers its state (Server.stateAt). Removed, its links and
-- the floor laid for it with it, when the test ends.
handler("tanks.place", function(_, args, defer)
    local square = Server.squareAt(args) or getCell():createNewGridSquare(args.x, args.y, args.z, true)
    if not square then
        return nil, "a square for " .. tostring(args.sprite) .. " at " .. args.x .. "," .. args.y .. "," .. args.z
    end
    if not square:getFloor() then
        local floor = square:addFloor("carpentry_02_58")
        defer(function()
            if floor:getObjectIndex() ~= -1 then
                square:transmitRemoveItemFromSquare(floor)
            end
            getCell():checkHaveRoof(args.x, args.y)
        end)
    end
    local object, missing = Server.build(square, args.sprite, args.litres, args.tainted)
    if not object then
        return nil, missing
    end
    Server.removeWhenDone(args, defer)
    return Server.stateAt(args)
end)

handler("tanks.read", function(_, args)
    return Server.stateAt(args)
end)

-- Removes, when the test ends, whatever stand or tank stands at x, y, z then, and its links: for
-- what the test builds through the game.
handler("tanks.track", function(_, args, defer)
    Server.removeWhenDone(args, defer)
    return {}
end)

handler("tanks.remove", function(_, args)
    Server.removeAt(args.x, args.y, args.z)
    return Server.stateAt(args)
end)

-- The system whose perform does each action feature's jobs.
local SYSTEMS = { stand = "StandSystem", link = "LinkSystem", treatment = "TreatmentSystem", pump = "PumpSystem" }

-- Runs the job `args.job` of the action feature `args.feature` at the object at x, y, z through the
-- authority's own perform (what the action's complete() calls), with `args.with`, or with the first
-- barrel moveable carried when `args.barrel`. Answers whether it was done and the object's state
-- after, so a test sees the server refuse what its menu would have greyed out.
handler("tanks.perform", function(player, args)
    local EI = mod()
    local square = Server.squareAt(args)
    local object = square and EI.findObjectOn(square, Server.isPlaced)
    if not object then
        return nil, "the server's object at " .. tostring(args.x) .. "," .. tostring(args.y)
    end
    local with = args.with
    if args.barrel then
        local carried = EI.Stands.barrelsCarried(player)[1]
        with = carried and carried.item
    end
    local done = EI[SYSTEMS[args.feature]].perform(player, args.job, object, with)
    local state = Server.stateAt(args)
    state.done = done == true
    return state
end)

-- Items ---------------------------------------------------------------------------------------------

-- Every item of `args.type` the server's copy of the character carries, bags included: its
-- condition, the ceiling it carries (Parts.ceilingOf) and, for a drainable, its uses left.
handler("items.carried", function(player, args)
    local items = player:getInventory():getAllTypeRecurse(args.type)
    local found = {}
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        table.insert(found, { condition = item:getCondition(), ceiling = mod().Parts.ceilingOf(item),
            uses = instanceof(item, "DrainableComboItem") and item:getCurrentUses() or nil })
    end
    return { items = found }
end)

-- Recipes -------------------------------------------------------------------------------------------

-- Makes the server's copy of the character know (`args.known`) or not know the recipes
-- `args.names`. When the test ends it knows exactly the recipes it knew before, including those a
-- level up taught meanwhile (vanilla's AutoLearn), which the leak check counts.
handler("recipes.know", function(player, args, defer)
    local saved = Fixtures.knownRecipes(player)
    if args.known then
        Fixtures.learnRecipes(player, args.names)
    else
        Fixtures.forgetRecipes(player, args.names)
    end
    defer(function()
        local known = player:getKnownRecipes()
        known:clear()
        for _, name in ipairs(saved) do
            known:add(name)
        end
    end)
    return {}
end)

return Server

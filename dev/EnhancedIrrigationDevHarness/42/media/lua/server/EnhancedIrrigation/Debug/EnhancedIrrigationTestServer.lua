require "PZHarness/ServerHandlers"
require "PZHarness/Fixtures"

-- Development only, not published. The server's half of EnhancedIrrigationTestLib.lua: the tanks
-- and the recipe knowledge every feature's tests use, and what the other handler files
-- (EnhancedIrrigationTestServer*.lua) share, which this file returns. Server Lua loads after
-- shared, and the mod's server modules exist only on the authority, so the handlers look them up
-- when they run. Named to sort before the handler files, so that a --stay rerun loads it again
-- (RELOAD_FILES) before the files that require it; it only registers handlers.
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

--- Whether `object` is one of the things the tank tests place: a stand, with or without its barrel,
--- a tank, or a well, which isn't one.
function Server.isPlaced(object)
    local EI = mod()
    return EI.Stands.isStand(object) or EI.Stands.isRaised(object) or EI.Tanks.isTank(object)
        or EI.entityName(object) == "Well"
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

-- Tanks ---------------------------------------------------------------------------------------------

-- Builds the object of the tile `sprite` on `square` as the build menu builds one
-- (ISBuildIsoEntity:setInfo): a thumpable with the entity that owns the tile. Sends it to the
-- clients. Returns it, or nil and what is missing.
local function build(square, sprite)
    local script = mod().tileEntity(sprite)
    if not script then
        return nil, "the entity of the tile " .. tostring(sprite)
    end
    local thumpable = IsoThumpable.new(getCell(), square, sprite, false, nil)
    GameEntityFactory.CreateIsoObjectEntity(thumpable, script, true)
    square:AddSpecialObject(thumpable)
    thumpable:transmitCompleteItemToClients()
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
    local object, missing = build(square, args.sprite)
    if not object then
        return nil, missing
    end
    Server.removeWhenDone(args, defer)
    if (args.litres or 0) > 0 then
        object:getFluidContainer():addFluid(args.tainted and FluidType.TaintedWater or FluidType.Water, args.litres)
        object:sync()
    end
    return Server.stateAt(args)
end)

handler("tanks.read", function(_, args)
    return Server.stateAt(args)
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

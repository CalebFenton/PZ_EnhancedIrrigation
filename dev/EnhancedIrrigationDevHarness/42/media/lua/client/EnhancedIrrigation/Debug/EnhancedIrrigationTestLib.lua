require "PZHarness/TestLib"
require "PZHarness/TestMenus"
require "PZHarness/TestBuild"
require "PZHarness/TestChunks"
require "PZHarness/TestLearning"
require "PZHarness/TestReads"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Links/Links"
require "EnhancedIrrigation/Links/LinkJobs"
require "EnhancedIrrigation/Tanks"

-- Development only, not published. The mod's test library: PZHarness.Test with the waits, reads,
-- menu helpers and fixtures the mod's tests share. Fixtures are placed by server handlers the way
-- the authority places them, and each waits for this client's copy. A tile handle is { x, y, z,
-- square }. The line, pump and treatment helpers extend it in EnhancedIrrigationTestLibLines,
-- TestLibPumps and TestLibTreatment, for the files that require them. A fixture only one test file
-- uses is that file's own.

EnhancedIrrigationTest = EnhancedIrrigationTest or setmetatable({}, { __index = PZHarness.Test })
local T = EnhancedIrrigationTest

local Lines = EnhancedIrrigation.Lines
local Links = EnhancedIrrigation.Links
local Tanks = EnhancedIrrigation.Tanks
local Sprites = EnhancedIrrigation.Sprites

-- How near the litres a test reads of a tank, basin or fixture must come to its sums.
T.LITRES = 0.05
-- How near this client's copy of a tank's water must come to what the server put in it, and the
-- litres of a small flow (a few minutes out of a hole, a tank of a few drops) to their sums, where
-- T.LITRES would pass a tank left as it was.
T.FINE_LITRES = 0.01
-- How near a crop's water, as a handler reads it in the same call as its sums, must come to them.
T.POINTS = 0.05
-- A crop's water as read, give or take vanilla's own ten-minute drying (SFarmingSystem.checkWater)
-- landing between placing the crop and reading it.
T.CROP_POINTS = 0.25
-- A tank that holds far more than a test's hours draw from it.
T.TANK_LITRES = 100
-- A raised barrel's water: vanilla's round rain barrel's.
T.BARREL_LITRES = 600
-- An hour's minute, and half an hour, as the records' sums take them.
T.MINUTE = 1 / 60
T.HALF_HOUR = 0.5
-- Vanilla's house wall on a square's west edge.
T.WALL_WEST = "walls_exterior_house_01_0"

-- Menus ---------------------------------------------------------------------------------------------

--- The option of the world menu `context` that queues `job` of the action feature `feature`
--- (EnhancedIrrigationAction.queue), with `with` if given, in any submenu, or nil.
function T.jobOption(context, feature, job, with)
    return T.findOption(context, function(option)
        return option.onSelect == EnhancedIrrigationAction.queue and option.param1 == feature and option.param2 == job
            and (with == nil or option.param4 == with)
    end)
end

--- Queues walking next to `handle`'s square and T.useOption on this client's copy of it
--- (T.copyOf).
function T.useMenu(self, handle, label, find, choose)
    T.goNextTo(self, handle.square)
    T.useOption(self, function() return T.copyOf(handle) end, label, find, choose)
end

--- A `find` for T.useOption: the option queuing `job` of the action feature `feature`, with `with`
--- if given (T.jobOption): an item or other value, or a function giving it when the menu is read,
--- for an item a step before gives.
function T.job(feature, job, with)
    return function(context)
        return T.jobOption(context, feature, job, type(with) == "function" and with() or with)
    end
end

--- How many of `fullType` T.count noted as "left", 0 if it noted none.
function T.counted(self, fullType)
    return self.counts.left and self.counts.left[fullType] or 0
end

-- Recipes -------------------------------------------------------------------------------------------

--- Queues crafting the recipe `name` from the first carried `from` the way the right-click menu
--- does or, with `opts.bench` ({ entity script, sprite }, T.placeBench), the way that bench's window
--- does: the character knows this recipe (until the test ends), has its skill and carries exactly
--- one craft's inputs (T.recipeInputs with `opts.prefer`). `opts.workTable` checks the scenario's
--- work table stands by the character (T.placeWorkTable); `opts.ready(self)`, if given, queues
--- what the inputs need first. Then counts `counted` (full types) into self.counts.craft. Returns
--- whether it queued the craft. T.craftTest would teach every recipe of the mod.
function T.craft(self, name, from, counted, opts)
    opts = opts or {}
    local recipe = T.need(self, getScriptManager():getCraftRecipe(name), "the recipe " .. name)
    if not recipe then return false end
    T.knowRecipes(self, { name }, true)
    if opts.workTable then
        T.placeWorkTable(T.player())
    end
    T.setRecipeSkills(self, recipe)
    local placed = opts.bench and T.placeBench(self, opts.bench[1], opts.bench[2])
    if opts.bench and not placed then return false end
    local inputs, unmatched = T.recipeInputs(recipe, opts.prefer)
    if not T.need(self, #unmatched == 0, "an item for " .. table.concat(unmatched, "; ")) then return false end
    T.give(self, "inputs", inputs)
    if opts.ready then
        opts.ready(self)
    end
    T.waitForLight(self)
    T.step(function()
        local item = T.need(self, T.carried(from), "a " .. from .. " to craft from")
        if not item then return end
        T.startCraft(self, recipe, item, placed and placed.object)
        -- Queued after the craft's actions, which T.startCraft has just queued.
        T.count(self, "craft", counted, { dropped = true })
    end)
    return true
end

-- The build menu -------------------------------------------------------------------------------------

--- Queues building `entity` (a full name) from the build menu on a T.buildSite (T.build, each
--- input the first of `prefer` it takes), the tile removed when the test ends (tanks.track), and
--- waits for this client's copy of the tile `sprite`. Returns the built tile's handle, or nil.
function T.buildTile(self, entity, sprite, prefer)
    local square = T.buildSite(self)
    if not square then return nil end
    local handle = T.where(square)
    local built = T.at(handle, { square = square, sprite = sprite })
    T.server(self, "tanks.track", T.at(handle))
    if not T.build(self, entity, square, prefer, function() return T.copyOf(built) ~= nil end,
        "this client's copy of the built " .. entity) then
        return nil
    end
    return built
end

-- Squares -------------------------------------------------------------------------------------------

--- A tile handle of `square`.
function T.where(square)
    return { x = square:getX(), y = square:getY(), z = square:getZ(), square = square }
end

--- The { x, y, z } of `handle`, with `extra`'s fields: the args of a server handler.
function T.at(handle, extra)
    local at = { x = handle.x, y = handle.y, z = handle.z }
    for key, value in pairs(extra or {}) do
        at[key] = value
    end
    return at
end

function T.tiles(handles)
    local tiles = {}
    for i, handle in ipairs(handles) do
        tiles[i] = T.at(handle)
    end
    return tiles
end

-- Whether `square` may take a fixture: not taken by this test, no vehicle on it, outdoors unless
-- `opts.indoors`; with `opts.bare`, walkable with nothing but its floor and not the character's own
-- (room for a tank), else able to take a line tile.
local function fits(self, square, opts)
    if square == nil or self.used[square] or square:getVehicleContainer() ~= nil
            or square:isOutside() == (opts.indoors == true) then
        return false
    end
    if opts.bare then
        return square:isFree(false) and square:getObjects():size() == 1 and square ~= T.player():getCurrentSquare()
    end
    return Lines.canTakeLine(square)
end

-- Whether no wall stands between any two of `squares` one step apart (Lines.joins), their offsets
-- being `offsets`.
local function joined(squares, offsets)
    for i, offset in ipairs(offsets) do
        for j, other in ipairs(offsets) do
            for _, step in ipairs(Lines.STEPS) do
                if other[1] == offset[1] + step.dx and other[2] == offset[2] + step.dy
                        and not Lines.joins(squares[i]:getX(), squares[i]:getY(), squares[i]:getZ(), step) then
                    return false
                end
            end
        end
    end
    return true
end

--- Handles of the squares at `offsets` ({ { dx, dy }, ... }) from an origin around the character,
--- on its level, at least `opts.minDistance` (1 unless given) away: each fits (bare or able to take a
--- line tile, indoors or out, as `opts` says), with `opts.joined` no wall between any two one step
--- apart, and with `opts.accept`, `opts.accept(squares)` holds of them. Nil, and missing, when there
--- is no such place.
function T.layout(self, offsets, opts)
    opts = opts or {}
    local centre = T.player():getCurrentSquare()
    local z = centre:getZ()
    for radius = opts.minDistance or 1, T.SEARCH_RADIUS do
        for x, y in PZHarness.Fixtures.ring(centre:getX(), centre:getY(), radius) do
            local squares = {}
            for i, offset in ipairs(offsets) do
                local square = getSquare(x + offset[1], y + offset[2], z)
                if not fits(self, square, opts) then
                    break
                end
                squares[i] = square
            end
            if #squares == #offsets and (not opts.joined or joined(squares, offsets))
                    and (not opts.accept or opts.accept(squares)) then
                local handles = {}
                for i, square in ipairs(squares) do
                    self.used[square] = true
                    handles[i] = T.where(square)
                end
                return handles
            end
        end
    end
    T.need(self, nil, #offsets .. " " .. (opts.bare and "bare " or "free ") .. (opts.indoors and "indoor" or "outdoor")
        .. " squares")
    return nil
end

--- `count` squares in a row west to east, each able to take a line tile (T.layout); with
--- `opts.rows` rows of them, each north of the last; no wall between any two of them. Returns the
--- rows, each a list of handles, or nil and missing.
function T.row(self, count, opts)
    opts = opts or {}
    local rows, offsets = opts.rows or 1, {}
    for r = 0, rows - 1 do
        for i = 0, count - 1 do
            table.insert(offsets, { i, -r })
        end
    end
    local handles = T.layout(self, offsets, { indoors = opts.indoors, minDistance = opts.minDistance, joined = true })
    if not handles then return nil end
    local found = {}
    for r = 1, rows do
        found[r] = {}
        for i = 1, count do
            found[r][i] = handles[(r - 1) * count + i]
        end
    end
    return found
end

-- Tanks and crops -----------------------------------------------------------------------------------

-- What T.placeTank places, by kind: the tile, and how many floors above the given square it goes.
T.TANKS = {
    -- Vanilla's open rain barrel on the ground: a tank with no head for a line on its floor.
    ground = { sprite = "carpentry_02_122" },
    -- The same barrel on the floor above, as a player sets one on a roof or upper storey.
    above = { sprite = "carpentry_02_122", up = 1 },
    -- A rain barrel on a Tank Stand on the floor above: two storeys of head.
    raisedAbove = { sprite = Sprites.RAISED_BARREL, up = 1 },
    -- Vanilla's lidded rain barrel, which no rain fills meanwhile.
    lidded = { sprite = "carpentry_02_126" },
    -- A Tank Stand with no barrel on it: no tank.
    stand = { sprite = Sprites.TANK_STAND },
    -- A rain barrel on a Tank Stand, open and lidded.
    raised = { sprite = Sprites.RAISED_BARREL },
    raisedLidded = { sprite = Sprites.RAISED_BARREL_CLOSED },
    -- Vanilla's well, on the floor above: never a tank, whatever water it holds.
    wellAbove = { sprite = "camping_01_16", up = 1 },
    -- The same well on the ground, as the map has them, for a pump to draw from.
    well = { sprite = "camping_01_16" },
    -- Vanilla's closed amphora: a tank smaller than the barrels, so equal fill isn't equal litres.
    amphora = { sprite = "crafted_04_32" },
}

--- Queues placing a T.TANKS `kind` at `handle`, holding `litres` of water (tainted when
--- `tainted`), and a wait for this client's copy. Returns its handle { x, y, z, sprite, square },
--- whose square is filled once this client has it.
function T.placeTank(self, handle, kind, litres, tainted)
    local spec = T.TANKS[kind]
    local up = spec.up or 0
    local tank = { x = handle.x, y = handle.y, z = handle.z + up, sprite = spec.sprite,
        square = up == 0 and handle.square or nil }
    T.server(self, "tanks.place", T.at(tank, { sprite = spec.sprite, litres = litres, tainted = tainted }))
    T.waitFor(self, function()
        local square = getSquare(tank.x, tank.y, tank.z)
        local copy = T.objectWithSprite(square, tank.sprite)
        tank.square = square
        return copy ~= nil and (not Tanks.isTank(copy) or math.abs(Tanks.litres(copy) - (litres or 0)) < T.FINE_LITRES)
    end, "this client's copy of the " .. kind)
    return tank
end

--- This client's copy of the object drawn as `sprite` (the handle's own unless given) on the
--- handle's square, or nil.
function T.copyOf(handle, sprite)
    return T.objectWithSprite(getSquare(handle.x, handle.y, handle.z), sprite or handle.sprite)
end

--- Whether the list of overlay names `names` (T.overlaysOf, or a server read's) holds `name`.
function T.hasOverlay(names, name)
    for _, overlay in ipairs(names or {}) do
        if overlay == name then
            return true
        end
    end
    return false
end

--- Queues a sown crop on each of `handles` at `water` water points, and a wait for this client's
--- copies.
function T.plant(self, handles, water)
    T.server(self, "lines.plant", { tiles = T.tiles(handles), water = water })
    T.waitFor(self, function()
        for _, handle in ipairs(handles) do
            if not CFarmingSystem.instance:getLuaObjectOnSquare(getSquare(handle.x, handle.y, handle.z)) then
                return false
            end
        end
        return true
    end, "this client's copies of the crops")
end

-- Items --------------------------------------------------------------------------------------------

--- The ceiling (Parts.ceilingOf) of `carried`, an item of the server's that T.carriedItems read,
--- or nil for none. Parts.ceilingOf reads only the item's modData, which the read carries.
function T.ceilingOf(carried)
    return carried and EnhancedIrrigation.Parts.ceilingOf({ getModData = function() return carried.modData end })
end

--- Queues giving the character what plumbing takes: the knowledge (LinkJobs.RECIPE), a pipe
--- wrench and `pipes` iron pipe, in self.items.tools.
function T.givePlumbing(self, pipes)
    T.knowRecipes(self, { EnhancedIrrigation.LinkJobs.RECIPE }, true)
    T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = "Base.MetalPipe", count = pipes } })
end

-- Links and fixtures --------------------------------------------------------------------------------

--- The links with an end on `handle` this client's own copy of the list holds, with the field
--- `role` (as a fixture's link has `fixture`) if given. Reads clientSystem, which the server's
--- commands set in single player too, since Links.linksAt reads the server's list there.
function T.clientLinks(handle, role)
    local at, found = T.at(handle), {}
    for _, link in ipairs(Links.clientSystem.links) do
        if Links.otherEnd(link, at) and (role == nil or link[role]) then
            table.insert(found, link)
        end
    end
    return found
end

--- Queues placing the fixture tile `sprite` at `handle` (fixtures.place, with `extra`'s args:
--- washer, combo, plumbed, buffer) and a wait for this client's copy, with the buffer's litres if
--- given. Returns its handle.
function T.placeFixture(self, handle, sprite, extra)
    local fixture = { x = handle.x, y = handle.y, z = handle.z, sprite = sprite, square = handle.square }
    local args = T.at(fixture, extra)
    args.sprite = sprite
    T.server(self, "fixtures.place", args)
    local litres = extra and extra.buffer and extra.buffer.litres
    T.waitFor(self, function()
        local copy = T.copyOf(fixture)
        local buffer = copy and copy:getFluidContainer()
        return copy ~= nil and (not litres
            or (buffer ~= nil and math.abs(buffer:getAmount() - math.min(litres, buffer:getCapacity())) < T.LITRES))
    end, "this client's copy of the " .. sprite)
    return fixture
end

-- Held actions --------------------------------------------------------------------------------------

-- Who holds a tap or a pump in the one-person tests, standing in for another player (holds.hold).
T.OTHER = "EnhancedIrrigationTestOther"
-- How often, in real milliseconds, the multiplayer server runs a held action in these tests: a
-- frame or two, where the mod's second would be most of a test's time.
T.RUN_MS = 20

--- Queues the clock at `speed` and the multiplayer server running every held action of the class
--- named `action` started from now each T.RUN_MS, until the test ends.
function T.quickRuns(self, action, speed)
    T.setMultiplier(self, speed)
    T.server(self, "holds.runEvery", { action = action, ms = T.RUN_MS })
end

--- Queues the held action `Action` at `getCopy()`, this client's copy of `what` it works on, for a
--- character whose client doesn't check that it may: its isValid always passes, so only the
--- authority's own check can stop it.
function T.queueUnchecked(self, Action, getCopy, what)
    T.step(function()
        local copy = T.need(self, getCopy(), "this client's copy of " .. what)
        if not copy then return end
        local action = Action:new(T.player(), copy)
        action.isValid = function() return true end
        ISTimedActionQueue.add(action)
    end)
end

return T

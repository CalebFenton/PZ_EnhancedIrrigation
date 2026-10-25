require "PZHarness/TestLib"
require "ISUI/ISWorldObjectContextMenu"
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

-- How long this client may take to show what the server changed.
local SYNC_MS = 5000
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

-- Waits and reads -----------------------------------------------------------------------------------

--- Queues a wait until `condition()` holds or `ms` (SYNC_MS unless given) pass; missing `what` if
--- it never held.
function T.waitFor(self, condition, what, ms)
    local sinceMs, held = nil, false
    T.waitUntil(function()
        sinceMs = sinceMs or getTimestampMs()
        held = condition() and true or false
        return held or getTimestampMs() - sinceMs > (ms or SYNC_MS)
    end, math.huge, what)
    T.step(function() T.need(self, held, what) end)
end

-- Queues a wait until it is light where the character stands. The game refuses a craft or build
-- in the dark (CraftRecipeData.canPerform), and the light lags the clock the previous test put
-- back by some frames, as T.craftTest's own wait allows for.
local function waitForLight(self)
    T.waitFor(self, function() return not T.player():tooDarkToRead() end, "light where the character stands")
end

--- Queues the server handler `name` with `args` and puts its answer in self.reads[label], the one
--- store of what the tests read from the server.
function T.read(self, name, args, label)
    self.reads = self.reads or {}
    T.server(self, name, args)
    T.step(function() self.reads[label] = self.server[name] end)
end

--- Queues calls of the server handler `name` until `done(answer)` holds or `maxMs` pass
--- (T.serverUntil), and puts the last answer in self.reads[label]: for what an action's complete()
--- does after this client's perform().
function T.readUntil(self, name, args, label, done, maxMs)
    self.reads = self.reads or {}
    T.serverUntil(self, name, args, function(reply) return reply ~= nil and done(reply) end, maxMs)
    T.step(function() self.reads[label] = self.server[name] end)
end

-- Menus ---------------------------------------------------------------------------------------------

--- The right-click menu of `object` as the character would open it, or nil.
function T.worldMenu(object)
    local context = ISWorldObjectContextMenu.createMenu(0, { object }, 0, 0)
    return type(context) == "table" and context or nil
end

--- The first option in `menu` or any submenu under it for which `matches(option)` holds, or nil.
function T.findOption(root, menu, matches)
    for _, option in ipairs(menu.options) do
        if matches(option) then
            return option
        end
        local sub = option.subOption and root:getSubMenu(option.subOption)
        local found = sub and T.findOption(root, sub, matches)
        if found then
            return found
        end
    end
    return nil
end

function T.findNamed(root, menu, name)
    return T.findOption(root, menu, function(option) return option.name == name end)
end

--- The option of the world menu `context` that queues `job` of the action feature `feature`
--- (EnhancedIrrigationAction.queue), with `with` if given, in any submenu, or nil.
function T.jobOption(context, feature, job, with)
    return T.findOption(context, context, function(option)
        return option.onSelect == EnhancedIrrigationAction.queue and option.param1 == feature and option.param2 == job
            and (with == nil or option.param4 == with)
    end)
end

--- Clicks `option` as ISContextMenu:onMouseUp does. A get-up option's handler would run only once
--- its ISWaitWhileGettingUp completes, behind the test's later waits; the character stands, so it
--- runs here at once.
function T.choose(option)
    if option.onSelect == ISContextMenu.onGetUpAndThen then
        option.param1(option.param2, option.param3, option.param4, option.param5, option.param6, option.param7,
            option.param8, option.param9, option.param10)
        return
    end
    option.onSelect(option.target, option.param1, option.param2, option.param3, option.param4, option.param5,
        option.param6, option.param7, option.param8, option.param9, option.param10)
end

function T.offered(option)
    return option ~= nil and not option.notAvailable
end

--- The tooltip text of `option`, or "".
function T.tooltipOf(option)
    return option and option.toolTip and option.toolTip.description or ""
end

--- Turns the character at once, body and animation, toward `target`: an object as an action's
--- faceThisObject aims at it (the nearest piece of a sprite grid, its facing position), or a
--- square's middle. An action otherwise waits for its turn (waitToStart) in real time, which
--- neither the instant cheat nor the frame rate shortens, and a square's middle isn't where the
--- game aims at a fixture or a treatment unit.
function T.face(target)
    local p = T.player()
    if instanceof(target, "IsoGridSquare") then
        local dx, dy = target:getX() + 0.5 - p:getX(), target:getY() + 0.5 - p:getY()
        if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
            p:setTargetAndCurrentDirection(dx, dy)
        end
        return
    end
    p:faceThisObject(target)
    local forward = p:getForwardDirection()
    p:setTargetAndCurrentDirection(forward:getX(), forward:getY())
end

--- Queues opening the world menu of `getObject()`, looked up when the step runs, and noting in
--- self.menu[label] what the option `find(context)` finds: { found, offered, tooltip, submenu,
--- name }. When `choose` and it is offered, the character faces the object (T.face) and chooses it.
function T.useOption(self, getObject, label, find, choose)
    self.menu = self.menu or {}
    T.step(function()
        local object = T.need(self, getObject(), "this client's copy of what " .. label .. " works on")
        local context = object and T.need(self, T.worldMenu(object), "a world menu for " .. label)
        if not context then return end
        local option = find(context)
        self.menu[label] = { found = option ~= nil, offered = T.offered(option), tooltip = T.tooltipOf(option),
            submenu = option ~= nil and option.subOption ~= nil, name = option and option.name }
        if choose and T.offered(option) then
            T.face(object)
            T.choose(option)
        end
        context:hideAndChildren()
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

--- A `find` for T.useOption: the option that runs `handler` (T.optionRunning).
function T.running(handler)
    return function(context) return T.optionRunning(context, handler) end
end

--- The option in `context`, in any submenu, that runs vanilla's `handler`. A get-up option carries
--- its handler as its first parameter.
function T.optionRunning(context, handler)
    return T.findOption(context, context, function(option)
        return option.onSelect == handler or option.param1 == handler
    end)
end

--- The option of the submenu named by `nameKey` in `context` for which `matches(option)` holds, or
--- nil.
function T.inSubmenu(context, nameKey, matches)
    local parent = T.findNamed(context, context, getText(nameKey))
    local sub = parent and parent.subOption and context:getSubMenu(parent.subOption)
    return sub and T.findOption(context, sub, matches) or nil
end

--- Queues the names of every option in the world menu of this client's copy of `handle`
--- (T.copyOf) into self.names[label].
function T.readMenu(self, handle, label)
    self.names = self.names or {}
    T.step(function()
        local copy = T.copyOf(handle)
        local context = T.need(self, copy and T.worldMenu(copy), "a world menu for " .. label)
        if not context then return end
        local names = {}
        T.findOption(context, context, function(option)
            table.insert(names, option.name)
            return false
        end)
        self.names[label] = names
        context:hideAndChildren()
    end)
end

--- Expects (`want`, or not) a line of the menu T.readMenu read as `label` to list `word` whole
--- among the words of its status line, where a search of the line would find "ripe" in "ripening".
function T.expectWord(self, label, word, want)
    local found = false
    for _, name in ipairs(self.names and self.names[label] or {}) do
        for part in (name .. ", "):gmatch("(.-), ") do
            found = found or part == word
        end
    end
    T.expect(found == (want ~= false), label .. ": the menu " .. (found and "lists " or "doesn't list ") .. word)
end

-- Expects (`want`, or not) a line of the menu T.readMenu read as `label` to contain `text`.
function T.expectLine(self, label, text, want)
    local found = false
    for _, name in ipairs(self.names and self.names[label] or {}) do
        found = found or name:find(text, 1, true) ~= nil
    end
    T.expect(found == (want ~= false), label .. ": the menu " .. (found and "says " or "doesn't say ") .. text)
end

--- Expects the option T.useOption noted as `label` offered.
function T.expectOffered(self, label)
    local seen = self.menu and self.menu[label]
    T.expect(seen and seen.offered, label .. ": not offered (" .. tostring(seen and seen.tooltip) .. ")")
end

--- Expects the option T.useOption noted as `label` in the menu but greyed out, its tooltip saying
--- the text of `tooltipKey` when given.
function T.expectRefused(self, label, tooltipKey)
    local seen = self.menu and self.menu[label]
    if T.expect(seen and seen.found, label .. ": the option isn't in the menu") then
        T.expect(not seen.offered, label .. ": offered")
        if tooltipKey then
            T.expect(seen.tooltip:find(getText(tooltipKey), 1, true) ~= nil,
                label .. ": the tooltip doesn't say " .. getText(tooltipKey) .. ": " .. seen.tooltip)
        end
    end
end

--- How many of `fullType` T.count noted as "left", 0 if it noted none.
function T.counted(self, fullType)
    return self.counts.left and self.counts.left[fullType] or 0
end

-- Recipes -------------------------------------------------------------------------------------------

--- Queues making this client's and the server's copy of the character know (`known`) or not know
--- the recipes `names`. When the test ends each side knows exactly the recipes it knew before,
--- including those a level up taught meanwhile (vanilla's AutoLearn), which the leak check counts.
function T.knowRecipes(self, names, known)
    T.step(function()
        local p = T.player()
        local saved = PZHarness.Fixtures.knownRecipes(p)
        if known then
            PZHarness.Fixtures.learnRecipes(p, names)
        else
            PZHarness.Fixtures.forgetRecipes(p, names)
        end
        T.defer(self, function()
            local list = p:getKnownRecipes()
            list:clear()
            for _, name in ipairs(saved) do
                list:add(name)
            end
        end)
    end)
    T.server(self, "recipes.know", { names = names, known = known })
end

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
    for i = 0, recipe:getRequiredSkillCount() - 1 do
        local skill = recipe:getRequiredSkill(i)
        T.setPerk(self, skill:getPerk(), skill:getLevel())
    end
    local placed = opts.bench and T.placeBench(self, opts.bench[1], opts.bench[2])
    if opts.bench and not placed then return false end
    local inputs, unmatched = T.recipeInputs(recipe, opts.prefer)
    if not T.need(self, #unmatched == 0, "an item for " .. table.concat(unmatched, "; ")) then return false end
    T.give(self, "inputs", inputs)
    if opts.ready then
        opts.ready(self)
    end
    waitForLight(self)
    T.step(function()
        local item = T.need(self, T.player():getInventory():getFirstTypeRecurse(from), "a " .. from .. " to craft from")
        if not item then return end
        T.startCraft(self, recipe, item, placed and placed.object)
        -- Queued after the craft's actions, which T.startCraft has just queued.
        T.count(self, "craft", counted, { dropped = true })
    end)
    return true
end

-- The build menu -------------------------------------------------------------------------------------

--- The build menu entry of `entity` (a game entity script's full name), or nil.
function T.buildEntry(entity)
    local script = getScriptManager():getGameEntityScript(entity)
    local spriteConfig = script and script:getComponentScriptFor(ComponentType.SpriteConfig)
    local infos = SpriteConfigManager.GetObjectInfoList()
    for i = 0, infos:size() - 1 do
        if spriteConfig and infos:get(i):getScript() == spriteConfig then
            return infos:get(i)
        end
    end
    return nil
end

-- What one build of `recipe` takes, as T.give items (T.recipeInputs, with `prefer`), with as many
-- full drainables as an input's uses need, where T.recipeInputs gives one: two sand bags for eight
-- uses. Also the inputs that had no possible item.
local function buildInputs(recipe, prefer)
    local items, unmatched = T.recipeInputs(recipe, prefer)
    if #unmatched > 0 then
        return items, unmatched
    end
    local inputs = recipe:getInputs()
    for i = 0, inputs:size() - 1 do
        local input, item = inputs:get(i), T.inputItem(inputs:get(i), prefer)
        if item:isItemType(ItemType.DRAINABLE) and not input:isItemCount() then
            local perItem = math.floor(1 / item:getUseDelta() + 0.0001)
            items[i + 1].count = math.ceil(input:getIntAmount() / perItem)
        end
    end
    return items, unmatched
end

--- Queues building `entity` (a full name) from the build menu at `handle`, through the build menu's
--- own path (ISBuildIsoEntity, ISBuildAction): the character gets the recipe's skill levels and
--- knowledge and exactly its inputs, each the first of `prefer` (full names) it takes if any
--- (T.inputItem), and the build waits for this client's copy of the tile `sprite`. A build the
--- menu refuses, for its inputs or its square, is missing. Returns the built tile's handle, or nil.
--- ISBuildIsoEntity is server Lua, which loads after this file, so it is reached at call time.
function T.buildFromMenu(self, entity, handle, sprite, prefer)
    local info = T.need(self, T.buildEntry(entity), "the build menu entry of " .. entity)
    local recipe = info and info:getRecipe() and info:getRecipe():getCraftRecipe()
    if not T.need(self, recipe, "the build recipe of " .. entity) then return nil end
    local built = T.at(handle, { square = handle.square, sprite = sprite })
    for i = 0, recipe:getRequiredSkillCount() - 1 do
        local skill = recipe:getRequiredSkill(i)
        T.setPerk(self, skill:getPerk(), skill:getLevel())
    end
    T.knowRecipes(self, { recipe:getName() }, true)
    local inputs, unmatched = buildInputs(recipe, prefer)
    if not T.need(self, #unmatched == 0, "an item for " .. table.concat(unmatched, "; ")) then return nil end
    T.give(self, "materials", inputs)
    T.server(self, "tanks.track", T.at(handle))
    -- Stands first: the character's current square follows a teleport only on its next update, and
    -- the cursor walks a character it can't see beside the site (luautils.walkAdjSquares).
    T.goNextTo(self, handle.square)
    waitForLight(self)
    T.step(function()
        local player = T.player()
        local build = ISBuildIsoEntity:new(player, info, 1, ISInventoryPaneContextMenu.getContainers(player))
        -- What the build panel does before the cursor can build (ISBuildPanel): the player number
        -- the drag sets (IsoCell.setDrag), and the recipe's inputs picked from what is carried.
        build.player = player:getPlayerNum()
        build.buildPanelLogic:refresh()
        build.buildPanelLogic:autoPopulateInputs()
        local canBuild = build.buildPanelLogic:canPerformCurrentRecipe()
        local validSquare = build:isValid(handle.square)
        if T.need(self, canBuild, "the build menu building " .. entity .. " from its inputs")
            and T.need(self, validSquare, "the build menu taking " .. entity .. "'s square") then
            build:tryBuild(handle.x, handle.y, handle.z)
        end
    end)
    T.waitFor(self, function() return T.copyOf(built) ~= nil end, "this client's copy of the built " .. entity)
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

-- Chunks --------------------------------------------------------------------------------------------

-- Tiles the character goes away for a reload, as Renewable Energy's chunk reload tests go: well
-- past this client's chunk map, so it saves the chunk and lets it go.
local AWAY = 600
-- How long a chunk may take to unload behind the character, or load again in front of it.
T.LOAD_MS = 60000
-- A test with a reload outlasts the runner's default timeout.
T.RELOAD_SECONDS = 150

--- Queues a trip AWAY tiles east and back, so this client saves the chunk of `at` ({ x, y, z }),
--- lets it go and loads it again; `whileAway()`, if given, queues what happens while it is gone.
--- In single player the server is the same game and its chunk goes too; a multiplayer server keeps
--- chunks loaded long after the character leaves, so there the trip reloads only this client's
--- copy, sent again by the server. Sets self.chunkLoads, the LoadChunk events for the chunk: none
--- would mean it came back from a cache with its state.
function T.reload(self, at, whileAway)
    local p = T.player()
    -- A teleport from inside a timed action doesn't stick, so OnTick makes it.
    local target, home
    T.onTick(self, function()
        if target then
            p:teleportTo(target[1], target[2], target[3])
            target = nil
        end
    end)
    local loads = 0
    local function onLoadChunk(chunk)
        local origin = chunk:getGridSquare(0, 0, 0)
        local dx, dy = origin and at.x - origin:getX(), origin and at.y - origin:getY()
        if origin and dx >= 0 and dx < 8 and dy >= 0 and dy < 8 then
            loads = loads + 1
        end
    end
    Events.LoadChunk.Add(onLoadChunk)
    T.defer(self, function() Events.LoadChunk.Remove(onLoadChunk) end)
    T.step(function()
        home = { p:getX(), p:getY(), p:getZ() }
        target = { at.x + AWAY + 0.5, at.y + 0.5, 0 }
    end)
    T.waitFor(self, function() return getSquare(at.x, at.y, at.z) == nil end, "this client to unload the chunk",
        T.LOAD_MS)
    if whileAway then
        whileAway()
    end
    T.step(function() target = home end)
    T.waitFor(self, function() return getSquare(at.x, at.y, at.z) ~= nil end, "this client to load the chunk again",
        T.LOAD_MS)
    T.step(function() self.chunkLoads = loads end)
end

--- Expects the chunk T.reload sent away to have come back through LoadChunk, not from a cache:
--- `what` names the thing in it.
function T.expectReloaded(self, what)
    T.expect((self.chunkLoads or 0) > 0, "the " .. what .. "'s chunk came back without LoadChunk, from a cache")
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

--- The names of the overlays drawn over `object` (its attached sprites), none for nil.
function T.overlaysOf(object)
    local names = {}
    local attached = object and object:getAttachedAnimSprite()
    for i = 0, (attached and attached:size() or 0) - 1 do
        table.insert(names, attached:get(i):getName())
    end
    return names
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

--- Queues filling the first carried `fullType`, emptied first, with `litres` of `fluid` (a
--- FluidType name) on the server, as much as it holds, and a wait for this client's copy to hold
--- that.
function T.fillCarried(self, fullType, fluid, litres)
    T.server(self, "items.fill", { type = fullType, fluid = fluid, litres = litres })
    T.waitFor(self, function()
        local item = T.player():getInventory():getFirstTypeRecurse(fullType)
        local container = item and item:getFluidContainer()
        return container ~= nil
            and math.abs(container:getAmount() - math.min(litres, container:getCapacity())) < T.LITRES
    end, "this client's copy of the filled " .. fullType)
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

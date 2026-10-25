require "PZHarness/TestLib"
require "ISUI/ISWorldObjectContextMenu"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines/Lines"
require "EnhancedIrrigation/Tanks"
require "EnhancedIrrigation/Pumps/Pumps"
require "EnhancedIrrigation/Treatment/Treatment"

-- Development only, not published. The mod's test library: PZHarness.Test with the waits, reads,
-- menu helpers and fixtures the mod's tests share. Fixtures are placed by server handlers the way
-- the authority places them, and each waits for this client's copy. A tile handle is { x, y, z,
-- square }. A fixture only one test file uses is that file's own.

EnhancedIrrigationTest = EnhancedIrrigationTest or setmetatable({}, { __index = PZHarness.Test })
local T = EnhancedIrrigationTest

local Lines = EnhancedIrrigation.Lines
local Tanks = EnhancedIrrigation.Tanks
local Sprites = EnhancedIrrigation.Sprites
local Pumps = EnhancedIrrigation.Pumps
local Treatment = EnhancedIrrigation.Treatment

-- How long this client may take to show what the server changed.
local SYNC_MS = 5000
-- How near this client's copy of a tank's water must come to what the server put in it.
local COPY_LITRES = 0.01
-- How near the litres a test reads of a tank, basin or fixture must come to its sums.
T.LITRES = 0.05
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

--- Queues a wait until it is light where the character stands. The game refuses a craft or build
--- in the dark (CraftRecipeData.canPerform), and the light lags the clock the previous test put
--- back by some frames, as T.craftTest's own wait allows for.
function T.waitForLight(self)
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
--- if given (T.jobOption).
function T.job(feature, job, with)
    return function(context) return T.jobOption(context, feature, job, with) end
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

--- Queues T.useOption on this client's copy of the line tile at `handle` for the line job `job`.
function T.useLineJob(self, handle, job, label, choose)
    T.useOption(self, function() return T.lineObject(handle) end, label, T.job("line", job), choose)
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
    T.waitForLight(self)
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
    T.waitForLight(self)
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

-- Line tiles ----------------------------------------------------------------------------------------

--- This client's copy of the line tile at `handle`, or nil.
function T.lineObject(handle)
    return Lines.lineAt(handle.x, handle.y, handle.z)
end

--- This client's summary of the line tile at `handle`, or nil.
function T.lineSummary(handle)
    local line = T.lineObject(handle)
    return line and Lines.summaryOf(line) or nil
end

--- The name of this client's sprite of the line tile at `handle`, or nil.
function T.lineSprite(handle)
    local line = T.lineObject(handle)
    return line and line:getSprite():getName() or nil
end

--- The saved fields of a tapped tile: { tap = true } with `extra`'s fields.
function T.tapped(extra)
    local fields = { tap = true }
    for key, value in pairs(extra or {}) do
        fields[key] = value
    end
    return fields
end

--- Queues a wait until this client has the line tile at every one of `handles` with its summary,
--- and `check(summary, handle)`, if given, holds for each.
function T.waitForLines(self, handles, what, check)
    T.waitFor(self, function()
        for _, handle in ipairs(handles) do
            local summary = T.lineSummary(handle)
            if not summary or (check and not check(summary, handle)) then
                return false
            end
        end
        return true
    end, what)
end

--- Queues laying a line tile of `material` on each of `handles` as the authority lays one, each
--- with its handle's `fields` (saved fields) set, and a wait for this client's copies.
function T.placeLine(self, handles, material, fields)
    local tiles = T.tiles(handles)
    for i, handle in ipairs(handles) do
        tiles[i].material = handle.material or material
        tiles[i].fields = handle.fields or fields
    end
    T.server(self, "lines.place", { tiles = tiles })
    T.waitForLines(self, handles, "this client's copy of the placed line")
end

--- Queues the server's view of `handles` into self.reads[label].tiles: a list in the handles'
--- order, each { record, sprite, overlays, plant }.
function T.readLines(self, handles, label)
    T.read(self, "lines.read", { tiles = T.tiles(handles) }, label)
end

--- Queues running the line tapped at `tap` for `hours` on the server as the tap runs it; the reply,
--- the litres `drawn` (nil when no tank fed it), why the water stops, `stopped`, if it does, and
--- `handles`' tiles, lands in self.reads[label].
function T.flow(self, tap, hours, handles, label)
    T.read(self, "lines.flow", T.at(tap, { hours = hours, tiles = T.tiles(handles) }), label)
end

--- Queues taking away, when the test ends, any line tile on `handles`, such as those its jobs lay.
function T.trackLines(self, handles)
    T.server(self, "lines.track", { tiles = T.tiles(handles) })
end

--- The shape (Sprites.pipe) a pipe tile's name draws, or nil for any other name.
function T.shapeOf(spriteName)
    local material, _, shape = Sprites.pipeOf(spriteName)
    return material and shape or nil
end

--- The Lay Line cursor for `material`, started as its menu option starts it unless `started`, and
--- put away when the test ends. Called in a step.
function T.layCursor(self, material, started)
    local playerNum = T.player():getPlayerNum()
    if not started then
        EnhancedIrrigation.LineCursor.start(playerNum, material)
    end
    local cursor = getCell():getDrag(playerNum)
    T.defer(self, function() getCell():setDrag(nil, playerNum) end)
    return cursor
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
        return copy ~= nil and (not Tanks.isTank(copy) or math.abs(Tanks.litres(copy) - (litres or 0)) < COPY_LITRES)
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

--- Queues a sown crop on `handle` at `water` water points, and a wait for this client's copy.
function T.plant(self, handle, water)
    T.server(self, "lines.plant", T.at(handle, { water = water }))
    T.waitFor(self, function()
        return CFarmingSystem.instance:getLuaObjectOnSquare(getSquare(handle.x, handle.y, handle.z)) ~= nil
    end, "this client's copy of the crop")
end

-- Pumps ---------------------------------------------------------------------------------------------

-- The tile of each pump entity: the hand pumps and the Pump Houses.
T.PUMP_SPRITES = {
    EnhancedIrrigation_WoodenHandPump = Sprites.WOODEN_HAND_PUMP,
    EnhancedIrrigation_IronHandPump = Sprites.IRON_HAND_PUMP,
    EnhancedIrrigation_PumpHouseWood = Sprites.PUMP_HOUSE_WOOD,
    EnhancedIrrigation_PumpHouseMetal = Sprites.PUMP_HOUSE_METAL,
}

--- This client's summary of the pump at `handle`, or nil.
function T.pumpSummary(handle)
    local copy = T.copyOf(handle)
    return copy and Pumps.summaryOf(copy)
end

--- Queues a wait until this client's summary of the pump at `handle` satisfies `holds(summary)`.
function T.waitForPumpSummary(self, handle, holds, what)
    T.waitFor(self, function()
        local summary = T.pumpSummary(handle)
        return summary ~= nil and holds(summary)
    end, what)
end

--- Queues placing the pump `entity` (a T.PUMP_SPRITES key) at `handle`, with `with.part` fitted
--- as Fit Pump fits it ({ type, condition, ceiling, fraction }) and `with.fields` on its record, if
--- given, and a wait for this client's copy and its summary. Returns its handle, with `spec`
--- (Pumps.ENTITIES, nil for a Pump House).
function T.placePump(self, handle, entity, with)
    local pump = { x = handle.x, y = handle.y, z = handle.z, sprite = T.PUMP_SPRITES[entity],
        spec = Pumps.ENTITIES[entity], square = handle.square }
    T.server(self, "pumps.place", T.at(pump, { sprite = pump.sprite, part = with and with.part,
        fields = with and with.fields }))
    T.waitFor(self, function() return T.pumpSummary(pump) ~= nil end, "this client's copy of the " .. entity)
    return pump
end

--- Queues plumbing the outlet of the pump at `pump` to the tank or line tile at `tank` on the
--- server, with `fields` set on its record, and a wait for this client to know of the link and,
--- when `fields.seal` is given, for its summary to have that seal.
function T.linkPump(self, pump, tank, fields)
    T.server(self, "pumps.link", T.at(pump, { tank = T.at(tank), fields = fields }))
    T.waitFor(self, function()
        if EnhancedIrrigation.Links.roleAt(T.at(pump), "pump") == nil then
            return false
        end
        local summary = fields and fields.seal and T.pumpSummary(pump)
        return not (fields and fields.seal) or (summary and summary.seal == fields.seal)
    end, "this client's copy of the pump's outlet")
end

-- Pump Houses ---------------------------------------------------------------------------------------

--- What a house is placed with: `part` (a full type) fitted as Fit Pump fits it, from an item new but
--- for what `item` gives ({ condition, ceiling, fraction } of a point past its condition), then
--- `fields` set on its record.
function T.pumpHouseFitted(part, fields, item)
    local fitting = { type = part }
    for key, value in pairs(item or {}) do
        fitting[key] = value
    end
    return { part = fitting, fields = fields }
end

--- The args of a server handler at the house, with the tank, generator and crop squares to read.
function T.pumpHouseAt(house, extra)
    return T.at(house, {
        tank = extra and extra.tank and T.at(extra.tank) or nil,
        generator = extra and extra.generator and T.at(extra.generator) or nil,
        squares = extra and extra.squares and T.tiles(extra.squares) or nil,
        water = extra and extra.water,
        hoursAgo = extra and extra.hoursAgo,
        fields = extra and extra.fields,
    })
end

--- Queues the house's ten-minute pass on the server, `extra.hoursAgo` hours after its last, with
--- `extra.fields` set first and the crops on `extra.squares` set to `extra.water`, into
--- self.reads[label] ({ now, before, after }).
function T.updatePumpHouse(self, house, label, extra)
    T.read(self, "pumpHouse.update", T.pumpHouseAt(house, extra), label)
end

function T.readPumpHouseUntil(self, house, label, done)
    T.readUntil(self, "pumpHouse.state", T.pumpHouseAt(house), label, done)
end

--- The litres `part` lifts in `hours`.
function T.pumpLifts(part, hours)
    return Pumps.perHour(Pumps.PARTS[part]) * hours
end

--- The generator fuel `part` burns in `hours`.
function T.pumpBurns(part, hours)
    return Pumps.PARTS[part].fuel * SandboxVars.GeneratorFuelConsumption * hours
end

-- Treatment units ---------------------------------------------------------------------------------

-- The tile of each treatment unit entity: the sand filters, the Filter Crock and the Boilers.
T.TREATMENT_SPRITES = { EnhancedIrrigation_BarrelFilter = Sprites.BARREL_FILTER,
    EnhancedIrrigation_BrickFilter = Sprites.BRICK_FILTER, EnhancedIrrigation_FilterCrock = Sprites.FILTER_CROCK,
    EnhancedIrrigation_BoilerStone = Sprites.BOILER_STONE, EnhancedIrrigation_BoilerWelded = Sprites.BOILER_WELDED }

--- Queues placing the unit `entity` at `handle` (up `opts.up` storeys), with `opts.fields` on its
--- record, and a wait for this client's copy and its summary. Returns its handle, with `spec`.
function T.placeUnit(self, handle, entity, opts)
    opts = opts or {}
    local up = opts.up or 0
    local unit = { x = handle.x, y = handle.y, z = handle.z + up, sprite = T.TREATMENT_SPRITES[entity],
        spec = Treatment.ENTITIES[entity], square = up == 0 and handle.square or nil }
    T.server(self, "treatment.place", T.at(unit, { sprite = unit.sprite, fields = opts.fields }))
    T.waitFor(self, function()
        unit.square = getSquare(unit.x, unit.y, unit.z)
        local copy = T.copyOf(unit)
        return copy ~= nil and Treatment.summaryOf(copy) ~= nil
    end, "this client's copy of the " .. entity)
    return unit
end

function T.readUnitUntil(self, unit, label, done, tank)
    T.readUntil(self, "treatment.state", T.at(unit, { tank = tank and T.at(tank) }), label, done)
end

-- Queues `fields` set on the unit's record and a run of each of `hours`, with the tank's state if
-- given, into self.reads[label] ({ before, steps }).
function T.runUnit(self, unit, label, hours, fields, tank)
    T.read(self, "treatment.run", T.at(unit, { hours = hours, fields = fields, tank = tank and T.at(tank) }), label)
end

-- Queues a wait until this client's copy of the unit holds `litres` in its basin, if given, and its
-- summary satisfies `holds(summary)`, if given.
function T.waitForUnitCopy(self, unit, litres, holds, what)
    T.waitFor(self, function()
        local copy = T.copyOf(unit)
        local summary = copy and Treatment.summaryOf(copy)
        return summary ~= nil and (not litres or math.abs(copy:getFluidContainer():getAmount() - litres) < T.LITRES)
            and (not holds or holds(summary))
    end, what)
end

-- Queues a wait until this client's summary of the unit agrees on `key` with the server's in
-- self.reads[label] (a state, an update's `after` or a run's last step), so a menu read after it
-- shows what the server answered.
function T.waitForUnitServer(self, unit, label, key)
    T.waitFor(self, function()
        local read = self.reads and self.reads[label]
        local state = read and (read.after or read.steps and read.steps[#read.steps] or read)
        local summary = Treatment.summaryOf(T.copyOf(unit))
        return state ~= nil and state.summary ~= nil and summary ~= nil and summary[key] == state.summary[key]
    end, "this client's summary of " .. label)
end

-- Queues the boiler's fire set on the authority (treatment.fire: `fuel` minutes if given, lit or
-- not) and a wait for this client's copy to show it, as vanilla's own fire actions leave it.
function T.setFire(self, unit, label, lit, fuel)
    T.read(self, "treatment.fire", T.at(unit, { lit = lit, fuel = fuel }), label)
    T.waitFor(self, function()
        local copy = T.copyOf(unit)
        return copy ~= nil and copy:isLit() == lit
    end, "this client's copy of the boiler " .. (lit and "lit" or "out"))
end

-- Fuel for the tests' fires, in minutes: longer than any test runs one.
T.FUEL = 600

-- Queues `litres` of raw water, tainted if `tainted`, set in the unit's head and treated into its
-- basin by the hours its rate takes (self.reads.filled), a boiler lit for them and put out after,
-- then a wait for this client's copy of the basin. A sand filter's film is grown for clean water
-- and new for tainted, so its basin holds the water as it was.
function T.fillBasin(self, unit, litres, tainted)
    local spec = unit.spec
    local fields, hours = { head = litres, headTainted = tainted == true }, litres / spec.rate
    if spec.kind == "sand" then
        fields.ripeHours = tainted and 0 or Treatment.RIPE_HOURS
    elseif spec.kind == "boiler" then
        -- A cold drum passes nothing until it is hot.
        hours = hours + Treatment.HOT_HOURS
        T.setFire(self, unit, "filled lit", true, T.FUEL)
    end
    T.runUnit(self, unit, "filled", { hours }, fields)
    if spec.kind == "boiler" then
        T.setFire(self, unit, "filled out", false)
    end
    T.waitForUnitCopy(self, unit, litres, nil, "this client's copy of the filled basin")
end

-- Expects (`want`, or not) a line of the menu T.readMenu read as `label` to contain `text`.
function T.expectLine(self, label, text, want)
    local found = false
    for _, name in ipairs(self.names and self.names[label] or {}) do
        found = found or name:find(text, 1, true) ~= nil
    end
    T.expect(found == (want ~= false), label .. ": the menu " .. (found and "says " or "doesn't say ") .. text)
end

function T.expectBasin(who, state, litres, tainted)
    if not T.expect(state and state.basin, who .. ": no unit") then return end
    T.expectNear(who .. ": the basin's water", state.basin.litres, litres, T.LITRES)
    if litres > 0 then
        T.expect(state.basin.tainted == tainted, who .. ": the basin's water is " .. (state.basin.tainted and "tainted" or "clean"))
    end
end

-- This client's copy's basin as the state T.expectBasin reads.
function T.clientBasin(unit)
    local copy = T.copyOf(unit)
    local basin = copy and copy:getFluidContainer()
    return basin and { basin = { litres = basin:getAmount(), tainted = basin:isTainted() } } or nil
end

-- The basin offers vanilla's Drink, Fill and Empty, but no pour into it, though the character
-- carries water; a bucket filled from it holds its water as it was. A Barrel Filter's basin holds
-- tainted water, and Drink warns of it; a crock's or a boiler's, clean, and Drink doesn't; the
-- boiler is a vanilla fireplace, whose fire menu stands beside the fluid menu. Catches a basin
-- vanilla can't reach, one it can pour into past the sand, the clay or the fire, or a taint lost or
-- made up. The crock's bucket holds no more than the one carried, so that one starts part full: a
-- Fill that empties its source ends in an invalid action on a multiplayer client, which clears the
-- queue.
--
-- `case`: the test's `name`, the unit's `entity`, the `litres` its basin is filled with and whether
-- they are `tainted`, and the litres already `inBucket`.
function T.vanillaBasinTest(case)
    T.test(case.name, {
        instant = true,
        run = function(self)
            local spots = T.layout(self, { { 0, 0 } }, { bare = true })
            if not spots then return end
            self.unit = T.placeUnit(self, spots[1], case.entity)
            T.fillBasin(self, self.unit, case.litres, case.tainted)
            T.give(self, "items", { { type = "Base.Bucket" }, { type = "Base.WaterBottle" } })
            -- Full, so vanilla's Fill lists only the bucket.
            T.server(self, "treatment.fillCarried", { type = "Base.WaterBottle", fluid = "Water", litres = 10 })
            if case.inBucket > 0 then
                T.server(self, "treatment.fillCarried", { type = "Base.Bucket", fluid = "Water", litres = case.inBucket })
            end
            T.waitFor(self, function()
                return self.items.items[2]:getFluidContainer():isFull()
                    and math.abs(self.items.items[1]:getFluidContainer():getAmount() - case.inBucket) < T.LITRES
            end, "this client's copies of the filled bottle and bucket")
            T.goNextTo(self, spots[1].square)
            T.step(function()
                local copy = T.copyOf(self.unit)
                local context = T.need(self, copy and T.worldMenu(copy), "a world menu for the unit")
                if not context then return end
                local drink = T.optionRunning(context, ISWorldObjectContextMenu.onDrink)
                local fill = T.optionRunning(context, ISWorldObjectContextMenu.onTakeWater)
                self.drink, self.drinkTooltip = T.offered(drink), T.tooltipOf(drink)
                self.fill = T.offered(fill)
                self.empty = T.offered(T.optionRunning(context, ISWorldObjectContextMenu.onFluidEmpty))
                self.pour = T.findNamed(context, context, getText("ContextMenu_AddFluidFromItem")) ~= nil
                if fill then
                    T.choose(fill)
                end
                context:hideAndChildren()
            end)
            T.readUnitUntil(self, self.unit, "drawn", function(state) return state.basin.litres < case.litres - 1 end)
            T.read(self, "treatment.carried", { type = "Base.Bucket" }, "bucket")
        end,
        validate = function(self)
            T.expect(self.drink, "the menu offers no Drink")
            local warns = self.drinkTooltip:find(getText("Tooltip_item_TaintedWater"), 1, true) ~= nil
            T.expect(warns == case.tainted, "Drink's tooltip " .. (warns and "warns" or "doesn't warn")
                .. " of tainted water: " .. self.drinkTooltip)
            T.expect(self.fill, "the menu offers no Fill for the bucket")
            T.expect(self.empty, "the menu offers no Empty")
            T.expect(not self.pour, "the menu offers vanilla's pour into the basin")
            local bucket = self.reads.bucket
            T.expect(bucket.litres > case.inBucket + 1, "Fill took nothing from the basin")
            T.expectNear("the basin and bucket", self.reads.drawn.basin.litres + bucket.litres, case.litres + case.inBucket,
                T.LITRES)
            T.expect(bucket.tainted == case.tainted, "the bucket filled from the basin holds "
                .. (bucket.tainted and "tainted" or "clean") .. " water")
        end,
    })
end

return T

require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "ISUI/ISInventoryPaneContextMenu"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/LineJobs"
require "EnhancedIrrigation/Pumps"
require "EnhancedIrrigation/Sprinklers"
require "EnhancedIrrigation/UI/LineMenu"
require "EnhancedIrrigation/UI/PlantInfo"

-- Lawn Sprinklers (Sprinklers.lua, the sprinkler's part of Flow.lua and LineObject.lua, Set and Take
-- Sprinkler in LineJobs.lua and LineSystem.lua, the line menu's options, the plant info's soil
-- word, Make Pipe Sprinkler in Recipes.txt): a sprinkler on a pumped line watering its rectangle at
-- the pump's rate, soaking it and rotting what's left waterlogged under it; nothing from a tapped
-- line; setting and taking one; making one and learning to. Lines run for set hours on the server
-- by what runs them there (EnhancedIrrigationTestServerSprinklers.lua), so the clock doesn't decide
-- the sums.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local Sprites, Lines, LineJobs = EnhancedIrrigation.Sprites, EnhancedIrrigation.Lines, EnhancedIrrigation.LineJobs
local Pumps, Sprinklers, PlantInfo = EnhancedIrrigation.Pumps, EnhancedIrrigation.Sprinklers, EnhancedIrrigation.PlantInfo

local POINTS = 0.05
local LITRES = 0.05
local IRON = "EnhancedIrrigation_IronHandPump"
local LEATHER = "Base.LeatherStrips"
local MINUTE = 1 / 60
-- A sprinkler as a new one goes on.
local NEW = { condition = 100, ceiling = 100 }
-- The squares a sprinkler waters.
local SQUARES = (2 * Sprinklers.ALONG + 1) * (2 * Sprinklers.ACROSS + 1)

-- Helpers -------------------------------------------------------------------------------------------

--- Queues placing the iron hand pump at `handle`, fitted with leather, a well beside it at `well`,
--- and its outlet plumbed to the line tile `into`; waits for this client's copies. Returns the
--- pump's handle.
local function pumpInto(self, handle, well, into)
    local pump = { x = handle.x, y = handle.y, z = handle.z, sprite = Sprites.IRON_HAND_PUMP, spec = Pumps.UNITS[IRON],
        square = handle.square }
    T.server(self, "pumps.place", T.at(pump, { sprite = pump.sprite }))
    T.placeTank(self, well, "well")
    T.server(self, "pumps.link", T.at(pump, { tank = T.at(into), fields = { seal = LEATHER } }))
    T.waitFor(self, function()
        local copy = T.objectWithSprite(getSquare(pump.x, pump.y, pump.z), pump.sprite)
        return copy ~= nil and Pumps.summaryOf(copy) ~= nil and Pumps.outletOf(T.at(pump)) ~= nil
    end, "this client's copy of the pump and its outlet")
    return pump
end

--- Queues a crop at no water on each of `handles`, and a wait for this client's copies.
local function plantAll(self, handles)
    T.server(self, "lines.plant", { tiles = T.tiles(handles), water = 0 })
    T.waitFor(self, function()
        for _, handle in ipairs(handles) do
            if not CFarmingSystem.instance:getLuaObjectOnSquare(getSquare(handle.x, handle.y, handle.z)) then
                return false
            end
        end
        return true
    end, "this client's copies of the crops")
end

-- Each square's change from `before` to `after` (sprinklers.* answers' squares): water and soak.
local function changes(before, after)
    local list = {}
    for i, square in ipairs(after) do
        list[i] = { water = (square.water or 0) - (before[i].water or 0), soak = square.soak - before[i].soak,
            health = (square.health or 0) - (before[i].health or 0), after = square }
    end
    return list
end

-- The plant points a sprinkler throws on each of its squares over `hours` from a pumped line that
-- gives it `litresPerHour`.
local function sprayed(litresPerHour, hours)
    return litresPerHour * hours * (1 - Sprinklers.LOST) * Lines.POINTS_PER_LITRE / SQUARES
end

-- Watering ------------------------------------------------------------------------------------------

-- The rectangle of a sprinkler on a line running north to south, with a crop on every square of it
-- and on the four squares just past its sides and ends: across, where an east-to-west rectangle
-- would reach, and along, a step past its ends.
local NORTH_SOUTH = {}
for dx = -Sprinklers.ACROSS, Sprinklers.ACROSS do
    for dy = -Sprinklers.ALONG, Sprinklers.ALONG do
        table.insert(NORTH_SOUTH, { dx, dy })
    end
end
local INSIDE = #NORTH_SOUTH
for _, offset in ipairs({ { -Sprinklers.ALONG, 0 }, { Sprinklers.ALONG, 0 }, { 0, -Sprinklers.ALONG - 1 },
    { 0, Sprinklers.ALONG + 1 } }) do
    table.insert(NORTH_SOUTH, offset)
end

-- The index in NORTH_SOUTH of the offset dx, dy.
local function indexOf(dx, dy)
    for i, offset in ipairs(NORTH_SOUTH) do
        if offset[1] == dx and offset[2] == dy then
            return i
        end
    end
    return nil
end

-- Hours the second run soaks the rectangle for: past full, so every square waterlogs.
local SOAK_HOURS = 0.25
-- Hours the soaked rectangle is left after, while its roots rot.
local ROT_HOURS = 2

-- A sprinkler in the middle of a three-tile line running north to south, driven by an iron hand
-- pump, which lifts less than the sprinkler asks: a minute's work waters every crop of the five by
-- three rectangle along the line the same, at the pump's rate less what the air takes, and none
-- past it, and wears the seal by what the pump lifted. Left on, it fills every crop and waterlogs
-- the soil, on the line's tiles and off them, which the plant info says of a crop off the line;
-- left a while, that crop's roots rot and its soil dries as a line tile's do. Catches a sprinkler
-- that waters off its rectangle or turned across the line, one that takes more than its pump
-- lifts, soak lost off the line, or soil that never dries or rots.
T.test("irrigation_sprinklers_water_their_rectangle_and_waterlog_it", {
    instant = true,
    run = function(self)
        local squares = T.layout(self, NORTH_SOUTH, { joined = true })
        if not squares then return end
        local spots = T.layout(self, { { 0, 0 }, { 1, 0 } }, { bare = true })
        if not spots then return end
        self.squares = squares
        local north, middle, south = squares[indexOf(0, -1)], squares[indexOf(0, 0)], squares[indexOf(0, 1)]
        middle.fields = { sprinkler = NEW }
        T.placeLine(self, { north, middle, south }, "iron")
        self.pump = pumpInto(self, spots[1], spots[2], north)
        plantAll(self, squares)
        local args = T.at(self.pump, { squares = T.tiles(squares), sprinkler = T.at(middle) })
        args.hours = { MINUTE }
        T.read(self, "sprinklers.pump", args, "minute")
        local soak = T.at(self.pump, { squares = T.tiles(squares), sprinkler = T.at(middle), hours = { SOAK_HOURS } })
        T.read(self, "sprinklers.pump", soak, "soaked")
        self.offLine, self.past = squares[indexOf(1, 0)], squares[indexOf(Sprinklers.ALONG, 0)]
        T.waitFor(self, function()
            local plant = CFarmingSystem.instance:getLuaObjectOnSquare(self.offLine.square)
            return plant ~= nil and PlantInfo.soilKeyOf(plant) == "IGUI_EnhancedIrrigation_Waterlogged"
        end, "this client's plant info naming the crop off the line waterlogged")
        T.step(function()
            local plant = CFarmingSystem.instance:getLuaObjectOnSquare(self.past.square)
            self.pastKey = plant and PlantInfo.soilKeyOf(plant)
        end)
        T.read(self, "sprinklers.age", { tiles = { T.at(middle) }, hours = ROT_HOURS, squares = { T.at(self.offLine) },
            sprinkler = T.at(middle) }, "rotted")
    end,
    validate = function(self)
        local spec = self.pump.spec
        local lifted = math.min(Sprinklers.RATE, spec.rate * 60)
        local minute = self.reads.minute
        local each = sprayed(lifted, MINUTE)
        for i, change in ipairs(changes(minute.before.squares, minute.after.squares)) do
            local offset = NORTH_SOUTH[i][1] .. "," .. NORTH_SOUTH[i][2]
            expectNear("the crop at " .. offset .. " after a minute", change.water, i <= INSIDE and each or 0, POINTS)
        end
        expectNear("the seal's wear after a minute", minute.after.pump.sealWear - minute.before.pump.sealWear,
            lifted * MINUTE, LITRES)
        local soaked = self.reads.soaked
        for i, square in ipairs(soaked.after.squares) do
            local offset = NORTH_SOUTH[i][1] .. "," .. NORTH_SOUTH[i][2]
            local inside = i <= INSIDE
            expectNear("the crop at " .. offset .. " left on", square.water, inside and Lines.PLANT_FULL or 0, POINTS)
            expectNear("the soak at " .. offset .. " left on", square.soak, inside and Lines.SOAK_MAX or 0, POINTS)
        end
        expect(self.pastKey == nil, "the plant info names the soil past the rectangle " .. tostring(self.pastKey))
        local rotted = self.reads.rotted
        local change = changes(rotted.before.squares, rotted.after.squares)[1]
        expectNear("the health of the waterlogged crop off the line", change.health, -Lines.ROOT_ROT_PER_HOUR * ROT_HOURS, POINTS)
        expectNear("the soak off the line after it was left", change.soak, -Lines.SOAK_DRY_OUT / 24 * ROT_HOURS, POINTS)
    end,
})

-- A sprinkler on a line a raised barrel taps does nothing: an hour at the tap waters the crop on
-- the holed tap tile and draws its hole's water, and none of the crops around the sprinkler, which
-- a storey of head can't turn. Catches a sprinkler that runs on gravity.
T.test("irrigation_sprinklers_do_nothing_on_a_tapped_line", {
    instant = true,
    run = function(self)
        -- The line west to east, the sprinkler in the middle; crops on the tap tile and around it.
        local squares = T.layout(self, { { 0, 0 }, { 1, 0 }, { 2, 0 }, { 1, -1 }, { 1, 1 }, { 3, 0 }, { -1, 0 } },
            { joined = true })
        if not squares then return end
        local tap, middle = squares[1], squares[2]
        self.tank = T.placeTank(self, tap, "above", 100)
        tap.fields = T.tapped({ holed = true })
        middle.fields = { sprinkler = NEW }
        T.placeLine(self, { tap, middle, squares[3] }, "iron")
        local crops = { tap, squares[4], squares[5], squares[6], squares[7] }
        plantAll(self, crops)
        T.read(self, "sprinklers.flow", { tap = T.at(tap), hours = 1, squares = T.tiles(crops), sprinkler = T.at(middle),
            tank = T.at(self.tank) }, "hour")
    end,
    validate = function(self)
        local hour = self.reads.hour
        expect(hour.stopped == nil, "the tap stopped: " .. tostring(hour.stopped))
        local changed = changes(hour.before.squares, hour.after.squares)
        expectNear("the crop on the holed tap tile", changed[1].water, Lines.HOLE_RATE * Lines.POINTS_PER_LITRE, POINTS)
        for i = 2, #changed do
            expectNear("crop " .. i .. " by the sprinkler", changed[i].water, 0, POINTS)
            expectNear("the soak under crop " .. i .. " by the sprinkler", changed[i].soak, 0, POINTS)
        end
        expectNear("the barrel's water drawn", hour.before.tank.litres - hour.after.tank.litres, Lines.HOLE_RATE, LITRES)
    end,
})

-- Setting and taking --------------------------------------------------------------------------------

local function useJob(self, handle, job, label, choose)
    T.useOption(self, function() return T.lineObject(handle) end, label, function(context)
        return T.jobOption(context, "line", job)
    end, choose)
end

local function hasSprinkler(line)
    local attached = line and line:getAttachedAnimSprite()
    for i = 0, (attached and attached:size() or 0) - 1 do
        if attached:get(i):getName() == Sprites.SPRINKLER then
            return true
        end
    end
    return false
end

-- A sprinkler made from pipe, worn: its condition and the ceiling its item carries.
local WORN = { condition = 70, ceiling = Sprinklers.MADE_CEILING }

-- Set Sprinkler is greyed out on the tap's tile and, carrying none, on the next; carrying a worn
-- one and a pipe wrench, it sets it there as it is, drawn over the pipe on both sides, and Fit Tap
-- is then refused there. Take Sprinkler gives it back as it went on, ceiling and all, and the tile
-- draws bare. Catches a sprinkler sharing the tap's tile, a sprinkler made new or lost, or one
-- left drawn.
T.test("irrigation_sprinklers_set_and_take_keep_condition", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 2)
        if not rows then return end
        local tap, tile = rows[1][1], rows[1][2]
        tap.fields = T.tapped()
        T.placeLine(self, { tap, tile }, "iron")
        T.give(self, "wrench", { { type = "Base.PipeWrench" } })
        T.goNextTo(self, tile.square)
        useJob(self, tap, LineJobs.SET_SPRINKLER, "on the tap", false)
        useJob(self, tile, LineJobs.SET_SPRINKLER, "carrying none", false)
        T.give(self, "sprinkler", { { type = Sprinklers.ITEM, condition = WORN.condition,
            modData = { [Pumps.CEILING_KEY] = WORN.ceiling } } })
        useJob(self, tile, LineJobs.SET_SPRINKLER, "set", true)
        T.readUntil(self, "lines.read", { tiles = { T.at(tile) } }, "set", function(reply)
            return reply.tiles[1].record.sprinkler ~= nil
        end)
        T.waitFor(self, function() return hasSprinkler(T.lineObject(tile)) end, "this client's copy of the sprinkler")
        useJob(self, tile, LineJobs.TAP, "tap on it", false)
        useJob(self, tile, LineJobs.TAKE_SPRINKLER, "take", true)
        T.readUntil(self, "lines.read", { tiles = { T.at(tile) } }, "taken", function(reply)
            return reply.tiles[1].record.sprinkler == nil
        end)
        T.waitFor(self, function() return not hasSprinkler(T.lineObject(tile)) end, "this client's copy of the bare tile")
        T.read(self, "pumpHouse.carried", { type = Sprinklers.ITEM }, "carried")
    end,
    validate = function(self)
        T.expectRefused(self, "on the tap", "Tooltip_EnhancedIrrigation_TapAndSprinkler")
        T.expectRefused(self, "carrying none", "Tooltip_EnhancedIrrigation_NoSprinkler")
        T.expectOffered(self, "set")
        local set = self.reads.set.tiles[1]
        local sprinkler = set.record.sprinkler
        expect(sprinkler and sprinkler.condition == WORN.condition and sprinkler.ceiling == WORN.ceiling,
            "the sprinkler went on at " .. tostring(sprinkler and sprinkler.condition) .. " of "
            .. tostring(sprinkler and sprinkler.ceiling))
        local drawn = false
        for _, name in ipairs(set.overlays or {}) do
            drawn = drawn or name == Sprites.SPRINKLER
        end
        expect(drawn, "the server doesn't draw the sprinkler")
        T.expectRefused(self, "tap on it", "Tooltip_EnhancedIrrigation_TapAndSprinkler")
        T.expectOffered(self, "take")
        local items = self.reads.carried.items
        expect(#items == 1 and items[1].condition == WORN.condition and items[1].ceiling == WORN.ceiling,
            "Take Sprinkler gave " .. #items .. " sprinklers" .. (items[1] and " at " .. items[1].condition .. " of "
            .. items[1].ceiling or ""))
    end,
})

-- Making and learning -------------------------------------------------------------------------------

local RECIPE = "EnhancedIrrigation_MakePipeSprinkler"

-- Make Pipe Sprinkler from an iron pipe, in hand, with the skill, the knowledge and exactly a
-- craft's inputs, makes a Lawn Sprinkler at the made ceiling, taking the pipe, the spray can and the
-- screws and keeping the drill and pliers. Catches a recipe the game won't craft, a made sprinkler
-- as good as a found one, or tools used up.
T.test("irrigation_sprinklers_make_pipe_sprinkler", {
    instant = true,
    run = function(self)
        local recipe = T.need(self, getScriptManager():getCraftRecipe(RECIPE), "the recipe " .. RECIPE)
        if not recipe then return end
        T.knowRecipes(self, { RECIPE }, true)
        for i = 0, recipe:getRequiredSkillCount() - 1 do
            local skill = recipe:getRequiredSkill(i)
            T.setPerk(self, skill:getPerk(), skill:getLevel())
        end
        local inputs, unmatched = T.recipeInputs(recipe, { "Base.Pliers" })
        if not T.need(self, #unmatched == 0, "an item for " .. table.concat(unmatched, "; ")) then return end
        T.give(self, "inputs", inputs)
        T.step(function()
            local pipe = T.need(self, T.player():getInventory():getFirstTypeRecurse("Base.MetalPipe"), "an iron pipe")
            if not pipe then return end
            T.startCraft(self, recipe, pipe)
            T.count(self, "craft", { Sprinklers.ITEM, "Base.MetalPipe", "Base.GardeningSprayEmpty", "Base.Screws",
                "Base.HandDrill", "Base.Pliers" }, { dropped = true })
        end)
        T.read(self, "pumpHouse.carried", { type = Sprinklers.ITEM }, "made")
    end,
    validate = function(self)
        local craft = self.counts.craft or {}
        expect(craft[Sprinklers.ITEM] == 1, "the craft made " .. tostring(craft[Sprinklers.ITEM]) .. " sprinklers")
        for _, fullType in ipairs({ "Base.MetalPipe", "Base.GardeningSprayEmpty", "Base.Screws" }) do
            expect(craft[fullType] == 0, "the craft left " .. tostring(craft[fullType]) .. " " .. fullType)
        end
        for _, fullType in ipairs({ "Base.HandDrill", "Base.Pliers" }) do
            expect(craft[fullType] == 1, "the craft took the " .. fullType)
        end
        local made = self.reads.made.items[1]
        expect(made and made.condition == Sprinklers.MADE_CEILING and made.ceiling == Sprinklers.MADE_CEILING,
            "the made sprinkler is at " .. tostring(made and made.condition) .. " of " .. tostring(made and made.ceiling))
    end,
})

-- A welder at the research level of Make Pipe Sprinkler (two-thirds of its Welding, rounded)
-- researches a Lawn Sprinkler and learns it on both sides. Catches a sprinkler that teaches nothing,
-- or teaches on one side only.
T.test("irrigation_sprinklers_researching_one_teaches_make_pipe_sprinkler", {
    instant = true,
    hour = 12,
    run = function(self)
        T.knowRecipes(self, { RECIPE }, false)
        T.setPerk(self, Perks.MetalWelding, getScriptManager():getCraftRecipe(RECIPE):getResearchSkillLevel())
        T.give(self, "sprinkler", { { type = Sprinklers.ITEM } })
        T.step(function()
            local context = ISInventoryPaneContextMenu.createMenu(0, true, { self.items.sprinkler[1] }, 0, 0)
            if not T.need(self, type(context) == "table" and context, "the Lawn Sprinkler's right-click menu") then return end
            local research = T.findNamed(context, context, getText("ContextMenu_ResearchCraft"))
            self.offered = T.offered(research)
            if self.offered then
                T.choose(research)
            end
            context:hideAndChildren()
        end)
        T.serverUntil(self, "learning.known", { names = { RECIPE } }, function(reply)
            return reply and reply.known and reply.known[RECIPE]
        end)
        T.waitFor(self, function() return T.player():isRecipeActuallyKnown(RECIPE) end,
            "this client's copy of the character knowing " .. RECIPE)
    end,
    validate = function(self)
        expect(self.offered, "the Lawn Sprinkler's menu offers no Research")
        local known = self.server["learning.known"] and self.server["learning.known"].known
        expect(known and known[RECIPE], "researching a Lawn Sprinkler didn't teach the server " .. RECIPE)
        expect(T.player():isRecipeActuallyKnown(RECIPE), "researching a Lawn Sprinkler didn't teach this client " .. RECIPE)
    end,
})

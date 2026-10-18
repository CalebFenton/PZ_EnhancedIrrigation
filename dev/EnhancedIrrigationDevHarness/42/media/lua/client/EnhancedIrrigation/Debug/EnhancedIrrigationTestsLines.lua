require "EnhancedIrrigation/Debug/EnhancedIrrigationTestLib"
require "EnhancedIrrigation/Sprites"
require "EnhancedIrrigation/Pipes"
require "EnhancedIrrigation/Lines"
require "EnhancedIrrigation/LineJobs"
require "EnhancedIrrigation/UI/LineMenu"
require "EnhancedIrrigation/UI/PlantInfo"

-- Garden lines (docs/design.md, Garden lines): laying, holing, tapping and running them, and what
-- time, frost and too much water do. Each test plays its jobs as a player does, from the line's
-- right-click menu and the Lay Line cursor, and reads what the authority made of them with the
-- handlers of EnhancedIrrigationTestServerLines.lua; the flow's sums are run for set hours there.

local T = EnhancedIrrigationTest
local expect, expectNear = T.expect, T.expectNear
local expectOffered, expectRefused = T.expectOffered, T.expectRefused
local Sprites = EnhancedIrrigation.Sprites
local Pipes = EnhancedIrrigation.Pipes
local Lines = EnhancedIrrigation.Lines
local LineJobs = EnhancedIrrigation.LineJobs
local LineMenu = EnhancedIrrigation.LineMenu
local PlantInfo = EnhancedIrrigation.PlantInfo
local Tanks = EnhancedIrrigation.Tanks

local LITRES = 0.01
local POINTS = 0.05
-- A crop's water as read, give or take vanilla's own ten-minute drying (SFarmingSystem.checkWater)
-- landing between placing the crop and reading it.
local CROP_POINTS = 0.25
-- How long the tap may take to drain the test's tank at the raised speed, in real time.
local WATER_MS = 60000
-- The clock's speed while the tap runs, so the tank empties in seconds.
local WATER_SPEED = 20
-- Vanilla's house wall on a square's west edge, and the door frame of that wall.
local WALL_WEST = "walls_exterior_house_01_0"
local DOOR_FRAME_WEST = "walls_exterior_house_01_10"
-- How far from the tap, in squares, the character goes: well past EnhancedIrrigationAction.REACH.
local AWAY_SQUARES = 8
-- What the tank holds when the tap is let go of early: far more than a few runs draw.
local TANK_LITRES = 100
-- What a tank the tap runs dry holds: a game minute's flow out of a crack, which a thirsty crop
-- takes all of.
local SMALL_TANK_LITRES = 0.05

-- Helpers -------------------------------------------------------------------------------------------

-- Queues the server's view of `handles` into self.reads[label].tiles, once `done(tiles)` holds or
-- the wait runs out, for what an action's complete() does after this client's perform().
local function readUntil(self, handles, label, done)
    T.readUntil(self, "lines.read", { tiles = T.tiles(handles) }, label, function(reply) return done(reply.tiles) end)
end

local function recordOf(self, label, i)
    local tiles = self.reads[label] and self.reads[label].tiles
    return tiles and tiles[i] and tiles[i].record
end

-- Queues T.useOption on this client's copy of the line tile at `handle` for the line job `job`
-- (with `with`, if given).
local function useJob(self, handle, job, with, label, choose)
    T.useOption(self, function() return T.lineObject(handle) end, label, function(context)
        return T.jobOption(context, "line", job, with)
    end, choose)
end

-- Queues T.useOption on this client's copy of the tap tile at `handle` for Water from Tank.
local function useWater(self, handle, label, choose)
    T.useOption(self, function() return T.lineObject(handle) end, label, function(context)
        return T.findOption(context, context, function(option)
            return option.onSelect == EnhancedIrrigationWaterAction.queue
        end)
    end, choose)
end

-- The fields of a tap fitted with a length of `material`.
local function tapOn(material)
    return { tap = true, tapMaterial = material or "iron" }
end

local function copyField(fields, extra)
    local copy = {}
    for k, v in pairs(fields or {}) do
        copy[k] = v
    end
    for k, v in pairs(extra or {}) do
        copy[k] = v
    end
    return copy
end

-- The client's sprite name at `handle`, or nil.
local function clientSprite(handle)
    local line = T.lineObject(handle)
    return line and line:getSprite():getName() or nil
end

local function hasOverlay(names, name)
    for _, overlay in ipairs(names or {}) do
        if overlay == name then
            return true
        end
    end
    return false
end

-- Runs the line tapped at `tap` for `hours` on the server; the reply, the litres `drawn` or the
-- refusal `stopped`, and `handles`' tiles, lands in self.reads[label].
local function flow(self, tap, hours, handles, label)
    T.read(self, "lines.flow", T.at(tap, { hours = hours, tiles = T.tiles(handles) }), label)
end

-- The shape (Sprites.pipe) a pipe tile's name draws, or nil for any other name.
local function shapeOf(spriteName)
    local material, _, shape = Sprites.pipeOf(spriteName)
    return material and shape or nil
end

-- Queues opening the tap at `handle` for a character whose client doesn't check that it stands
-- there: the action's isValid always passes, so only the authority's own check can stop it.
local function waterUnchecked(self, handle)
    T.step(function()
        local tap = T.lineObject(handle)
        if not T.need(self, tap, "this client's copy of the tap tile") then return end
        local action = EnhancedIrrigationWaterAction:new(T.player(), tap)
        action.isValid = function() return true end
        ISTimedActionQueue.add(action)
    end)
end

-- Laying -------------------------------------------------------------------------------------------

-- Three iron lengths laid with the cursor, the first beside a tank on the floor above: each tile
-- costs a length, and each joins its neighbours, so the row draws as one pipe.
T.test("irrigation_lines_lay_costs_and_shapes", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local tiles = rows[1]
        self.tiles = tiles
        T.trackLines(self, tiles)
        T.placeTank(self, tiles[1], "above", 0)
        T.give(self, "pipes", { { type = "Base.MetalPipe", count = 3 } })
        T.goNextTo(self, tiles[2].square)
        T.step(function()
            local context = T.need(self, T.worldMenu(tiles[1].square:getFloor()), "a world menu on the ground")
            if not context then return end
            local lay = T.findOption(context, context, function(option)
                return option.onSelect == EnhancedIrrigation.LineCursor.start and option.param1 == "iron"
            end)
            self.layOffered = T.offered(lay)
            if lay then
                T.choose(lay)
            end
            context:hideAndChildren()
            local playerNum = T.player():getPlayerNum()
            local cursor = getCell():getDrag(playerNum)
            if not T.need(self, cursor and cursor.kind == "iron" and cursor, "the Lay Line cursor for iron pipe") then
                return
            end
            T.defer(self, function() getCell():setDrag(nil, playerNum) end)
            self.cursor, self.valid = cursor, {}
        end)
        -- A tile a step, faced first, each once the one before is laid.
        for i, tile in ipairs(tiles) do
            T.step(function()
                T.face(tile.square)
                self.valid[i] = self.cursor:isValid(tile.square)
                self.cursor:tryBuild(tile.x, tile.y, tile.z)
            end)
            T.waitForLines(self, { tile }, "this client's copy of laid tile " .. i)
        end
        T.readLines(self, tiles, "laid")
        T.count(self, "left", { "Base.MetalPipe" })
    end,
    validate = function(self)
        expect(self.layOffered, "the ground's menu doesn't offer Lay Line for iron pipe")
        local shapes = { Sprites.EAST, Sprites.EAST + Sprites.WEST, Sprites.WEST }
        for i, tile in ipairs(self.tiles) do
            expect(self.valid and self.valid[i], "the cursor refused tile " .. i)
            local want = Sprites.pipe("iron", false, shapes[i])
            local read = self.reads.laid.tiles[i]
            expect(read.record and read.record.material == "iron", "tile " .. i .. " has no iron record")
            expect(read.sprite == want, "the server shows tile " .. i .. " as " .. tostring(read.sprite) .. ", not " .. want)
            expect(clientSprite(tile) == want, "this client shows tile " .. i .. " as " .. tostring(clientSprite(tile)))
        end
        expect(self.counts.left["Base.MetalPipe"] == 0, "laying left " .. tostring(self.counts.left["Base.MetalPipe"]) .. " iron pipe")
    end,
})

-- A plastic length takes a use of glue for its joint.
T.test("irrigation_lines_lay_plastic_uses_a_joint", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 1)
        if not rows then return end
        local tile = rows[1][1]
        self.tile = tile
        T.trackLines(self, { tile })
        T.placeTank(self, tile, "above", 0)
        T.give(self, "joint", { { type = "Base.Glue" } })
        T.give(self, "pipes", { { type = "Base.Pipe" } })
        T.goNextTo(self, tile.square)
        T.step(function()
            local glue = self.items.joint[1]
            self.usesBefore = glue:getCurrentUses()
            local playerNum = T.player():getPlayerNum()
            EnhancedIrrigation.LineCursor.start(playerNum, "plastic")
            local cursor = getCell():getDrag(playerNum)
            T.defer(self, function() getCell():setDrag(nil, playerNum) end)
            self.valid = cursor:isValid(tile.square)
            cursor:tryBuild(tile.x, tile.y, tile.z)
        end)
        T.waitForLines(self, { tile }, "this client's copy of the plastic tile")
        T.waitFor(self, function() return self.items.joint[1]:getCurrentUses() < self.usesBefore end,
            "this client's glue, used")
        T.count(self, "left", { "Base.Pipe" })
    end,
    validate = function(self)
        expect(self.valid, "the cursor refused a tile beside a tank")
        expect(self.items.joint[1]:getCurrentUses() == self.usesBefore - 1,
            "the joint used " .. (self.usesBefore - self.items.joint[1]:getCurrentUses()) .. " uses of glue, not 1")
        expect(self.counts.left["Base.Pipe"] == 0, "laying left the plastic pipe")
        expect(T.lineSummary(self.tile).material == "plastic", "the tile isn't plastic")
    end,
})

-- The first tile of a line must be in a tank's reach; the next ones need only touch the line.
T.test("irrigation_lines_first_tile_needs_a_tank", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3, { minDistance = 2 })
        if not rows then return end
        local tiles = rows[1]
        T.trackLines(self, tiles)
        T.give(self, "pipes", { { type = "Base.MetalPipe", count = 3 } })
        T.step(function()
            if not T.need(self, #EnhancedIrrigation.Tanks.tanksReaching(tiles[1].x, tiles[1].y, tiles[1].z) == 0,
                    "squares out of every tank's reach") then
                return
            end
            local playerNum = T.player():getPlayerNum()
            EnhancedIrrigation.LineCursor.start(playerNum, "iron")
            self.cursor = getCell():getDrag(playerNum)
            T.defer(self, function() getCell():setDrag(nil, playerNum) end)
            self.alone = self.cursor:refusal(tiles[1].square)
        end)
        T.placeLine(self, { tiles[2] }, "iron")
        T.step(function()
            self.besideLine = self.cursor:refusal(tiles[1].square)
            self.besideLineEast = self.cursor:refusal(tiles[3].square)
        end)
    end,
    validate = function(self)
        expect(self.alone == "Tooltip_EnhancedIrrigation_NoTankReach",
            "a tile far from tanks and lines: " .. tostring(self.alone))
        expect(self.besideLine == nil, "a tile beside a line was refused: " .. tostring(self.besideLine))
        expect(self.besideLineEast == nil, "a tile beside a line was refused: " .. tostring(self.besideLineEast))
    end,
})

-- A tile between two tapped lines would make one line with two taps; between a tapped and an
-- untapped one it just joins them.
T.test("irrigation_lines_merging_two_tapped_lines_refused", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local tiles = rows[1]
        T.trackLines(self, tiles)
        tiles[1].fields = tapOn()
        tiles[3].fields = tapOn()
        T.placeLine(self, { tiles[1], tiles[3] }, "iron")
        T.give(self, "pipes", { { type = "Base.MetalPipe" } })
        T.goNextTo(self, tiles[2].square)
        T.step(function()
            local playerNum = T.player():getPlayerNum()
            EnhancedIrrigation.LineCursor.start(playerNum, "iron")
            self.cursor = getCell():getDrag(playerNum)
            T.defer(self, function() getCell():setDrag(nil, playerNum) end)
            self.twoTaps = self.cursor:refusal(tiles[2].square)
            -- What the Lay job's start() and the authority ask (LineJobs.refusal).
            self.jobRefusal = LineJobs.refusal(T.player(), LineJobs.LAY, tiles[2].square:getFloor(), "iron")
        end)
        T.server(self, "lines.set", { tiles = { { x = tiles[3].x, y = tiles[3].y, z = tiles[3].z, fields = { tap = false } } } })
        T.waitForLines(self, { tiles[3] }, "this client's copy of the untapped line", function(summary) return not summary.tap end)
        T.step(function()
            self.oneTap = self.cursor:refusal(tiles[2].square)
        end)
    end,
    validate = function(self)
        expect(self.twoTaps == "Tooltip_EnhancedIrrigation_JoinsTwoTaps", "between two taps: " .. tostring(self.twoTaps))
        expect(self.jobRefusal == "Tooltip_EnhancedIrrigation_JoinsTwoTaps", "the Lay job between two taps: "
            .. tostring(self.jobRefusal))
        expect(self.oneTap == nil, "between a tapped and an untapped line: " .. tostring(self.oneTap))
    end,
})

-- A wall parts line on either side of it: laying beside line behind a wall finds nothing to join,
-- their shapes don't meet and the crop behind the wall gets none of the water. A door frame is no
-- wall, so a line enters a greenhouse by its door. Catches a wall check missing from laying, the
-- shapes or the flow.
T.test("irrigation_lines_walls_part_lines_doorways_join", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3, { minDistance = 2 })
        if not rows then return end
        local behind, inside, doorway = rows[1][1], rows[1][2], rows[1][3]
        self.tiles = { behind, inside, doorway }
        T.trackLines(self, self.tiles)
        -- The wall stands on the middle square's west edge, the door frame on the east square's.
        T.placeTile(self, inside.square, WALL_WEST)
        T.placeTile(self, doorway.square, DOOR_FRAME_WEST)
        T.placeLine(self, { inside }, "iron", { holed = true })
        T.give(self, "pipes", { { type = "Base.MetalPipe", count = 2 } })
        T.step(function()
            for _, tile in ipairs(self.tiles) do
                if not T.need(self, #Tanks.tanksReaching(tile.x, tile.y, tile.z) == 0,
                        "squares out of every tank's reach") then
                    return
                end
            end
            local playerNum = T.player():getPlayerNum()
            EnhancedIrrigation.LineCursor.start(playerNum, "iron")
            local cursor = getCell():getDrag(playerNum)
            T.defer(self, function() getCell():setDrag(nil, playerNum) end)
            self.behindWall = cursor:refusal(behind.square)
            self.throughDoorway = cursor:refusal(doorway.square)
        end)
        self.tank = T.placeTank(self, doorway, "above", TANK_LITRES)
        behind.fields = { holed = true }
        doorway.fields = tapOn()
        T.placeLine(self, { behind, doorway }, "iron")
        T.plant(self, behind, 0)
        T.plant(self, inside, 0)
        flow(self, doorway, 1, self.tiles, "hour")
    end,
    validate = function(self)
        expect(self.behindWall == "Tooltip_EnhancedIrrigation_NoTankReach",
            "laying beside line behind a wall: " .. tostring(self.behindWall))
        expect(self.throughDoorway == nil, "laying beside line through a door frame was refused: "
            .. tostring(self.throughDoorway))
        local hour = self.reads.hour
        if not expect(hour.drawn, "the line didn't run: " .. tostring(hour.stopped)) then return end
        local names = { "behind the wall", "inside", "in the doorway" }
        local wanted = { 0, Sprites.EAST, Sprites.WEST }
        for i, tile in ipairs(hour.tiles) do
            expect(shapeOf(tile.sprite) == wanted[i], "the tile " .. names[i] .. " is shaped "
                .. tostring(shapeOf(tile.sprite)) .. ", not " .. wanted[i])
        end
        -- The tank stands a storey over the line: one storey of head.
        expectNear("the crop inside's water", hour.tiles[2].plant.water, Lines.HOLE_RATE * Lines.POINTS_PER_LITRE, CROP_POINTS)
        expectNear("the crop behind the wall's water", hour.tiles[1].plant.water, 0, CROP_POINTS)
    end,
})

-- Holes ---------------------------------------------------------------------------------------------

-- Notes in self.drills[label] how many Drill Holes options the line tile at `handle` offers, and
-- uses the option as useJob does.
local function useDrill(self, handle, label, choose)
    self.drills = self.drills or {}
    T.useOption(self, function() return T.lineObject(handle) end, label, function(context)
        local count = 0
        T.findOption(context, context, function(option)
            if option.onSelect == EnhancedIrrigationAction.queue and option.param2 == LineJobs.DRILL then
                count = count + 1
            end
            return false
        end)
        self.drills[label] = count
        return T.jobOption(context, "line", LineJobs.DRILL)
    end, choose)
end

-- An awl gets into soft pipe but not iron or clay, which its one Drill Holes option says; a hand
-- drill gets into iron; a holed tile offers no more drilling. Catches a tool gate that lets the
-- wrong tool through, a menu with an option per tool, or re-drilling.
T.test("irrigation_lines_drill_holes_tool_gate", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local iron, clay, plastic = rows[1][1], rows[1][2], rows[1][3]
        self.tiles = { iron, clay, plastic }
        iron.material, clay.material, plastic.material = "iron", "clay", "plastic"
        T.placeLine(self, self.tiles)
        T.give(self, "awl", { { type = "Base.Awl" } })
        T.goNextTo(self, clay.square)
        useDrill(self, iron, "awl on iron", false)
        useDrill(self, clay, "awl on clay", false)
        useDrill(self, plastic, "awl on plastic", true)
        T.waitForLines(self, { plastic }, "this client's summary of the awl's hole", function(summary) return summary.holed end)
        T.give(self, "drill", { { type = "Base.HandDrill" } })
        useDrill(self, iron, "hand drill on iron", true)
        T.waitForLines(self, { iron }, "this client's summary of the drill's hole", function(summary) return summary.holed end)
        useDrill(self, plastic, "holed plastic", false)
        T.readLines(self, self.tiles, "drilled")
    end,
    validate = function(self)
        expectRefused(self, "awl on iron", "Tooltip_EnhancedIrrigation_NoHoleMaker")
        expectRefused(self, "awl on clay", "Tooltip_EnhancedIrrigation_NoHoleMaker")
        expectOffered(self, "awl on plastic")
        expectOffered(self, "hand drill on iron")
        expect(self.drills["hand drill on iron"] == 1, "carrying an awl and a hand drill, the menu has "
            .. tostring(self.drills["hand drill on iron"]) .. " Drill Holes options")
        expect(not self.menu["holed plastic"].found, "a holed tile still offers Drill Holes")
        local drilled = self.reads.drilled.tiles
        expect(drilled[1].record.holed and drilled[3].record.holed, "the server has the iron or the plastic tile unholed")
        expect(not drilled[2].record.holed, "the clay tile was holed")
        local described = LineMenu.describe(T.lineSummary(self.tiles[3]))
        expect(described:find(getText("IGUI_EnhancedIrrigation_Holed"), 1, true) ~= nil,
            "the menu doesn't say the tile is holed: " .. described)
    end,
})

-- A hammer drives one nail through plastic, which the menu warns may split it, and here it does.
-- Catches the nail not being used up, the hammer being taken, or a punch that never cracks.
T.test("irrigation_lines_hammer_and_nail_can_crack_plastic", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 1)
        if not rows then return end
        local tile = rows[1][1]
        T.placeLine(self, { tile }, "plastic")
        T.give(self, "tools", { { type = "Base.Hammer" }, { type = "Base.Nails", count = 2 } })
        T.goNextTo(self, tile.square)
        T.server(self, "lines.pinRoll", {})
        useDrill(self, tile, "nail", true)
        T.waitForLines(self, { tile }, "this client's summary of the nailed tile", function(summary)
            return summary.holed and summary.cracked
        end)
        T.count(self, "left", { "Base.Nails", "Base.Hammer" })
    end,
    validate = function(self)
        expectOffered(self, "nail")
        local tooltip = self.menu.nail.tooltip
        expect(tooltip:find(getText("Tooltip_EnhancedIrrigation_MayCrack"), 1, true) ~= nil,
            "the tooltip doesn't warn the nail may split plastic: " .. tooltip)
        expect(self.counts.left["Base.Nails"] == 1, "drilling left " .. tostring(self.counts.left["Base.Nails"]) .. " nails, not 1")
        expect(self.counts.left["Base.Hammer"] == 1, "drilling took the hammer")
    end,
})

-- Taps ---------------------------------------------------------------------------------------------

-- Fit Tap wants a tank reaching the tile a storey above the line: beside a barrel on the ground
-- it's refused, saying so; beside a barrel on a stand it fits with a length of the tile's own pipe,
-- whatever else is carried, and shows the riser on both sides.
T.test("irrigation_lines_fit_tap_needs_a_tank_a_storey_up", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local west, tile, east = rows[1][1], rows[1][2], rows[1][3]
        T.placeLine(self, { tile }, "lead")
        T.placeTank(self, west, "ground", 100)
        T.give(self, "tools", { { type = "Base.PipeWrench" }, { type = Pipes.KINDS.iron.item },
            { type = Pipes.KINDS.lead.item } })
        T.goNextTo(self, tile.square)
        useJob(self, tile, LineJobs.TAP, nil, "beside a ground barrel", false)
        T.placeTank(self, east, "raised", 0)
        useJob(self, tile, LineJobs.TAP, nil, "beside a raised barrel", true)
        readUntil(self, { tile }, "tapped", function(tiles) return tiles[1].record.tap == true end)
        T.waitFor(self, function()
            local line = T.lineObject(tile)
            local attached = line and line:getAttachedAnimSprite()
            for i = 0, (attached and attached:size() or 0) - 1 do
                if attached:get(i):getName() == Sprites.TAP then
                    return true
                end
            end
            return false
        end, "this client's copy of the tap's riser")
        T.count(self, "left", { Pipes.KINDS.iron.item, Pipes.KINDS.lead.item, "Base.PipeWrench" })
    end,
    validate = function(self)
        expectRefused(self, "beside a ground barrel", "Tooltip_EnhancedIrrigation_NoPressure")
        expectOffered(self, "beside a raised barrel")
        local record = recordOf(self, "tapped", 1)
        expect(record.tap and record.tapMaterial == "lead", "the tap fitted: " .. tostring(record.tap) .. ", of "
            .. tostring(record.tapMaterial) .. " pipe, not the lead tile's own")
        expect(hasOverlay(self.reads.tapped.tiles[1].overlays, Sprites.TAP), "the server shows no riser")
        local iron, lead = Pipes.KINDS.iron.item, Pipes.KINDS.lead.item
        expect(self.counts.left[lead] == 0, "the tap took no lead pipe")
        expect(self.counts.left[iron] == 1, "the tap on lead pipe took iron pipe")
        expect(self.counts.left["Base.PipeWrench"] == 1, "the tap took the pipe wrench")
    end,
})

-- Each time the water runs, the tap draws on the highest tank reaching it that holds water, the
-- fuller of two on one level: an empty barrel two storeys up and a full one on the ground give
-- none, and the fuller of two a storey up gives it all. Catches a tap tied to one tank, an empty
-- tank chosen, or a tank without the head drawn on.
T.test("irrigation_lines_tap_draws_from_the_highest_tank_holding_water", {
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local west, tile, east = rows[1][1], rows[1][2], rows[1][3]
        tile.fields = copyField(tapOn(), { holed = true })
        T.placeLine(self, { tile }, "iron")
        self.start = { empty = 0, fuller = 20, emptier = 10, ground = TANK_LITRES }
        self.tanks = {
            empty = T.placeTank(self, east, "raisedAbove", self.start.empty),
            fuller = T.placeTank(self, tile, "above", self.start.fuller),
            emptier = T.placeTank(self, west, "raised", self.start.emptier),
            ground = T.placeTank(self, east, "lidded", self.start.ground),
        }
        T.batch(function()
            flow(self, tile, 1, {}, "hour")
            for name, tank in pairs(self.tanks) do
                T.read(self, "tanks.read", T.at(tank), name)
            end
        end)
    end,
    validate = function(self)
        local hour = self.reads.hour
        if not expect(hour.drawn, "the line didn't run: " .. tostring(hour.stopped)) then return end
        -- The fuller tank stands a storey over the line: one storey of head.
        local want = { empty = 0, fuller = Lines.HOLE_RATE, emptier = 0, ground = 0 }
        for name, drawn in pairs(want) do
            expectNear("the " .. name .. " tank's water", self.reads[name].litres, self.start[name] - drawn, LITRES)
        end
    end,
})

-- A tap on a barrel standing on the line's own floor has no head: Water from Tank says so.
T.test("irrigation_lines_water_needs_pressure", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 2)
        if not rows then return end
        local tile, beside = rows[1][1], rows[1][2]
        T.placeTank(self, beside, "ground", 100)
        tile.fields = tapOn()
        T.placeLine(self, { tile }, "iron")
        T.goNextTo(self, tile.square)
        useWater(self, tile, "water", false)
    end,
    validate = function(self)
        expectRefused(self, "water", "Tooltip_EnhancedIrrigation_NoPressure")
    end,
})

-- The tap held open at a barrel on a Tank Stand runs the line until the barrel is dry: the crop on
-- the cracked tile gets all of it, and the soil shows it. Catches the real verb losing water
-- between tank and crop, or the tap not closing on an empty tank.
T.test("irrigation_lines_water_from_a_raised_tank", {
    instant = true,
    timeoutSeconds = 90,
    run = function(self)
        local rows = T.row(self, 2, { indoors = true })
        if not rows then return end
        local tile, beside = rows[1][1], rows[1][2]
        self.tile = tile
        self.tank = T.placeTank(self, beside, "raised", SMALL_TANK_LITRES)
        tile.fields = copyField(tapOn(), { cracked = true })
        T.placeLine(self, { tile }, "plastic")
        T.plant(self, tile, 0)
        T.goNextTo(self, tile.square)
        T.setMultiplier(self, WATER_SPEED)
        useWater(self, tile, "water", true)
        -- The open tap holds the queue until it closes itself; a refused or stopped one would have
        -- emptied it, failing the test.
        T.readUntil(self, "tanks.read", T.at(self.tank), "tank", function(reply)
            return reply.found and reply.litres <= 0
        end, WATER_MS)
        T.readLines(self, { tile }, "watered")
        T.waitFor(self, function()
            return clientSprite(tile) == Sprites.pipe("plastic", true, 0)
        end, "this client's copy of the wet tile")
    end,
    validate = function(self)
        expectOffered(self, "water")
        expectNear("the raised tank's water", self.reads.tank.litres, 0, LITRES)
        local read = self.reads.watered.tiles[1]
        expectNear("the crop's water", read.plant.water, SMALL_TANK_LITRES * Lines.POINTS_PER_LITRE, CROP_POINTS)
        expect(read.record.full, "the line isn't full")
        expect(read.record.wet, "the crack's soil isn't wet")
    end,
})

-- The authority lets go of the tap once the character walks off it, though their client says they
-- are still there: the line stops, and the tank keeps the rest.
T.test("irrigation_lines_water_stops_when_the_character_walks_off", {
    instant = true,
    timeoutSeconds = 60,
    run = function(self)
        local rows = T.row(self, 1)
        local away = T.row(self, 1, { minDistance = AWAY_SQUARES })
        if not (rows and away) then return end
        local tile, there = rows[1][1], away[1][1]
        self.tank = T.placeTank(self, tile, "above", TANK_LITRES)
        tile.fields = copyField(tapOn(), { cracked = true })
        T.placeLine(self, { tile }, "plastic")
        T.goNextTo(self, tile.square)
        T.setMultiplier(self, WATER_SPEED)
        -- Walks off once the water runs, which this client's copy of the tank shows.
        T.step(function()
            T.onTick(self, function()
                local copy = not self.walkedOff and Tanks.tankAt(self.tank.x, self.tank.y, self.tank.z)
                if copy and Tanks.litres(copy) < TANK_LITRES - LITRES then
                    self.walkedOff = true
                    PZHarness.Fixtures.teleportToMiddle(T.player(), there.x, there.y, there.z)
                end
            end)
        end)
        -- An open tap the authority never closes holds the queue until the test runs out of time.
        waterUnchecked(self, tile)
        T.read(self, "tanks.read", T.at(self.tank), "tank")
    end,
    validate = function(self)
        expect(self.walkedOff, "the water never ran")
        expect(self.reads.tank.litres > TANK_LITRES / 2, "the line ran on after the character walked off: "
            .. self.reads.tank.litres .. " litres left")
    end,
})

-- The authority won't open a tap for a character who isn't at it, whatever their client says.
T.test("irrigation_lines_water_refused_out_of_reach", {
    instant = true,
    mpOnly = "single player has one copy of the character, whose start() refuses with isValid's own check",
    run = function(self)
        local rows = T.row(self, 1)
        local away = T.row(self, 1, { minDistance = AWAY_SQUARES })
        if not (rows and away) then return end
        local tile = rows[1][1]
        self.tank = T.placeTank(self, tile, "above", TANK_LITRES)
        tile.fields = copyField(tapOn(), { cracked = true })
        T.placeLine(self, { tile }, "plastic")
        T.goNextTo(self, away[1][1].square)
        waterUnchecked(self, tile)
        T.read(self, "tanks.read", T.at(self.tank), "tank")
        T.readLines(self, { tile }, "after")
    end,
    validate = function(self)
        expectNear("the tank's water", self.reads.tank.litres, TANK_LITRES, LITRES)
        local record = self.reads.after.tiles[1].record
        expect(record and not record.full, "the line filled from a tap nobody stood at")
    end,
})

-- Flow ---------------------------------------------------------------------------------------------

-- An hour through two holes under a storey of head: each draws Lines.HOLE_RATE from the tank; the
-- thirsty crop takes its share at vanilla's points a litre, and the full crop's share soaks into
-- the soil. Catches water lost or made between tank and outlets, or a full crop's water vanishing.
T.test("irrigation_lines_flow_points_per_litre", {
    run = function(self)
        local rows = T.row(self, 3, { indoors = true })
        if not rows then return end
        local tap, thirsty, full = rows[1][1], rows[1][2], rows[1][3]
        self.tank = T.placeTank(self, tap, "above", TANK_LITRES)
        tap.fields = tapOn()
        thirsty.fields = { holed = true }
        full.fields = { holed = true }
        T.placeLine(self, { tap, thirsty, full }, "iron")
        T.plant(self, thirsty, 0)
        T.plant(self, full, Lines.PLANT_FULL)
        T.batch(function()
            flow(self, tap, 1, { thirsty, full }, "hour")
            T.read(self, "tanks.read", T.at(self.tank), "tank")
        end)
    end,
    validate = function(self)
        local hour = self.reads.hour
        if not expect(hour.drawn, "the line didn't run: " .. tostring(hour.stopped)) then return end
        local each = Lines.HOLE_RATE
        expectNear("litres drawn", hour.drawn, 2 * each, LITRES)
        expectNear("the tank's water", self.reads.tank.litres, TANK_LITRES - 2 * each, LITRES)
        local thirsty, full = hour.tiles[1], hour.tiles[2]
        expectNear("the thirsty crop's water", thirsty.plant.water, each * Lines.POINTS_PER_LITRE, CROP_POINTS)
        expectNear("the soak under the thirsty crop", thirsty.record.soak, 0, POINTS)
        expectNear("the full crop's water", full.plant.water, Lines.PLANT_FULL, CROP_POINTS)
        expectNear("the soak under the full crop", full.record.soak, each * Lines.POINTS_PER_LITRE, CROP_POINTS)
        expect(thirsty.record.full and full.record.full, "the line isn't full")
    end,
})

-- A tank two storeys over a line pushes each hole's water out the square root of two times as fast
-- as one a storey over it (Torricelli). Catches the head ignored, or taken linearly.
T.test("irrigation_lines_higher_tank_waters_faster", {
    run = function(self)
        local tiles = T.layout(self, { { 0, 0 }, { 2, 0 } }, { indoors = true })
        if not tiles then return end
        self.low = T.placeTank(self, tiles[1], "above", TANK_LITRES)
        -- A barrel on a stand on the floor above.
        self.high = T.placeTank(self, tiles[2], "raisedAbove", TANK_LITRES)
        tiles[1].fields = copyField(tapOn(), { holed = true })
        tiles[2].fields = copyField(tapOn(), { holed = true })
        T.placeLine(self, tiles, "iron")
        T.batch(function()
            flow(self, tiles[1], 1, {}, "low hour")
            flow(self, tiles[2], 1, {}, "high hour")
            T.read(self, "tanks.read", T.at(self.low), "low tank")
            T.read(self, "tanks.read", T.at(self.high), "high tank")
        end)
    end,
    validate = function(self)
        local low = TANK_LITRES - self.reads["low tank"].litres
        local high = TANK_LITRES - self.reads["high tank"].litres
        expectNear("the litres a storey of head gives in an hour", low, Lines.HOLE_RATE, LITRES)
        expectNear("the litres two storeys of head give in an hour", high, Lines.HOLE_RATE * math.sqrt(2), LITRES)
    end,
})

-- Soak, mildew, frost --------------------------------------------------------------------------------

-- How long the waterlogged soil of the mildew test stays above the threshold as it dries, of the
-- twice as long it ages.
local LOGGED_HOURS = 6

-- A crop mildews for the hours its soil stays waterlogged as it dries through the threshold, not the
-- whole pass; one on the threshold itself doesn't. Catches mildew counted for the whole pass, or
-- the threshold taken as inclusive.
T.test("irrigation_lines_waterlogged_crop_mildews", {
    run = function(self)
        local rows = T.row(self, 2, { indoors = true })
        if not rows then return end
        local logged, edge = rows[1][1], rows[1][2]
        self.tiles = { logged, edge }
        self.dryPerHour = Lines.SOAK_DRY_IN / 24
        logged.fields = { soak = Lines.WATERLOGGED + LOGGED_HOURS * self.dryPerHour }
        edge.fields = { soak = Lines.WATERLOGGED }
        T.placeLine(self, self.tiles, "iron")
        T.plant(self, logged, Lines.PLANT_FULL / 2)
        T.plant(self, edge, Lines.PLANT_FULL / 2)
        T.read(self, "lines.age", { tiles = T.tiles(self.tiles), hours = 2 * LOGGED_HOURS }, "aged")
    end,
    validate = function(self)
        local aged = self.reads.aged.tiles
        expectNear("the soak, dried past the threshold", aged[1].record.soak,
            Lines.WATERLOGGED - LOGGED_HOURS * self.dryPerHour, POINTS)
        expectNear("the mildew of the crop whose soil dried through the threshold", aged[1].plant.mildew,
            LOGGED_HOURS * Lines.MILDEW_PER_HOUR, POINTS)
        expectNear("the mildew of the crop on the threshold", aged[2].plant.mildew, 0, POINTS)
    end,
})

-- Soak dries twice as fast outdoors, and the tile's soil stops showing wet once it has.
T.test("irrigation_lines_soak_dries", {
    run = function(self)
        local outdoor = T.row(self, 1)
        local indoor = T.row(self, 1, { indoors = true })
        if not (outdoor and indoor) then return end
        self.tiles = { outdoor[1][1], indoor[1][1] }
        for _, tile in ipairs(self.tiles) do
            tile.fields = { soak = 10 }
        end
        T.placeLine(self, self.tiles, "plastic")
        T.waitFor(self, function() return clientSprite(self.tiles[1]) == Sprites.pipe("plastic", true, 0) end,
            "this client's copy of the soaked tile, wet")
        T.batch(function()
            T.read(self, "lines.age", { tiles = T.tiles(self.tiles), hours = 12 }, "half")
            T.read(self, "lines.age", { tiles = T.tiles(self.tiles), hours = 12 }, "day")
        end)
        T.waitFor(self, function() return clientSprite(self.tiles[1]) == Sprites.pipe("plastic", false, 0) end,
            "this client's copy of the dried tile, dry")
    end,
    validate = function(self)
        local half, day = self.reads.half.tiles, self.reads.day.tiles
        expectNear("the outdoor soak after half a day", half[1].record.soak, 10 - Lines.SOAK_DRY_OUT / 2, POINTS)
        expectNear("the indoor soak after half a day", half[2].record.soak, 10 - Lines.SOAK_DRY_IN / 2, POINTS)
        expectNear("the outdoor soak after a day", day[1].record.soak, 0, POINTS)
        expect(not day[1].record.wet, "the dry tile is still wet")
        expect(day[1].sprite == Sprites.pipe("plastic", false, 0), "the server still shows the dried tile wet")
    end,
})

-- A hard freeze may split a full pipe and leaves an empty one whole; a frost short of a hard freeze
-- splits nothing. Each roll is pinned to a sure split, so only the cold and the water decide.
-- Catches the threshold back at freezing, or an empty pipe that splits.
T.test("irrigation_lines_frost_cracks_full_lines", {
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local full, empty, mild = rows[1][1], rows[1][2], rows[1][3]
        full.fields = { full = true }
        empty.fields = { full = false }
        -- Filled only once the air is above a hard freeze, so no hard freeze can reach it before.
        mild.fields = { full = false }
        T.placeLine(self, { full, empty, mild }, "clay")
        T.batch(function()
            T.server(self, "lines.temperature", { celsius = Lines.HARD_FREEZE_CELSIUS - 1 })
            T.server(self, "lines.pinRoll", {})
            T.read(self, "lines.age", { tiles = T.tiles({ full, empty }), hours = 1 }, "frozen")
            -- Below freezing, short of a hard freeze.
            T.server(self, "lines.temperature", { celsius = Lines.HARD_FREEZE_CELSIUS / 2 })
            T.server(self, "lines.set", { tiles = { T.at(mild, { fields = { full = true } }) } })
            T.server(self, "lines.pinRoll", {})
            T.read(self, "lines.age", { tiles = T.tiles({ mild }), hours = 1 }, "mild")
        end)
        T.waitForLines(self, { full }, "this client's summary of the split pipe", function(summary) return summary.cracked end)
    end,
    validate = function(self)
        local frozen, mild = self.reads.frozen.tiles, self.reads.mild.tiles
        expect(frozen[1].record.cracked, "a full pipe came through a hard freeze whole")
        expect(not frozen[2].record.cracked, "an empty pipe split in a hard freeze")
        expect(not mild[1].record.cracked, "a full pipe split in a frost short of a hard freeze")
    end,
})

-- A line runs on while its chunk is unloaded: a soaked tile dries for the hours away, as outdoors,
-- and its full pipe splits in a hard freeze, which both sides show once the chunk loads again. The
-- tap tile is holed, so an hour's flow fills the line and soaks the soil under it; the hours away
-- are those that leave it just short of damp, so it loads dry. Catches a record that stops while
-- unloaded, or a tile that loads showing what it was before.
T.test("irrigation_lines_dry_and_freeze_while_unloaded", {
    spOnly = "a multiplayer server keeps the chunk loaded after the character leaves",
    timeoutSeconds = T.RELOAD_SECONDS,
    run = function(self)
        local rows = T.row(self, 2)
        if not rows then return end
        local tile, beside = rows[1][1], rows[1][2]
        self.tile = tile
        -- Beside the tile, not over it: a floor above would roof it.
        T.placeTank(self, beside, "raised", TANK_LITRES)
        tile.fields = copyField(tapOn(), { holed = true })
        T.placeLine(self, { tile }, "iron")
        flow(self, tile, 1, { tile }, "watered")
        T.waitFor(self, function() return clientSprite(tile) == Sprites.pipe("iron", true, 0) end,
            "this client's copy of the watered tile, wet")
        self.dryPerHour = Lines.SOAK_DRY_OUT / 24
        self.hours = (Lines.HOLE_RATE * Lines.POINTS_PER_LITRE - Lines.DAMP / 2) / self.dryPerHour
        T.reload(self, tile, function()
            T.batch(function()
                -- Caught up to now first, so the soak dries for exactly the hours away.
                T.read(self, "lines.age", { tiles = T.tiles({ tile }), hours = 0 }, "left")
                T.server(self, "lines.temperature", { celsius = Lines.HARD_FREEZE_CELSIUS - 1 })
                T.server(self, "lines.pinRoll", {})
                T.read(self, "lines.age", { tiles = T.tiles({ tile }), hours = self.hours }, "away")
            end)
        end)
        T.waitForLines(self, { tile }, "this client's copy of the tile, loaded again")
        T.readLines(self, { tile }, "back")
    end,
    validate = function(self)
        local watered, left = self.reads.watered.tiles[1].record, self.reads.left.tiles[1]
        local away, back = self.reads.away.tiles[1], self.reads.back.tiles[1]
        expect((self.chunkLoads or 0) > 0, "the tile's chunk came back without LoadChunk, from a cache")
        expect(watered.full and left.record.soak >= Lines.DAMP, "the hour's flow left the tile full "
            .. tostring(watered.full) .. ", soak " .. tostring(left.record.soak))
        expect(left.sprite == nil, "the server kept the tile's chunk loaded")
        expectNear("the soak after the hours away", away.record.soak,
            left.record.soak - self.hours * self.dryPerHour, POINTS)
        expect(away.record.cracked, "the full pipe came through the hard freeze whole")
        expect(back.record.cracked and not back.record.wet, "the server's record, loaded again: cracked "
            .. tostring(back.record.cracked) .. ", wet " .. tostring(back.record.wet))
        expect(back.sprite == Sprites.pipe("iron", false, 0), "the server shows the dried tile as " .. tostring(back.sprite))
        local summary = T.lineSummary(self.tile)
        expect(summary.cracked, "this client's summary of the tile isn't cracked")
        expectNear("this client's soak", summary.soak, back.record.soak, 1)
        expect(clientSprite(self.tile) == Sprites.pipe("iron", false, 0),
            "this client shows the dried tile as " .. tostring(clientSprite(self.tile)))
    end,
})

-- Upkeep --------------------------------------------------------------------------------------------

-- Tape over a crack mends it, and the tile remembers the patch.
T.test("irrigation_lines_patch_crack", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 1)
        if not rows then return end
        local tile = rows[1][1]
        self.tile = tile
        tile.fields = { cracked = true }
        T.placeLine(self, { tile }, "plastic")
        T.give(self, "tape", { { type = "Base.DuctTape" } })
        T.goNextTo(self, tile.square)
        T.step(function() self.usesBefore = self.items.tape[1]:getCurrentUses() end)
        useJob(self, tile, LineJobs.PATCH, nil, "patch", true)
        readUntil(self, { tile }, "patched", function(tiles) return not tiles[1].record.cracked end)
        T.waitFor(self, function() return self.items.tape[1]:getCurrentUses() < self.usesBefore end, "this client's tape, used")
        T.waitForLines(self, { tile }, "this client's summary of the patch", function(summary) return summary.patches == 1 end)
    end,
    validate = function(self)
        expectOffered(self, "patch")
        local record = recordOf(self, "patched", 1)
        expect(not record.cracked and record.patches == 1, "the patch left cracked " .. tostring(record.cracked)
            .. ", patches " .. tostring(record.patches))
        expect(self.items.tape[1]:getCurrentUses() == self.usesBefore - 1, "the patch didn't take one use of tape")
        local described = LineMenu.describe(T.lineSummary(self.tile))
        expect(described:find(getText("IGUI_EnhancedIrrigation_PatchedOnce"), 1, true) ~= nil,
            "the menu doesn't say patched once: " .. described)
    end,
})

-- Draining from a middle tile empties the whole line onto the ground there: that tile's soil shows
-- wet, and no tile's soil soaks. Catches a drain limited to an end, one that leaves water standing,
-- or one that rots a bed.
T.test("irrigation_lines_drain_from_the_middle", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        self.tiles = rows[1]
        for _, tile in ipairs(self.tiles) do
            tile.fields = { full = true }
        end
        T.placeLine(self, self.tiles, "lead")
        T.goNextTo(self, self.tiles[2].square)
        useJob(self, self.tiles[2], LineJobs.DRAIN, nil, "drain the middle", true)
        readUntil(self, self.tiles, "drained", function(tiles)
            for _, tile in ipairs(tiles) do
                if tile.record.full then
                    return false
                end
            end
            return true
        end)
        T.waitFor(self, function()
            return clientSprite(self.tiles[2]) == Sprites.pipe("lead", true, Sprites.EAST + Sprites.WEST)
        end, "this client's copy of the drained tile, wet")
    end,
    validate = function(self)
        expectOffered(self, "drain the middle")
        local shapes = { Sprites.EAST, Sprites.EAST + Sprites.WEST, Sprites.WEST }
        for i, tile in ipairs(self.reads.drained.tiles) do
            expect(not tile.record.full, "tile " .. i .. " is still full")
            expectNear("tile " .. i .. "'s soak", tile.record.soak, 0, POINTS)
            local wet = i == 2
            expect(tile.record.wet == wet, "the server shows tile " .. i .. (wet and " dry" or " wet"))
            expect(clientSprite(self.tiles[i]) == Sprites.pipe("lead", wet, shapes[i]),
                "this client shows tile " .. i .. " as " .. tostring(clientSprite(self.tiles[i])))
        end
    end,
})

-- Taking up gives back what the tile took unless it is scrap: a patched tap tile gives the tap's
-- length alone, a cracked tile nothing, a whole one its length, a clay tile both its segments.
-- What's left reshapes. Catches scrap given back, the tap's pipe lost, or a clay segment kept.
T.test("irrigation_lines_take_up_returns_items", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 4)
        if not rows then return end
        local tapTile, cracked, clay, whole = rows[1][1], rows[1][2], rows[1][3], rows[1][4]
        self.tiles = rows[1]
        tapTile.fields = copyField(tapOn("iron"), { patches = 1 })
        cracked.fields = { cracked = true }
        tapTile.material, cracked.material, clay.material, whole.material = "iron", "iron", "clay", "iron"
        T.placeLine(self, self.tiles)
        T.goNextTo(self, tapTile.square)
        useJob(self, tapTile, LineJobs.TAKE_UP, nil, "take up the tap", true)
        T.waitFor(self, function() return T.lineObject(tapTile) == nil end, "this client to lose the tap tile")
        T.waitFor(self, function() return clientSprite(cracked) == Sprites.pipe("iron", false, Sprites.EAST) end,
            "this client's copy of the cracked tile, reshaped")
        for _, tile in ipairs({ cracked, clay, whole }) do
            T.goNextTo(self, tile.square)
            useJob(self, tile, LineJobs.TAKE_UP, nil, "take up the " .. tile.material, true)
            T.waitFor(self, function() return T.lineObject(tile) == nil end, "this client to lose a taken-up tile")
        end
        T.readLines(self, self.tiles, "gone")
        T.count(self, "back", { Pipes.KINDS.iron.item, Pipes.KINDS.clay.item })
    end,
    validate = function(self)
        expectOffered(self, "take up the tap")
        local iron, clay = Pipes.KINDS.iron, Pipes.KINDS.clay
        -- The tap's length and the whole tile's.
        local ironWanted = 2 * iron.perLength
        expect(self.counts.back[iron.item] == ironWanted, "the iron tiles gave back "
            .. tostring(self.counts.back[iron.item]) .. " iron pipe, not " .. ironWanted)
        expect(self.counts.back[clay.item] == clay.perLength, "the clay tile gave back "
            .. tostring(self.counts.back[clay.item]) .. " segments, not " .. clay.perLength)
        for i, tile in ipairs(self.reads.gone.tiles) do
            expect(tile.record == nil and tile.sprite == nil, "tile " .. i .. " is still there")
        end
    end,
})

-- An iron pipe laid worn comes back from Take Up as worn as it went in. Catches laying and taking
-- up a weapon mending it.
T.test("irrigation_lines_take_up_keeps_the_pipes_condition", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 1)
        if not rows then return end
        local tile = rows[1][1]
        T.trackLines(self, { tile })
        T.placeTank(self, tile, "above", 0)
        self.worn = math.floor(instanceItem(Pipes.KINDS.iron.item):getConditionMax() / 2)
        T.give(self, "pipe", { { type = Pipes.KINDS.iron.item, condition = self.worn } })
        T.goNextTo(self, tile.square)
        T.step(function()
            local playerNum = T.player():getPlayerNum()
            EnhancedIrrigation.LineCursor.start(playerNum, "iron")
            local cursor = getCell():getDrag(playerNum)
            T.defer(self, function() getCell():setDrag(nil, playerNum) end)
            T.face(tile.square)
            cursor:tryBuild(tile.x, tile.y, tile.z)
        end)
        T.waitForLines(self, { tile }, "this client's copy of the laid tile")
        useJob(self, tile, LineJobs.TAKE_UP, nil, "take up", true)
        T.waitFor(self, function()
            self.back = T.player():getInventory():getFirstTypeRecurse(Pipes.KINDS.iron.item)
            return self.back ~= nil
        end, "this client's copy of the pipe taken up")
    end,
    validate = function(self)
        expectOffered(self, "take up")
        expect(self.back:getCondition() == self.worn, "the pipe came back at condition " .. self.back:getCondition()
            .. ", laid at " .. self.worn)
    end,
})

-- A sledgehammer smashes a line tile as it smashes any object, through vanilla's Destroy cursor
-- and action: the tile's record goes with it, tap and all, and its neighbours reshape.
T.test("irrigation_lines_sledgehammer_reshapes_neighbours", {
    instant = true,
    run = function(self)
        local rows = T.row(self, 3)
        if not rows then return end
        local west, middle, east = rows[1][1], rows[1][2], rows[1][3]
        self.tiles = { west, middle, east }
        middle.fields = tapOn("iron")
        T.placeLine(self, self.tiles, "iron")
        T.give(self, "sledge", { { type = "Base.Sledgehammer" } })
        T.goNextTo(self, middle.square)
        -- The cursor lists what it can smash on the square it hovers, once the character sees it.
        T.waitFor(self, function()
            self.cursor = self.cursor or ISDestroyCursor:new(T.player(), false, self.items.sledge[1])
            self.cursor:isValid(middle.square)
            for i, object in ipairs(self.cursor:getObjectList()) do
                if Lines.isLine(object) then
                    self.cursor.objectIndex = i
                    return true
                end
            end
            return false
        end, "the Destroy cursor offering the line tile")
        T.step(function() self.cursor:create(middle.x, middle.y, middle.z) end)
        T.waitFor(self, function() return T.lineObject(middle) == nil end, "this client to lose the smashed tile")
        T.waitFor(self, function()
            return shapeOf(clientSprite(west)) == 0 and shapeOf(clientSprite(east)) == 0
        end, "this client's copies of the neighbours, reshaped")
        T.readLines(self, self.tiles, "after")
    end,
    validate = function(self)
        local after = self.reads.after.tiles
        expect(after[2].record == nil and after[2].sprite == nil, "the smashed tile is still there")
        for _, i in ipairs({ 1, 3 }) do
            local tile = after[i]
            expect(shapeOf(tile.sprite) == 0, "the server shapes neighbour " .. i .. " "
                .. tostring(shapeOf(tile.sprite)) .. ", not alone")
            expect(tile.record and tile.record.tiles == 1 and not tile.record.tap,
                "neighbour " .. i .. " is still in a line, or tapped")
        end
    end,
})

-- Waits for the UI to draw a few times: it draws at its own rate, slower than the game's frames
-- in a test run, and the plant info sizes itself only as it draws.
local function uiDraws(self, what)
    T.step(function()
        if not self.draws then
            local count = function() self.draws = self.draws + 1 end
            Events.OnPostUIDraw.Add(count)
            T.defer(self, function() Events.OnPostUIDraw.Remove(count) end)
        end
        self.draws = 0
    end)
    T.waitFor(self, function() return self.draws >= 3 end, what)
end

-- The soil line --------------------------------------------------------------------------------------

-- The heights of the plant info windows once drawn.
local function heights(self)
    return { self.windows[1].farmingPanel:getHeight(), self.windows[2].farmingPanel:getHeight() }
end

-- With Agriculture 2 the plant info names wet soil under the crop, one line taller than a dry
-- crop's; below it, the wet crop's info looks like a dry one's. Four crops on a line whose soil is
-- damp, soaked, waterlogged and dry; the plant info windows open as Plant Info opens them
-- (ISPlantInfoAction) for the waterlogged crop and the dry one.
T.test("irrigation_lines_plant_info_names_the_soil", {
    run = function(self)
        local rows = T.row(self, 4, { indoors = true })
        if not rows then return end
        self.tiles = rows[1]
        local soaks = { 5, 20, 40, 0 }
        for i, tile in ipairs(self.tiles) do
            tile.fields = { soak = soaks[i] }
        end
        T.placeLine(self, self.tiles, "plastic")
        for _, tile in ipairs(self.tiles) do
            T.plant(self, tile, 50)
        end
        T.goNextTo(self, self.tiles[3].square)
        T.setPerk(self, Perks.Farming, PlantInfo.FARMING_LEVEL - 1)
        T.step(function()
            self.keys, self.windows = {}, {}
            for i, tile in ipairs(self.tiles) do
                local plant = CFarmingSystem.instance:getLuaObjectOnSquare(tile.square)
                if not T.need(self, plant, "this client's crop on tile " .. i) then return end
                self.keys[i] = PlantInfo.soilKeyOf(plant)
            end
            for i, tileIndex in ipairs({ 3, 4 }) do
                local plant = CFarmingSystem.instance:getLuaObjectOnSquare(self.tiles[tileIndex].square)
                local window = ISFarmingWindow:new(100 + 340 * (i - 1), 100, 320, 240, T.player(), plant)
                window:initialise()
                window:addToUIManager()
                window:setVisible(true)
                self.windows[i] = window
                T.defer(self, function() window:removeFromUIManager() end)
            end
        end)
        uiDraws(self, "the plant info windows to draw")
        T.step(function()
            self.unskilled = heights(self)
            T.setPerk(self, Perks.Farming, PlantInfo.FARMING_LEVEL)
        end)
        uiDraws(self, "the plant info windows to draw for the skilled")
        T.step(function() self.skilled = heights(self) end)
    end,
    validate = function(self)
        local want = { "IGUI_EnhancedIrrigation_Damp", "IGUI_EnhancedIrrigation_Soaked",
            "IGUI_EnhancedIrrigation_Waterlogged" }
        for i, wanted in ipairs(want) do
            expect(self.keys[i] == wanted, "soil under tile " .. i .. ": " .. tostring(self.keys[i]) .. ", not " .. wanted)
        end
        expect(self.keys[4] == nil, "dry soil is named " .. tostring(self.keys[4]))
        local level = PlantInfo.FARMING_LEVEL
        expect(self.skilled[1] > self.skilled[2], "with Agriculture " .. level .. " the wet crop's info is "
            .. self.skilled[1] .. " tall and the dry one's " .. self.skilled[2] .. ": no soil line")
        expect(self.unskilled[1] == self.unskilled[2], "below Agriculture " .. level .. " the wet crop's info is "
            .. self.unskilled[1] .. " tall and the dry one's " .. self.unskilled[2])
    end,
})
